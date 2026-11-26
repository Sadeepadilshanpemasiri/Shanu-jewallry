import 'dart:convert';
import 'dart:typed_data';

import 'package:cloud_firestore/cloud_firestore.dart';

Future<Uint8List> exportShopBackup(FirebaseFirestore database) async {
  const collections = [
    'products',
    'stock_movements',
    'inventory_skus',
    'customers',
    'orders',
    'couriers',
    'waybills',
    'settings',
    'notifications',
    'inventory_activity',
  ];
  final snapshots = await Future.wait([
    for (final name in collections)
      database.collection(name).get(const GetOptions(source: Source.server)),
  ]);
  final payload = {
    'format': 'jewellery-business-manager',
    'version': 1,
    'exportedAt': DateTime.now().toUtc().toIso8601String(),
    'collections': {
      for (final (index, snapshot) in snapshots.indexed)
        collections[index]: [
          for (final doc in snapshot.docs) {'id': doc.id, 'data': doc.data()},
        ],
    },
  };
  return Uint8List.fromList(
    utf8.encode(
      JsonEncoder.withIndent('  ', (Object? value) {
        if (value is Timestamp) {
          return {'timestamp': value.toDate().toUtc().toIso8601String()};
        }
        throw JsonUnsupportedObjectError(value);
      }).convert(payload),
    ),
  );
}
