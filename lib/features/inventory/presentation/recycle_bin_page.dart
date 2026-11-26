import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../domain/inventory_product.dart';
import 'inventory_format.dart';
import 'inventory_providers.dart';

final archivedProductsProvider =
    StreamProvider.autoDispose<List<InventoryProduct>>(
      (ref) =>
          ref.watch(inventoryRepositoryProvider).watchProducts(archived: true),
    );

class RecycleBinPage extends ConsumerStatefulWidget {
  const RecycleBinPage({super.key});

  @override
  ConsumerState<RecycleBinPage> createState() => _RecycleBinPageState();
}

class _RecycleBinPageState extends ConsumerState<RecycleBinPage> {
  final _restoring = <String>{};

  Future<void> _restore(InventoryProduct product) async {
    setState(() => _restoring.add(product.id));
    try {
      await ref
          .read(inventoryRepositoryProvider)
          .setArchived(product.id, false);
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('Product restored.')));
      }
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(inventoryError(error))));
      }
    } finally {
      if (mounted) setState(() => _restoring.remove(product.id));
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Product recycle bin')),
    body: ref
        .watch(archivedProductsProvider)
        .when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (error, _) => Center(
            child: TextButton(
              onPressed: () => ref.invalidate(archivedProductsProvider),
              child: Text('${inventoryError(error)} Retry'),
            ),
          ),
          data: (products) => products.isEmpty
              ? const Center(child: Text('No archived products.'))
              : ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: products.length,
                  itemBuilder: (context, index) {
                    final product = products[index];
                    return Card(
                      child: ListTile(
                        title: Text(product.details.name),
                        subtitle: Text(
                          '${product.details.sku} · ${product.quantity} units',
                        ),
                        trailing: TextButton(
                          onPressed: _restoring.contains(product.id)
                              ? null
                              : () => _restore(product),
                          child: const Text('Restore'),
                        ),
                      ),
                    );
                  },
                ),
        ),
  );
}
