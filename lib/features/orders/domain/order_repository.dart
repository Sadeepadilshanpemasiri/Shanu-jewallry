import '../../../core/data/cursor_page.dart';

import 'shop_order.dart';

abstract interface class OrderRepository {
  Future<CursorPage<ShopOrder>> readOrders({bool newest = true});
  Stream<List<ShopOrder>> watchOrders({String? phone});
  Future<ShopOrder?> getOrder(String id);
  Future<String> create(OrderDraft draft);
  Future<String> updatePending(String id, OrderDraft draft);
  Future<void> transition(String id, OrderUpdate update);
  Future<void> updateDetails(
    String id, {
    required String notes,
    required OrderPayment payment,
    required int advance,
  });
}
