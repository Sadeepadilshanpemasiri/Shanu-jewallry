import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:pdf/widgets.dart' as pdf;
import 'package:jewellery_business_manager/features/customers/domain/customer.dart';
import 'package:jewellery_business_manager/features/dashboard/domain/dashboard_data.dart';
import 'package:jewellery_business_manager/features/inventory/domain/inventory_product.dart';
import 'package:jewellery_business_manager/features/orders/domain/shop_order.dart';
import 'package:jewellery_business_manager/features/reports/domain/business_report.dart';
import 'package:jewellery_business_manager/features/reports/presentation/report_export.dart';

const customer = Customer(
  phone: '+94771234567',
  name: 'Test owner',
  address: 'Test address',
  city: 'Colombo',
  stats: CustomerStats(total: 2, cancelled: 1, returned: 1),
);

ShopOrder order(
  String id,
  OrderStatus status,
  DateTime created, {
  DateTime? delivered,
  DateTime? shipped,
  DateTime? cancelled,
  String category = '',
  String label = 'Ring',
}) => ShopOrder(
  id: id,
  number: id,
  customer: customer,
  lines: [
    OrderLine('product-1', label, 'RING-1', 2, 10000, 3000, category: category),
  ],
  totals: const OrderTotals(subtotal: 20000, delivery: 3000, discount: 2000),
  status: status,
  payment: OrderPayment.cod,
  advance: 0,
  timing: StockTiming.confirmed,
  source: 'WhatsApp',
  notes: '',
  courier: shipped == null ? '' : 'Courier',
  tracking: '',
  createdAt: created,
  deliveredAt: delivered,
  shippedAt: shipped,
  cancelledAt: cancelled,
  history: shipped != null && status == OrderStatus.shipped
      ? [
          OrderEvent(
            status: OrderStatus.failedDelivery,
            note: '',
            actor: 'owner',
            at: shipped,
          ),
        ]
      : [],
  restockAvailable: false,
);

const product = InventoryProduct(
  id: 'product-1',
  quantity: 1,
  details: ProductDetails(
    name: 'Ring',
    sku: 'RING-1',
    category: 'Current category',
    metal: 'Gold',
    description: '',
    cost: 1000,
    price: 12000,
    threshold: 2,
    variants: [],
    images: [],
  ),
);

void main() {
  test('PDF export creates a nonempty PDF for a populated report', () async {
    final now = DateTime.utc(2026, 11, 23, 10);
    final report = BusinessReport.calculate(
      [
        order(
          'delivered',
          OrderStatus.delivered,
          now,
          delivered: now,
          shipped: now,
          category: 'Rings',
        ),
      ],
      [],
      ReportWindow.last(1, now),
    );
    final bytes = await reportPdf(
      report,
      fonts: pdf.ThemeData.withFont(base: pdf.Font.helvetica()),
    );
    expect(ascii.decode(bytes.take(5).toList()), '%PDF-');
    expect(bytes.length, greaterThan(1000));
  });
  test('Sri Lanka reporting day changes at 18:30 UTC', () {
    expect(
      shopDay(DateTime.utc(2026, 11, 22, 18, 29)),
      DateTime.utc(2026, 11, 22),
    );
    expect(
      shopDay(DateTime.utc(2026, 11, 22, 18, 30)),
      DateTime.utc(2026, 11, 23),
    );
  });

  test(
    'sales use delivery dates and snapshots, outcomes use placement dates',
    () {
      final today = DateTime.utc(2026, 11, 23, 6);
      final earlier = DateTime.utc(2026, 11, 22, 9);
      final window = ReportWindow.last(1, today);
      final report = BusinessReport.calculate(
        [
          order(
            'old',
            OrderStatus.delivered,
            earlier,
            delivered: today,
            category: 'Historical rings',
          ),
          order('new', OrderStatus.cancelled, today, cancelled: today),
          order(
            'returned',
            OrderStatus.returned,
            today,
            delivered: today,
            shipped: today,
          ),
        ],
        [product],
        window,
      );
      expect(report.placed, 2);
      expect(report.delivered, 1);
      expect(report.revenue, 21000);
      expect(report.profit, 12000);
      expect(report.cancellationRate, 50);
      expect(report.returnRate, 50);
      expect(report.sources['WhatsApp']!.revenue, 21000);
      expect(report.categories['Historical rings']!.units, 2);
      expect(report.categories.containsKey('Current category'), isFalse);
      expect(report.trend().single.revenue, 21000);
    },
  );

  test('courier averages and retried deliveries use dispatch cohorts', () {
    final now = DateTime.utc(2026, 11, 23, 12);
    final sent = now.subtract(const Duration(hours: 30));
    final report = BusinessReport.calculate(
      [
        order(
          'delivered',
          OrderStatus.delivered,
          sent,
          shipped: sent,
          delivered: now,
        ),
        order('retried', OrderStatus.shipped, sent, shipped: sent),
      ],
      [product],
      ReportWindow.last(7, now),
    );
    final courier = report.couriers['Courier']!;
    expect(courier.dispatched, 2);
    expect(courier.failed, 1);
    expect(courier.delivered, 1);
    expect(courier.averageDays, 1.25);
    expect(report.categories['Current category']!.units, 2);
  });

  test(
    'dashboard flags delayed active orders, transit, low stock, and recorded risk',
    () {
      final now = DateTime.utc(2026, 11, 23, 10);
      final old = now.subtract(const Duration(days: 6));
      final pending = order('pending', OrderStatus.pending, old);
      final packed = order('packed', OrderStatus.packed, now);
      final dispatched = order(
        'shipped',
        OrderStatus.shipped,
        old,
        shipped: old,
      );
      final cancelled = order(
        'cancelled',
        OrderStatus.cancelled,
        old,
        cancelled: now,
      );
      final data = DashboardData.calculate(
        [pending, packed, dispatched, cancelled],
        [product],
        [customer],
        now,
        const AttentionThresholds(toShipDays: 2, transitDays: 5),
      );
      expect(data.todayOrders, 1);
      expect(data.toShip, 1);
      expect(data.inTransit, 1);
      expect(data.cancelledThisWeek, 1);
      expect(data.unshipped.map((item) => item.id), ['pending']);
      expect(data.overdue.map((item) => item.id), ['shipped']);
      expect(data.stockAlerts.single, product);
      expect(data.customerAlerts.length, 3);
    },
  );

  test('CSV exports aggregate values and neutralizes spreadsheet formulas', () {
    final now = DateTime.utc(2026, 11, 23, 10);
    final report = BusinessReport.calculate(
      [
        order(
          'delivered',
          OrderStatus.delivered,
          now,
          delivered: now,
          label: '=1+2',
        ),
      ],
      [],
      ReportWindow.last(1, now),
    );
    final csv = utf8.decode(reportCsv(report));
    expect(csv, contains('"Delivered revenue (LKR)",210.0'));
    expect(csv, contains('"\'=1+2"'));
    expect(csv, contains('"Uncategorized"'));
    expect(csv, contains('"Asia/Colombo"'));
  });
}
