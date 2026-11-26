import 'package:jewellery_business_manager/core/localization/copy.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:printing/printing.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../core/widgets/premium_card.dart';
import '../../../core/widgets/scan_code_page.dart';
import '../../shipping/domain/courier.dart';
import '../../shipping/presentation/shipping_providers.dart';
import '../../inventory/domain/inventory_product.dart';
import '../../inventory/presentation/inventory_format.dart';
import '../domain/shop_order.dart';
import 'order_editor_page.dart';
import 'order_format.dart';
import 'order_printing.dart';
import 'order_providers.dart';

Future<void> openOrderDetails(BuildContext context, ShopOrder order) =>
    Navigator.push<void>(
      context,
      MaterialPageRoute(builder: (_) => _OrderDetailsPage(initial: order)),
    );

Future<OrderUpdate?> askOrderTransition(
  BuildContext context,
  ShopOrder order,
  OrderStatus target,
) => showModalBottomSheet<OrderUpdate>(
  context: context,
  isScrollControlled: true,
  useSafeArea: true,
  showDragHandle: true,
  constraints: const BoxConstraints(maxWidth: 550),
  builder: (_) => _TransitionSheet(order: order, target: target),
);

class _OrderDetailsPage extends ConsumerStatefulWidget {
  const _OrderDetailsPage({required this.initial});
  final ShopOrder initial;

  @override
  ConsumerState<_OrderDetailsPage> createState() => _OrderDetailsPageState();
}

class _OrderDetailsPageState extends ConsumerState<_OrderDetailsPage> {
  bool _busy = false;

  Future<void> _work(Future<void> Function() action) async {
    if (_busy) return;
    setState(() => _busy = true);
    try {
      await action();
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(orderError(error))));
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _transition(ShopOrder order, OrderStatus target) =>
      _work(() async {
        final update = await askOrderTransition(context, order, target);
        if (mounted && update != null) {
          await ref.read(orderRepositoryProvider).transition(order.id, update);
        }
      });

  Future<void> _contact(ShopOrder order, {required bool whatsapp}) =>
      _work(() async {
        final phone = order.customer.phone;
        final uri = whatsapp
            ? Uri.https('wa.me', '/${phone.substring(1)}')
            : Uri(scheme: 'tel', path: phone);
        if (!await launchUrl(uri, webOnlyWindowName: '_blank')) {
          throw const OrderFailure('Could not open the contact app.');
        }
      });

  Future<void> _message(ShopOrder order, String text) => _work(() async {
    final uri = Uri.https('wa.me', '/${order.customer.phone.substring(1)}', {
      'text': text,
    });
    if (!await launchUrl(uri, webOnlyWindowName: '_blank')) {
      throw const OrderFailure('Could not open WhatsApp.');
    }
  });

  Future<void> _print(
    ShopOrder order, {
    bool label = false,
    bool share = false,
  }) => _work(() async {
    final filename = '${order.number}-${label ? 'label' : 'invoice'}.pdf';
    if (share) {
      await Printing.sharePdf(
        bytes: await orderPdf(order, label: label),
        filename: filename,
      );
    } else {
      await Printing.layoutPdf(
        onLayout: (_) => orderPdf(order, label: label),
        name: filename,
      );
    }
  });

  @override
  Widget build(BuildContext context) {
    final initial = widget.initial;
    final order =
        ref
            .watch(ordersProvider(phone: initial.customer.phone))
            .asData
            ?.value
            .where((entry) => entry.id == initial.id)
            .firstOrNull ??
        initial;
    final theme = Theme.of(context);
    final courier = order.tracking.isEmpty
        ? null
        : ref
              .watch(couriersProvider)
              .asData
              ?.value
              .where((record) => record.key == courierKey(order.courier))
              .firstOrNull;
    final trackingLink = courier?.trackingLink(order.tracking);
    final grossProfit =
        order.totals.subtotal -
        order.totals.discount -
        order.lines.fold<int>(
          0,
          (total, line) => total + line.cost * line.quantity,
        );
    return Scaffold(
      appBar: AppBar(
        title: Text(order.number),
        actions: [
          IconButton(
            onPressed: _busy
                ? null
                : () => _work(() async {
                    await showModalBottomSheet<void>(
                      context: context,
                      isScrollControlled: true,
                      useSafeArea: true,
                      showDragHandle: true,
                      constraints: const BoxConstraints(maxWidth: 600),
                      builder: (_) => _EditDetails(order: order),
                    );
                  }),
            icon: const Icon(Icons.edit_outlined),
            tooltip: 'Edit notes and payment',
          ),
        ],
      ),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 800),
          child: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              if (_busy) const LinearProgressIndicator(),
              PremiumCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Chip(label: Text(order.status.label)),
                    Text(
                      order.customer.name,
                      style: theme.textTheme.headlineMedium,
                    ),
                    SelectableText(order.customer.phone),
                    Text('${order.customer.address}, ${order.customer.city}'),
                    Wrap(
                      spacing: 8,
                      children: [
                        TextButton.icon(
                          onPressed: _busy
                              ? null
                              : () => _contact(order, whatsapp: false),
                          icon: const Icon(Icons.call_outlined),
                          label: const Text('Call'),
                        ),
                        TextButton.icon(
                          onPressed: _busy
                              ? null
                              : () => _contact(order, whatsapp: true),
                          icon: const Icon(Icons.chat_outlined),
                          label: const Text('WhatsApp'),
                        ),
                        PopupMenuButton<String>(
                          enabled: !_busy,
                          tooltip: 'WhatsApp templates',
                          onSelected: (text) => _message(order, text),
                          itemBuilder: (_) => [
                            PopupMenuItem(
                              value:
                                  'Hi ${order.customer.name}, we’ve confirmed order ${order.number}. We’ll let you know when it ships.',
                              child: const Text('Order confirmed'),
                            ),
                            if (order.tracking.isNotEmpty)
                              PopupMenuItem(
                                value:
                                    'Hi ${order.customer.name}, order ${order.number} shipped with ${order.courier}. Tracking: ${order.tracking}${trackingLink == null ? '' : ' · $trackingLink'}',
                                child: const Text('Shipped with tracking'),
                              ),
                            PopupMenuItem(
                              value:
                                  'Hi ${order.customer.name}, did order ${order.number} arrive safely?',
                              child: const Text('Delivery follow-up'),
                            ),
                          ],
                          child: const Padding(
                            padding: EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 12,
                            ),
                            child: Text('Message templates'),
                          ),
                        ),
                      ],
                    ),
                    Text(
                      'Source: ${order.source} · ${orderDate(order.createdAt)}',
                    ),
                    if (order.tracking.isNotEmpty)
                      SelectableText('${order.courier} · ${order.tracking}'),
                    if (trackingLink != null)
                      TextButton.icon(
                        onPressed: _busy
                            ? null
                            : () => _work(() async {
                                if (!await launchUrl(
                                  trackingLink,
                                  webOnlyWindowName: '_blank',
                                )) {
                                  throw const OrderFailure(
                                    'Could not open the courier tracking page.',
                                  );
                                }
                              }),
                        icon: const Icon(Icons.open_in_new),
                        label: const Copy('Track with courier'),
                      ),
                    if (order.notes.isNotEmpty) Text(order.notes),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              PremiumCard(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Copy('Order items', style: theme.textTheme.titleLarge),
                    for (final line in order.lines)
                      ListTile(
                        contentPadding: EdgeInsets.zero,
                        title: Text(line.name),
                        subtitle: Text(
                          '${line.sku} · ${line.quantity} × ${lkr(line.price)}',
                        ),
                        trailing: Text(lkr(line.price * line.quantity)),
                      ),
                    const Divider(),
                    Text('Subtotal ${lkr(order.totals.subtotal)}'),
                    Text(
                      'Delivery ${lkr(order.totals.delivery)} · Discount ${lkr(order.totals.discount)}',
                    ),
                    Text(
                      'Total ${lkr(order.totals.total)}',
                      style: theme.textTheme.titleMedium,
                    ),
                    Text(
                      '${order.payment.label} · Outstanding ${lkr(order.remaining)}',
                    ),
                    Text('Gross merchandise profit ${lkr(grossProfit)}'),
                    const SizedBox(height: 10),
                    Wrap(
                      spacing: 8,
                      runSpacing: 6,
                      children: [
                        OutlinedButton.icon(
                          onPressed: _busy ? null : () => _print(order),
                          icon: const Icon(Icons.print_outlined),
                          label: const Copy('Print invoice'),
                        ),
                        OutlinedButton.icon(
                          onPressed: _busy
                              ? null
                              : () => _print(order, share: true),
                          icon: const Icon(Icons.share_outlined),
                          label: const Copy('Share invoice'),
                        ),
                        OutlinedButton.icon(
                          onPressed: _busy
                              ? null
                              : () => _print(order, label: true),
                          icon: const Icon(Icons.local_shipping_outlined),
                          label: const Copy('Print courier label'),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              if (order.status == OrderStatus.pending) ...[
                const SizedBox(height: 12),
                OutlinedButton.icon(
                  onPressed: _busy
                      ? null
                      : () => Navigator.of(context).push<String>(
                          MaterialPageRoute(
                            builder: (_) => OrderEditorPage(existing: order),
                          ),
                        ),
                  icon: const Icon(Icons.edit_note),
                  label: const Text('Edit items and charges'),
                ),
              ],
              if (order.status.next.isNotEmpty) ...[
                const SizedBox(height: 14),
                Copy('Update status', style: theme.textTheme.titleLarge),
                Wrap(
                  spacing: 8,
                  runSpacing: 6,
                  children: [
                    for (final next in order.status.next)
                      FilledButton.tonal(
                        onPressed: _busy
                            ? null
                            : () => _transition(order, next),
                        child: Copy(next.label),
                      ),
                  ],
                ),
              ],
              const SizedBox(height: 16),
              Copy('Status timeline', style: theme.textTheme.titleLarge),
              const SizedBox(height: 6),
              TweenAnimationBuilder<double>(
                tween: Tween(begin: 0, end: 1),
                duration: MediaQuery.disableAnimationsOf(context)
                    ? Duration.zero
                    : const Duration(milliseconds: 260),
                builder: (_, value, child) =>
                    Opacity(opacity: value, child: child),
                child: Column(
                  children: [
                    for (final event in order.history.reversed)
                      ListTile(
                        contentPadding: EdgeInsets.zero,
                        leading: const Icon(Icons.radio_button_checked),
                        title: Text(event.status.label),
                        subtitle: Text(
                          event.note.isEmpty
                              ? orderDate(event.at)
                              : '${orderDate(event.at)}\n${event.note}',
                        ),
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
}

class _TransitionSheet extends ConsumerStatefulWidget {
  const _TransitionSheet({required this.order, required this.target});
  final ShopOrder order;
  final OrderStatus target;

  @override
  ConsumerState<_TransitionSheet> createState() => _TransitionSheetState();
}

class _TransitionSheetState extends ConsumerState<_TransitionSheet> {
  final _form = GlobalKey<FormState>();
  final _note = TextEditingController();
  late final _courier = TextEditingController(text: widget.order.courier);
  late final _tracking = TextEditingController(text: widget.order.tracking);
  bool _restock = false;
  String? _trackingError;

  Future<void> _scan() async {
    final value = await Navigator.push<String>(
      context,
      MaterialPageRoute(
        builder: (_) => const ScanCodePage(
          title: 'Scan parcel waybill',
          manualLabel: 'Enter tracking ID manually',
        ),
      ),
    );
    if (!mounted || value == null) return;
    if (normalizedWaybill(value) == null) {
      setState(
        () =>
            _trackingError = 'Scan the courier’s waybill, or type it manually.',
      );
      return;
    }
    setState(() {
      _tracking.text = value;
      _trackingError = null;
    });
  }

  @override
  void dispose() {
    _note.dispose();
    _courier.dispose();
    _tracking.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final shipping = widget.target == OrderStatus.shipped;
    final couriers = shipping
        ? ref
                  .watch(couriersProvider)
                  .asData
                  ?.value
                  .where((record) => record.active)
                  .toList() ??
              <Courier>[]
        : <Courier>[];
    final canRestock =
        widget.order.restockAvailable &&
        (widget.target == OrderStatus.cancelled ||
            widget.target == OrderStatus.returned);
    return SingleChildScrollView(
      padding: EdgeInsets.fromLTRB(
        20,
        8,
        20,
        24 + MediaQuery.viewInsetsOf(context).bottom,
      ),
      child: Form(
        key: _form,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              'Mark as ${widget.target.label.toLowerCase()}',
              style: Theme.of(context).textTheme.headlineMedium,
            ),
            const SizedBox(height: 12),
            if (shipping) ...[
              if (couriers.isNotEmpty)
                Align(
                  alignment: Alignment.centerLeft,
                  child: PopupMenuButton<Courier>(
                    tooltip: 'Choose saved courier',
                    onSelected: (record) =>
                        setState(() => _courier.text = record.name),
                    itemBuilder: (_) => [
                      for (final record in couriers)
                        PopupMenuItem(value: record, child: Text(record.name)),
                    ],
                    child: const Chip(
                      avatar: Icon(Icons.local_shipping_outlined),
                      label: Text('Choose saved courier'),
                    ),
                  ),
                ),
              _field(_courier, 'Courier name', required: true),
              _field(_tracking, 'Tracking ID', required: true),
              OutlinedButton.icon(
                onPressed: _scan,
                icon: const Icon(Icons.qr_code_scanner),
                label: const Copy('Scan parcel'),
              ),
              if (_trackingError case final message?)
                Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: Text(
                    message,
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.error,
                    ),
                  ),
                ),
              const SizedBox(height: 8),
            ],
            _field(
              _note,
              widget.target.needsReason ? 'Reason' : 'Note (optional)',
              required: widget.target.needsReason,
            ),
            if (canRestock)
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                value: _restock,
                title: const Text('Return units to inventory'),
                subtitle: const Text(
                  'Enable only if the units are back and sellable.',
                ),
                onChanged: (value) => setState(() => _restock = value),
              ),
            FilledButton(
              onPressed: () {
                if (_form.currentState!.validate()) {
                  if (shipping && normalizedWaybill(_tracking.text) == null) {
                    setState(() => _trackingError = 'Enter a valid waybill.');
                    return;
                  }
                  Navigator.pop(
                    context,
                    OrderUpdate(
                      widget.target,
                      note: _note.text,
                      courier: _courier.text,
                      tracking: _tracking.text,
                      restock: _restock,
                    ),
                  );
                }
              },
              child: const Copy('Confirm status change'),
            ),
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Copy('Back'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _field(
    TextEditingController controller,
    String label, {
    required bool required,
  }) => Padding(
    padding: const EdgeInsets.only(bottom: 12),
    child: TextFormField(
      controller: controller,
      maxLength: 250,
      decoration: InputDecoration(labelText: label, counterText: ''),
      validator: (value) =>
          required && (value?.trim() ?? '').isEmpty ? 'Required' : null,
    ),
  );
}

class _EditDetails extends ConsumerStatefulWidget {
  const _EditDetails({required this.order});
  final ShopOrder order;

  @override
  ConsumerState<_EditDetails> createState() => _EditDetailsState();
}

class _EditDetailsState extends ConsumerState<_EditDetails> {
  late final _notes = TextEditingController(text: widget.order.notes);
  late final _advance = TextEditingController(
    text: (widget.order.advance / 100).toStringAsFixed(2),
  );
  late OrderPayment _payment = widget.order.payment;
  bool _busy = false;
  String? _error;

  Future<void> _save() async {
    final advance = toCents(_advance.text);
    if (advance == null) {
      setState(() => _error = 'Enter a valid advance amount.');
      return;
    }
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await ref
          .read(orderRepositoryProvider)
          .updateDetails(
            widget.order.id,
            notes: _notes.text,
            payment: _payment,
            advance: advance,
          );
      if (mounted) Navigator.pop(context);
    } catch (error) {
      if (mounted) setState(() => _error = orderError(error));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  void dispose() {
    _notes.dispose();
    _advance.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => SingleChildScrollView(
    padding: EdgeInsets.fromLTRB(
      20,
      8,
      20,
      24 + MediaQuery.viewInsetsOf(context).bottom,
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          'Edit notes and payment',
          style: Theme.of(context).textTheme.headlineMedium,
        ),
        const SizedBox(height: 12),
        TextField(
          controller: _notes,
          enabled: !_busy,
          maxLines: 2,
          maxLength: 1000,
          decoration: const InputDecoration(labelText: 'Order notes'),
        ),
        const SizedBox(height: 12),
        DropdownButtonFormField<OrderPayment>(
          value: _payment,
          isExpanded: true,
          decoration: const InputDecoration(label: Copy('Payment method')),
          items: [
            for (final payment in OrderPayment.values)
              DropdownMenuItem(value: payment, child: Copy(payment.label)),
          ],
          onChanged: _busy
              ? null
              : (value) => setState(() => _payment = value!),
        ),
        const SizedBox(height: 12),
        TextField(
          controller: _advance,
          enabled: !_busy,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          decoration: const InputDecoration(
            labelText: 'Advance received (LKR)',
          ),
        ),
        if (_error case final message?)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 8),
            child: Text(message),
          ),
        const SizedBox(height: 12),
        FilledButton(
          onPressed: _busy ? null : _save,
          child: Text(_busy ? 'Saving…' : 'Save changes'),
        ),
      ],
    ),
  );
}
