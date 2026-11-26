import 'package:cloud_firestore/cloud_firestore.dart';

import '../domain/notice.dart';
import '../domain/notification_repository.dart';

class FirestoreNotificationRepository implements NotificationRepository {
  FirestoreNotificationRepository(this._db);
  final FirebaseFirestore _db;
  CollectionReference<Map<String, dynamic>> get _notices =>
      _db.collection('notifications');
  DocumentReference<Map<String, dynamic>> get _rules =>
      _db.doc('settings/reminders');

  @override
  Stream<List<Notice>> watch(NoticeFolder folder) {
    final filter = switch (folder) {
      NoticeFolder.inbox => _notices.where('state', isEqualTo: 'open'),
      NoticeFolder.snoozed => _notices.where('state', isEqualTo: 'snoozed'),
      NoticeFolder.completed => _notices.where(
        'state',
        whereIn: ['done', 'resolved'],
      ),
    };
    return filter
        .orderBy('createdAt', descending: true)
        .limit(120)
        .snapshots()
        .map(
          (snapshot) => snapshot.docs.map((doc) {
            final data = doc.data();
            return Notice(
              id: doc.id,
              type: data['type'] as String,
              title: data['title'] as String,
              body: data['body'] as String,
              isRead: data['isRead'] == true,
              orderId: data['relatedOrderId'] as String?,
              productId: data['productId'] as String?,
              createdAt: (data['createdAt'] as Timestamp?)?.toDate(),
              snoozedUntil: (data['snoozedUntil'] as Timestamp?)?.toDate(),
            );
          }).toList(),
        );
  }

  @override
  Stream<int> watchUnread() => _notices
      .where('state', isEqualTo: 'open')
      .where('isRead', isEqualTo: false)
      .limit(100)
      .snapshots()
      .map((snapshot) => snapshot.size);

  @override
  Stream<ReminderRules> watchRules() => _rules.snapshots().map(
    (snapshot) => ReminderRules.fromJson(snapshot.data()),
  );

  @override
  Future<void> saveRules(ReminderRules rules) => _rules.set({
    ...rules.toJson(),
    'updatedAt': FieldValue.serverTimestamp(),
  }, SetOptions(merge: true));

  @override
  Future<void> markRead(String id) => _notices.doc(id).update({'isRead': true});

  @override
  Future<void> markDone(String id) => _notices.doc(id).update({
    'state': 'done',
    'isRead': true,
    'snoozedUntil': null,
  });

  @override
  Future<void> snooze(String id, DateTime until) => _notices.doc(id).update({
    'state': 'snoozed',
    'isRead': true,
    'snoozedUntil': Timestamp.fromDate(until),
  });
}
