import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../data/browser_push.dart';
import '../data/firestore_notification_repository.dart';
import '../domain/notice.dart';
import '../domain/notification_repository.dart';

part 'notification_providers.g.dart';

@riverpod
NotificationRepository notificationRepository(Ref ref) =>
    FirestoreNotificationRepository(FirebaseFirestore.instance);

@riverpod
BrowserPush browserPush(Ref ref) =>
    BrowserPush(FirebaseFirestore.instance, FirebaseAuth.instance);

@riverpod
Stream<List<Notice>> notices(Ref ref, NoticeFolder folder) =>
    ref.watch(notificationRepositoryProvider).watch(folder);

@riverpod
Stream<int> unreadNotices(Ref ref) =>
    ref.watch(notificationRepositoryProvider).watchUnread();

@riverpod
Stream<ReminderRules> reminderRules(Ref ref) =>
    ref.watch(notificationRepositoryProvider).watchRules();
