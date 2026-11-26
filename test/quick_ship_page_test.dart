import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jewellery_business_manager/features/customers/domain/customer.dart';
import 'package:jewellery_business_manager/features/orders/domain/order_repository.dart';
import 'package:jewellery_business_manager/features/orders/domain/shop_order.dart';
import 'package:jewellery_business_manager/features/orders/presentation/order_providers.dart';
import 'package:jewellery_business_manager/features/shipping/domain/courier.dart';
import 'package:jewellery_business_manager/features/shipping/presentation/quick_ship_page.dart';
import 'package:jewellery_business_manager/features/shipping/presentation/shipping_providers.dart';

class _Orders extends Fake implements OrderRepository {
  final sent = <(String, OrderUpdate)>[];

  @override
  Future<void> transition(String id, OrderUpdate update) async =>
      sent.add((id, update));
}

void main() {
  testWidgets(
    'manual waybill can be linked and shipped from the phone-size batch screen',
    (tester) async {
      await tester.binding.setSurfaceSize(const Size(360, 740));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      final repository = _Orders();
      const order = ShopOrder(
        id: 'order-one',
        number: 'JB-000001',
        customer: Customer(
          phone: '+94771234567',
          name: 'Test customer',
          address: 'Test street',
          city: 'Colombo',
        ),
        lines: [],
        totals: OrderTotals(subtotal: 0, delivery: 0, discount: 0),
        status: OrderStatus.packed,
        payment: OrderPayment.cod,
        advance: 0,
        timing: StockTiming.confirmed,
        source: 'WhatsApp',
        notes: '',
        courier: '',
        tracking: '',
        createdAt: null,
        history: [],
        restockAvailable: false,
      );
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            courierRepositoryProvider.overrideWith(
              (ref) => throw StateError('Courier writes are not used.'),
            ),
            couriersProvider.overrideWith(
              (ref) => Stream.value([
                const Courier(name: 'Courier One', template: ''),
              ]),
            ),
            ordersProvider().overrideWith((ref) => Stream.value([order])),
            orderRepositoryProvider.overrideWith((ref) => repository),
          ],
          child: const MaterialApp(home: QuickShipPage()),
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.byType(DropdownButtonFormField<String>));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Courier One').last);
      await tester.pumpAndSettle();

      await tester.enterText(find.byType(TextField), 'SL-012345');
      await tester.tap(find.byTooltip('Add code'));
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.text('Link order'));
      await tester.tap(find.text('Link order'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('JB-000001 · Test customer'));
      await tester.pumpAndSettle();

      await tester.ensureVisible(find.text('Ship 1 ready'));
      await tester.tap(find.text('Ship 1 ready'));
      await tester.pumpAndSettle();

      expect(repository.sent.single.$1, 'order-one');
      expect(repository.sent.single.$2.status, OrderStatus.shipped);
      expect(repository.sent.single.$2.courier, 'Courier One');
      expect(repository.sent.single.$2.tracking, 'SL-012345');
      expect(find.text('Shipped 1 parcel.'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );
}
