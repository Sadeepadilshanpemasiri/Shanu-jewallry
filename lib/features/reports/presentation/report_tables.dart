import 'package:intl/intl.dart';

import '../../inventory/presentation/inventory_format.dart';
import '../../orders/domain/shop_order.dart';
import '../domain/business_report.dart';

class ReportTable {
  const ReportTable(this.title, this.columns, this.rows);
  final String title;
  final List<String> columns;
  final List<List<Object>> rows;
}

String reportDate(DateTime day) => DateFormat('yyyy-MM-dd').format(day);
String rateLabel(double? value) =>
    value == null ? '—' : '${value.toStringAsFixed(1)}%';

List<ReportTable> reportTables(BusinessReport report, {bool csv = false}) {
  Object money(int cents) => csv ? cents / 100 : lkr(cents);
  final weekdays = report.daily.values.toList()
    ..sort((a, b) => a.day.compareTo(b.day));
  final sources = report.sources.values.toList()
    ..sort((a, b) => b.revenue.compareTo(a.revenue));
  final couriers = report.couriers.values.toList()
    ..sort((a, b) => b.dispatched.compareTo(a.dispatched));
  return [
    ReportTable(
      'Daily delivered sales',
      ['Delivery date', 'Revenue (LKR)', 'Gross profit (LKR)'],
      [
        for (final day in weekdays)
          [reportDate(day.day), money(day.revenue), money(day.profit)],
      ],
    ),
    ReportTable(
      'Order outcomes',
      ['Status', 'Orders placed in period'],
      [
        for (final status in OrderStatus.values)
          [status.label, report.statuses[status] ?? 0],
      ],
    ),
    ReportTable(
      'Best-selling products',
      ['Product', 'SKU', 'Units', 'Before discounts (LKR)'],
      [
        for (final item in report.ranked(report.products.values))
          [item.label, item.code, item.units, money(item.value)],
      ],
    ),
    ReportTable(
      'Category performance',
      ['Category', 'Units', 'Before discounts (LKR)'],
      [
        for (final item in report.ranked(report.categories.values))
          [item.label, item.units, money(item.value)],
      ],
    ),
    ReportTable(
      'Courier performance',
      [
        'Courier',
        'Dispatched',
        'Delivered',
        'Failed at least once',
        'Returned',
        'Avg. days to deliver',
      ],
      [
        for (final carrier in couriers)
          [
            carrier.name,
            carrier.dispatched,
            carrier.delivered,
            carrier.failed,
            carrier.returned,
            carrier.averageDays?.toStringAsFixed(1) ?? '—',
          ],
      ],
    ),
    ReportTable(
      'Order sources',
      ['Source', 'Orders placed', 'Delivered revenue (LKR)'],
      [
        for (final source in sources)
          [source.name, source.orders, money(source.revenue)],
      ],
    ),
  ];
}
