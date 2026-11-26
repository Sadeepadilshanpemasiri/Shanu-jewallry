import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../data/firestore_order_repository.dart';
import '../domain/order_repository.dart';
import '../domain/shop_order.dart';

part 'order_providers.g.dart';

@riverpod
OrderRepository orderRepository(Ref ref) =>
    FirestoreOrderRepository(FirebaseFirestore.instance, FirebaseAuth.instance);

@riverpod
Stream<List<ShopOrder>> orders(Ref ref, {String? phone}) =>
    ref.watch(orderRepositoryProvider).watchOrders(phone: phone);
