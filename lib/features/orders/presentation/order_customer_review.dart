import 'package:jewellery_business_manager/core/localization/copy.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../customers/domain/customer.dart';
import '../domain/shop_order.dart';
import 'order_format.dart';
import 'order_providers.dart';

typedef ReviewChoice = ({CustomerReview decision, bool overrideBlacklist});

Future<ReviewChoice?> reviewCustomer(
  BuildContext context,
  Customer customer,
  List<Customer> similar,
) => showModalBottomSheet<ReviewChoice>(
  context: context,
  useSafeArea: true,
  isScrollControlled: true,
  showDragHandle: true,
  constraints: const BoxConstraints(maxWidth: 600),
  builder: (_) => _ReviewSheet(customer: customer, similar: similar),
);

class _ReviewSheet extends ConsumerStatefulWidget {
  const _ReviewSheet({required this.customer, required this.similar});
  final Customer customer;
  final List<Customer> similar;

  @override
  ConsumerState<_ReviewSheet> createState() => _ReviewSheetState();
}

class _ReviewSheetState extends ConsumerState<_ReviewSheet> {
  bool _override = false;

  @override
  Widget build(BuildContext context) {
    final customer = widget.customer;
    final history = customer.stats.total > 0
        ? ref.watch(ordersProvider(phone: customer.phone))
        : const AsyncData<List<ShopOrder>>([]);
    final colors = Theme.of(context).colorScheme;
    final enabled =
        (!customer.blacklisted || _override) &&
        (customer.stats.total == 0 || history.hasValue);
    return FractionallySizedBox(
      heightFactor: .82,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
        children: [
          Icon(Icons.warning_amber_rounded, size: 38, color: colors.error),
          Copy(
            'Review customer history',
            style: Theme.of(context).textTheme.headlineMedium,
          ),
          Text(customer.name),
          if (customer.needsReview)
            Text(
              '${customer.stats.cancelled} cancelled · '
              '${customer.stats.returned} returned · ${customer.stats.failed} with failed delivery',
            ),
          if (customer.stats.cancelledAfterShipping > 0)
            Text(
              '${customer.stats.cancelledAfterShipping} cancelled after shipping',
            ),
          if (customer.restrictionReason.isNotEmpty)
            Text(customer.restrictionReason),
          if (widget.similar.isNotEmpty) ...[
            const SizedBox(height: 12),
            const Text(
              'Check these similar contacts or addresses before creating this customer.',
            ),
            for (final record in widget.similar.take(5))
              ListTile(
                contentPadding: EdgeInsets.zero,
                title: Text(record.name),
                subtitle: Text('${record.phone} · ${record.address}'),
              ),
          ],
          history.when(
            loading: () => const LinearProgressIndicator(),
            error: (error, _) => Column(
              children: [
                Text(orderError(error)),
                TextButton(
                  onPressed: () =>
                      ref.invalidate(ordersProvider(phone: customer.phone)),
                  child: const Text('Retry history'),
                ),
              ],
            ),
            data: (orders) => Column(
              children: [
                for (final order in orders)
                  for (final event in order.history.where(
                    (event) => event.status.needsReason,
                  ))
                    ListTile(
                      contentPadding: EdgeInsets.zero,
                      title: Text('${order.number} · ${event.status.label}'),
                      subtitle: Text('${orderDate(event.at)}\n${event.note}'),
                    ),
              ],
            ),
          ),
          if (customer.blacklisted)
            CheckboxListTile(
              contentPadding: EdgeInsets.zero,
              value: _override,
              title: const Text('Override the blacklist for this order'),
              onChanged: (value) => setState(() => _override = value ?? false),
            ),
          const SizedBox(height: 12),
          FilledButton(
            onPressed: enabled
                ? () => Navigator.pop(context, (
                    decision: CustomerReview.proceed,
                    overrideBlacklist: _override,
                  ))
                : null,
            child: const Copy('Proceed'),
          ),
          OutlinedButton(
            onPressed: enabled
                ? () => Navigator.pop(context, (
                    decision: CustomerReview.advance,
                    overrideBlacklist: _override,
                  ))
                : null,
            child: const Copy('Require advance payment'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Copy('Back'),
          ),
        ],
      ),
    );
  }
}
