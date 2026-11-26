import 'package:jewellery_business_manager/core/localization/copy.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/widgets/cursor_catalog.dart';
import '../../../core/widgets/scan_code_page.dart';
import '../../customers/domain/customer.dart';
import '../../shipping/domain/parcel_lookup.dart';
import '../../inventory/presentation/inventory_format.dart';
import '../domain/shop_order.dart';
import 'order_details_page.dart';
import 'order_editor_page.dart';
import 'order_format.dart';
import 'order_providers.dart';

class OrdersPage extends ConsumerStatefulWidget {
  const OrdersPage({super.key});

  @override
  ConsumerState<OrdersPage> createState() => _OrdersPageState();
}

class _OrdersPageState extends ConsumerState<OrdersPage> {
  String _query = '';
  OrderStatus? _status;
  DateTimeRange? _range;
  bool _newest = true;
  int _revision = 0;

  void _reload() => setState(() => _revision++);

  Future<void> _open(ShopOrder order) async {
    await openOrderDetails(context, order);
    if (mounted) _reload();
  }

  Future<void> _create() async {
    final number = await Navigator.push<String>(
      context,
      MaterialPageRoute(builder: (_) => const OrderEditorPage()),
    );
    if (mounted && number != null) {
      _reload();
      _message('Order $number saved.');
    }
  }

  Future<void> _openByLabel() async {
    final code = await Navigator.push<String>(
      context,
      MaterialPageRoute(
        builder: (_) => const ScanCodePage(
          title: 'Scan order label',
          manualLabel: 'Enter order number',
        ),
      ),
    );
    if (!mounted || code == null) return;
    try {
      final orders = await ref
          .read(orderRepositoryProvider)
          .watchOrders()
          .first;
      if (!mounted) return;
      final matches = matchParcelOrders(orders, code, '');
      if (matches.length == 1) {
        await _open(matches.single);
      } else {
        _message('No order matches that label or order number.');
      }
    } catch (error) {
      if (mounted) _message(orderError(error));
    }
  }

  void _message(String text) =>
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(text)));

  Future<bool> _quick(ShopOrder order, OrderStatus status) async {
    final update = await askOrderTransition(context, order, status);
    if (!mounted || update == null) return false;
    try {
      await ref.read(orderRepositoryProvider).transition(order.id, update);
      if (mounted) _reload();
      if (mounted) _message('${order.number} · ${status.label}');
    } catch (error) {
      if (mounted) _message(orderError(error));
    }
    return false;
  }

  Future<void> _pickRange() async {
    final List<ShopOrder> orders;
    try {
      final repository = ref.read(orderRepositoryProvider);
      orders = (await repository.readOrders(newest: false)).items;
    } catch (error) {
      if (mounted) _message(orderError(error));
      return;
    }
    if (!mounted) return;
    final today = DateUtils.dateOnly(DateTime.now());
    final earliest = orders
        .map((order) => order.createdAt?.toLocal())
        .whereType<DateTime>()
        .fold(today, (min, value) => value.isBefore(min) ? value : min);
    final range = await showDateRangePicker(
      context: context,
      firstDate: DateUtils.dateOnly(
        _range != null && _range!.start.isBefore(earliest)
            ? _range!.start
            : earliest,
      ),
      lastDate: today,
      initialDateRange: _range,
    );
    if (mounted && range != null) setState(() => _range = range);
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(
      title: const Copy('Orders'),
      leading: BackButton(onPressed: () => context.go('/')),
      actions: [
        IconButton(
          onPressed: _openByLabel,
          icon: const Icon(Icons.qr_code_scanner),
          tooltip: 'Scan order label',
        ),
        IconButton(
          onPressed: () async {
            await context.push('/shipping');
            if (mounted) _reload();
          },
          icon: const Icon(Icons.local_shipping_outlined),
          tooltip: 'Quick Ship',
        ),
      ],
    ),
    floatingActionButton: FloatingActionButton.extended(
      onPressed: _create,
      icon: const Icon(Icons.add),
      label: const Copy('New order'),
    ),
    body: CursorCatalog<ShopOrder>(
      revision: (_revision, _newest),
      recordId: (order) => order.id,
      first: () =>
          ref.read(orderRepositoryProvider).readOrders(newest: _newest),
      full: _filtered ? ref.watch(ordersProvider()) : null,
      refreshFull: () => ref.invalidate(ordersProvider()),
      errorText: orderError,
      builder: _catalog,
    ),
  );

  bool get _filtered =>
      _query.trim().isNotEmpty || _status != null || _range != null;

  Widget _catalog(
    List<ShopOrder> all,
    Widget? footer,
    Future<void> Function() refresh,
  ) {
    final range = _range;
    final query = _query.trim().toLowerCase();
    final phone = normalizeSriLankanPhone(query) ?? query;
    final matches = all.where((order) {
      if (_status != null && order.status != _status) return false;
      if (range != null) {
        final date = order.createdAt?.toLocal();
        if (date == null) return false;
        final day = DateUtils.dateOnly(date);
        if (day.isBefore(range.start) || day.isAfter(range.end)) return false;
      }
      return '${order.number} ${order.tracking} ${order.customer.name}'
              .toLowerCase()
              .contains(query) ||
          order.customer.phone.contains(phone);
    }).toList();
    final orders = _filtered && !_newest ? matches.reversed.toList() : matches;
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 900),
        child: RefreshIndicator(
          onRefresh: refresh,
          child: CustomScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            slivers: [
              SliverPadding(
                padding: const EdgeInsets.all(16),
                sliver: SliverToBoxAdapter(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      TextField(
                        onChanged: (value) => setState(() => _query = value),
                        decoration: const InputDecoration(
                          labelText: 'Search order, name, phone or tracking ID',
                          prefixIcon: Icon(Icons.search),
                        ),
                      ),
                      const SizedBox(height: 10),
                      SizedBox(
                        height: 44,
                        child: ListView(
                          scrollDirection: Axis.horizontal,
                          children: [
                            for (final status in [null, ...OrderStatus.values])
                              Padding(
                                padding: const EdgeInsets.only(right: 7),
                                child: ChoiceChip(
                                  label: Text(status?.label ?? 'All'),
                                  selected: _status == status,
                                  onSelected: (_) =>
                                      setState(() => _status = status),
                                ),
                              ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 8),
                      Wrap(
                        spacing: 8,
                        runSpacing: 4,
                        children: [
                          OutlinedButton.icon(
                            onPressed: _pickRange,
                            icon: const Icon(Icons.date_range_outlined),
                            label: Text(
                              range == null
                                  ? 'Any date'
                                  : '${MaterialLocalizations.of(context).formatCompactDate(range.start)} – ${MaterialLocalizations.of(context).formatCompactDate(range.end)}',
                            ),
                          ),
                          if (range != null)
                            IconButton(
                              onPressed: () => setState(() => _range = null),
                              tooltip: 'Clear date filter',
                              icon: const Icon(Icons.close),
                            ),
                          TextButton.icon(
                            onPressed: () => setState(() => _newest = !_newest),
                            icon: const Icon(Icons.sort),
                            label: Text(
                              _newest ? 'Newest first' : 'Oldest first',
                            ),
                          ),
                        ],
                      ),
                      if (orders.isEmpty && footer == null)
                        Padding(
                          padding: const EdgeInsets.only(top: 14),
                          child: Text(
                            all.isEmpty
                                ? 'Create your first order.'
                                : 'No orders match these filters.',
                          ),
                        ),
                    ],
                  ),
                ),
              ),
              SliverPadding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                sliver: SliverList.builder(
                  itemCount: orders.length,
                  itemBuilder: (context, index) {
                    final order = orders[index];
                    final quick = switch (order.status) {
                      OrderStatus.confirmed => OrderStatus.packed,
                      OrderStatus.packed => OrderStatus.shipped,
                      _ => null,
                    };
                    final tile = Card(
                      child: ListTile(
                        title: Text(
                          '${order.number} · ${order.customer.name}',
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                        subtitle: Text(
                          '${order.status.label} · ${orderDate(order.createdAt)}',
                        ),
                        trailing: Text(lkr(order.totals.total)),
                        onTap: () => _open(order),
                        onLongPress: quick == null
                            ? null
                            : () => _quick(order, quick),
                      ),
                    );
                    if (quick == null) return tile;
                    return Dismissible(
                      key: ValueKey(order.id),
                      direction: DismissDirection.endToStart,
                      confirmDismiss: (_) => _quick(order, quick),
                      background: Container(
                        alignment: Alignment.centerRight,
                        padding: const EdgeInsets.only(right: 16),
                        color: Theme.of(context).colorScheme.primaryContainer,
                        child: Text(quick.label),
                      ),
                      child: tile,
                    );
                  },
                ),
              ),
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 104),
                sliver: SliverToBoxAdapter(child: footer),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
