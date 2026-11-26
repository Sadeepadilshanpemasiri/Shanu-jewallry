import 'notice.dart';

abstract interface class NotificationRepository {
  Stream<List<Notice>> watch(NoticeFolder folder);
  Stream<int> watchUnread();
  Stream<ReminderRules> watchRules();
  Future<void> saveRules(ReminderRules rules);
  Future<void> markRead(String id);
  Future<void> markDone(String id);
  Future<void> snooze(String id, DateTime until);
}
