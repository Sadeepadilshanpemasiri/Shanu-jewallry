import 'package:jewellery_business_manager/core/localization/copy.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/widgets/premium_card.dart';
import '../../orders/presentation/order_details_page.dart';
import '../../orders/presentation/order_format.dart';
import '../../orders/presentation/order_providers.dart';
import '../domain/notice.dart';
import 'browser_push_panel.dart';
import 'notification_providers.dart';
import 'reminder_settings_sheet.dart';

enum _NoticeAction { read, done, hour, tomorrow }

class NotificationsPage extends ConsumerStatefulWidget {
  const NotificationsPage({super.key});

  @override
  ConsumerState<NotificationsPage> createState() => _NotificationsPageState();
}

class _NotificationsPageState extends ConsumerState<NotificationsPage> {
  NoticeFolder _folder = NoticeFolder.inbox;
  final _busy = <String>{};

  Future<void> _work(Notice notice, Future<void> Function() action) async {
    if (_busy.contains(notice.id)) return;
    setState(() => _busy.add(notice.id));
    try {
      await action();
    } catch (_) {
      if (mounted) {
        _message('Could not complete the notification action. Try again.');
      }
    } finally {
      if (mounted) setState(() => _busy.remove(notice.id));
    }
  }

  void _message(String message) => ScaffoldMessenger.of(
    context,
  ).showSnackBar(SnackBar(content: Text(message)));

  Future<void> _action(Notice notice, _NoticeAction action) =>
      _work(notice, () {
        final repository = ref.read(notificationRepositoryProvider);
        return switch (action) {
          _NoticeAction.read => repository.markRead(notice.id),
          _NoticeAction.done => repository.markDone(notice.id),
          _NoticeAction.hour => repository.snooze(
            notice.id,
            DateTime.now().add(const Duration(hours: 1)),
          ),
          _NoticeAction.tomorrow => repository.snooze(
            notice.id,
            DateTime.now().add(const Duration(days: 1)),
          ),
        };
      });

  Future<void> _open(Notice notice) => _work(notice, () async {
    if (!notice.isRead) {
      await ref.read(notificationRepositoryProvider).markRead(notice.id);
    }
    if (!mounted) return;
    if (notice.orderId case final id?) {
      final order = await ref.read(orderRepositoryProvider).getOrder(id);
      if (!mounted) return;
      if (order == null) {
        _message('This order is no longer available.');
      } else {
        await openOrderDetails(context, order);
      }
    } else if (notice.productId != null) {
      await context.push('/inventory');
    }
  });

  @override
  Widget build(BuildContext context) {
    final notices = ref.watch(noticesProvider(_folder));
    final unread = ref.watch(unreadNoticesProvider).asData?.value;
    return Scaffold(
      appBar: AppBar(
        title: const Copy('Notifications'),
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
            onPressed: () => openReminderSettings(context),
            tooltip: 'Reminder rules',
            icon: const Icon(Icons.tune),
          ),
        ],
      ),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 840),
          child: CustomScrollView(
            slivers: [
              SliverPadding(
                padding: const EdgeInsets.all(16),
                sliver: SliverToBoxAdapter(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Copy(
                        'Shop reminders',
                        style: Theme.of(context).textTheme.headlineMedium,
                      ),
                      if (unread != null)
                        Text(unread >= 100 ? '99+ unread' : '$unread unread'),
                      const SizedBox(height: 12),
                      const BrowserPushPanel(),
                      const SizedBox(height: 12),
                      Wrap(
                        spacing: 8,
                        runSpacing: 6,
                        children: [
                          for (final entry in const {
                            NoticeFolder.inbox: 'Inbox',
                            NoticeFolder.snoozed: 'Snoozed',
                            NoticeFolder.completed: 'Completed',
                          }.entries)
                            ChoiceChip(
                              label: Text(entry.value),
                              selected: _folder == entry.key,
                              onSelected: (_) =>
                                  setState(() => _folder = entry.key),
                            ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
              notices.when(
                loading: () =>
                    const SliverToBoxAdapter(child: LinearProgressIndicator()),
                error: (_, _) => SliverToBoxAdapter(
                  child: Center(
                    child: TextButton(
                      onPressed: () => ref.invalidate(noticesProvider(_folder)),
                      child: const Text('Could not load notifications. Retry'),
                    ),
                  ),
                ),
                data: (items) => items.isEmpty
                    ? SliverToBoxAdapter(
                        child: Padding(
                          padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                          child: PremiumCard(
                            child: Text(switch (_folder) {
                              NoticeFolder.inbox => 'You’re all caught up.',
                              NoticeFolder.snoozed => 'No snoozed reminders.',
                              NoticeFolder.completed =>
                                'No completed reminders.',
                            }),
                          ),
                        ),
                      )
                    : SliverPadding(
                        padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
                        sliver: SliverList.builder(
                          itemCount: items.length,
                          itemBuilder: (context, index) => _tile(items[index]),
                        ),
                      ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _tile(Notice notice) {
    final theme = Theme.of(context);
    final enabled = !_busy.contains(notice.id);
    final day = notice.createdAt;
    final timestamp = notice.snoozedUntil;
    return Card(
      child: ListTile(
        onTap: enabled ? () => _open(notice) : null,
        leading: Icon(
          switch (notice.type) {
            'transit' => Icons.local_shipping_outlined,
            'cod' => Icons.payments_outlined,
            'low-stock' => Icons.inventory_2_outlined,
            'daily' || 'weekly' => Icons.summarize_outlined,
            _ => Icons.schedule_outlined,
          },
          color: notice.isRead
              ? theme.colorScheme.onSurfaceVariant
              : theme.colorScheme.primary,
        ),
        title: Text(
          notice.title,
          style: notice.isRead
              ? null
              : const TextStyle(fontWeight: FontWeight.bold),
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(notice.body),
            if (day != null)
              Text(orderDate(day), style: theme.textTheme.bodySmall),
            if (timestamp != null)
              Text(
                'Snoozed until ${orderDate(timestamp)}',
                style: theme.textTheme.bodySmall,
              ),
          ],
        ),
        trailing: _folder == NoticeFolder.completed
            ? null
            : PopupMenuButton<_NoticeAction>(
                enabled: enabled,
                tooltip: 'Reminder actions',
                onSelected: (action) => _action(notice, action),
                itemBuilder: (_) => [
                  if (!notice.isRead)
                    const PopupMenuItem(
                      value: _NoticeAction.read,
                      child: Copy('Mark as read'),
                    ),
                  const PopupMenuItem(
                    value: _NoticeAction.hour,
                    child: Copy('Snooze for 1 hour'),
                  ),
                  const PopupMenuItem(
                    value: _NoticeAction.tomorrow,
                    child: Copy('Snooze for 1 day'),
                  ),
                  const PopupMenuItem(
                    value: _NoticeAction.done,
                    child: Copy('Mark done'),
                  ),
                ],
              ),
      ),
    );
  }
}
