import '../../orders/domain/shop_order.dart';
import 'courier.dart';

bool canShip(ShopOrder order) =>
    order.status.next.contains(OrderStatus.shipped);

List<ShopOrder> matchParcelOrders(
  List<ShopOrder> orders,
  String input,
  String courier,
) {
  final text = input.trim();
  if (text.isEmpty) return [];
  final labelId = parcelLabelOrderId(text);
  if (labelId != null) {
    return orders.where((order) => order.id == labelId).toList();
  }
  final byOrder = orders
      .where(
        (order) =>
            order.id == text ||
            order.number.toUpperCase() == text.toUpperCase(),
      )
      .toList();
  if (byOrder.isNotEmpty) return byOrder;
  final waybill = normalizedWaybill(text);
  if (waybill == null) return [];
  return orders
      .where(
        (order) =>
            courierKey(order.courier) == courierKey(courier) &&
            normalizedWaybill(order.tracking) == waybill,
      )
      .toList();
}
