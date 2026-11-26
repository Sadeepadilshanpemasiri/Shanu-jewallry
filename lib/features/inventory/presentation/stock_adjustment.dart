import 'package:jewellery_business_manager/core/localization/copy.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../domain/inventory_product.dart';
import 'inventory_format.dart';
import 'inventory_providers.dart';

class StockAdjustment extends ConsumerStatefulWidget {
  const StockAdjustment({super.key, required this.product});
  final InventoryProduct product;

  @override
  ConsumerState<StockAdjustment> createState() => _StockAdjustmentState();
}

class _StockAdjustmentState extends ConsumerState<StockAdjustment> {
  final _form = GlobalKey<FormState>();
  final _quantity = TextEditingController();
  final _reason = TextEditingController();
  StockMovementType _type = StockMovementType.stockIn;
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
          .read(inventoryRepositoryProvider)
          .adjust(
            widget.product.id,
            _type,
            int.parse(_quantity.text.trim()),
            _reason.text,
          );
      if (mounted) Navigator.pop(context, true);
    } catch (error) {
      if (mounted) setState(() => _error = inventoryError(error));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  void dispose() {
    _quantity.dispose();
    _reason.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => SafeArea(
    top: false,
    child: SingleChildScrollView(
      padding: EdgeInsets.fromLTRB(
        20,
        8,
        20,
        20 + MediaQuery.viewInsetsOf(context).bottom,
      ),
      child: Form(
        key: _form,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Copy(
              'Adjust stock',
              style: Theme.of(context).textTheme.headlineMedium,
            ),
            Text(
              '${widget.product.details.name} · ${widget.product.quantity} in stock',
            ),
            const SizedBox(height: 14),
            DropdownButtonFormField<StockMovementType>(
              value: _type,
              decoration: const InputDecoration(labelText: 'Movement'),
              items: [
                for (final option in StockMovementType.values)
                  DropdownMenuItem(
                    value: option,
                    child: Text(movementLabel(option)),
                  ),
              ],
              onChanged: _busy
                  ? null
                  : (value) => setState(() => _type = value!),
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _quantity,
              enabled: !_busy,
              keyboardType: TextInputType.number,
              decoration: InputDecoration(
                labelText: _type == StockMovementType.adjustment
                    ? 'New stock balance'
                    : 'Quantity',
              ),
              validator: (value) {
                final quantity = int.tryParse(value?.trim() ?? '');
                final minimum = _type == StockMovementType.adjustment ? 0 : 1;
                return quantity == null ||
                        quantity < minimum ||
                        quantity > maxStock
                    ? 'Enter a valid quantity.'
                    : null;
              },
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _reason,
              enabled: !_busy,
              maxLength: 250,
              decoration: const InputDecoration(label: Copy('Reason')),
              validator: (value) =>
                  (value?.trim() ?? '').isEmpty ? 'Enter a reason.' : null,
            ),
            if (_error case final message?)
              Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: Semantics(
                  liveRegion: true,
                  child: Text(
                    message,
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.error,
                    ),
                  ),
                ),
              ),
            FilledButton(
              onPressed: _busy ? null : _save,
              child: Text(_busy ? 'Saving…' : 'Save stock movement'),
            ),
          ],
        ),
      ),
    ),
  );
}
