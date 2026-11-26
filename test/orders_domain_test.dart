import 'package:flutter_test/flutter_test.dart';
import 'package:jewellery_business_manager/features/customers/domain/customer.dart';
import 'package:jewellery_business_manager/features/orders/domain/shop_order.dart';

void main() {
  test('normalizes Sri Lankan numbers to one profile key', () {
    for (final value in [
      '077 123 4567',
      '+94 (77) 123-4567',
      '0094771234567',
      '94771234567',
    ]) {
      expect(normalizeSriLankanPhone(value), '+94771234567');
    }
    expect(normalizeSriLankanPhone('+44 1234567890'), isNull);
    expect(similarPhone('+94771234567', '+94771234568'), isTrue);
  });

  test('totals use cents and reject a discount greater than the total', () {
    const totals = OrderTotals(
      subtotal: 100050,
      delivery: 35000,
      discount: 5000,
    );
    expect(totals.total, 130050);
    expect(
      () => const OrderTotals(subtotal: 1, delivery: 0, discount: 2).validate(),
      throwsA(isA<OrderFailure>()),
    );
  });

  test('status transitions stop invalid jumps and terminal edits', () {
    expect(OrderStatus.pending.next, [
      OrderStatus.confirmed,
      OrderStatus.cancelled,
    ]);
    expect(OrderStatus.packed.next, contains(OrderStatus.shipped));
    expect(OrderStatus.returned.next, isEmpty);
    expect(OrderStatus.failedDelivery.next, contains(OrderStatus.shipped));
  });

  test(
    'risk follows recorded outcomes and preserves failed delivery history',
    () {
      final pending = OrderStatus.pending.contribution(everShipped: false);
      final failed = OrderStatus.failedDelivery.contribution(everShipped: true);
      final retried = OrderStatus.shipped.contribution(
        everShipped: true,
        everFailed: true,
      );
      final cancelled = OrderStatus.cancelled.contribution(
        everShipped: true,
        everFailed: true,
      );
      final stats =
          const CustomerStats() +
          pending -
          pending +
          failed -
          failed +
          retried -
          retried +
          cancelled;
      expect(stats.total, 1);
      expect(stats.cancelledAfterShipping, 1);
      expect(stats.failed, 1);
      expect(stats.risk, CustomerRisk.high);
    },
  );
}
