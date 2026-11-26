import 'package:cloud_firestore/cloud_firestore.dart';

import '../domain/courier.dart';
import '../domain/courier_repository.dart';

class FirestoreCourierRepository implements CourierRepository {
  FirestoreCourierRepository(this._db);
  final FirebaseFirestore _db;

  CollectionReference<Map<String, dynamic>> get _couriers =>
      _db.collection('couriers');

  @override
  Stream<List<Courier>> watchCouriers() => _couriers
      .orderBy('name')
      .snapshots()
      .map(
        (snapshot) => snapshot.docs.map((doc) {
          final data = doc.data();
          return Courier(
            name: data['name'] as String,
            template: data['trackingTemplate'] as String,
            active: data['isActive'] == true,
          );
        }).toList(),
      );

  @override
  Future<void> save(Courier courier, {required bool editing}) async {
    final name = courier.name.trim();
    final template = courier.template.trim();
    if (name.isEmpty ||
        name.length > 80 ||
        (template.isNotEmpty &&
            (template.length > 600 ||
                trackingUri(template, 'DEMO-123') == null))) {
      throw const ShippingFailure(
        'Enter a courier name and a valid HTTPS tracking template.',
      );
    }
    final record = _couriers.doc(Uri.encodeComponent(courier.key));
    await _db.runTransaction((transaction) async {
      final current = await transaction.get(record);
      if (current.exists != editing) {
        throw ShippingFailure(
          editing
              ? 'This courier is no longer available.'
              : 'A courier with this name already exists.',
        );
      }
      transaction.set(record, {
        'name': name,
        'trackingTemplate': template,
        'isActive': courier.active,
        'updatedAt': FieldValue.serverTimestamp(),
      });
    });
  }
}
