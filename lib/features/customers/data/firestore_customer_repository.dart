import 'package:cloud_firestore/cloud_firestore.dart';

import '../../../core/data/cursor_page.dart';
import '../../../core/data/firestore_cursor.dart';
import '../domain/customer.dart';
import '../domain/customer_repository.dart';

Map<String, Object> customerFields(Customer customer) => {
  'name': customer.name,
  'phone': customer.phone,
  'address': customer.address,
  'city': customer.city,
  'notes': customer.notes,
  'watchlist': customer.watchlisted,
  'blacklist': customer.blacklisted,
  'restrictionReason': customer.restrictionReason,
};

class CustomerFailure implements Exception {
  const CustomerFailure(this.message);
  final String message;
}

class FirestoreCustomerRepository implements CustomerRepository {
  FirestoreCustomerRepository(this._db);
  final FirebaseFirestore _db;

  CollectionReference<Map<String, dynamic>> get _customers =>
      _db.collection('customers');

  @override
  Future<CursorPage<Customer>> readCustomers() => readFirestorePage(
    _customers.orderBy('name'),
    (doc) => Customer.fromJson(doc.id, doc.data()),
  );

  @override
  Stream<List<Customer>> watchCustomers() => _customers
      .orderBy('name')
      .snapshots()
      .map(
        (snapshot) => snapshot.docs
            .map((doc) => Customer.fromJson(doc.id, doc.data()))
            .toList(),
      );

  @override
  Future<void> saveCustomer(Customer customer, {required bool editing}) async {
    if (normalizeSriLankanPhone(customer.phone) != customer.phone ||
        customer.name.trim().isEmpty ||
        customer.address.trim().isEmpty ||
        customer.city.trim().isEmpty ||
        ((customer.watchlisted || customer.blacklisted) &&
            customer.restrictionReason.trim().isEmpty)) {
      throw const CustomerFailure(
        'Check the contact details and enter a reason for any restriction.',
      );
    }
    final reference = _customers.doc(customer.phone);
    await _db.runTransaction((transaction) async {
      final old = await transaction.get(reference);
      if (old.exists && !editing) {
        throw const CustomerFailure(
          'This phone already belongs to a customer.',
        );
      }
      if (!old.exists && editing) {
        throw const CustomerFailure('This customer is no longer available.');
      }
      transaction.set(reference, {
        ...customerFields(customer),
        if (!editing) ...{
          ...const CustomerStats().toJson(),
          'createdAt': FieldValue.serverTimestamp(),
        },
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
    });
  }
}
