import '../../../core/data/cursor_page.dart';

import 'dart:typed_data';

import 'inventory_product.dart';

class ProductPhoto {
  const ProductPhoto({required this.bytes, required this.contentType});
  final Uint8List bytes;
  final String contentType;
}

abstract interface class InventoryRepository {
  Future<CursorPage<InventoryProduct>> readProducts();
  Stream<List<InventoryProduct>> watchProducts({bool archived = false});
  Future<String?> setArchived(
    String productId,
    bool archived, {
    String? expectedAction,
  });
  Stream<List<StockMovement>> watchMovements(String productId);
  Future<void> save({
    required ProductDetails details,
    String? productId,
    int openingQuantity = 0,
    List<ProductPhoto> photos = const [],
  });
  Future<void> adjust(
    String productId,
    StockMovementType type,
    int quantity,
    String reason,
  );
}
