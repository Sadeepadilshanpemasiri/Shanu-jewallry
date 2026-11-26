import 'package:jewellery_business_manager/core/localization/copy.dart';
import 'dart:math' as math;

import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../../core/widgets/premium_card.dart';
import '../../inventory/presentation/inventory_format.dart';
import '../domain/business_report.dart';

class SalesTrendChart extends StatelessWidget {
  const SalesTrendChart({super.key, required this.report});
  final BusinessReport report;

  @override
  Widget build(BuildContext context) {
    if (report.delivered == 0) {
      return const Text('No delivered sales in this period.');
    }
    final theme = Theme.of(context);
    final primary = theme.colorScheme.primary;
    final profit = theme.brightness == Brightness.dark
        ? const Color(0xff8ed7ae)
        : const Color(0xff247451);
    final series = report.trend();
    final values = series.expand(
      (day) => [day.revenue / 100, day.profit / 100],
    );
    final bottom = values.fold<double>(0, math.min);
    final top = values.fold<double>(0, math.max);
    final spacing = math.max((series.length / 3).ceil(), 1).toDouble();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Wrap(
          spacing: 14,
          runSpacing: 6,
          children: [
            _legend(primary, 'Delivered revenue'),
            _legend(profit, 'Gross profit'),
          ],
        ),
        const SizedBox(height: 14),
        if (series.length == 1)
          Text(
            '${lkr(report.revenue)} revenue · ${lkr(report.profit)} gross profit',
          )
        else
          SizedBox(
            height: 210,
            child: Semantics(
              label:
                  'Daily delivered revenue and gross profit in Sri Lankan rupees.',
              child: LineChart(
                LineChartData(
                  minY: bottom < 0 ? bottom * 1.12 : 0,
                  maxY: top > 0 ? top * 1.12 : 1,
                  borderData: FlBorderData(show: false),
                  gridData: const FlGridData(drawVerticalLine: false),
                  titlesData: FlTitlesData(
                    topTitles: const AxisTitles(
                      sideTitles: SideTitles(showTitles: false),
                    ),
                    rightTitles: const AxisTitles(
                      sideTitles: SideTitles(showTitles: false),
                    ),
                    leftTitles: AxisTitles(
                      sideTitles: SideTitles(
                        showTitles: true,
                        reservedSize: 48,
                        getTitlesWidget: (value, _) => Text(
                          NumberFormat.compact().format(value),
                          style: theme.textTheme.labelSmall,
                        ),
                      ),
                    ),
                    bottomTitles: AxisTitles(
                      sideTitles: SideTitles(
                        showTitles: true,
                        interval: spacing,
                        reservedSize: 25,
                        maxIncluded: false,
                        getTitlesWidget: (value, _) {
                          final i = value.round();
                          if (i < 0 || i >= series.length) {
                            return const SizedBox.shrink();
                          }
                          return Padding(
                            padding: const EdgeInsets.only(top: 8),
                            child: Text(
                              DateFormat('dd MMM').format(series[i].day),
                              style: theme.textTheme.labelSmall,
                            ),
                          );
                        },
                      ),
                    ),
                  ),
                  lineBarsData: [
                    _line(series, primary, (day) => day.revenue),
                    _line(series, profit, (day) => day.profit),
                  ],
                ),
                duration: _duration(context),
              ),
            ),
          ),
      ],
    );
  }

  LineChartBarData _line(
    List<DailySales> series,
    Color color,
    int Function(DailySales) amount,
  ) => LineChartBarData(
    color: color,
    barWidth: 2.5,
    isStrokeCapRound: true,
    dotData: const FlDotData(show: false),
    spots: [
      for (var index = 0; index < series.length; index++)
        FlSpot(index.toDouble(), amount(series[index]) / 100),
    ],
  );
}

class OrderStatusDonut extends StatelessWidget {
  const OrderStatusDonut({super.key, required this.report});
  final BusinessReport report;
  static const _colors = [
    Color(0xffb99159),
    Color(0xff5b917f),
    Color(0xff7c82b5),
    Color(0xff70a5c3),
    Color(0xff3a8259),
    Color(0xffb56764),
    Color(0xffa972a5),
    Color(0xffa5704a),
  ];

  @override
  Widget build(BuildContext context) {
    final statuses = report.statuses.entries.toList()
      ..sort((a, b) => a.key.index.compareTo(b.key.index));
    if (statuses.isEmpty) return const Text('No orders placed in this period.');
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          height: 154,
          child: PieChart(
            PieChartData(
              centerSpaceRadius: 43,
              sectionsSpace: 2,
              sections: [
                for (final status in statuses)
                  PieChartSectionData(
                    color: _colors[status.key.index],
                    value: status.value.toDouble(),
                    radius: 29,
                    showTitle: false,
                  ),
              ],
            ),
            duration: _duration(context),
          ),
        ),
        const SizedBox(height: 8),
        Wrap(
          spacing: 12,
          runSpacing: 7,
          children: [
            for (final status in statuses)
              _legend(
                _colors[status.key.index],
                '${status.key.label} ${status.value}',
              ),
          ],
        ),
      ],
    );
  }
}

Widget _legend(Color color, String title) => Row(
  mainAxisSize: MainAxisSize.min,
  children: [
    DecoratedBox(
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(4),
      ),
      child: const SizedBox.square(dimension: 11),
    ),
    const SizedBox(width: 5),
    Text(title),
  ],
);

Duration _duration(BuildContext context) =>
    MediaQuery.disableAnimationsOf(context)
    ? Duration.zero
    : const Duration(milliseconds: 250);

class ReportSection extends StatelessWidget {
  const ReportSection({
    super.key,
    required this.title,
    required this.child,
    this.subtitle,
  });
  final String title;
  final String? subtitle;
  final Widget child;

  @override
  Widget build(BuildContext context) => PremiumCard(
    padding: const EdgeInsets.all(16),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Copy(title, style: Theme.of(context).textTheme.titleLarge),
        if (subtitle != null) ...[
          const SizedBox(height: 4),
          Text(subtitle!, style: Theme.of(context).textTheme.bodySmall),
        ],
        const SizedBox(height: 12),
        child,
      ],
    ),
  );
}

class ReportTiles extends StatelessWidget {
  const ReportTiles({
    super.key,
    required this.children,
    this.minimumWidth = 148,
  });
  final List<Widget> children;
  final double minimumWidth;

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, constraints) {
      const gap = 10.0;
      final width = constraints.maxWidth;
      final required =
          minimumWidth * MediaQuery.textScalerOf(context).scale(14) / 14;
      final columns = math.max(
        1,
        math.min(4, ((width + gap) / (required + gap)).floor()),
      );
      final itemWidth = (width - gap * (columns - 1)) / columns;
      return Wrap(
        spacing: gap,
        runSpacing: gap,
        children: [
          for (final child in children)
            SizedBox(width: itemWidth, child: child),
        ],
      );
    },
  );
}

class MetricTile extends StatelessWidget {
  const MetricTile({
    super.key,
    required this.label,
    required this.value,
    this.money = false,
    this.icon,
  });
  final String label;
  final int value;
  final bool money;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return PremiumCard(
      padding: const EdgeInsets.all(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (icon != null) ...[
            Icon(icon, color: theme.colorScheme.primary, size: 20),
            const SizedBox(height: 7),
          ],
          Copy(label, style: theme.textTheme.labelLarge),
          const SizedBox(height: 6),
          TweenAnimationBuilder<double>(
            tween: Tween(begin: 0, end: value.toDouble()),
            duration: _duration(context),
            builder: (context, current, _) => Text(
              money
                  ? lkr(current.round())
                  : NumberFormat.decimalPattern().format(current.round()),
              style: theme.textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
