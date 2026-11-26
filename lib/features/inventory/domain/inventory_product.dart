enum StockLevel { inStock, low, out }

class InventoryProduct {
  const InventoryProduct({
    required this.id,
    required this.details,
    required this.quantity,
  });

  final String id;
  final ProductDetails details;
  final int quantity;

  StockLevel get level => quantity == 0
      ? StockLevel.out
      : quantity <= details.threshold
      ? StockLevel.low
      : StockLevel.inStock;
  int get costValue => quantity * details.cost;
  int get retailValue => quantity * details.price;
}

class ProductDetails {
  const ProductDetails({
    required this.name,
    required this.sku,
    required this.category,
    required this.metal,
    required this.description,
    required this.cost,
    required this.price,
    required this.threshold,
    required this.variants,
    required this.images,
  });

  final String name, sku, category, metal, description;
  final int cost, price, threshold;
  final List<String> variants, images;
  double? get profitMargin => price == 0 ? null : (price - cost) * 100 / price;
}

enum StockMovementType { stockIn, stockOut, adjustment, returned }

class StockMovement {
  const StockMovement({
    required this.type,
    required this.delta,
    required this.balance,
    required this.reason,
    required this.createdAt,
  });
  final StockMovementType type;
  final int delta, balance;
  final String reason;
  final DateTime? createdAt;
}

const maxStock = 1000000;

int adjustedStock(int current, int delta) {
  final next = current + delta;
  if (next < 0 || next > maxStock) {
    throw const InventoryFailure(
      'The resulting stock must be between 0 and 1,000,000.',
    );
  }
  return next;
}

int? toCents(String value) {
  final match = RegExp(r'^(\d{1,7})(?:\.(\d{1,2}))?$').firstMatch(value.trim());
  if (match == null) return null;
  final whole = int.parse(match[1]!);
  final fraction = int.parse((match[2] ?? '').padRight(2, '0'));
  final cents = whole * 100 + fraction;
  return cents <= 100000000 ? cents : null;
}

class InventoryFailure implements Exception {
  const InventoryFailure(this.message);
  final String message;
}
