import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../../customers/data/firestore_customer_repository.dart';
import '../../customers/domain/customer.dart';
import '../../inventory/domain/inventory_product.dart';
import '../../shipping/domain/courier.dart';
import '../../../core/data/cursor_page.dart';
import '../../../core/data/firestore_cursor.dart';
import '../domain/order_repository.dart';
import '../domain/shop_order.dart';

typedef _Document = DocumentReference<Map<String, dynamic>>;
typedef _Snapshot = DocumentSnapshot<Map<String, dynamic>>;

class FirestoreOrderRepository implements OrderRepository {
  FirestoreOrderRepository(this._db, this._auth);
  final FirebaseFirestore _db;
  final FirebaseAuth _auth;

  CollectionReference<Map<String, dynamic>> get _orders =>
      _db.collection('orders');
  _Document _customer(String phone) => _db.collection('customers').doc(phone);
  _Document _product(String id) => _db.collection('products').doc(id);

  String get _actor =>
      _auth.currentUser?.uid ??
      (throw const OrderFailure('Sign in to manage orders.'));

  @override
  Future<CursorPage<ShopOrder>> readOrders({bool newest = true}) =>
      readFirestorePage(
        _orders.orderBy('createdAt', descending: newest),
        _parse,
      );

  @override
  Stream<List<ShopOrder>> watchOrders({String? phone}) {
    final query = phone == null
        ? _orders.orderBy('createdAt', descending: true)
        : _orders
              .where('customerId', isEqualTo: phone)
              .orderBy('createdAt', descending: true);
    return query.snapshots().map(
      (snapshot) => snapshot.docs.map(_parse).toList(),
    );
  }

  @override
  Future<ShopOrder?> getOrder(String id) async {
    final snapshot = await _orders.doc(id).get();
    return snapshot.exists ? _parse(snapshot) : null;
  }

  OrderStatus _status(Map<String, dynamic> data) =>
      OrderStatus.values.byName(data['status'] as String);

  List<OrderLine> _lines(Map<String, dynamic> data) => (data['items'] as List)
      .map(
        (value) => OrderLine.fromJson(Map<String, dynamic>.from(value as Map)),
      )
      .toList();

  ShopOrder _parse(_Snapshot document) {
    final data = document.data()!;
    final history = (data['statusHistory'] as List).map((raw) {
      final event = Map<String, dynamic>.from(raw as Map);
      return OrderEvent(
        status: _status(event),
        note: event['note'] as String,
        actor: event['actorUid'] as String,
        at: (event['at'] as Timestamp?)?.toDate(),
      );
    }).toList();
    return ShopOrder(
      id: document.id,
      number: data['orderNo'] as String,
      customer: Customer.fromJson(
        data['customerId'] as String,
        Map<String, dynamic>.from(data['customer'] as Map),
      ),
      lines: _lines(data),
      totals: OrderTotals(
        subtotal: data['subtotal'] as int,
        delivery: data['deliveryCharge'] as int,
        discount: data['discount'] as int,
      ),
      status: _status(data),
      payment: OrderPayment.values.byName(data['paymentMethod'] as String),
      advance: data['advance'] as int,
      timing: StockTiming.values.byName(data['stockTiming'] as String),
      source: data['source'] as String,
      notes: data['notes'] as String,
      courier: data['courier'] as String? ?? '',
      tracking: data['trackingId'] as String? ?? '',
      createdAt: (data['createdAt'] as Timestamp?)?.toDate(),
      shippedAt: (data['shippedAt'] as Timestamp?)?.toDate(),
      deliveredAt: (data['deliveredAt'] as Timestamp?)?.toDate(),
      cancelledAt: (data['cancelledAt'] as Timestamp?)?.toDate(),
      history: history,
      restockAvailable:
          data['stockDeducted'] == true && data['stockRestored'] != true,
    );
  }

  @override
  Future<String> create(OrderDraft draft) async {
    final phone = draft.customer.phone;
    _validateQuantities(draft);
    final order = _orders.doc();
    final counter = _db.doc('settings/order_sequence');
    final actor = _actor;
    return _db.runTransaction((transaction) async {
      final customer = await transaction.get(_customer(phone));
      final sequence = await transaction.get(counter);
      final products = await _readProducts(transaction, draft.quantities.keys);
      final known = customer.exists
          ? Customer.fromJson(phone, customer.data()!)
          : draft.customer;
      if (known.name.trim().isEmpty ||
          known.address.trim().isEmpty ||
          known.city.trim().isEmpty) {
        throw const OrderFailure('Enter the customer name, address, and city.');
      }
      if (known.needsReview && draft.review == CustomerReview.none) {
        throw const OrderFailure(
          'Review this customer’s history before saving the order.',
        );
      }
      if (known.blacklisted && !draft.overrideBlacklist) {
        throw const OrderFailure(
          'Explicitly override this customer’s blacklist before continuing.',
        );
      }
      final lines = _draftLines(products, draft);
      final totals = _draftTotals(lines, draft);
      _validatePayment(
        totals.total,
        draft.advance,
        draft.payment,
        requiresAdvance: draft.review == CustomerReview.advance,
        confirm: draft.confirmImmediately,
      );
      final nextNumber = ((sequence.data()?['last'] as int?) ?? 0) + 1;
      final orderNo = 'JB-${nextNumber.toString().padLeft(6, '0')}';
      final status = draft.confirmImmediately
          ? OrderStatus.confirmed
          : OrderStatus.pending;
      final deduct = status == draft.timing.status;
      if (deduct) {
        _writeStock(
          transaction,
          products,
          lines,
          order.id,
          orderNo,
          actor,
          restore: false,
        );
      }
      transaction.set(counter, {'last': nextNumber});
      transaction.set(customer.reference, {
        if (!customer.exists) ...{
          ...customerFields(known),
          'createdAt': FieldValue.serverTimestamp(),
        },
        ...(known.stats + status.contribution(everShipped: false)).toJson(),
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
      transaction.set(order, {
        'orderNo': orderNo,
        'customerId': phone,
        'customer': {
          'name': known.name,
          'phone': phone,
          'address': known.address,
          'city': known.city,
        },
        'items': lines.map((line) => line.toJson()).toList(),
        'subtotal': totals.subtotal,
        'deliveryCharge': totals.delivery,
        'discount': totals.discount,
        'total': totals.total,
        'paymentMethod': draft.payment.name,
        'advance': draft.advance,
        'paymentStatus': _paymentStatus(
          draft.payment,
          draft.advance,
          totals.total,
        ),
        'status': status.name,
        'statusChangedAt': FieldValue.serverTimestamp(),
        'stockTiming': draft.timing.name,
        'stockDeducted': deduct,
        'stockRestored': false,
        'requiresAdvance': draft.review == CustomerReview.advance,
        'customerReview': draft.review.name,
        'blacklistOverride': draft.overrideBlacklist,
        'source': draft.source.trim(),
        'notes': draft.notes.trim(),
        'statusHistory': [
          _event(OrderStatus.pending, 'Order created', actor),
          if (status == OrderStatus.confirmed)
            _event(status, 'Confirmed during entry', actor),
        ],
        'createdAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      });
      return orderNo;
    });
  }

  @override
  Future<String> updatePending(String id, OrderDraft draft) async {
    _validateQuantities(draft);
    final reference = _orders.doc(id);
    return _db.runTransaction((transaction) async {
      final data = (await transaction.get(reference)).data();
      if (data == null || _status(data) != OrderStatus.pending) {
        throw const OrderFailure(
          'Items and charges can only be edited while the order is pending.',
        );
      }
      final products = await _readProducts(transaction, draft.quantities.keys);
      final lines = _draftLines(products, draft);
      final totals = _draftTotals(lines, draft);
      _validatePayment(
        totals.total,
        draft.advance,
        draft.payment,
        requiresAdvance: data['requiresAdvance'] == true,
        confirm: false,
      );
      transaction.update(reference, {
        'items': lines.map((line) => line.toJson()).toList(),
        'subtotal': totals.subtotal,
        'deliveryCharge': totals.delivery,
        'discount': totals.discount,
        'total': totals.total,
        'paymentMethod': draft.payment.name,
        'advance': draft.advance,
        'paymentStatus': _paymentStatus(
          draft.payment,
          draft.advance,
          totals.total,
        ),
        'stockTiming': draft.timing.name,
        'source': draft.source.trim(),
        'notes': draft.notes.trim(),
        'updatedAt': FieldValue.serverTimestamp(),
      });
      return data['orderNo'] as String;
    });
  }

  OrderTotals _draftTotals(List<OrderLine> lines, OrderDraft draft) =>
      OrderTotals(
        subtotal: lines.fold(
          0,
          (amount, item) => amount + item.price * item.quantity,
        ),
        delivery: draft.delivery,
        discount: draft.discount,
      )..validate();

  List<OrderLine> _draftLines(List<_Snapshot> products, OrderDraft draft) {
    return products.map((product) {
      final data = product.data();
      final quantity = draft.quantities[product.id]!;
      if (data == null ||
          data['isActive'] != true ||
          (data['stockQty'] as int) < quantity) {
        throw const OrderFailure(
          'A selected product no longer has enough stock.',
        );
      }
      final price = data['sellingPrice'] as int;
      if (draft.expectedPrices[product.id] != price) {
        throw const OrderFailure(
          'A price changed. Review the current totals and try again.',
        );
      }
      return OrderLine(
        product.id,
        data['name'] as String,
        data['sku'] as String,
        quantity,
        price,
        data['costPrice'] as int,
        category: data['category'] as String? ?? '',
      );
    }).toList();
  }

  void _validateQuantities(OrderDraft draft) {
    if (normalizeSriLankanPhone(draft.customer.phone) != draft.customer.phone ||
        draft.quantities.isEmpty ||
        draft.quantities.length > 6 ||
        draft.quantities.values.any((qty) => qty < 1 || qty > maxStock)) {
      throw const OrderFailure(
        'Check the phone number and select 1–6 different products.',
      );
    }
  }

  @override
  Future<void> transition(String id, OrderUpdate update) async {
    final order = _orders.doc(id);
    final actor = _actor;
    final next = update.status;
    final note = update.note.trim();
    if (next.needsReason && note.isEmpty) {
      throw const OrderFailure('Enter a reason for this status change.');
    }
    final courier = update.courier.trim();
    final tracking = update.tracking.trim();
    _Document? waybill;
    if (next == OrderStatus.shipped) {
      if (courier.isEmpty ||
          courier.length > 80 ||
          normalizedWaybill(tracking) == null) {
        throw const OrderFailure('Enter a courier and a valid parcel waybill.');
      }
      waybill = _db
          .collection('waybills')
          .doc(waybillDocumentId(courier, tracking));
      final previousAssignments = await _orders
          .where('trackingId', isEqualTo: tracking)
          .get();
      if (previousAssignments.docs.any(
        (record) =>
            record.id != id &&
            courierKey(record.data()['courier'] as String? ?? '') ==
                courierKey(courier),
      )) {
        throw const OrderFailure(
          'This waybill already belongs to another order for this courier.',
        );
      }
    }

    await _db.runTransaction((transaction) async {
      final data = (await transaction.get(order)).data();
      if (data == null) {
        throw const OrderFailure('This order no longer exists.');
      }
      final previous = _status(data);
      if (next == previous) {
        if (waybill != null &&
            (courierKey(data['courier'] as String? ?? '') !=
                    courierKey(courier) ||
                normalizedWaybill(data['trackingId'] as String? ?? '') !=
                    normalizedWaybill(tracking))) {
          throw const OrderFailure(
            'This order was already shipped with a different waybill.',
          );
        }
        return;
      }
      if (!previous.next.contains(next)) {
        throw const OrderFailure(
          'The order status has changed. Reopen the order.',
        );
      }
      if (next == OrderStatus.confirmed) {
        _validatePayment(
          data['total'] as int,
          data['advance'] as int,
          OrderPayment.values.byName(data['paymentMethod'] as String),
          requiresAdvance: data['requiresAdvance'] == true,
          confirm: true,
        );
      }
      final customer = await transaction.get(
        _customer(data['customerId'] as String),
      );
      if (!customer.exists) {
        throw const OrderFailure('The customer record could not be found.');
      }
      final profile = Customer.fromJson(customer.id, customer.data()!);
      final timing = StockTiming.values.byName(data['stockTiming'] as String);
      final deduct = next == timing.status && data['stockDeducted'] != true;
      final restore =
          update.restock &&
          (next == OrderStatus.returned || next == OrderStatus.cancelled) &&
          data['stockDeducted'] == true &&
          data['stockRestored'] != true;
      final reservation = waybill == null
          ? null
          : await transaction.get(waybill);
      if (reservation?.exists == true &&
          reservation?.data()?['orderId'] != id) {
        throw const OrderFailure(
          'This waybill already belongs to another order for this courier.',
        );
      }
      final lines = _lines(data);
      if (deduct || restore) {
        final products = await _readProducts(
          transaction,
          lines.map((line) => line.productId),
        );
        _writeStock(
          transaction,
          products,
          lines,
          id,
          data['orderNo'] as String,
          actor,
          restore: restore,
        );
      }
      if (waybill != null && reservation?.exists != true) {
        transaction.set(waybill, {
          'orderId': id,
          'courierKey': courierKey(courier),
          'trackingNormalized': normalizedWaybill(tracking),
          'createdAt': FieldValue.serverTimestamp(),
        });
      }
      final everShipped = data['shippedAt'] != null;
      final everFailed = (data['statusHistory'] as List).any(
        (event) => event['status'] == OrderStatus.failedDelivery.name,
      );
      final updatedStats =
          profile.stats -
          previous.contribution(
            everShipped: everShipped,
            everFailed: everFailed,
          ) +
          next.contribution(
            everShipped: next == OrderStatus.shipped || everShipped,
            everFailed: everFailed,
          );
      transaction.update(customer.reference, {
        ...updatedStats.toJson(),
        'updatedAt': FieldValue.serverTimestamp(),
      });
      transaction.update(order, {
        'status': next.name,
        'statusChangedAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
        'statusHistory': FieldValue.arrayUnion([_event(next, note, actor)]),
        if (deduct) 'stockDeducted': true,
        if (restore) 'stockRestored': true,
        if (next == OrderStatus.shipped) ...{
          'courier': courier,
          'trackingId': tracking,
          'waybillKey': waybill!.id,
          'shippedAt': FieldValue.serverTimestamp(),
        },
        if (next == OrderStatus.delivered)
          'deliveredAt': FieldValue.serverTimestamp(),
        if (next == OrderStatus.cancelled) ...{
          'cancelledAt': FieldValue.serverTimestamp(),
          'cancelReason': note,
        },
      });
    });
  }

  @override
  Future<void> updateDetails(
    String id, {
    required String notes,
    required OrderPayment payment,
    required int advance,
  }) async {
    final order = _orders.doc(id);
    await _db.runTransaction((transaction) async {
      final data = (await transaction.get(order)).data();
      if (data == null) {
        throw const OrderFailure('This order no longer exists.');
      }
      final total = data['total'] as int;
      _validatePayment(
        total,
        advance,
        payment,
        requiresAdvance: data['requiresAdvance'] == true,
        confirm:
            _status(data) != OrderStatus.pending && !_status(data).needsReason,
      );
      transaction.update(order, {
        'notes': notes.trim(),
        'paymentMethod': payment.name,
        'advance': advance,
        'paymentStatus': _paymentStatus(payment, advance, total),
        'updatedAt': FieldValue.serverTimestamp(),
      });
    });
  }

  Future<List<_Snapshot>> _readProducts(
    Transaction transaction,
    Iterable<String> ids,
  ) async {
    final snapshots = <_Snapshot>[];
    for (final id in ids) {
      snapshots.add(await transaction.get(_product(id)));
    }
    return snapshots;
  }

  void _writeStock(
    Transaction transaction,
    List<_Snapshot> products,
    List<OrderLine> lines,
    String orderId,
    String orderNo,
    String actor, {
    required bool restore,
  }) {
    final quantities = {
      for (final line in lines) line.productId: line.quantity,
    };
    for (final product in products) {
      final data = product.data();
      if (data == null || (!restore && data['isActive'] != true)) {
        throw const OrderFailure(
          'A product in this order is no longer available.',
        );
      }
      final delta = quantities[product.id]! * (restore ? 1 : -1);
      final balance = adjustedStock(data['stockQty'] as int, delta);
      final movement = _db.collection('stock_movements').doc();
      transaction.update(product.reference, {
        'stockQty': balance,
        'lastMovementId': movement.id,
        'updatedAt': FieldValue.serverTimestamp(),
      });
      transaction.set(movement, {
        'productId': product.id,
        'orderId': orderId,
        'qty': delta,
        'balance': balance,
        'actorUid': actor,
        'type': restore
            ? StockMovementType.returned.name
            : StockMovementType.stockOut.name,
        'reason': restore ? 'Restocked from $orderNo' : 'Order $orderNo',
        'createdAt': FieldValue.serverTimestamp(),
      });
    }
  }

  void _validatePayment(
    int total,
    int advance,
    OrderPayment payment, {
    required bool requiresAdvance,
    required bool confirm,
  }) {
    if (advance < 0 || advance > total) {
      throw const OrderFailure('Advance cannot exceed the order total.');
    }
    if (requiresAdvance &&
        confirm &&
        advance == 0 &&
        payment != OrderPayment.paid) {
      throw const OrderFailure(
        'Record the advance payment before confirming this order.',
      );
    }
  }

  String _paymentStatus(OrderPayment payment, int advance, int total) =>
      payment == OrderPayment.paid || advance == total
      ? 'paid'
      : advance > 0
      ? 'partial'
      : 'unpaid';

  Map<String, Object> _event(OrderStatus status, String note, String actor) => {
    'status': status.name,
    'note': note,
    'actorUid': actor,
    'at': Timestamp.now(),
  };
}
