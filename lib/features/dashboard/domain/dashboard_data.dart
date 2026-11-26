import '../../customers/domain/customer.dart';
import '../../inventory/domain/inventory_product.dart';
import '../../orders/domain/shop_order.dart';
import '../../reports/domain/business_report.dart';

class AttentionThresholds {
  const AttentionThresholds({this.toShipDays = 2, this.transitDays = 5});
  final int toShipDays, transitDays;
}

class DashboardData {
  DashboardData({
    required this.todayOrders,
    required this.todayRevenue,
    required this.pending,
    required this.toShip,
    required this.inTransit,
    required this.cancelledThisWeek,
    required this.unshipped,
    required this.overdue,
    required this.stockAlerts,
    required this.customerAlerts,
  });

  final int todayOrders,
      todayRevenue,
      pending,
      toShip,
      inTransit,
      cancelledThisWeek;
  final List<ShopOrder> unshipped, overdue, customerAlerts;
  final List<InventoryProduct> stockAlerts;

  static DashboardData calculate(
    List<ShopOrder> orders,
    List<InventoryProduct> products,
    List<Customer> customers,
    DateTime now,
    AttentionThresholds thresholds,
  ) {
    final today = shopDay(now);
    final week = ReportWindow(
      today.subtract(Duration(days: today.weekday - 1)),
      today,
    );
    final window = ReportWindow(today, today);
    final byPhone = {
      for (final customer in customers) customer.phone: customer,
    };
    final unshipped = <ShopOrder>[];
    final overdue = <ShopOrder>[];
    final customerAlerts = <ShopOrder>[];
    var todayOrders = 0,
        todayRevenue = 0,
        pending = 0,
        toShip = 0,
        inTransit = 0,
        cancelled = 0;
    for (final order in orders) {
      final status = order.status;
      if (window.contains(order.createdAt)) todayOrders++;
      if (status == OrderStatus.delivered &&
          window.contains(order.eventDate(status))) {
        todayRevenue += order.totals.total;
      }
      if (status == OrderStatus.cancelled &&
          week.contains(order.eventDate(status))) {
        cancelled++;
      }
      final ready =
          status == OrderStatus.confirmed || status == OrderStatus.packed;
      if (status == OrderStatus.pending) pending++;
      if (ready) toShip++;
      if (status == OrderStatus.shipped) inTransit++;
      if ((ready || status == OrderStatus.pending) &&
          _late(order.createdAt, now, thresholds.toShipDays)) {
        unshipped.add(order);
      }
      if (status == OrderStatus.shipped &&
          _late(order.eventDate(status), now, thresholds.transitDays)) {
        overdue.add(order);
      }
      final customer = byPhone[order.customer.phone];
      final active = status.next.isNotEmpty && status != OrderStatus.delivered;
      if (active &&
          customer != null &&
          (customer.blacklisted ||
              customer.watchlisted ||
              customer.stats.risk == CustomerRisk.high)) {
        customerAlerts.add(order);
      }
    }
    return DashboardData(
      todayOrders: todayOrders,
      todayRevenue: todayRevenue,
      pending: pending,
      toShip: toShip,
      inTransit: inTransit,
      cancelledThisWeek: cancelled,
      unshipped: unshipped,
      overdue: overdue,
      customerAlerts: customerAlerts,
      stockAlerts: products
          .where((product) => product.level != StockLevel.inStock)
          .toList(),
    );
  }

  static bool _late(DateTime? date, DateTime now, int days) =>
      date != null && now.difference(date) >= Duration(days: days);
}
