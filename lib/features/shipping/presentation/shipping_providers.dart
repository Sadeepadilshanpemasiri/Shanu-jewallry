import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../data/firestore_courier_repository.dart';
import '../domain/courier.dart';
import '../domain/courier_repository.dart';

part 'shipping_providers.g.dart';

@riverpod
CourierRepository courierRepository(Ref ref) =>
    FirestoreCourierRepository(FirebaseFirestore.instance);

@riverpod
Stream<List<Courier>> couriers(Ref ref) =>
    ref.watch(courierRepositoryProvider).watchCouriers();
