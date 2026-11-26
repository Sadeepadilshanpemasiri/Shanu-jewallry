import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jewellery_business_manager/features/customers/domain/customer.dart';
import 'package:jewellery_business_manager/features/inventory/presentation/inventory_providers.dart';
import 'package:jewellery_business_manager/features/orders/domain/shop_order.dart';
import 'package:jewellery_business_manager/features/orders/presentation/order_providers.dart';
import 'package:jewellery_business_manager/features/reports/presentation/reports_page.dart';

void main() {
  testWidgets(
    'reports fit on a phone and render live sales and export actions',
    (tester) async {
      await tester.binding.setSurfaceSize(const Size(360, 740));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      final now = DateTime.now();
      final order = ShopOrder(
        id: 'report-order',
        number: 'JB-000123',
        customer: const Customer(
          phone: '+94771234567',
          name: 'Test',
          address: 'Test Road',
          city: 'Colombo',
        ),
        lines: const [OrderLine('ring', 'Ring', 'RING-1', 1, 150000, 50000)],
        totals: const OrderTotals(
          subtotal: 150000,
          delivery: 30000,
          discount: 0,
        ),
        status: OrderStatus.delivered,
        payment: OrderPayment.cod,
        advance: 0,
        timing: StockTiming.confirmed,
        source: 'WhatsApp',
        notes: '',
        courier: 'Courier',
        tracking: 'AB-1',
        createdAt: now,
        deliveredAt: now,
        shippedAt: now,
        history: const [],
        restockAvailable: true,
      );
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            productsProvider.overrideWith((ref) => Stream.value([])),
            ordersProvider().overrideWith((ref) => Stream.value([order])),
          ],
          child: const MaterialApp(home: ReportsPage()),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('Download CSV'), findsOneWidget);
      expect(find.text('Download PDF'), findsOneWidget);
      expect(find.text('LKR 1,800.00'), findsOneWidget);
      await tester.drag(find.byType(ListView).first, const Offset(0, -580));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
    },
  );
}
