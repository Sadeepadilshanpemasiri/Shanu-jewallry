enum NoticeFolder { inbox, snoozed, completed }

class Notice {
  const Notice({
    required this.id,
    required this.type,
    required this.title,
    required this.body,
    required this.isRead,
    required this.createdAt,
    this.orderId,
    this.productId,
    this.snoozedUntil,
  });

  final String id, type, title, body;
  final bool isRead;
  final DateTime? createdAt, snoozedUntil;
  final String? orderId, productId;
}

class ReminderRules {
  const ReminderRules({
    this.enabled = true,
    this.lowStock = true,
    this.dailyDigest = true,
    this.weeklyDigest = true,
    this.pendingHours = 24,
    this.confirmedHours = 24,
    this.packedHours = 24,
    this.transitDays = 5,
    this.codDays = 3,
    this.digestHour = 8,
  });

  final bool enabled, lowStock, dailyDigest, weeklyDigest;
  final int pendingHours,
      confirmedHours,
      packedHours,
      transitDays,
      codDays,
      digestHour;

  factory ReminderRules.fromJson(Map<String, dynamic>? data) {
    int number(String key, int fallback, int minimum, int maximum) {
      final value = data?[key];
      return value is int && value >= minimum && value <= maximum
          ? value
          : fallback;
    }

    return ReminderRules(
      enabled: data?['enabled'] != false,
      lowStock: data?['lowStock'] != false,
      dailyDigest: data?['dailyDigest'] != false,
      weeklyDigest: data?['weeklyDigest'] != false,
      pendingHours: number('pendingHours', 24, 1, 720),
      confirmedHours: number('confirmedHours', 24, 1, 720),
      packedHours: number('packedHours', 24, 1, 720),
      transitDays: number('transitDays', 5, 1, 90),
      codDays: number('codDays', 3, 1, 90),
      digestHour: number('digestHour', 8, 0, 23),
    );
  }

  Map<String, Object> toJson() => {
    'enabled': enabled,
    'lowStock': lowStock,
    'dailyDigest': dailyDigest,
    'weeklyDigest': weeklyDigest,
    'pendingHours': pendingHours,
    'confirmedHours': confirmedHours,
    'packedHours': packedHours,
    'transitDays': transitDays,
    'codDays': codDays,
    'digestHour': digestHour,
  };
}
