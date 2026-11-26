import 'package:flutter_test/flutter_test.dart';
import 'package:jewellery_business_manager/features/customers/domain/customer.dart';
import 'package:jewellery_business_manager/features/orders/domain/shop_order.dart';
import 'package:jewellery_business_manager/features/shipping/domain/courier.dart';
import 'package:jewellery_business_manager/features/shipping/domain/parcel_lookup.dart';

ShopOrder sample(
  String id,
  String number,
  String courier,
  String tracking,
  OrderStatus status,
) => ShopOrder(
  id: id,
  number: number,
  customer: const Customer(
    phone: '+94771234567',
    name: 'Test',
    address: 'Test address',
    city: 'Colombo',
  ),
  lines: const [],
  totals: const OrderTotals(subtotal: 0, delivery: 0, discount: 0),
  status: status,
  payment: OrderPayment.cod,
  advance: 0,
  timing: StockTiming.confirmed,
  source: 'WhatsApp',
  notes: '',
  courier: courier,
  tracking: tracking,
  createdAt: null,
  history: const [],
  restockAvailable: false,
);

void main() {
  test('normalizes waybill references within each courier only', () {
    expect(normalizedWaybill('  AB 012/3  '), 'AB012/3');
    expect(normalizedWaybill('https://example.test'), isNull);
    expect(
      waybillDocumentId(' Courier One ', 'ab 12'),
      waybillDocumentId('courier one', 'AB12'),
    );
    expect(
      waybillDocumentId('Courier One', 'AB12'),
      isNot(waybillDocumentId('Courier Two', 'AB12')),
    );
  });

  test('tracking template keeps HTTPS origin and encodes the waybill', () {
    final uri = trackingUri(
      'https://courier.test/track?ref={tracking}',
      'A/12 3',
    );
    expect(uri?.host, 'courier.test');
    expect(uri?.queryParameters['ref'], 'A/12 3');
    expect(trackingUri('http://courier.test/{tracking}', 'AB12'), isNull);
    expect(trackingUri('https://{tracking}.test/track', 'AB12'), isNull);
    expect(
      trackingUri('https://owner@courier.test/{tracking}', 'AB12'),
      isNull,
    );
    expect(trackingUri('https://courier.test/track', 'AB12'), isNull);
  });

  test(
    'label, order number, and courier-scoped waybill locate the expected parcel',
    () {
      final first = sample(
        'aB1',
        'JB-000001',
        'Courier One',
        'AB12',
        OrderStatus.packed,
      );
      final second = sample(
        'bA2',
        'JB-000002',
        'Courier Two',
        'AB12',
        OrderStatus.failedDelivery,
      );
      final orders = [first, second];
      expect(matchParcelOrders(orders, parcelLabelCode('aB1'), 'Courier Two'), [
        first,
      ]);
      expect(matchParcelOrders(orders, 'jb-000002', 'Courier One'), [second]);
      expect(matchParcelOrders(orders, 'ab 12', 'Courier Two'), [second]);
      expect(matchParcelOrders(orders, 'AB12', 'Courier Three'), isEmpty);
      expect(parcelLabelOrderId('JBM:incorrect/path'), isNull);
      expect(canShip(first), isTrue);
      expect(canShip(second), isTrue);
      expect(
        canShip(sample('cC3', 'JB-000003', '', '', OrderStatus.delivered)),
        isFalse,
      );
    },
  );
}
