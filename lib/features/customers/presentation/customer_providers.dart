import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../data/firestore_customer_repository.dart';
import '../domain/customer.dart';
import '../domain/customer_repository.dart';

part 'customer_providers.g.dart';

@riverpod
CustomerRepository customerRepository(Ref ref) =>
    FirestoreCustomerRepository(FirebaseFirestore.instance);

@riverpod
Stream<List<Customer>> customers(Ref ref) =>
    ref.watch(customerRepositoryProvider).watchCustomers();
