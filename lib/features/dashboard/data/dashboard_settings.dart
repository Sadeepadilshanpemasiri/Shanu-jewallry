import 'package:cloud_firestore/cloud_firestore.dart';

import '../domain/dashboard_data.dart';

class DashboardSettings {
  DashboardSettings(FirebaseFirestore firestore)
    : _document = firestore.doc('settings/dashboard_attention');
  final DocumentReference<Map<String, dynamic>> _document;

  Stream<AttentionThresholds> watch() => _document.snapshots().map((snapshot) {
    final data = snapshot.data();
    return AttentionThresholds(
      toShipDays: _days(data?['toShipDays'], 2),
      transitDays: _days(data?['transitDays'], 5),
    );
  });

  int _days(Object? value, int fallback) =>
      value is int && value >= 1 && value <= 90 ? value : fallback;

  Future<void> save(AttentionThresholds thresholds) => _document.set({
    'toShipDays': thresholds.toShipDays,
    'transitDays': thresholds.transitDays,
    'updatedAt': FieldValue.serverTimestamp(),
  }, SetOptions(merge: true));
}
