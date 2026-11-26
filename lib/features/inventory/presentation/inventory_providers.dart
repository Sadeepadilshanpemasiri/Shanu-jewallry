import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../data/firestore_inventory_repository.dart';
import '../domain/inventory_product.dart';
import '../domain/inventory_repository.dart';

part 'inventory_providers.g.dart';

@riverpod
InventoryRepository inventoryRepository(Ref ref) =>
    FirestoreInventoryRepository(
      FirebaseFirestore.instance,
      FirebaseStorage.instance,
      FirebaseAuth.instance,
    );

@riverpod
Stream<List<InventoryProduct>> products(Ref ref) =>
    ref.watch(inventoryRepositoryProvider).watchProducts();

@riverpod
Stream<List<StockMovement>> stockMovements(Ref ref, String productId) =>
    ref.watch(inventoryRepositoryProvider).watchMovements(productId);
