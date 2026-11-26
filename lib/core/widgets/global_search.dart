import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../features/customers/domain/customer.dart';
import '../../features/customers/presentation/customer_providers.dart';
import '../../features/customers/presentation/customers_page.dart';
import '../../features/inventory/presentation/inventory_page.dart';
import '../../features/inventory/presentation/inventory_providers.dart';
import '../../features/orders/presentation/order_details_page.dart';
import '../../features/orders/presentation/order_providers.dart';
import '../localization/copy.dart';

Future<void> openGlobalSearch(BuildContext context) =>
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      showDragHandle: true,
      constraints: const BoxConstraints(maxWidth: 700),
      builder: (_) =>
          const FractionallySizedBox(heightFactor: .9, child: _GlobalSearch()),
    );

class _GlobalSearch extends ConsumerStatefulWidget {
  const _GlobalSearch();
  @override
  ConsumerState<_GlobalSearch> createState() => _GlobalSearchState();
}

class _GlobalSearchState extends ConsumerState<_GlobalSearch> {
  String _query = '';

  @override
  Widget build(BuildContext context) {
    final orders = ref.watch(ordersProvider());
    final customers = ref.watch(customersProvider);
    final products = ref.watch(productsProvider);
    final query = _query.trim().toLowerCase();
    final phone = normalizeSriLankanPhone(query);
    bool matches(String text) =>
        query.isNotEmpty && text.toLowerCase().contains(query);
    final orderResults = (orders.asData?.value ?? [])
        .where(
          (item) =>
              matches(
                '${item.number} ${item.customer.name} ${item.customer.phone} ${item.tracking}',
              ) ||
              item.customer.phone == phone,
        )
        .take(8)
        .toList();
    final customerResults = (customers.asData?.value ?? [])
        .where(
          (item) =>
              matches('${item.name} ${item.phone} ${item.city}') ||
              item.phone == phone,
        )
        .take(8)
        .toList();
    final productResults = (products.asData?.value ?? [])
        .where(
          (item) => matches(
            '${item.details.name} ${item.details.sku} ${item.details.category}',
          ),
        )
        .take(8)
        .toList();
    return Padding(
      padding: EdgeInsets.fromLTRB(
        16,
        4,
        16,
        MediaQuery.viewInsetsOf(context).bottom + 12,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          TextField(
            autofocus: true,
            onChanged: (text) => setState(() => _query = text),
            decoration: const InputDecoration(
              prefixIcon: Icon(Icons.search),
              label: Copy('Search orders, customers or products'),
            ),
          ),
          const SizedBox(height: 8),
          if (orders.isLoading || customers.isLoading || products.isLoading)
            const LinearProgressIndicator(),
          if (orders.hasError || customers.hasError || products.hasError)
            const Copy('Some records could not be loaded.'),
          Expanded(
            child: ListView(
              children: [
                if (orderResults.isNotEmpty)
                  const ListTile(title: Copy('Orders')),
                for (final item in orderResults)
                  ListTile(
                    title: Text('${item.number} · ${item.customer.name}'),
                    subtitle: Copy(item.status.label),
                    onTap: () => openOrderDetails(context, item),
                  ),
                if (customerResults.isNotEmpty)
                  const ListTile(title: Copy('Customers')),
                for (final item in customerResults)
                  ListTile(
                    title: Text(item.name),
                    subtitle: Text(item.phone),
                    onTap: () => openCustomerProfile(context, item),
                  ),
                if (productResults.isNotEmpty)
                  const ListTile(title: Copy('Products')),
                for (final item in productResults)
                  ListTile(
                    title: Text(item.details.name),
                    subtitle: Text(item.details.sku),
                    onTap: () => openInventoryProduct(context, item),
                  ),
                if (query.isNotEmpty &&
                    orderResults.isEmpty &&
                    customerResults.isEmpty &&
                    productResults.isEmpty &&
                    !orders.isLoading &&
                    !customers.isLoading &&
                    !products.isLoading)
                  const ListTile(title: Copy('No matching records.')),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
