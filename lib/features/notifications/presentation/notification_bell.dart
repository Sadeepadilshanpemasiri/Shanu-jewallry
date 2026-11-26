import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'notification_providers.dart';

class NotificationBell extends ConsumerStatefulWidget {
  const NotificationBell({super.key});

  @override
  ConsumerState<NotificationBell> createState() => _NotificationBellState();
}

class _NotificationBellState extends ConsumerState<NotificationBell> {
  @override
  void initState() {
    super.initState();
    ref.read(browserPushProvider).refreshRegistered().ignore();
  }

  @override
  Widget build(BuildContext context) {
    final unread = ref.watch(unreadNoticesProvider).asData?.value ?? 0;
    return IconButton(
      onPressed: () => context.push('/notifications'),
      tooltip: unread == 0
          ? 'Notifications'
          : 'Notifications, ${unread >= 100 ? '99+' : unread} unread',
      icon: Badge(
        isLabelVisible: unread > 0,
        label: Text(unread >= 100 ? '99+' : '$unread'),
        child: const Icon(Icons.notifications_outlined),
      ),
    );
  }
}
