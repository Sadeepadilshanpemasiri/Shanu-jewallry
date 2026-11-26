import 'package:jewellery_business_manager/core/localization/copy.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../orders/domain/shop_order.dart';
import '../../domain/dashboard_data.dart';
import '../dashboard_providers.dart';

class AttentionPanel extends StatelessWidget {
  const AttentionPanel({
    super.key,
    required this.data,
    required this.thresholds,
    required this.onSettings,
    required this.onOrder,
    required this.onStock,
  });

  final DashboardData data;
  final AttentionThresholds thresholds;
  final VoidCallback onSettings, onStock;
  final ValueChanged<ShopOrder> onOrder;

  @override
  Widget build(BuildContext context) {
    final noAlerts =
        data.unshipped.isEmpty &&
        data.overdue.isEmpty &&
        data.stockAlerts.isEmpty &&
        data.customerAlerts.isEmpty;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (noAlerts) const Copy('No orders or stock need attention.'),
        _orders(
          'Waiting to ship',
          'At least ${thresholds.toShipDays} days since placement',
          data.unshipped,
        ),
        _orders(
          'In transit to follow up',
          'At least ${thresholds.transitDays} days since dispatch',
          data.overdue,
        ),
        _orders(
          'Customer review',
          'Active orders for high-risk, watchlisted, or blacklisted customers',
          data.customerAlerts,
        ),
        if (data.stockAlerts.isNotEmpty)
          ExpansionTile(
            tilePadding: EdgeInsets.zero,
            title: Text('Low or out of stock · ${data.stockAlerts.length}'),
            leading: const Icon(Icons.inventory_2_outlined),
            childrenPadding: const EdgeInsets.only(bottom: 8),
            children: [
              for (final product in data.stockAlerts.take(8))
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  title: Text(product.details.name),
                  subtitle: Text(product.details.sku),
                  trailing: Text('${product.quantity} left'),
                  onTap: onStock,
                ),
              TextButton(
                onPressed: onStock,
                child: const Copy('Open inventory'),
              ),
            ],
          ),
        Align(
          alignment: Alignment.centerLeft,
          child: TextButton.icon(
            onPressed: onSettings,
            icon: const Icon(Icons.tune),
            label: const Copy('Attention thresholds'),
          ),
        ),
      ],
    );
  }

  Widget _orders(String title, String detail, List<ShopOrder> orders) =>
      orders.isEmpty
      ? const SizedBox.shrink()
      : ExpansionTile(
          tilePadding: EdgeInsets.zero,
          title: Text('$title · ${orders.length}'),
          subtitle: Text(detail),
          leading: const Icon(Icons.warning_amber_outlined),
          children: [
            for (final order in orders)
              ListTile(
                contentPadding: EdgeInsets.zero,
                title: Text('${order.number} · ${order.customer.name}'),
                subtitle: Text(order.status.label),
                trailing: const Icon(Icons.chevron_right),
                onTap: () => onOrder(order),
              ),
          ],
        );
}

class AttentionSettingsSheet extends ConsumerStatefulWidget {
  const AttentionSettingsSheet({super.key, required this.current});
  final AttentionThresholds current;

  @override
  ConsumerState<AttentionSettingsSheet> createState() =>
      _AttentionSettingsSheetState();
}

class _AttentionSettingsSheetState
    extends ConsumerState<AttentionSettingsSheet> {
  final _form = GlobalKey<FormState>();
  late final _waiting = TextEditingController(
    text: widget.current.toShipDays.toString(),
  );
  late final _transit = TextEditingController(
    text: widget.current.transitDays.toString(),
  );
  bool _busy = false;
  String? _error;

  Future<void> _save() async {
    if (_busy || !_form.currentState!.validate()) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await ref
          .read(dashboardSettingsProvider)
          .save(
            AttentionThresholds(
              toShipDays: int.parse(_waiting.text.trim()),
              transitDays: int.parse(_transit.text.trim()),
            ),
          );
      if (mounted) Navigator.pop(context);
    } catch (_) {
      if (mounted) {
        setState(() => _error = 'Could not save thresholds. Try again.');
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  void dispose() {
    _waiting.dispose();
    _transit.dispose();
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
    child: Form(
      key: _form,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Copy(
            'Attention thresholds',
            style: Theme.of(context).textTheme.headlineMedium,
          ),
          const SizedBox(height: 12),
          for (final field in {
            'Days since order placement': _waiting,
            'Days since dispatch': _transit,
          }.entries)
            Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: TextFormField(
                controller: field.value,
                enabled: !_busy,
                keyboardType: TextInputType.number,
                decoration: InputDecoration(labelText: field.key),
                validator: (value) {
                  final days = int.tryParse(value?.trim() ?? '');
                  return days == null || days < 1 || days > 90
                      ? 'Enter 1 to 90 days.'
                      : null;
                },
              ),
            ),
          if (_error case final message?)
            Text(
              message,
              style: TextStyle(color: Theme.of(context).colorScheme.error),
            ),
          FilledButton(
            onPressed: _busy ? null : _save,
            child: Text(_busy ? 'Saving…' : 'Save thresholds'),
          ),
        ],
      ),
    ),
  );
}
