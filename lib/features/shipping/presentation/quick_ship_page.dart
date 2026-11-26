import 'package:jewellery_business_manager/core/localization/copy.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/widgets/barcode_camera.dart';
import '../../../core/widgets/premium_card.dart';
import '../../orders/domain/shop_order.dart';
import '../../orders/presentation/order_details_page.dart';
import '../../orders/presentation/order_providers.dart';
import '../domain/courier.dart';
import '../domain/parcel_lookup.dart';
import 'couriers_page.dart';
import 'parcel_link_sheet.dart';
import 'shipping_providers.dart';

class QuickShipPage extends ConsumerStatefulWidget {
  const QuickShipPage({super.key});

  @override
  ConsumerState<QuickShipPage> createState() => _QuickShipPageState();
}

class _Parcel {
  _Parcel({this.order, this.waybill = ''});
  ShopOrder? order;
  String waybill;
  bool shipped = false;
  String? error;
  bool get ready =>
      !shipped && order != null && normalizedWaybill(waybill) != null;
}

class _QuickShipPageState extends ConsumerState<QuickShipPage> {
  final _code = TextEditingController();
  final _queue = <_Parcel>[];
  String? _courierKey, _notice;
  _Parcel? _target;
  bool _camera = false, _busy = false, _warning = false;

  @override
  void dispose() {
    _code.dispose();
    super.dispose();
  }

  void _feedback(String message, {bool warning = false}) {
    setState(() {
      _notice = message;
      _warning = warning;
    });
    if (!warning) {
      HapticFeedback.selectionClick().ignore();
      SystemSound.play(SystemSoundType.click).ignore();
    }
  }

  _Parcel? _queuedOrder(String id) =>
      _queue.where((item) => item.order?.id == id).firstOrNull;
  bool _usedWaybill(String value, {_Parcel? except}) => _queue.any(
    (item) =>
        item != except &&
        normalizedWaybill(item.waybill) == normalizedWaybill(value),
  );

  void _receive(String input, List<ShopOrder> orders, Courier courier) {
    if (!mounted || _busy || ModalRoute.of(context)?.isCurrent != true) return;
    final code = input.trim();
    if (code.isEmpty) return;
    final matches = matchParcelOrders(orders, code, courier.name);
    if (matches.length > 1) {
      _feedback(
        'Several older orders match this waybill. Review them in Orders.',
        warning: true,
      );
      return;
    }
    if (matches.isNotEmpty) {
      final order = matches.single;
      if (!canShip(order)) {
        _feedback(
          '${order.number} is ${order.status.label.toLowerCase()}. Quick Ship accepts packed or failed-delivery orders.',
          warning: true,
        );
        return;
      }
      if (_queuedOrder(order.id) case final item?) {
        if (!item.shipped && item.waybill.isEmpty) {
          setState(() => _target = item);
          _feedback('Scan the courier waybill for ${order.number}.');
        }
        return;
      }
      final tracked =
          courierKey(order.courier) == courier.key &&
              normalizedWaybill(order.tracking) != null &&
              !_usedWaybill(order.tracking)
          ? order.tracking
          : '';
      final parcel = _Parcel(order: order, waybill: tracked);
      setState(() {
        _queue.add(parcel);
        if (tracked.isEmpty) _target = parcel;
      });
      _feedback(
        tracked.isEmpty
            ? 'Scan the courier waybill for ${order.number}.'
            : '${order.number} added to the batch.',
      );
      return;
    }
    if (normalizedWaybill(code) == null) {
      _feedback(
        'This code is not a recognized order label or waybill.',
        warning: true,
      );
      return;
    }
    if (_usedWaybill(code)) return;
    final next = _target;
    if (next != null && next.waybill.isEmpty) {
      setState(() {
        next.waybill = code;
        _target = null;
      });
      _feedback('${next.order!.number} linked to $code.');
    } else {
      setState(() => _queue.add(_Parcel(waybill: code)));
      _feedback('Waybill added. Choose the order for $code.');
    }
  }

  Future<void> _link(_Parcel parcel, List<ShopOrder> orders) async {
    final eligible = orders
        .where((item) => canShip(item) && _queuedOrder(item.id) == null)
        .toList();
    final order = await chooseParcelOrder(context, eligible);
    if (!mounted || order == null) return;
    setState(() {
      parcel.order = order;
      parcel.error = null;
    });
    _feedback('${order.number} linked to ${parcel.waybill}.');
  }

  Future<void> _editWaybill(_Parcel parcel) async {
    final code = await showDialog<String>(
      context: context,
      builder: (_) => _WaybillDialog(parcel.waybill),
    );
    if (!mounted || code == null) return;
    if (_usedWaybill(code, except: parcel)) {
      _feedback('This waybill is already in the batch.', warning: true);
      return;
    }
    setState(() {
      parcel.waybill = code;
      parcel.error = null;
      if (_target == parcel) _target = null;
    });
    _feedback('Waybill updated.');
  }

  Future<void> _ship(Courier courier, List<_Parcel> parcels) async {
    if (_busy || parcels.isEmpty) return;
    final repository = ref.read(orderRepositoryProvider);
    setState(() {
      _busy = true;
      _camera = false;
    });
    var completed = 0;
    for (final parcel in parcels) {
      if (!mounted) return;
      try {
        await repository.transition(
          parcel.order!.id,
          OrderUpdate(
            OrderStatus.shipped,
            courier: courier.name,
            tracking: parcel.waybill,
            note: 'Dispatched from Quick Ship',
          ),
        );
        if (!mounted) return;
        setState(() {
          parcel.shipped = true;
          parcel.error = null;
        });
        completed++;
      } catch (error) {
        if (!mounted) return;
        setState(() => parcel.error = shippingError(error));
      }
    }
    if (!mounted) return;
    setState(() => _busy = false);
    _feedback(
      completed == parcels.length
          ? 'Shipped $completed ${completed == 1 ? 'parcel' : 'parcels'}.'
          : 'Shipped $completed of ${parcels.length}. Review parcels with errors.',
      warning: completed != parcels.length,
    );
  }

  @override
  Widget build(BuildContext context) {
    final saved = ref.watch(couriersProvider);
    final recent = ref.watch(ordersProvider());
    final active =
        saved.asData?.value.where((courier) => courier.active).toList() ?? [];
    final courier = active
        .where((value) => value.key == _courierKey)
        .firstOrNull;
    final orders = recent.asData?.value ?? <ShopOrder>[];
    final ready = _queue.where((parcel) => parcel.ready).toList();
    final completed = _queue.where((parcel) => parcel.shipped).length;
    final enabled = courier != null && recent.hasValue && !_busy;
    return PopScope(
      canPop: !_busy,
      child: Scaffold(
        appBar: AppBar(
          title: const Copy('Quick Ship'),
          leading: BackButton(
            onPressed: _busy
                ? () {}
                : () {
                    if (context.canPop()) {
                      context.pop();
                    } else {
                      context.go('/');
                    }
                  },
          ),
          actions: [
            IconButton(
              onPressed: _busy
                  ? null
                  : () {
                      if (_camera) setState(() => _camera = false);
                      Navigator.push<void>(
                        context,
                        MaterialPageRoute(builder: (_) => const CouriersPage()),
                      );
                    },
              icon: const Icon(Icons.settings_outlined),
              tooltip: 'Manage couriers',
            ),
          ],
        ),
        body: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 760),
            child: ListView(
              padding: const EdgeInsets.all(16),
              children: [
                if (saved.isLoading || recent.isLoading)
                  const LinearProgressIndicator(),
                if (saved.hasError || recent.hasError)
                  TextButton(
                    onPressed: () {
                      ref.invalidate(couriersProvider);
                      ref.invalidate(ordersProvider());
                    },
                    child: const Text(
                      'Could not load couriers or orders. Retry',
                    ),
                  ),
                if (saved.hasValue && active.isEmpty)
                  const Text(
                    'Add an active courier in Manage couriers to build a shipping batch.',
                  ),
                DropdownButtonFormField<String>(
                  value: courier?.key,
                  isExpanded: true,
                  decoration: const InputDecoration(
                    labelText: 'Courier for this batch',
                  ),
                  items: [
                    for (final value in active)
                      DropdownMenuItem(
                        value: value.key,
                        child: Text(value.name),
                      ),
                  ],
                  onChanged: _queue.isNotEmpty || _busy || active.isEmpty
                      ? null
                      : (value) {
                          setState(() {
                            _courierKey = value;
                            _notice = null;
                          });
                        },
                ),
                if (_queue.isNotEmpty && courier == null && saved.hasValue)
                  const Text(
                    'This courier is inactive. Reactivate it or clear this batch.',
                  ),
                const SizedBox(height: 12),
                if (_target case final parcel?)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: Text(
                      'Next waybill links to ${parcel.order!.number}.',
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                  ),
                if (_camera && enabled)
                  BarcodeCamera(
                    onCode: (value) => _receive(value, orders, courier),
                  ),
                Wrap(
                  spacing: 8,
                  runSpacing: 4,
                  children: [
                    OutlinedButton.icon(
                      onPressed: !enabled
                          ? null
                          : () => setState(() => _camera = !_camera),
                      icon: Icon(
                        _camera
                            ? Icons.videocam_off_outlined
                            : Icons.qr_code_scanner,
                      ),
                      label: Text(_camera ? 'Stop camera' : 'Start camera'),
                    ),
                    if (enabled)
                      TextButton.icon(
                        icon: const Icon(Icons.search),
                        label: const Copy('Choose order'),
                        onPressed: () async {
                          final order = await chooseParcelOrder(
                            context,
                            orders.where(canShip).toList(),
                          );
                          if (mounted && order != null) {
                            _receive(
                              parcelLabelCode(order.id),
                              orders,
                              courier,
                            );
                          }
                        },
                      ),
                  ],
                ),
                const SizedBox(height: 8),
                TextField(
                  controller: _code,
                  enabled: enabled,
                  textInputAction: TextInputAction.done,
                  autocorrect: false,
                  decoration: InputDecoration(
                    labelText: 'Enter order number or waybill',
                    suffixIcon: IconButton(
                      tooltip: 'Add code',
                      icon: const Icon(Icons.add_circle_outline),
                      onPressed: enabled
                          ? () {
                              _receive(_code.text, orders, courier);
                              _code.clear();
                            }
                          : null,
                    ),
                  ),
                  onSubmitted: enabled
                      ? (value) {
                          _receive(value, orders, courier);
                          _code.clear();
                        }
                      : null,
                ),
                if (_notice case final notice?)
                  Padding(
                    padding: const EdgeInsets.only(top: 12),
                    child: Semantics(
                      liveRegion: true,
                      child: AnimatedSwitcher(
                        duration: MediaQuery.disableAnimationsOf(context)
                            ? Duration.zero
                            : const Duration(milliseconds: 200),
                        child: Row(
                          key: ValueKey(notice),
                          children: [
                            Icon(
                              _warning
                                  ? Icons.warning_amber
                                  : Icons.check_circle_outline,
                              color: _warning
                                  ? Theme.of(context).colorScheme.error
                                  : Theme.of(context).colorScheme.primary,
                            ),
                            const SizedBox(width: 8),
                            Expanded(child: Text(notice)),
                          ],
                        ),
                      ),
                    ),
                  ),
                const SizedBox(height: 14),
                PremiumCard(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Copy(
                        'Batch summary',
                        style: Theme.of(context).textTheme.titleLarge,
                      ),
                      Text(
                        '$completed shipped · ${ready.length} ready · ${_queue.length - completed - ready.length} to link',
                      ),
                      if (_busy) const LinearProgressIndicator(),
                      const SizedBox(height: 8),
                      FilledButton.icon(
                        onPressed: enabled && ready.isNotEmpty
                            ? () => _ship(courier, ready)
                            : null,
                        icon: const Icon(Icons.local_shipping_outlined),
                        label: Text('Ship ${ready.length} ready'),
                      ),
                      if (_queue.isNotEmpty)
                        TextButton(
                          onPressed: _busy
                              ? null
                              : () => setState(() {
                                  _queue.clear();
                                  _target = null;
                                  _notice = null;
                                }),
                          child: const Text('Clear batch'),
                        ),
                    ],
                  ),
                ),
                for (final parcel in _queue) _tile(parcel, orders, courier),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _tile(
    _Parcel parcel,
    List<ShopOrder> orders,
    Courier? courier,
  ) => Card(
    child: Padding(
      padding: const EdgeInsets.all(12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            parcel.order == null
                ? 'Unmatched waybill'
                : '${parcel.order!.number} · ${parcel.order!.customer.name}',
            style: Theme.of(context).textTheme.titleMedium,
          ),
          Text(parcel.waybill.isEmpty ? 'Waybill needed' : parcel.waybill),
          if (parcel.shipped)
            const Chip(
              avatar: Icon(Icons.check, size: 18),
              label: Copy('Shipped'),
            ),
          if (parcel.error case final error?)
            Text(
              error,
              style: TextStyle(color: Theme.of(context).colorScheme.error),
            ),
          Wrap(
            spacing: 6,
            children: [
              if (parcel.order != null)
                TextButton(
                  onPressed: _busy
                      ? null
                      : () {
                          if (_camera) setState(() => _camera = false);
                          openOrderDetails(context, parcel.order!);
                        },
                  child: const Text('Open order'),
                ),
              if (!parcel.shipped) ...[
                if (parcel.order == null)
                  TextButton(
                    onPressed: _busy ? null : () => _link(parcel, orders),
                    child: const Copy('Link order'),
                  ),
                TextButton(
                  onPressed: _busy ? null : () => _editWaybill(parcel),
                  child: const Copy('Enter waybill'),
                ),
                if (parcel.waybill.isEmpty && parcel.order != null)
                  TextButton(
                    onPressed: _busy
                        ? null
                        : () => setState(() {
                            _target = parcel;
                            _camera = true;
                          }),
                    child: const Text('Scan waybill'),
                  ),
                if (parcel.ready && courier != null)
                  FilledButton.tonal(
                    onPressed: _busy ? null : () => _ship(courier, [parcel]),
                    child: const Text('Mark shipped'),
                  ),
                TextButton(
                  onPressed: _busy
                      ? null
                      : () => setState(() {
                          _queue.remove(parcel);
                          if (_target == parcel) _target = null;
                        }),
                  child: const Text('Remove'),
                ),
              ],
            ],
          ),
        ],
      ),
    ),
  );
}

class _WaybillDialog extends StatefulWidget {
  const _WaybillDialog(this.initial);
  final String initial;

  @override
  State<_WaybillDialog> createState() => _WaybillDialogState();
}

class _WaybillDialogState extends State<_WaybillDialog> {
  late final _text = TextEditingController(text: widget.initial);
  final _form = GlobalKey<FormState>();

  @override
  void dispose() {
    _text.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
    title: const Text('Parcel waybill'),
    content: Form(
      key: _form,
      child: TextFormField(
        controller: _text,
        autofocus: true,
        decoration: const InputDecoration(labelText: 'Waybill number'),
        validator: (value) => normalizedWaybill(value ?? '') == null
            ? 'Enter a valid waybill.'
            : null,
      ),
    ),
    actions: [
      TextButton(
        onPressed: () => Navigator.pop(context),
        child: const Copy('Back'),
      ),
      FilledButton(
        onPressed: () {
          if (_form.currentState!.validate()) {
            Navigator.pop(context, _text.text.trim());
          }
        },
        child: const Text('Use waybill'),
      ),
    ],
  );
}
