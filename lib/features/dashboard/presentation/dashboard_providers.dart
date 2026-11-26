import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../data/dashboard_settings.dart';
import '../domain/dashboard_data.dart';

part 'dashboard_providers.g.dart';

@riverpod
DashboardSettings dashboardSettings(Ref ref) =>
    DashboardSettings(FirebaseFirestore.instance);

@riverpod
Stream<AttentionThresholds> attentionThresholds(Ref ref) =>
    ref.watch(dashboardSettingsProvider).watch();
