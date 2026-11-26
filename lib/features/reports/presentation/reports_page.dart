import 'package:jewellery_business_manager/core/localization/copy.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:share_plus/share_plus.dart';

import '../../../core/services/report_download.dart';
import '../../inventory/presentation/inventory_providers.dart';
import '../../orders/domain/shop_order.dart';
import '../../orders/presentation/order_providers.dart';
import '../domain/business_report.dart';
import 'report_charts.dart';
import 'report_export.dart';
import 'report_tables.dart';

class ReportsPage extends ConsumerStatefulWidget {
  const ReportsPage({super.key});

  @override
  ConsumerState<ReportsPage> createState() => _ReportsPageState();
}

class _ReportsPageState extends ConsumerState<ReportsPage> {
  ReportWindow _window = ReportWindow.last(30, DateTime.now());
  bool _busy = false;

  Future<void> _chooseRange(List<ShopOrder> orders) async {
    final today = shopDay(DateTime.now());
    final earliest = orders
        .expand(
          (order) => [
            order.createdAt,
            order.eventDate(OrderStatus.delivered),
            order.eventDate(OrderStatus.shipped),
          ],
        )
        .whereType<DateTime>()
        .map(shopDay)
        .fold(_window.start, (min, next) => next.isBefore(min) ? next : min);
    final range = await showDateRangePicker(
      context: context,
      firstDate: earliest,
      lastDate: today,
      initialDateRange: DateTimeRange(start: _window.start, end: _window.end),
    );
    if (mounted && range != null) {
      setState(
        () => _window = ReportWindow(
          DateTime.utc(range.start.year, range.start.month, range.start.day),
          DateTime.utc(range.end.year, range.end.month, range.end.day),
        ),
      );
    }
  }

  Future<void> _export(Future<void> Function() action) async {
    if (_busy) return;
    setState(() => _busy = true);
    try {
      await action();
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Could not export the report. Try again.'),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final orders = ref.watch(ordersProvider());
    final products = ref.watch(productsProvider);
    return Scaffold(
      appBar: AppBar(
        title: const Copy('Reports'),
        leading: BackButton(onPressed: () => context.go('/')),
      ),
      body: orders.hasError || products.hasError
          ? Center(
              child: TextButton(
                onPressed: () {
                  ref.invalidate(ordersProvider());
                  ref.invalidate(productsProvider);
                },
                child: const Text('Could not load reporting data. Retry'),
              ),
            )
          : !orders.hasValue || !products.hasValue
          ? const Center(child: CircularProgressIndicator())
          : _content(
              orders.requireValue,
              BusinessReport.calculate(
                orders.requireValue,
                products.requireValue,
                _window,
              ),
            ),
    );
  }

  Widget _content(List<ShopOrder> orders, BusinessReport report) {
    final filename = reportFilename(report);
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 1100),
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            Copy(
              'Business performance',
              style: Theme.of(context).textTheme.headlineMedium,
            ),
            const SizedBox(height: 6),
            const Text('Sri Lanka dates · LKR'),
            const SizedBox(height: 10),
            Wrap(
              spacing: 8,
              runSpacing: 6,
              children: [
                OutlinedButton.icon(
                  icon: const Icon(Icons.date_range_outlined),
                  onPressed: () => _chooseRange(orders),
                  label: Text(
                    '${reportDate(_window.start)} to ${reportDate(_window.end)}',
                  ),
                ),
                for (final days in [7, 30, 90])
                  TextButton(
                    onPressed: () => setState(
                      () => _window = ReportWindow.last(days, DateTime.now()),
                    ),
                    child: Text('Last $days days'),
                  ),
              ],
            ),
            Wrap(
              spacing: 8,
              runSpacing: 6,
              children: [
                OutlinedButton.icon(
                  icon: const Icon(Icons.download_outlined),
                  label: const Copy('Download CSV'),
                  onPressed: _busy
                      ? null
                      : () => _export(
                          () async => downloadReport(
                            reportCsv(report),
                            '$filename.csv',
                            'text/csv;charset=utf-8',
                          ),
                        ),
                ),
                OutlinedButton.icon(
                  icon: const Icon(Icons.picture_as_pdf_outlined),
                  label: const Copy('Download PDF'),
                  onPressed: _busy
                      ? null
                      : () => _export(
                          () async => downloadReport(
                            await reportPdf(report),
                            '$filename.pdf',
                            'application/pdf',
                          ),
                        ),
                ),
                OutlinedButton.icon(
                  icon: const Icon(Icons.share_outlined),
                  label: const Copy('Share CSV'),
                  onPressed: _busy
                      ? null
                      : () => _export(() async {
                          await SharePlus.instance.share(
                            ShareParams(
                              files: [
                                XFile.fromData(
                                  reportCsv(report),
                                  mimeType: 'text/csv',
                                ),
                              ],
                              fileNameOverrides: ['$filename.csv'],
                              title: 'Jewellery business report',
                            ),
                          );
                        }),
                ),
              ],
            ),
            if (_busy) const LinearProgressIndicator(),
            const SizedBox(height: 12),
            ReportTiles(
              children: [
                MetricTile(label: 'Orders placed', value: report.placed),
                MetricTile(label: 'Orders delivered', value: report.delivered),
                MetricTile(
                  label: 'Delivered revenue',
                  value: report.revenue,
                  money: true,
                ),
                MetricTile(
                  label: 'Gross profit',
                  value: report.profit,
                  money: true,
                ),
              ],
            ),
            const SizedBox(height: 12),
            ReportSection(
              title: 'Cancellation and returns',
              subtitle: 'Current outcomes of orders placed in this period',
              child: Wrap(
                spacing: 16,
                runSpacing: 8,
                children: [
                  Text(
                    'Cancelled ${report.cancelled} · ${rateLabel(report.cancellationRate)}',
                  ),
                  Text(
                    'Returned ${report.returned} · ${rateLabel(report.returnRate)}',
                  ),
                ],
              ),
            ),
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 12),
              child: Text(reportBasis),
            ),
            if (_window.days <= 90) ...[
              ReportSection(
                title: 'Revenue and gross profit',
                child: SalesTrendChart(report: report),
              ),
              const SizedBox(height: 12),
            ],
            for (final table in reportTables(report)) ...[
              _TableCard(table: table),
              const SizedBox(height: 12),
            ],
          ],
        ),
      ),
    );
  }
}

class _TableCard extends StatelessWidget {
  const _TableCard({required this.table});
  final ReportTable table;

  @override
  Widget build(BuildContext context) => ReportSection(
    title: table.title,
    child: table.rows.isEmpty
        ? const Copy('No records for this period.')
        : SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: DataTable(
              headingRowHeight: 42,
              columnSpacing: 24,
              columns: table.columns
                  .map((label) => DataColumn(label: Text(label)))
                  .toList(),
              rows: [
                for (final row in table.rows)
                  DataRow(
                    cells: [
                      for (final value in row) DataCell(Text(value.toString())),
                    ],
                  ),
              ],
            ),
          ),
  );
}
