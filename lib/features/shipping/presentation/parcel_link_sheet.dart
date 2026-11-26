import 'package:jewellery_business_manager/core/localization/copy.dart';
import 'package:flutter/material.dart';

import '../../orders/domain/shop_order.dart';

Future<ShopOrder?> chooseParcelOrder(
  BuildContext context,
  List<ShopOrder> orders,
) => showModalBottomSheet<ShopOrder>(
  context: context,
  isScrollControlled: true,
  useSafeArea: true,
  showDragHandle: true,
  constraints: const BoxConstraints(maxWidth: 620),
  builder: (_) => _ParcelLinkSheet(orders: orders),
);

class _ParcelLinkSheet extends StatefulWidget {
  const _ParcelLinkSheet({required this.orders});
  final List<ShopOrder> orders;

  @override
  State<_ParcelLinkSheet> createState() => _ParcelLinkSheetState();
}

class _ParcelLinkSheetState extends State<_ParcelLinkSheet> {
  String _query = '';

  @override
  Widget build(BuildContext context) {
    final results = widget.orders
        .where(
          (order) =>
              '${order.number} ${order.customer.name} ${order.customer.phone} ${order.customer.city}'
                  .toLowerCase()
                  .contains(_query),
        )
        .toList();
    return FractionallySizedBox(
      heightFactor: .82,
      child: Padding(
        padding: EdgeInsets.fromLTRB(
          16,
          4,
          16,
          MediaQuery.viewInsetsOf(context).bottom + 16,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Copy(
              'Link parcel to order',
              style: Theme.of(context).textTheme.headlineMedium,
            ),
            const SizedBox(height: 12),
            TextField(
              onChanged: (value) =>
                  setState(() => _query = value.trim().toLowerCase()),
              decoration: const InputDecoration(
                prefixIcon: Icon(Icons.search),
                labelText: 'Order number, customer, phone or city',
              ),
            ),
            const SizedBox(height: 8),
            if (results.isEmpty) const Text('No eligible orders found.'),
            Expanded(
              child: ListView.builder(
                itemCount: results.length,
                itemBuilder: (context, index) {
                  final order = results[index];
                  return ListTile(
                    title: Text('${order.number} · ${order.customer.name}'),
                    subtitle: Text(
                      '${order.status.label} · ${order.customer.city}',
                    ),
                    trailing: const Icon(Icons.link),
                    onTap: () => Navigator.pop(context, order),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}
