enum CustomerRisk { low, medium, high }

class CustomerStats {
  const CustomerStats({
    this.total = 0,
    this.delivered = 0,
    this.cancelled = 0,
    this.cancelledAfterShipping = 0,
    this.returned = 0,
    this.failed = 0,
  });

  final int total,
      delivered,
      cancelled,
      cancelledAfterShipping,
      returned,
      failed;

  CustomerRisk get risk {
    final score =
        cancelledAfterShipping * 2 +
        returned * 2 +
        failed +
        cancelled -
        cancelledAfterShipping;
    return score >= 3
        ? CustomerRisk.high
        : score > 0
        ? CustomerRisk.medium
        : CustomerRisk.low;
  }

  CustomerStats operator +(CustomerStats other) => CustomerStats(
    total: total + other.total,
    delivered: delivered + other.delivered,
    cancelled: cancelled + other.cancelled,
    cancelledAfterShipping:
        cancelledAfterShipping + other.cancelledAfterShipping,
    returned: returned + other.returned,
    failed: failed + other.failed,
  );

  CustomerStats operator -(CustomerStats other) =>
      this +
      CustomerStats(
        total: -other.total,
        delivered: -other.delivered,
        cancelled: -other.cancelled,
        cancelledAfterShipping: -other.cancelledAfterShipping,
        returned: -other.returned,
        failed: -other.failed,
      );

  Map<String, Object> toJson() => {
    'totalOrders': total,
    'deliveredCount': delivered,
    'cancelledCount': cancelled,
    'cancelledAfterShipping': cancelledAfterShipping,
    'returnedCount': returned,
    'failedCount': failed,
    'riskLevel': risk.name,
  };

  factory CustomerStats.fromJson(Map<String, dynamic> data) => CustomerStats(
    total: data['totalOrders'] as int? ?? 0,
    delivered: data['deliveredCount'] as int? ?? 0,
    cancelled: data['cancelledCount'] as int? ?? 0,
    cancelledAfterShipping: data['cancelledAfterShipping'] as int? ?? 0,
    returned: data['returnedCount'] as int? ?? 0,
    failed: data['failedCount'] as int? ?? 0,
  );
}

class Customer {
  const Customer({
    required this.phone,
    required this.name,
    required this.address,
    required this.city,
    this.notes = '',
    this.watchlisted = false,
    this.blacklisted = false,
    this.restrictionReason = '',
    this.stats = const CustomerStats(),
  });

  final String phone, name, address, city, notes, restrictionReason;
  final bool watchlisted, blacklisted;
  final CustomerStats stats;

  bool get needsReview =>
      watchlisted || blacklisted || stats.risk != CustomerRisk.low;

  factory Customer.fromJson(String phone, Map<String, dynamic> data) =>
      Customer(
        phone: phone,
        name: data['name'] as String,
        address: data['address'] as String,
        city: data['city'] as String,
        notes: data['notes'] as String? ?? '',
        watchlisted: data['watchlist'] == true,
        blacklisted: data['blacklist'] == true,
        restrictionReason: data['restrictionReason'] as String? ?? '',
        stats: CustomerStats.fromJson(data),
      );
}

String? normalizeSriLankanPhone(String input) {
  final compact = input.trim().replaceAll(RegExp(r'[\s()\-]'), '');
  final match = RegExp(r'^(?:\+94|0094|94|0)([1-9]\d{8})$').firstMatch(compact);
  return match == null ? null : '+94${match[1]}';
}

bool similarPhone(String first, String second) {
  if (first.length != second.length || first == second) return false;
  var differences = 0;
  for (var i = 0; i < first.length; i++) {
    if (first[i] != second[i]) differences++;
  }
  return differences == 1;
}
