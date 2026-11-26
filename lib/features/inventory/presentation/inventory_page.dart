import 'package:jewellery_business_manager/core/localization/copy.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/widgets/cursor_catalog.dart';
import '../../../core/widgets/premium_card.dart';
import '../domain/inventory_product.dart';
import 'inventory_format.dart';
import 'inventory_providers.dart';
import 'product_details_sheet.dart';
import 'product_editor.dart';
import 'product_scanner.dart';
import 'stock_adjustment.dart';

Future<void> openInventoryProduct(
  BuildContext context,
  InventoryProduct product, {
  VoidCallback? onRestored,
}) async {
  final action = await showModalBottomSheet<ProductAction>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    showDragHandle: true,
    constraints: const BoxConstraints(maxWidth: 640),
    builder: (_) => FractionallySizedBox(
      heightFactor: .92,
      child: ProductDetailsSheet(product: product),
    ),
  );
  if (!context.mounted) return;
  if (action == ProductAction.archive) {
    await _archiveProduct(context, product, onRestored);
    return;
  }
  final pending = switch (action) {
    ProductAction.edit => openProductEditor(context, product),
    ProductAction.adjust => showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      showDragHandle: true,
      constraints: const BoxConstraints(maxWidth: 640),
      builder: (_) => StockAdjustment(product: product),
    ),
    ProductAction.archive || null => null,
  };
  final saved = await pending;
  if (context.mounted && saved == true) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Copy(
          action == ProductAction.edit
              ? 'Product saved.'
              : 'Stock movement recorded.',
        ),
      ),
    );
  }
}

Future<void> _archiveProduct(
  BuildContext context,
  InventoryProduct product,
  VoidCallback? onRestored,
) async {
  final confirmed = await showDialog<bool>(
    context: context,
    builder: (dialogContext) => AlertDialog(
      title: Text('Archive ${product.details.name}?'),
      content: const Text(
        'The product moves to the recycle bin. Its stock and order history are kept. Pending orders may need an available replacement.',
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(dialogContext),
          child: const Text('Back'),
        ),
        FilledButton(
          onPressed: () => Navigator.pop(dialogContext, true),
          child: const Text('Archive'),
        ),
      ],
    ),
  );
  if (!context.mounted || confirmed != true) return;
  final repository = ProviderScope.containerOf(
    context,
    listen: false,
  ).read(inventoryRepositoryProvider);
  final messenger = ScaffoldMessenger.of(context);
  try {
    final actionId = await repository.setArchived(product.id, true);
    if (!messenger.mounted || actionId == null) return;
    messenger.showSnackBar(
      SnackBar(
        content: const Text('Product moved to the recycle bin.'),
        action: SnackBarAction(
          label: 'Undo',
          onPressed: () async {
            try {
              await repository.setArchived(
                product.id,
                false,
                expectedAction: actionId,
              );
              onRestored?.call();
              if (messenger.mounted) {
                messenger.showSnackBar(
                  const SnackBar(content: Text('Product restored.')),
                );
              }
            } catch (error) {
              if (messenger.mounted) {
                messenger.showSnackBar(
                  SnackBar(content: Text(inventoryError(error))),
                );
              }
            }
          },
        ),
      ),
    );
  } catch (error) {
    if (messenger.mounted) {
      messenger.showSnackBar(SnackBar(content: Text(inventoryError(error))));
    }
  }
}

class InventoryPage extends ConsumerStatefulWidget {
  const InventoryPage({super.key});

  @override
  ConsumerState<InventoryPage> createState() => _InventoryPageState();
}

class _InventoryPageState extends ConsumerState<InventoryPage> {
  final _query = TextEditingController();
  String? _category, _metal;
  StockLevel? _level;
  bool _grid = false;
  bool _showFilters = false;
  int _revision = 0;

  void _reload() => setState(() => _revision++);

  void _toggleFilters() => setState(() {
    _showFilters = !_showFilters;
    if (!_showFilters) {
      _category = null;
      _metal = null;
      _level = null;
    }
  });

  @override
  void dispose() {
    _query.dispose();
    super.dispose();
  }

  Future<void> _edit([InventoryProduct? product]) async {
    final saved = await openProductEditor(context, product);
    if (mounted && saved == true) {
      _reload();
      _message('Product saved.');
    }
  }

  Future<void> _open(InventoryProduct product) async {
    await openInventoryProduct(
      context,
      product,
      onRestored: () {
        if (mounted) _reload();
      },
    );
    if (mounted) _reload();
  }

  Future<void> _scan() async {
    final sku = await Navigator.of(
      context,
    ).push<String>(MaterialPageRoute(builder: (_) => const ProductScanner()));
    if (!mounted || sku == null) return;
    final List<InventoryProduct> latest;
    try {
      latest = await ref
          .read(inventoryRepositoryProvider)
          .watchProducts()
          .first;
    } catch (error) {
      if (mounted) _message(inventoryError(error));
      return;
    }
    if (!mounted) return;
    final exact = latest
        .where(
          (product) => product.details.sku.toLowerCase() == sku.toLowerCase(),
        )
        .firstOrNull;
    setState(() {
      _query.text = sku;
      _category = null;
      _metal = null;
      _level = null;
    });
    if (exact == null) {
      _message('No product has this SKU.');
    } else {
      await _open(exact);
    }
  }

  void _message(String message) => ScaffoldMessenger.of(
    context,
  ).showSnackBar(SnackBar(content: Text(message)));

  @override
  Widget build(BuildContext context) {
    final useFullCatalog = _showFilters || _query.text.trim().isNotEmpty;
    return Scaffold(
      appBar: AppBar(
        title: const Copy('Inventory'),
        leading: BackButton(
          onPressed: () {
            if (context.canPop()) {
              context.pop();
            } else {
              context.go('/');
            }
          },
        ),
        actions: [
          IconButton(
            onPressed: _scan,
            icon: const Icon(Icons.qr_code_scanner),
            tooltip: 'Scan SKU',
          ),
          IconButton(
            onPressed: () => setState(() => _grid = !_grid),
            icon: Icon(
              _grid ? Icons.view_list_outlined : Icons.grid_view_outlined,
            ),
            tooltip: _grid ? 'List view' : 'Grid view',
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _edit,
        label: const Copy('Add product'),
        icon: const Icon(Icons.add),
      ),
      body: CursorCatalog<InventoryProduct>(
        revision: _revision,
        recordId: (product) => product.id,
        first: () => ref.read(inventoryRepositoryProvider).readProducts(),
        full: useFullCatalog ? ref.watch(productsProvider) : null,
        refreshFull: () => ref.invalidate(productsProvider),
        errorText: inventoryError,
        builder: (all, footer, refresh) =>
            _catalog(context, all, footer, refresh),
      ),
    );
  }

  Widget _catalog(
    BuildContext context,
    List<InventoryProduct> all,
    Widget? footer,
    Future<void> Function() refresh,
  ) {
    final query = _query.text.trim().toLowerCase();
    final categories = all.map((p) => p.details.category).toSet().toList()
      ..sort();
    final metals = all.map((p) => p.details.metal).toSet().toList()..sort();
    final visible = all.where((product) {
      final details = product.details;
      return (_category == null || _category == details.category) &&
          (_metal == null || _metal == details.metal) &&
          (_level == null || _level == product.level) &&
          '${details.name} ${details.sku}'.toLowerCase().contains(query);
    }).toList();
    final cost = all.fold(0, (int sum, item) => sum + item.costValue);
    final retail = all.fold(0, (int sum, item) => sum + item.retailValue);
    final low = all.where((p) => p.level == StockLevel.low).length;
    final out = all.where((p) => p.level == StockLevel.out).length;
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 1100),
        child: RefreshIndicator(
          onRefresh: refresh,
          child: CustomScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            slivers: [
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
                sliver: SliverToBoxAdapter(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      OutlinedButton.icon(
                        onPressed: _toggleFilters,
                        icon: const Icon(Icons.tune),
                        label: Text(
                          _showFilters
                              ? 'Hide valuation and filters'
                              : 'Valuation and filters',
                        ),
                      ),
                      if (_showFilters && (all.isNotEmpty || footer == null))
                        PremiumCard(
                          padding: const EdgeInsets.all(16),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Copy(
                                'Inventory valuation',
                                style: Theme.of(context).textTheme.titleLarge,
                              ),
                              const SizedBox(height: 6),
                              Wrap(
                                spacing: 22,
                                runSpacing: 4,
                                children: [
                                  Text('Cost ${lkr(cost)}'),
                                  Text('Retail ${lkr(retail)}'),
                                ],
                              ),
                              const SizedBox(height: 8),
                              Wrap(
                                spacing: 8,
                                children: [
                                  FilterChip(
                                    label: Text('$low low stock'),
                                    selected: _level == StockLevel.low,
                                    onSelected: (select) => setState(
                                      () => _level = select
                                          ? StockLevel.low
                                          : null,
                                    ),
                                  ),
                                  FilterChip(
                                    label: Text('$out out of stock'),
                                    selected: _level == StockLevel.out,
                                    onSelected: (select) => setState(
                                      () => _level = select
                                          ? StockLevel.out
                                          : null,
                                    ),
                                  ),
                                  FilterChip(
                                    label: const Copy('In stock'),
                                    selected: _level == StockLevel.inStock,
                                    onSelected: (select) => setState(
                                      () => _level = select
                                          ? StockLevel.inStock
                                          : null,
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      const SizedBox(height: 12),
                      TextField(
                        controller: _query,
                        onChanged: (_) => setState(() {}),
                        decoration: InputDecoration(
                          label: Copy('Search by name or SKU'),
                          prefixIcon: const Icon(Icons.search),
                          suffixIcon: query.isEmpty
                              ? null
                              : IconButton(
                                  tooltip: 'Clear search',
                                  onPressed: () => setState(_query.clear),
                                  icon: const Icon(Icons.close),
                                ),
                        ),
                      ),
                      const SizedBox(height: 8),
                      if (_showFilters && (all.isNotEmpty || footer == null))
                        Wrap(
                          spacing: 8,
                          runSpacing: 6,
                          children: [
                            _filter(
                              'Category',
                              _category,
                              categories,
                              (value) => setState(() => _category = value),
                            ),
                            _filter(
                              'Metal',
                              _metal,
                              metals,
                              (value) => setState(() => _metal = value),
                            ),
                          ],
                        ),
                      if (visible.isEmpty && footer == null)
                        Padding(
                          padding: const EdgeInsets.symmetric(vertical: 20),
                          child: Text(
                            all.isEmpty
                                ? 'Add your first product to start tracking stock.'
                                : 'No products match these filters.',
                          ),
                        ),
                    ],
                  ),
                ),
              ),
              SliverPadding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                sliver: _grid
                    ? SliverGrid.builder(
                        gridDelegate:
                            const SliverGridDelegateWithMaxCrossAxisExtent(
                              maxCrossAxisExtent: 260,
                              mainAxisExtent: 236,
                              crossAxisSpacing: 10,
                              mainAxisSpacing: 10,
                            ),
                        itemCount: visible.length,
                        itemBuilder: (context, index) =>
                            _product(visible[index], grid: true),
                      )
                    : SliverList.builder(
                        itemCount: visible.length,
                        itemBuilder: (context, index) => Padding(
                          padding: const EdgeInsets.only(bottom: 8),
                          child: _product(visible[index], grid: false),
                        ),
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

  Widget _filter(
    String name,
    String? selected,
    List<String> choices,
    ValueChanged<String?> changed,
  ) => PopupMenuButton<(String?,)>(
    tooltip: 'Filter by $name',
    onSelected: (selection) => changed(selection.$1),
    itemBuilder: (_) => [
      PopupMenuItem(
        value: (null,),
        child: Text('All ${name.toLowerCase()} options'),
      ),
      for (final option in choices)
        PopupMenuItem(value: (option,), child: Text(option)),
    ],
    child: Chip(
      label: Text(selected ?? name),
      avatar: const Icon(Icons.filter_list, size: 16),
    ),
  );

  Widget _product(InventoryProduct product, {required bool grid}) {
    final details = product.details;
    final color = Theme.of(context).colorScheme;
    final title = Text(
      details.name,
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
      style: Theme.of(context).textTheme.titleMedium,
    );
    final stock = Text(
      switch (product.level) {
        StockLevel.out => 'Out of stock',
        StockLevel.low => '${product.quantity} left · Low stock',
        StockLevel.inStock => '${product.quantity} in stock',
      },
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
      style: TextStyle(
        color: product.level == StockLevel.inStock
            ? color.onSurfaceVariant
            : color.error,
      ),
    );
    final price = Text(
      lkr(details.price),
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
    );
    final photo = ProductImage(url: details.images.firstOrNull);
    return Card(
      margin: EdgeInsets.zero,
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: () => _open(product),
        child: Padding(
          padding: const EdgeInsets.all(10),
          child: grid
              ? Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Expanded(child: photo),
                    const SizedBox(height: 8),
                    title,
                    price,
                    stock,
                  ],
                )
              : Row(
                  children: [
                    SizedBox.square(dimension: 58, child: photo),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          title,
                          Text(
                            details.sku,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          stock,
                          price,
                        ],
                      ),
                    ),
                    const Icon(Icons.chevron_right),
                  ],
                ),
        ),
      ),
    );
  }
}
