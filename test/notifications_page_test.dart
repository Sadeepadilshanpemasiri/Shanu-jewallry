import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jewellery_business_manager/features/notifications/data/browser_push.dart';
import 'package:jewellery_business_manager/features/notifications/domain/notice.dart';
import 'package:jewellery_business_manager/features/notifications/domain/notification_repository.dart';
import 'package:jewellery_business_manager/features/notifications/presentation/notification_providers.dart';
import 'package:jewellery_business_manager/features/notifications/presentation/notifications_page.dart';

class _Push extends Fake implements BrowserPush {
  @override
  Future<bool> supported() async => false;
}

class _Repository extends Fake implements NotificationRepository {
  String? snoozed;
  DateTime? until;

  @override
  Future<void> snooze(String id, DateTime until) async {
    snoozed = id;
    this.until = until;
  }
}

void main() {
  test('reminder settings use safe defaults for unsupported values', () {
    final rules = ReminderRules.fromJson({
      'pendingHours': 0,
      'transitDays': 9,
      'digestHour': 25,
      'lowStock': false,
    });
    expect(rules.pendingHours, 24);
    expect(rules.transitDays, 9);
    expect(rules.digestHour, 8);
    expect(rules.toJson()['lowStock'], isFalse);
  });

  testWidgets(
    'phone-width notification inbox exposes unread and snooze actions',
    (tester) async {
      await tester.binding.setSurfaceSize(const Size(360, 740));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      final repository = _Repository();
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            browserPushProvider.overrideWith((ref) => _Push()),
            notificationRepositoryProvider.overrideWith((ref) => repository),
            unreadNoticesProvider.overrideWith((ref) => Stream.value(1)),
            noticesProvider(NoticeFolder.inbox).overrideWith(
              (ref) => Stream.value([
                const Notice(
                  id: 'stale-order--one',
                  type: 'stale-order',
                  title: 'Pending order needs review',
                  body: 'JB-000001 needs attention.',
                  isRead: false,
                  createdAt: null,
                ),
              ]),
            ),
            noticesProvider(
              NoticeFolder.snoozed,
            ).overrideWith((ref) => Stream.value([])),
          ],
          child: const MaterialApp(home: NotificationsPage()),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('1 unread'), findsOneWidget);
      expect(find.text('Pending order needs review'), findsOneWidget);
      await tester.tap(find.byTooltip('Reminder actions'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Snooze for 1 hour'));
      await tester.pumpAndSettle();
      expect(repository.snoozed, 'stale-order--one');
      expect(
        repository.until!.difference(DateTime.now()).inMinutes,
        inInclusiveRange(59, 60),
      );
      await tester.tap(find.text('Snoozed'));
      await tester.pumpAndSettle();
      expect(find.text('No snoozed reminders.'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );
}
