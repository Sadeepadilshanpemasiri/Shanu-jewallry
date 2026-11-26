import 'package:jewellery_business_manager/core/localization/copy.dart';
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/constants/app_copy.dart';
import '../../../../core/widgets/global_search.dart';
import '../../../../core/theme/theme_provider.dart';
import '../../../auth/presentation/providers/auth_providers.dart';
import '../../../customers/presentation/customer_providers.dart';
import '../../../inventory/presentation/inventory_providers.dart';
import '../../../inventory/presentation/product_editor.dart';
import '../../../notifications/presentation/notification_bell.dart';
import '../../../orders/presentation/order_details_page.dart';
import '../../../orders/presentation/order_editor_page.dart';
import '../../../orders/presentation/order_providers.dart';
import '../../../reports/domain/business_report.dart';
import '../../../reports/presentation/report_charts.dart';
import '../../domain/dashboard_data.dart';
import '../dashboard_providers.dart';
import '../widgets/attention_panel.dart';

class DashboardPage extends ConsumerStatefulWidget {
  const DashboardPage({super.key});

  @override
  ConsumerState<DashboardPage> createState() => _DashboardPageState();
}

class _DashboardPageState extends ConsumerState<DashboardPage> {
  var _now = DateTime.now();
  var _days = 30;
  late final Timer _clock;

  @override
  void initState() {
    super.initState();
    _clock = Timer.periodic(const Duration(minutes: 1), (_) {
      if (mounted) setState(() => _now = DateTime.now());
    });
  }

  @override
  void dispose() {
    _clock.cancel();
    super.dispose();
  }

  void _message(String message) => ScaffoldMessenger.of(
    context,
  ).showSnackBar(SnackBar(content: Text(message)));

  Future<void> _createOrder() async {
    final number = await Navigator.push<String>(
      context,
      MaterialPageRoute(builder: (_) => const OrderEditorPage()),
    );
    if (mounted && number != null) _message('Order $number saved.');
  }

  Future<void> _addProduct() async {
    final saved = await openProductEditor(context);
    if (mounted && saved == true) _message('Product saved.');
  }

  Future<void> _chooseThresholds(AttentionThresholds current) async {
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      showDragHandle: true,
      constraints: const BoxConstraints(maxWidth: 560),
      builder: (_) => AttentionSettingsSheet(current: current),
    );
  }

  @override
  Widget build(BuildContext context) {
    final orders = ref.watch(ordersProvider());
    final products = ref.watch(productsProvider);
    final customers = ref.watch(customersProvider);
    final thresholds = ref.watch(attentionThresholdsProvider);
    final appearance =
        ref.watch(appearanceProvider).asData?.value ?? ThemeMode.system;
    final owner = ref.watch(ownerSessionProvider).asData?.value;
    final theme = Theme.of(context);
    final ready = orders.hasValue && products.hasValue && customers.hasValue;
    final settings = thresholds.asData?.value ?? const AttentionThresholds();
    final failed = orders.hasError || products.hasError || customers.hasError;
    return Scaffold(
      appBar: AppBar(
        title: const Copy(AppCopy.workspace),
        actions: [
          IconButton(
            onPressed: () => openGlobalSearch(context),
            tooltip: context.tr('Global search'),
            icon: const Icon(Icons.search),
          ),
          const NotificationBell(),
          PopupMenuButton<String>(
            tooltip: 'Open workspace section',
            icon: const Icon(Icons.dashboard_outlined),
            onSelected: (route) => context.push(route),
            itemBuilder: (_) => [
              for (final entry in const {
                '/orders': 'Orders',
                '/inventory': 'Inventory',
                '/customers': 'Customers',
                '/shipping': 'Quick Ship',
                '/reports': 'Reports',
                '/settings': 'Settings',
              }.entries)
                PopupMenuItem(value: entry.key, child: Copy(entry.value)),
            ],
          ),
          IconButton(
            icon: const Icon(Icons.logout),
            tooltip: AppCopy.signOut,
            onPressed: () async {
              try {
                await ref.read(authRepositoryProvider).signOut();
              } catch (_) {
                if (mounted) _message(AppCopy.networkError);
              }
            },
          ),
        ],
      ),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 1190),
          child: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              Copy('Business overview', style: theme.textTheme.headlineMedium),
              const SizedBox(height: 4),
              Text(
                owner?.email.isNotEmpty == true ? owner!.email : AppCopy.name,
                style: theme.textTheme.bodySmall,
              ),
              const SizedBox(height: 14),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  FilledButton.icon(
                    onPressed: _createOrder,
                    icon: const Icon(Icons.add),
                    label: const Copy('New order'),
                  ),
                  FilledButton.tonalIcon(
                    onPressed: () => context.push('/shipping'),
                    icon: const Icon(Icons.qr_code_scanner),
                    label: const Copy('Scan parcel'),
                  ),
                  OutlinedButton.icon(
                    onPressed: _addProduct,
                    icon: const Icon(Icons.inventory_2_outlined),
                    label: const Copy('Add product'),
                  ),
                  OutlinedButton.icon(
                    onPressed: () => context.push('/reports'),
                    icon: const Icon(Icons.analytics_outlined),
                    label: const Copy('Reports'),
                  ),
                  TextButton(
                    onPressed: () => context.push('/orders'),
                    child: const Copy('Open orders'),
                  ),
                  TextButton(
                    onPressed: () => context.push('/inventory'),
                    child: const Copy('Open inventory'),
                  ),
                  TextButton(
                    onPressed: () => context.push('/customers'),
                    child: const Copy('Open customers'),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              if (failed)
                ReportSection(
                  title: 'Dashboard data',
                  child: TextButton(
                    onPressed: () {
                      ref.invalidate(ordersProvider());
                      ref.invalidate(productsProvider);
                      ref.invalidate(customersProvider);
                    },
                    child: const Text('Could not load dashboard data. Retry'),
                  ),
                )
              else if (!ready)
                const LinearProgressIndicator()
              else
                ..._dashboard(
                  DashboardData.calculate(
                    orders.requireValue,
                    products.requireValue,
                    customers.requireValue,
                    _now,
                    settings,
                  ),
                  BusinessReport.calculate(
                    orders.requireValue,
                    products.requireValue,
                    ReportWindow.last(_days, _now),
                  ),
                  settings,
                ),
              if (thresholds.hasError)
                TextButton(
                  onPressed: () => ref.invalidate(attentionThresholdsProvider),
                  child: const Text('Could not load attention settings. Retry'),
                ),
              const SizedBox(height: 12),
              ReportSection(
                title: AppCopy.theme,
                child: Wrap(
                  spacing: 8,
                  runSpacing: 6,
                  children: [
                    for (final entry in const {
                      ThemeMode.system: AppCopy.systemTheme,
                      ThemeMode.light: AppCopy.lightTheme,
                      ThemeMode.dark: AppCopy.darkTheme,
                    }.entries)
                      ChoiceChip(
                        selected: appearance == entry.key,
                        label: Copy(entry.value),
                        onSelected: (_) async {
                          try {
                            await ref
                                .read(appearanceProvider.notifier)
                                .select(entry.key);
                          } catch (_) {
                            if (mounted) _message(AppCopy.unavailable);
                          }
                        },
                      ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  List<Widget> _dashboard(
    DashboardData data,
    BusinessReport report,
    AttentionThresholds settings,
  ) {
    final stockAlert = data.stockAlerts.length;
    final best = report.ranked(report.products.values).take(5).toList();
    return [
      ReportTiles(
        children: [
          MetricTile(
            label: 'Today’s orders',
            value: data.todayOrders,
            icon: Icons.receipt_long_outlined,
          ),
          MetricTile(
            label: 'Today’s delivered revenue',
            value: data.todayRevenue,
            money: true,
            icon: Icons.payments_outlined,
          ),
          MetricTile(
            label: 'Pending orders',
            value: data.pending,
            icon: Icons.schedule_outlined,
          ),
          MetricTile(
            label: 'To ship',
            value: data.toShip,
            icon: Icons.inventory_2_outlined,
          ),
          MetricTile(
            label: 'In transit',
            value: data.inTransit,
            icon: Icons.local_shipping_outlined,
          ),
          MetricTile(
            label: 'Low or out of stock',
            value: stockAlert,
            icon: Icons.warning_amber_outlined,
          ),
          MetricTile(
            label: 'Cancelled this week',
            value: data.cancelledThisWeek,
            icon: Icons.event_busy_outlined,
          ),
        ],
      ),
      const SizedBox(height: 14),
      ReportSection(
        title: 'Needs attention',
        child: AttentionPanel(
          data: data,
          thresholds: settings,
          onSettings: () => _chooseThresholds(settings),
          onOrder: (order) => openOrderDetails(context, order),
          onStock: () => context.push('/inventory'),
        ),
      ),
      const SizedBox(height: 14),
      Wrap(
        spacing: 8,
        runSpacing: 6,
        children: [
          for (final days in [7, 30, 90])
            ChoiceChip(
              label: Text('$days days'),
              selected: _days == days,
              onSelected: (_) => setState(() {
                _days = days;
                _now = DateTime.now();
              }),
            ),
        ],
      ),
      const SizedBox(height: 8),
      ReportSection(
        title: 'Sales trend',
        subtitle: 'Delivered revenue and gross merchandise profit · LKR',
        child: SalesTrendChart(report: report),
      ),
      const SizedBox(height: 12),
      LayoutBuilder(
        builder: (_, constraints) {
          final outcomes = ReportSection(
            title: 'Order status',
            subtitle: 'Orders placed in the selected period',
            child: OrderStatusDonut(report: report),
          );
          final products = ReportSection(
            title: 'Best-selling products',
            subtitle: 'Ranked by delivered units',
            child: best.isEmpty
                ? const Text('No products sold in this period.')
                : Column(
                    children: [
                      for (final item in best)
                        Padding(
                          padding: const EdgeInsets.only(bottom: 12),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              Row(
                                children: [
                                  Expanded(
                                    child: Text(
                                      item.label,
                                      maxLines: 2,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  Text('${item.units} units'),
                                ],
                              ),
                              const SizedBox(height: 5),
                              LinearProgressIndicator(
                                value: item.units / best.first.units,
                                borderRadius: BorderRadius.circular(8),
                              ),
                            ],
                          ),
                        ),
                    ],
                  ),
          );
          return constraints.maxWidth < 760
              ? Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [outcomes, const SizedBox(height: 12), products],
                )
              : Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(child: outcomes),
                    const SizedBox(width: 12),
                    Expanded(child: products),
                  ],
                );
        },
      ),
    ];
  }
}
