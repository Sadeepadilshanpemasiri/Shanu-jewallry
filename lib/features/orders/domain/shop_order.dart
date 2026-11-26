import '../../customers/domain/customer.dart';

enum OrderStatus {
  pending,
  confirmed,
  packed,
  shipped,
  delivered,
  cancelled,
  returned,
  failedDelivery;

  String get label => switch (this) {
    pending => 'Pending',
    confirmed => 'Confirmed',
    packed => 'Packed',
    shipped => 'Shipped',
    delivered => 'Delivered',
    cancelled => 'Cancelled',
    returned => 'Returned',
    failedDelivery => 'Failed delivery',
  };

  List<OrderStatus> get next => switch (this) {
    pending => [confirmed, cancelled],
    confirmed => [packed, cancelled],
    packed => [shipped, cancelled],
    shipped => [delivered, failedDelivery, returned, cancelled],
    delivered => [returned],
    failedDelivery => [shipped, returned, cancelled],
    _ => const [],
  };

  bool get needsReason =>
      this == cancelled || this == returned || this == failedDelivery;

  CustomerStats contribution({
    required bool everShipped,
    bool everFailed = false,
  }) => CustomerStats(
    total: 1,
    delivered: this == delivered ? 1 : 0,
    cancelled: this == cancelled ? 1 : 0,
    cancelledAfterShipping: this == cancelled && everShipped ? 1 : 0,
    returned: this == returned ? 1 : 0,
    failed: this == failedDelivery || everFailed ? 1 : 0,
  );
}

enum OrderPayment {
  cod,
  bankTransfer,
  paid;

  String get label => switch (this) {
    cod => 'Cash on delivery',
    bankTransfer => 'Bank transfer',
    paid => 'Paid',
  };
}

enum StockTiming {
  confirmed,
  packed;

  String get label => this == confirmed ? 'On confirmation' : 'On packing';
  OrderStatus get status =>
      this == confirmed ? OrderStatus.confirmed : OrderStatus.packed;
}

enum CustomerReview { none, proceed, advance }

class OrderLine {
  const OrderLine(
    this.productId,
    this.name,
    this.sku,
    this.quantity,
    this.price,
    this.cost, {
    this.category = '',
  });
  final String productId, name, sku, category;
  final int quantity, price, cost;

  Map<String, Object> toJson() => {
    'productId': productId,
    'name': name,
    'sku': sku,
    'qty': quantity,
    'price': price,
    'cost': cost,
    if (category.isNotEmpty) 'category': category,
  };

  factory OrderLine.fromJson(Map<String, dynamic> data) => OrderLine(
    data['productId'] as String,
    data['name'] as String,
    data['sku'] as String,
    data['qty'] as int,
    data['price'] as int,
    data['cost'] as int,
    category: data['category'] as String? ?? '',
  );
}

class OrderTotals {
  const OrderTotals({
    required this.subtotal,
    required this.delivery,
    required this.discount,
  });
  final int subtotal, delivery, discount;
  int get total => subtotal + delivery - discount;

  void validate() {
    if (subtotal < 0 || delivery < 0 || discount < 0 || total < 0) {
      throw const OrderFailure(
        'Discount cannot exceed the subtotal plus delivery.',
      );
    }
  }
}

class OrderEvent {
  const OrderEvent({
    required this.status,
    required this.note,
    required this.actor,
    required this.at,
  });
  final OrderStatus status;
  final String note, actor;
  final DateTime? at;
}

class ShopOrder {
  const ShopOrder({
    required this.id,
    required this.number,
    required this.customer,
    required this.lines,
    required this.totals,
    required this.status,
    required this.payment,
    required this.advance,
    required this.timing,
    required this.source,
    required this.notes,
    required this.courier,
    required this.tracking,
    required this.createdAt,
    required this.history,
    required this.restockAvailable,
    this.shippedAt,
    this.deliveredAt,
    this.cancelledAt,
  });

  final String id, number, source, notes, courier, tracking;
  final Customer customer;
  final List<OrderLine> lines;
  final OrderTotals totals;
  final OrderStatus status;
  final OrderPayment payment;
  final int advance;
  final StockTiming timing;
  final DateTime? createdAt, shippedAt, deliveredAt, cancelledAt;
  final List<OrderEvent> history;
  final bool restockAvailable;
  DateTime? eventDate(OrderStatus target) {
    final recorded = switch (target) {
      OrderStatus.shipped => shippedAt,
      OrderStatus.delivered => deliveredAt,
      OrderStatus.cancelled => cancelledAt,
      _ => null,
    };
    return recorded ??
        history.reversed
            .where((event) => event.status == target && event.at != null)
            .firstOrNull
            ?.at;
  }

  int get remaining =>
      payment == OrderPayment.paid ? 0 : totals.total - advance;
}

class OrderDraft {
  const OrderDraft({
    required this.customer,
    required this.quantities,
    required this.expectedPrices,
    required this.delivery,
    required this.discount,
    required this.advance,
    required this.payment,
    required this.timing,
    required this.review,
    required this.source,
    required this.notes,
    required this.confirmImmediately,
    this.overrideBlacklist = false,
  });
  final Customer customer;
  final Map<String, int> quantities, expectedPrices;
  final int delivery, discount, advance;
  final OrderPayment payment;
  final StockTiming timing;
  final CustomerReview review;
  final String source, notes;
  final bool confirmImmediately, overrideBlacklist;
}

class OrderUpdate {
  const OrderUpdate(
    this.status, {
    this.note = '',
    this.courier = '',
    this.tracking = '',
    this.restock = false,
  });
  final OrderStatus status;
  final String note, courier, tracking;
  final bool restock;
}

class OrderFailure implements Exception {
  const OrderFailure(this.message);
  final String message;
}
