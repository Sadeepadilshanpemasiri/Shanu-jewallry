import 'package:firebase_core/firebase_core.dart';
import 'package:intl/intl.dart';

import '../domain/inventory_product.dart';

final _money = NumberFormat.currency(
  locale: 'en_LK',
  symbol: 'LKR ',
  decimalDigits: 2,
);
String lkr(int cents) => _money.format(cents / 100);

String inventoryError(Object error) => switch (error) {
  InventoryFailure() => error.message,
  FirebaseException(code: 'permission-denied' || 'unauthorized') =>
    'Owner access is required.',
  FirebaseException(code: 'unavailable' || 'failed-precondition') =>
    'Check your connection and Firebase setup, then try again.',
  _ => 'Inventory could not complete the request. Try again.',
};

String movementLabel(StockMovementType type) => switch (type) {
  StockMovementType.stockIn => 'Stock in',
  StockMovementType.stockOut => 'Stock out',
  StockMovementType.adjustment => 'Set balance',
  StockMovementType.returned => 'Return to stock',
};
