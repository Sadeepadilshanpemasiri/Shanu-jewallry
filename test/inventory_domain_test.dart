import 'package:flutter_test/flutter_test.dart';
import 'package:jewellery_business_manager/features/inventory/domain/inventory_product.dart';

void main() {
  test('stock changes cannot oversell or go above the supported limit', () {
    expect(adjustedStock(4, -4), 0);
    expect(() => adjustedStock(4, -5), throwsA(isA<InventoryFailure>()));
    expect(() => adjustedStock(maxStock, 1), throwsA(isA<InventoryFailure>()));
  });

  test('money parsing uses exact minor units', () {
    expect(toCents(' 1250.05 '), 125005);
    expect(toCents('1.2'), 120);
    expect(toCents('1000000.01'), isNull);
    expect(toCents('40.001'), isNull);
  });

  test('stock thresholds, gross margin and valuation', () {
    const details = ProductDetails(
      name: 'Ring',
      sku: 'R-001',
      category: 'Rings',
      metal: 'Silver',
      description: '',
      cost: 10000,
      price: 25000,
      threshold: 2,
      variants: [],
      images: [],
    );
    expect(
      const InventoryProduct(id: 'ring', details: details, quantity: 0).level,
      StockLevel.out,
    );
    const low = InventoryProduct(id: 'ring', details: details, quantity: 2);
    expect(low.level, StockLevel.low);
    expect(low.costValue, 20000);
    expect(low.retailValue, 50000);
    expect(details.profitMargin, 60);
  });
}
