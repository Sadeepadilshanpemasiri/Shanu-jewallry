import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../auth/presentation/providers/auth_providers.dart';
import '../../inventory/presentation/inventory_providers.dart';
import '../../inventory/presentation/recycle_bin_page.dart';
import '../../orders/presentation/order_details_page.dart';
import '../../orders/presentation/order_providers.dart';

enum _Kind { order, stock, archive }

typedef _Activity = ({
  DateTime at,
  String title,
  String note,
  String actor,
  _Kind kind,
  VoidCallback? open,
});

final _recentInventoryEvents = StreamProvider.autoDispose
    .family<QuerySnapshot<Map<String, dynamic>>, String>(
      (ref, collection) => FirebaseFirestore.instance
          .collection(collection)
          .orderBy('createdAt', descending: true)
          .limit(100)
          .snapshots(),
    );

class ActivityPage extends ConsumerStatefulWidget {
  const ActivityPage({super.key});

  @override
  ConsumerState<ActivityPage> createState() => _ActivityPageState();
}

class _ActivityPageState extends ConsumerState<ActivityPage> {
  _Kind? _filter;
  int _limit = 25;

  @override
  Widget build(BuildContext context) {
    final orders = ref.watch(ordersProvider());
    final stock = ref.watch(_recentInventoryEvents('stock_movements'));
    final archives = ref.watch(_recentInventoryEvents('inventory_activity'));
    final owner = ref.watch(ownerSessionProvider).asData?.value;
    final products = {
      for (final item in [
        ...ref.watch(productsProvider).asData?.value ?? [],
        ...ref.watch(archivedProductsProvider).asData?.value ?? [],
      ])
        item.id: item.details.name,
    };
    final entries = <_Activity>[];
    for (final order in orders.asData?.value ?? []) {
      for (final event in order.history) {
        if (event.at case final at?) {
          entries.add((
            at: at,
            title: '${order.number} · ${event.status.label}',
            note: event.note,
            actor: event.actor,
            kind: _Kind.order,
            open: () => openOrderDetails(context, order),
          ));
        }
      }
    }
    for (final doc
        in stock.asData?.value.docs ??
            <QueryDocumentSnapshot<Map<String, dynamic>>>[]) {
      final data = doc.data();
      if (data['createdAt'] case final Timestamp at) {
        final quantity = data['qty'] as int? ?? 0;
        final name = products[data['productId']] ?? 'Product';
        entries.add((
          at: at.toDate(),
          title: '$name · ${quantity > 0 ? '+' : ''}$quantity',
          note: data['reason'] as String? ?? '',
          actor: data['actorUid'] as String? ?? '',
          kind: _Kind.stock,
          open: null,
        ));
      }
    }
    for (final doc
        in archives.asData?.value.docs ??
            <QueryDocumentSnapshot<Map<String, dynamic>>>[]) {
      final data = doc.data();
      if (data['createdAt'] case final Timestamp at) {
        final verb = data['archived'] == true ? 'Archived' : 'Restored';
        entries.add((
          at: at.toDate(),
          title: '$verb · ${data['productName']}',
          note: '',
          actor: data['actorUid'] as String? ?? '',
          kind: _Kind.archive,
          open: null,
        ));
      }
    }
    entries.sort((first, second) => second.at.compareTo(first.at));
    final matches = entries
        .where((item) => _filter == null || item.kind == _filter)
        .toList();
    final visible = matches.take(_limit).toList();
    final loading = orders.isLoading || stock.isLoading || archives.isLoading;
    final error = orders.hasError || stock.hasError || archives.hasError;
    final format = DateFormat('dd MMM yyyy, HH:mm');
    return Scaffold(
      appBar: AppBar(title: const Text('Activity')),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 840),
          child: CustomScrollView(
            slivers: [
              SliverPadding(
                padding: const EdgeInsets.all(16),
                sliver: SliverToBoxAdapter(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Wrap(
                        spacing: 8,
                        runSpacing: 6,
                        children: [
                          for (final entry in const <_Kind?, String>{
                            null: 'All',
                            _Kind.order: 'Orders',
                            _Kind.stock: 'Stock',
                            _Kind.archive: 'Archive',
                          }.entries)
                            ChoiceChip(
                              label: Text(entry.value),
                              selected: _filter == entry.key,
                              onSelected: (_) => setState(() {
                                _filter = entry.key;
                                _limit = 25;
                              }),
                            ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      if (loading) const LinearProgressIndicator(),
                      if (error)
                        TextButton(
                          onPressed: () {
                            ref.invalidate(ordersProvider());
                            ref.invalidate(
                              _recentInventoryEvents('stock_movements'),
                            );
                            ref.invalidate(
                              _recentInventoryEvents('inventory_activity'),
                            );
                          },
                          child: const Text(
                            'Some activity could not load. Retry',
                          ),
                        ),
                      if (!loading && !error && visible.isEmpty)
                        const Text('No activity in this view.'),
                    ],
                  ),
                ),
              ),
              SliverPadding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                sliver: SliverList.builder(
                  itemCount: visible.length,
                  itemBuilder: (context, index) {
                    final item = visible[index];
                    final actor = item.actor == owner?.uid
                        ? (owner?.email.isNotEmpty == true
                              ? owner!.email
                              : 'Owner')
                        : item.actor.isEmpty
                        ? 'Unknown'
                        : item.actor;
                    return Card(
                      child: ListTile(
                        onTap: item.open,
                        leading: Icon(switch (item.kind) {
                          _Kind.order => Icons.receipt_long_outlined,
                          _Kind.stock => Icons.inventory_2_outlined,
                          _Kind.archive => Icons.archive_outlined,
                        }),
                        title: Text(item.title),
                        subtitle: Text(
                          [
                            format.format(item.at.toLocal()),
                            actor,
                            if (item.note.isNotEmpty) item.note,
                          ].join('\n'),
                        ),
                      ),
                    );
                  },
                ),
              ),
              if (matches.length > _limit)
                SliverToBoxAdapter(
                  child: TextButton(
                    onPressed: () => setState(() => _limit += 25),
                    child: const Text('Show more'),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
