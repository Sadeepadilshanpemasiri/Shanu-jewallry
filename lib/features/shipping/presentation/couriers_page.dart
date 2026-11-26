import 'package:jewellery_business_manager/core/localization/copy.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../orders/presentation/order_format.dart';
import '../domain/courier.dart';
import 'shipping_providers.dart';

class CouriersPage extends ConsumerWidget {
  const CouriersPage({super.key});

  Future<void> _edit(BuildContext context, [Courier? courier]) =>
      showModalBottomSheet<void>(
        context: context,
        useSafeArea: true,
        isScrollControlled: true,
        showDragHandle: true,
        constraints: const BoxConstraints(maxWidth: 560),
        builder: (_) => _CourierEditor(courier: courier),
      );

  @override
  Widget build(BuildContext context, WidgetRef ref) => Scaffold(
    appBar: AppBar(title: const Copy('Couriers')),
    floatingActionButton: FloatingActionButton.extended(
      onPressed: () => _edit(context),
      icon: const Icon(Icons.add),
      label: const Copy('Add courier'),
    ),
    body: ref
        .watch(couriersProvider)
        .when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (error, _) => Center(
            child: TextButton(
              onPressed: () => ref.invalidate(couriersProvider),
              child: Text('${shippingError(error)} Retry'),
            ),
          ),
          data: (couriers) => Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 740),
              child: couriers.isEmpty
                  ? const Text('Add a courier to start using Quick Ship.')
                  : ListView.builder(
                      padding: const EdgeInsets.fromLTRB(16, 12, 16, 100),
                      itemCount: couriers.length,
                      itemBuilder: (context, index) {
                        final courier = couriers[index];
                        return Card(
                          child: ListTile(
                            leading: const Icon(Icons.local_shipping_outlined),
                            title: Text(courier.name),
                            subtitle: Text(
                              courier.template.isEmpty
                                  ? 'No tracking link configured'
                                  : courier.template,
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                            ),
                            trailing: courier.active
                                ? const Icon(Icons.edit_outlined)
                                : const Text('Inactive'),
                            onTap: () => _edit(context, courier),
                          ),
                        );
                      },
                    ),
            ),
          ),
        ),
  );
}

String shippingError(Object error) =>
    error is ShippingFailure ? error.message : orderError(error);

class _CourierEditor extends ConsumerStatefulWidget {
  const _CourierEditor({this.courier});
  final Courier? courier;

  @override
  ConsumerState<_CourierEditor> createState() => _CourierEditorState();
}

class _CourierEditorState extends ConsumerState<_CourierEditor> {
  final _form = GlobalKey<FormState>();
  late final _name = TextEditingController(text: widget.courier?.name);
  late final _template = TextEditingController(text: widget.courier?.template);
  late bool _active = widget.courier?.active ?? true;
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
          .read(courierRepositoryProvider)
          .save(
            Courier(
              name: _name.text.trim(),
              template: _template.text.trim(),
              active: _active,
            ),
            editing: widget.courier != null,
          );
      if (mounted) Navigator.pop(context);
    } catch (error) {
      if (mounted) setState(() => _error = shippingError(error));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  void dispose() {
    _name.dispose();
    _template.dispose();
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
          Text(
            widget.courier == null ? 'Add courier' : 'Courier settings',
            style: Theme.of(context).textTheme.headlineMedium,
          ),
          const SizedBox(height: 12),
          TextFormField(
            controller: _name,
            enabled: !_busy && widget.courier == null,
            maxLength: 80,
            decoration: const InputDecoration(
              label: Copy('Courier name'),
              counterText: '',
            ),
            validator: (value) =>
                (value?.trim() ?? '').isEmpty ? 'Enter a name.' : null,
          ),
          const SizedBox(height: 12),
          TextFormField(
            controller: _template,
            enabled: !_busy,
            maxLength: 600,
            keyboardType: TextInputType.url,
            decoration: const InputDecoration(
              labelText: 'Tracking URL template (optional)',
              helperText: 'Use {tracking} where the waybill goes.',
              counterText: '',
            ),
            validator: (value) {
              final template = value?.trim() ?? '';
              return template.isNotEmpty &&
                      trackingUri(template, 'DEMO-123') == null
                  ? 'Enter an HTTPS URL with {tracking} in the path or query.'
                  : null;
            },
          ),
          const SizedBox(height: 8),
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            value: _active,
            title: const Text('Available for new shipments'),
            onChanged: _busy
                ? null
                : (value) => setState(() => _active = value),
          ),
          if (_error case final message?)
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Text(
                message,
                style: TextStyle(color: Theme.of(context).colorScheme.error),
              ),
            ),
          FilledButton(
            onPressed: _busy ? null : _save,
            child: Text(_busy ? 'Saving…' : 'Save courier'),
          ),
        ],
      ),
    ),
  );
}
