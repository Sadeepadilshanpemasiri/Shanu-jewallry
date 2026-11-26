import 'package:jewellery_business_manager/core/localization/copy.dart';
import 'package:barcode_widget/barcode_widget.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../domain/inventory_product.dart';
import 'inventory_format.dart';
import 'inventory_providers.dart';

enum ProductAction { edit, adjust, archive }

class ProductDetailsSheet extends ConsumerWidget {
  const ProductDetailsSheet({super.key, required this.product});
  final InventoryProduct product;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final details = product.details;
    final history = ref.watch(stockMovementsProvider(product.id));
    final theme = Theme.of(context);
    return SafeArea(
      top: false,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
        children: [
          Text(details.name, style: theme.textTheme.headlineMedium),
          const SizedBox(height: 4),
          SelectableText(
            '${details.sku} · ${details.category} · ${details.metal}',
          ),
          if (details.images.isNotEmpty) ...[
            const SizedBox(height: 14),
            SizedBox(
              height: 160,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                itemCount: details.images.length,
                separatorBuilder: (_, _) => const SizedBox(width: 8),
                itemBuilder: (context, index) => SizedBox(
                  width: 160,
                  child: ProductImage(url: details.images[index]),
                ),
              ),
            ),
          ],
          const SizedBox(height: 12),
          Text('${product.quantity} units · ${lkr(details.price)} each'),
          Text(
            'Cost ${lkr(details.cost)}'
            '${details.profitMargin == null ? '' : ' · Margin ${details.profitMargin!.toStringAsFixed(1)}%'}',
          ),
          if (details.description.isNotEmpty) Text(details.description),
          if (details.variants.isNotEmpty)
            Wrap(
              spacing: 6,
              children: [
                for (final value in details.variants) Chip(label: Text(value)),
              ],
            ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 6,
            children: [
              FilledButton.tonalIcon(
                onPressed: () => Navigator.pop(context, ProductAction.adjust),
                icon: const Icon(Icons.tune),
                label: const Copy('Adjust stock'),
              ),
              OutlinedButton.icon(
                onPressed: () => Navigator.pop(context, ProductAction.edit),
                icon: const Icon(Icons.edit_outlined),
                label: const Copy('Edit product'),
              ),
              TextButton.icon(
                onPressed: () => Navigator.pop(context, ProductAction.archive),
                icon: const Icon(Icons.archive_outlined),
                label: const Text('Archive product'),
              ),
            ],
          ),
          const SizedBox(height: 10),
          ExpansionTile(
            title: const Copy('Product barcode'),
            children: [
              Container(
                color: Colors.white,
                padding: const EdgeInsets.all(12),
                child: BarcodeWidget(
                  barcode: Barcode.code128(),
                  data: details.sku,
                  width: 360,
                  height: 84,
                  color: Colors.black,
                ),
              ),
              TextButton.icon(
                onPressed: () async {
                  await Clipboard.setData(ClipboardData(text: details.sku));
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('SKU copied.')),
                    );
                  }
                },
                icon: const Icon(Icons.copy),
                label: const Copy('Copy SKU'),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Copy('Stock history', style: theme.textTheme.titleLarge),
          const SizedBox(height: 6),
          history.when(
            loading: () => const LinearProgressIndicator(),
            error: (error, _) => Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(inventoryError(error)),
                TextButton(
                  onPressed: () =>
                      ref.invalidate(stockMovementsProvider(product.id)),
                  child: const Copy('Retry'),
                ),
              ],
            ),
            data: (movements) => movements.isEmpty
                ? const Text('No stock movements recorded.')
                : Column(
                    children: [
                      for (final move in movements)
                        ListTile(
                          contentPadding: EdgeInsets.zero,
                          leading: Icon(
                            move.delta > 0
                                ? Icons.add_circle_outline
                                : Icons.remove_circle_outline,
                          ),
                          title: Text(
                            '${movementLabel(move.type)} · ${move.reason}',
                          ),
                          subtitle: Text(
                            move.createdAt == null
                                ? 'Saving timestamp…'
                                : DateFormat(
                                    'dd MMM yyyy, HH:mm',
                                  ).format(move.createdAt!.toLocal()),
                          ),
                          trailing: Text(
                            '${move.delta > 0 ? '+' : ''}${move.delta}\nBalance ${move.balance}',
                            textAlign: TextAlign.end,
                          ),
                        ),
                    ],
                  ),
          ),
        ],
      ),
    );
  }
}

class ProductImage extends StatelessWidget {
  const ProductImage({super.key, this.url});
  final String? url;

  @override
  Widget build(BuildContext context) => ClipRRect(
    borderRadius: BorderRadius.circular(12),
    child: ColoredBox(
      color: Theme.of(context).colorScheme.surfaceContainerHigh,
      child: url == null
          ? const Center(child: Icon(Icons.diamond_outlined))
          : Image.network(
              url!,
              webHtmlElementStrategy: WebHtmlElementStrategy.fallback,
              fit: BoxFit.cover,
              errorBuilder: (_, _, _) =>
                  const Center(child: Icon(Icons.broken_image_outlined)),
            ),
    ),
  );
}
