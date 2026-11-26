import 'package:jewellery_business_manager/core/localization/copy.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';

import '../domain/inventory_product.dart';
import '../domain/inventory_repository.dart';
import 'inventory_format.dart';
import 'inventory_providers.dart';

Future<bool?> openProductEditor(
  BuildContext context, [
  InventoryProduct? product,
]) => showModalBottomSheet<bool>(
  context: context,
  isScrollControlled: true,
  useSafeArea: true,
  showDragHandle: true,
  constraints: const BoxConstraints(maxWidth: 640),
  builder: (_) => FractionallySizedBox(
    heightFactor: .92,
    child: ProductEditor(product: product),
  ),
);

class ProductEditor extends ConsumerStatefulWidget {
  const ProductEditor({super.key, this.product});
  final InventoryProduct? product;

  @override
  ConsumerState<ProductEditor> createState() => _ProductEditorState();
}

class _ProductEditorState extends ConsumerState<ProductEditor> {
  final _form = GlobalKey<FormState>();
  late final _details = widget.product?.details;
  late final _name = TextEditingController(text: _details?.name);
  late final _sku = TextEditingController(text: _details?.sku);
  late final _category = TextEditingController(text: _details?.category);
  late final _metal = TextEditingController(text: _details?.metal);
  late final _description = TextEditingController(text: _details?.description);
  late final _cost = TextEditingController(text: _priceText(_details?.cost));
  late final _price = TextEditingController(text: _priceText(_details?.price));
  late final _threshold = TextEditingController(
    text: (_details?.threshold ?? 2).toString(),
  );
  late final _variants = TextEditingController(
    text: _details?.variants.join(', '),
  );
  final _opening = TextEditingController(text: '0');
  late final _existing = [...?_details?.images];
  final _photos = <ProductPhoto>[];
  bool _busy = false;
  String? _error;

  String _priceText(int? cents) =>
      cents == null ? '' : (cents / 100).toStringAsFixed(2);

  Future<void> _choose() async {
    final remaining = 6 - _photos.length - _existing.length;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final files = await ImagePicker().pickMultiImage(
        maxWidth: 1600,
        maxHeight: 1600,
        imageQuality: 82,
        limit: remaining,
      );
      final selected = <ProductPhoto>[];
      for (final file in files.take(remaining)) {
        final bytes = await file.readAsBytes();
        final type = _imageType(bytes);
        if (type == null || bytes.length > 5 * 1024 * 1024) {
          throw const InventoryFailure(
            'Select JPEG, PNG, or WebP images up to 5 MB each.',
          );
        }
        selected.add(ProductPhoto(bytes: bytes, contentType: type));
      }
      if (mounted) setState(() => _photos.addAll(selected));
    } catch (error) {
      if (mounted) setState(() => _error = inventoryError(error));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  String? _imageType(List<int> bytes) {
    if (bytes.length < 12) return null;
    if (bytes[0] == 255 && bytes[1] == 216 && bytes[2] == 255) {
      return 'image/jpeg';
    }
    if (bytes[0] == 137 && String.fromCharCodes(bytes.sublist(1, 4)) == 'PNG') {
      return 'image/png';
    }
    if (String.fromCharCodes(bytes.sublist(0, 4)) == 'RIFF' &&
        String.fromCharCodes(bytes.sublist(8, 12)) == 'WEBP') {
      return 'image/webp';
    }
    return null;
  }

  Future<void> _save() async {
    if (_busy || !_form.currentState!.validate()) return;
    final repository = ref.read(inventoryRepositoryProvider);
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await repository.save(
        productId: widget.product?.id,
        openingQuantity: widget.product == null
            ? int.parse(_opening.text.trim())
            : 0,
        photos: List.of(_photos),
        details: ProductDetails(
          name: _name.text.trim(),
          sku: _sku.text.trim(),
          category: _category.text.trim(),
          metal: _metal.text.trim(),
          description: _description.text.trim(),
          cost: toCents(_cost.text)!,
          price: toCents(_price.text)!,
          threshold: int.parse(_threshold.text.trim()),
          variants: _variants.text
              .split(',')
              .map((value) => value.trim())
              .where((value) => value.isNotEmpty)
              .toSet()
              .toList(),
          images: List.of(_existing),
        ),
      );
      if (mounted) Navigator.of(context).pop(true);
    } catch (error) {
      if (mounted) setState(() => _error = inventoryError(error));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  void dispose() {
    for (final controller in [
      _name,
      _sku,
      _category,
      _metal,
      _description,
      _cost,
      _price,
      _threshold,
      _variants,
      _opening,
    ]) {
      controller.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final cost = toCents(_cost.text);
    final price = toCents(_price.text);
    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom),
      child: SafeArea(
        top: false,
        child: Form(
          key: _form,
          child: ListView(
            padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
            children: [
              Text(
                widget.product == null ? 'Add product' : 'Edit product',
                style: Theme.of(context).textTheme.headlineMedium,
              ),
              const SizedBox(height: 16),
              _field(_name, 'Product name', max: 120, required: true),
              _field(
                _sku,
                'SKU (blank to generate)',
                max: 40,
                validator: (value) =>
                    value!.trim().isEmpty ||
                        RegExp(r'^[A-Za-z0-9._-]{3,40}$').hasMatch(value.trim())
                    ? null
                    : 'Enter a valid SKU.',
              ),
              _field(_category, 'Category', max: 60, required: true),
              _field(_metal, 'Metal type', max: 60, required: true),
              _field(_description, 'Description', max: 1000, lines: 2),
              _field(
                _variants,
                'Variants (comma separated)',
                max: 300,
                help: 'For example: Size 7, Rose gold, 45 cm',
              ),
              _field(_cost, 'Cost price (LKR)', monetary: true),
              _field(_price, 'Selling price (LKR)', monetary: true),
              if (cost != null && price != null && price > 0)
                Padding(
                  padding: const EdgeInsets.only(bottom: 14),
                  child: Text(
                    'Gross margin: ${((price - cost) * 100 / price).toStringAsFixed(1)}%',
                  ),
                ),
              if (widget.product == null)
                _field(_opening, 'Opening stock', count: true),
              _field(_threshold, 'Low-stock threshold', count: true),
              const SizedBox(height: 4),
              Copy(
                'Product photos',
                style: Theme.of(context).textTheme.titleMedium,
              ),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  for (var i = 0; i < _existing.length; i++)
                    _thumbnail(
                      Image.network(
                        _existing[i],
                        webHtmlElementStrategy: WebHtmlElementStrategy.fallback,
                        fit: BoxFit.cover,
                        errorBuilder: (_, _, _) =>
                            const Icon(Icons.broken_image_outlined),
                      ),
                      () => setState(() => _existing.removeAt(i)),
                    ),
                  for (var i = 0; i < _photos.length; i++)
                    _thumbnail(
                      Image.memory(_photos[i].bytes, fit: BoxFit.cover),
                      () => setState(() => _photos.removeAt(i)),
                    ),
                ],
              ),
              const SizedBox(height: 8),
              OutlinedButton.icon(
                onPressed: _busy || _existing.length + _photos.length >= 6
                    ? null
                    : _choose,
                icon: const Icon(Icons.add_photo_alternate_outlined),
                label: const Copy('Choose photos'),
              ),
              if (_error case final message?)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 8),
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
              const SizedBox(height: 12),
              FilledButton(
                onPressed: _busy ? null : _save,
                child: Text(_busy ? 'Working…' : 'Save product'),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _field(
    TextEditingController controller,
    String label, {
    bool required = false,
    bool monetary = false,
    bool count = false,
    int? max,
    int lines = 1,
    String? help,
    String? Function(String?)? validator,
  }) => Padding(
    padding: const EdgeInsets.only(bottom: 12),
    child: TextFormField(
      controller: controller,
      enabled: !_busy,
      maxLength: max,
      maxLines: lines,
      keyboardType: monetary || count
          ? TextInputType.numberWithOptions(decimal: monetary)
          : null,
      decoration: InputDecoration(
        labelText: label,
        helperText: help,
        counterText: '',
      ),
      onChanged: monetary ? (_) => setState(() {}) : null,
      validator:
          validator ??
          (value) {
            final text = value?.trim() ?? '';
            if (required && text.isEmpty) return 'Required';
            if (monetary && toCents(text) == null) {
              return 'Enter an amount up to LKR 1,000,000.';
            }
            if (count) {
              final parsed = int.tryParse(text);
              if (parsed == null || parsed < 0 || parsed > maxStock) {
                return 'Enter 0 to 1,000,000.';
              }
            }
            return null;
          },
    ),
  );

  Widget _thumbnail(Widget photo, VoidCallback remove) => SizedBox.square(
    dimension: 80,
    child: Stack(
      fit: StackFit.expand,
      children: [
        ClipRRect(borderRadius: BorderRadius.circular(12), child: photo),
        Align(
          alignment: Alignment.topRight,
          child: IconButton.filledTonal(
            tooltip: 'Remove photo',
            onPressed: _busy ? null : remove,
            icon: const Icon(Icons.close, size: 16),
          ),
        ),
      ],
    ),
  );
}
