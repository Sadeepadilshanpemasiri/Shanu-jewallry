import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jewellery_business_manager/core/services/firebase_config.dart';
import 'package:jewellery_business_manager/features/customers/data/firestore_customer_repository.dart';
import 'package:jewellery_business_manager/features/customers/domain/customer.dart';
import 'package:jewellery_business_manager/features/inventory/data/firestore_inventory_repository.dart';
import 'package:jewellery_business_manager/features/inventory/domain/inventory_product.dart';
import 'package:jewellery_business_manager/features/orders/data/firestore_order_repository.dart';
import 'package:jewellery_business_manager/features/orders/domain/shop_order.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test(
    'browser repository commits and restores stock for a six-product order',
    () async {
      await FirebaseConfig.initialize();
      final auth = FirebaseAuth.instance;
      await auth.signInWithEmailAndPassword(
        email: 'owner@jewellery.test',
        password: 'JewelleryDemo123',
      );
      final db = FirebaseFirestore.instance;
      final inventory = FirestoreInventoryRepository(
        db,
        FirebaseStorage.instance,
        auth,
      );
      final orders = FirestoreOrderRepository(db, auth);
      final people = FirestoreCustomerRepository(db);
      const phone = '+94770000001';
      const customer = Customer(
        phone: phone,
        name: 'Phase 3 Test',
        address: 'Test street',
        city: 'Colombo',
      );

      for (var index = 0; index < 6; index++) {
        await inventory.save(
          openingQuantity: 2,
          details: ProductDetails(
            name: 'Order test $index',
            sku: 'ORDER-TEST-$index',
            category: 'Rings',
            metal: 'Silver',
            description: '',
            cost: 10000,
            price: 25000,
            threshold: 1,
            variants: [],
            images: [],
          ),
        );
      }
      final products = await inventory.watchProducts().firstWhere(
        (items) =>
            items
                .where((item) => item.details.sku.startsWith('ORDER-TEST-'))
                .length ==
            6,
      );
      final chosen = products
          .where((item) => item.details.sku.startsWith('ORDER-TEST-'))
          .toList();
      final draft = OrderDraft(
        customer: customer,
        quantities: {for (final item in chosen) item.id: 1},
        expectedPrices: {
          for (final item in chosen) item.id: item.details.price,
        },
        delivery: 30000,
        discount: 1000,
        advance: 0,
        payment: OrderPayment.cod,
        timing: StockTiming.confirmed,
        review: CustomerReview.none,
        source: 'WhatsApp',
        notes: '',
        confirmImmediately: true,
      );
      final number = await orders.create(draft);
      expect(number, 'JB-000001');
      final order =
          (await orders
                  .watchOrders(phone: phone)
                  .firstWhere((items) => items.isNotEmpty))
              .single;
      expect(order.status, OrderStatus.confirmed);
      expect(order.totals.total, 179000);
      expect(order.history.map((event) => event.status), [
        OrderStatus.pending,
        OrderStatus.confirmed,
      ]);
      for (final item in chosen) {
        expect(
          (await db.collection('products').doc(item.id).get()).get('stockQty'),
          1,
        );
      }

      await expectLater(
        orders.transition(order.id, const OrderUpdate(OrderStatus.delivered)),
        throwsA(isA<OrderFailure>()),
      );

      await orders.transition(order.id, const OrderUpdate(OrderStatus.packed));
      await orders.transition(
        order.id,
        const OrderUpdate(
          OrderStatus.shipped,
          courier: 'Courier',
          tracking: 'TEST-ID',
        ),
      );
      await orders.transition(
        order.id,
        const OrderUpdate(
          OrderStatus.cancelled,
          note: 'Test return',
          restock: true,
        ),
      );
      await orders.transition(
        order.id,
        const OrderUpdate(OrderStatus.cancelled, note: 'Retry', restock: true),
      );
      for (final item in chosen) {
        expect(
          (await db.collection('products').doc(item.id).get()).get('stockQty'),
          2,
        );
      }
      final profile = (await people.watchCustomers().firstWhere(
        (items) => items.any(
          (item) => item.phone == phone && item.stats.cancelled == 1,
        ),
      )).firstWhere((item) => item.phone == phone);
      expect(profile.stats.total, 1);
      expect(profile.stats.cancelledAfterShipping, 1);
      await expectLater(orders.create(draft), throwsA(isA<OrderFailure>()));
      final first = chosen.first;
      OrderDraft pendingDraft(int quantity) => OrderDraft(
        customer: customer,
        quantities: {first.id: quantity},
        expectedPrices: {first.id: first.details.price},
        delivery: 10000,
        discount: 0,
        advance: 0,
        payment: OrderPayment.cod,
        timing: StockTiming.packed,
        review: CustomerReview.advance,
        source: 'WhatsApp',
        notes: '',
        confirmImmediately: false,
      );
      final secondNumber = await orders.create(pendingDraft(1));
      expect(secondNumber, 'JB-000002');
      final pending =
          (await orders
                  .watchOrders(phone: phone)
                  .firstWhere(
                    (items) => items.any((item) => item.number == secondNumber),
                  ))
              .firstWhere((item) => item.number == secondNumber);
      await orders.updatePending(pending.id, pendingDraft(2));
      await expectLater(
        orders.transition(pending.id, const OrderUpdate(OrderStatus.confirmed)),
        throwsA(isA<OrderFailure>()),
      );
      await orders.updateDetails(
        pending.id,
        notes: 'Deposit received',
        payment: OrderPayment.cod,
        advance: 10000,
      );
      await orders.transition(
        pending.id,
        const OrderUpdate(OrderStatus.confirmed),
      );
      expect(
        (await db.collection('products').doc(first.id).get()).get('stockQty'),
        2,
      );
      await orders.transition(
        pending.id,
        const OrderUpdate(OrderStatus.packed),
      );
      expect(
        (await db.collection('products').doc(first.id).get()).get('stockQty'),
        0,
      );
      final newest = await orders.readOrders();
      final oldest = await orders.readOrders(newest: false);
      expect(newest.items.map((item) => item.number), [secondNumber, number]);
      expect(oldest.items.map((item) => item.number), [number, secondNumber]);

      for (var index = 0; index < 26; index++) {
        await people.saveCustomer(
          Customer(
            phone: '+94771110${index.toString().padLeft(3, '0')}',
            name: 'Duplicate sort key',
            address: 'Test street',
            city: 'Colombo',
          ),
          editing: false,
        );
      }
      final firstPage = await people.readCustomers();
      final secondPage = await firstPage.next!();
      final paged = [...firstPage.items, ...secondPage.items];
      expect(firstPage.items, hasLength(25));
      expect(secondPage.next, isNull);
      expect(paged.map((item) => item.phone).toSet(), hasLength(27));
      final active = await inventory.readProducts();
      expect(
        active.items.map((item) => item.id).toSet(),
        chosen.map((item) => item.id).toSet(),
      );
      await auth.signOut();
    },
    skip: !FirebaseConfig.local,
    timeout: const Timeout(Duration(minutes: 2)),
  );
}
