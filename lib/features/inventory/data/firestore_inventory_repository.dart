import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';

import '../../../core/data/cursor_page.dart';
import '../../../core/data/firestore_cursor.dart';
import '../domain/inventory_product.dart';
import '../domain/inventory_repository.dart';

class FirestoreInventoryRepository implements InventoryRepository {
  FirestoreInventoryRepository(this._db, this._storage, this._auth);
  final FirebaseFirestore _db;
  final FirebaseStorage _storage;
  final FirebaseAuth _auth;

  CollectionReference<Map<String, dynamic>> get _products =>
      _db.collection('products');
  CollectionReference<Map<String, dynamic>> get _movements =>
      _db.collection('stock_movements');

  @override
  Future<CursorPage<InventoryProduct>> readProducts() => readFirestorePage(
    _products.where('isActive', isEqualTo: true).orderBy('name'),
    _product,
  );

  @override
  Stream<List<InventoryProduct>> watchProducts({bool archived = false}) =>
      _products
          .where('isActive', isEqualTo: !archived)
          .snapshots()
          .map(
            (snapshot) => snapshot.docs.map(_product).toList()
              ..sort(
                (a, b) => a.details.name.toLowerCase().compareTo(
                  b.details.name.toLowerCase(),
                ),
              ),
          );

  @override
  Future<String?> setArchived(
    String productId,
    bool archived, {
    String? expectedAction,
  }) async {
    final actor = _auth.currentUser?.uid;
    if (actor == null) {
      throw const InventoryFailure('Sign in to manage inventory.');
    }
    final product = _products.doc(productId);
    final action = _db.collection('inventory_activity').doc();
    return _db.runTransaction((tx) async {
      final current = (await tx.get(product)).data();
      if (current == null) {
        throw const InventoryFailure('Product is no longer available.');
      }
      if (expectedAction != null &&
          current['lastArchiveAction'] != expectedAction) {
        throw const InventoryFailure('The product changed since this action.');
      }
      if (current['isActive'] == !archived) return null;
      tx.update(product, {
        'isActive': !archived,
        'lastArchiveAction': action.id,
        'updatedAt': FieldValue.serverTimestamp(),
      });
      tx.set(action, {
        'productId': productId,
        'productName': current['name'],
        'archived': archived,
        'actorUid': actor,
        'createdAt': FieldValue.serverTimestamp(),
      });
      return action.id;
    });
  }

  InventoryProduct _product(QueryDocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data();
    return InventoryProduct(
      id: doc.id,
      quantity: data['stockQty'] as int,
      details: ProductDetails(
        name: data['name'] as String,
        sku: data['sku'] as String,
        category: data['category'] as String,
        metal: data['metalType'] as String,
        description: data['description'] as String,
        cost: data['costPrice'] as int,
        price: data['sellingPrice'] as int,
        threshold: data['lowStockThreshold'] as int,
        variants: List<String>.from(data['variants'] as List),
        images: List<String>.from(data['images'] as List),
      ),
    );
  }

  @override
  Stream<List<StockMovement>> watchMovements(String productId) => _movements
      .where('productId', isEqualTo: productId)
      .orderBy('createdAt', descending: true)
      .snapshots()
      .map(
        (snapshot) => snapshot.docs.map((doc) {
          final data = doc.data();
          return StockMovement(
            type: StockMovementType.values.byName(data['type'] as String),
            delta: data['qty'] as int,
            balance: data['balance'] as int,
            reason: data['reason'] as String,
            createdAt: (data['createdAt'] as Timestamp?)?.toDate(),
          );
        }).toList(),
      );

  @override
  Future<void> save({
    required ProductDetails details,
    String? productId,
    int openingQuantity = 0,
    List<ProductPhoto> photos = const [],
  }) async {
    final product = productId == null
        ? _products.doc()
        : _products.doc(productId);
    final sku = details.sku.isEmpty
        ? 'JWL-${product.id.toUpperCase()}'
        : details.sku.toUpperCase();
    if (!RegExp(r'^[A-Z0-9._-]{3,40}$').hasMatch(sku)) {
      throw const InventoryFailure(
        'Use 3–40 letters, numbers, dots, underscores or hyphens for the SKU.',
      );
    }
    adjustedStock(0, openingQuantity);
    if (details.images.length + photos.length > 6) {
      throw const InventoryFailure('Add up to six product photos.');
    }
    final reservation = _db.collection('inventory_skus').doc(sku);
    final images = [...details.images];
    final uploaded = <Reference>[];
    var commitAttempted = false;
    try {
      for (final photo in photos) {
        final path = _storage.ref(
          'products/${product.id}/${_products.doc().id}',
        );
        uploaded.add(path);
        await path.putData(
          photo.bytes,
          SettableMetadata(contentType: photo.contentType),
        );
        images.add(await path.getDownloadURL());
      }
      commitAttempted = true;
      final movement = _movements.doc();
      await _db.runTransaction((transaction) async {
        final current = (await transaction.get(product)).data();
        if (productId != null && current?['isActive'] != true) {
          throw const InventoryFailure('This product is no longer available.');
        }
        final reserved = (await transaction.get(reservation)).data();
        if (reserved != null && reserved['productId'] != product.id) {
          throw const InventoryFailure(
            'This SKU is already assigned to another product.',
          );
        }
        final previousSku = current?['sku'] as String?;
        if (previousSku != null && previousSku != sku) {
          transaction.delete(_db.collection('inventory_skus').doc(previousSku));
        }
        transaction.set(reservation, {'productId': product.id});
        transaction.set(product, {
          'name': details.name,
          'sku': sku,
          'category': details.category,
          'metalType': details.metal,
          'description': details.description,
          'costPrice': details.cost,
          'sellingPrice': details.price,
          'lowStockThreshold': details.threshold,
          'variants': details.variants,
          'images': images,
          'updatedAt': FieldValue.serverTimestamp(),
          if (productId == null) ...{
            'stockQty': openingQuantity,
            'isActive': true,
            if (openingQuantity > 0) 'lastMovementId': movement.id,
            'createdAt': FieldValue.serverTimestamp(),
          },
        }, SetOptions(merge: true));
        if (productId == null && openingQuantity > 0) {
          transaction.set(
            movement,
            _audit(
              product.id,
              StockMovementType.stockIn,
              openingQuantity,
              openingQuantity,
              'Opening stock',
            ),
          );
        }
      });
    } catch (error) {
      if (!commitAttempted || error is InventoryFailure) {
        await Future.wait(
          uploaded.map((photo) async {
            try {
              await photo.delete();
            } on FirebaseException {
              // Preserve the original error if a photo cannot be removed.
            }
          }),
        );
      }
      rethrow;
    }
  }

  @override
  Future<void> adjust(
    String productId,
    StockMovementType type,
    int quantity,
    String reason,
  ) async {
    if (reason.trim().isEmpty ||
        reason.trim().length > 250 ||
        quantity < 0 ||
        quantity > maxStock ||
        (quantity == 0 && type != StockMovementType.adjustment)) {
      throw const InventoryFailure('Enter a valid quantity and a reason.');
    }
    final product = _products.doc(productId);
    final movement = _movements.doc();
    await _db.runTransaction((transaction) async {
      final data = (await transaction.get(product)).data();
      if (data?['isActive'] != true) {
        throw const InventoryFailure('This product is no longer available.');
      }
      final current = data!['stockQty'] as int;
      final delta = switch (type) {
        StockMovementType.stockIn || StockMovementType.returned => quantity,
        StockMovementType.stockOut => -quantity,
        StockMovementType.adjustment => quantity - current,
      };
      if (delta == 0) {
        throw const InventoryFailure('The quantity has not changed.');
      }
      final next = adjustedStock(current, delta);
      transaction.update(product, {
        'stockQty': next,
        'updatedAt': FieldValue.serverTimestamp(),
        'lastMovementId': movement.id,
      });
      transaction.set(
        movement,
        _audit(productId, type, delta, next, reason.trim()),
      );
    });
  }

  Map<String, Object?> _audit(
    String id,
    StockMovementType type,
    int delta,
    int balance,
    String reason,
  ) => {
    'productId': id,
    'type': type.name,
    'qty': delta,
    'balance': balance,
    'reason': reason,
    'actorUid': _auth.currentUser?.uid,
    'createdAt': FieldValue.serverTimestamp(),
  };
}
