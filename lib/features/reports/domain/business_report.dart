import '../../inventory/domain/inventory_product.dart';
import '../../orders/domain/shop_order.dart';

DateTime shopDay(DateTime instant) {
  final local = instant.toUtc().add(const Duration(hours: 5, minutes: 30));
  return DateTime.utc(local.year, local.month, local.day);
}

class ReportWindow {
  const ReportWindow(this.start, this.end);

  factory ReportWindow.last(int days, DateTime now) {
    final end = shopDay(now);
    return ReportWindow(end.subtract(Duration(days: days - 1)), end);
  }

  final DateTime start, end;
  int get days => end.difference(start).inDays + 1;
  bool contains(DateTime? instant) {
    if (instant == null) return false;
    final day = shopDay(instant);
    return !day.isBefore(start) && !day.isAfter(end);
  }
}

class DailySales {
  DailySales(this.day);
  final DateTime day;
  int revenue = 0, profit = 0;
}

class ItemSales {
  ItemSales(this.label, {this.code = ''});
  final String label, code;
  int units = 0, value = 0;
}

class SourceSales {
  SourceSales(this.name);
  final String name;
  int orders = 0, revenue = 0;
}

class CourierSales {
  CourierSales(this.name);
  final String name;
  int dispatched = 0, delivered = 0, failed = 0, returned = 0;
  int _deliveryMinutes = 0, _deliverySamples = 0;
  double? get averageDays =>
      _deliverySamples == 0 ? null : _deliveryMinutes / _deliverySamples / 1440;
}

class BusinessReport {
  BusinessReport._(this.window);
  final ReportWindow window;
  int placed = 0, delivered = 0, revenue = 0, profit = 0;
  final statuses = <OrderStatus, int>{};
  final sources = <String, SourceSales>{};
  final couriers = <String, CourierSales>{};
  final products = <String, ItemSales>{};
  final categories = <String, ItemSales>{};
  final daily = <DateTime, DailySales>{};

  int get cancelled => statuses[OrderStatus.cancelled] ?? 0;
  int get returned => statuses[OrderStatus.returned] ?? 0;
  double? get cancellationRate => placed == 0 ? null : cancelled * 100 / placed;
  double? get returnRate => placed == 0 ? null : returned * 100 / placed;

  List<ItemSales> ranked(Iterable<ItemSales> items) =>
      items.toList()..sort((a, b) {
        final quantity = b.units.compareTo(a.units);
        return quantity == 0 ? a.label.compareTo(b.label) : quantity;
      });

  static BusinessReport calculate(
    List<ShopOrder> orders,
    List<InventoryProduct> inventory,
    ReportWindow window,
  ) {
    final report = BusinessReport._(window);
    final currentCategory = {
      for (final product in inventory) product.id: product.details.category,
    };
    for (final order in orders) {
      final sourceName = order.source.trim().isEmpty
          ? 'Unspecified'
          : order.source.trim();
      if (window.contains(order.createdAt)) {
        report.placed++;
        report.statuses.update(
          order.status,
          (count) => count + 1,
          ifAbsent: () => 1,
        );
        report.sources
            .putIfAbsent(sourceName, () => SourceSales(sourceName))
            .orders++;
      }
      final dispatched = order.eventDate(OrderStatus.shipped);
      final delivered = order.eventDate(OrderStatus.delivered);
      if (order.courier.isNotEmpty &&
          dispatched != null &&
          window.contains(dispatched)) {
        final courier = report.couriers.putIfAbsent(
          order.courier,
          () => CourierSales(order.courier),
        );
        courier.dispatched++;
        if (order.history.any(
          (event) => event.status == OrderStatus.failedDelivery,
        )) {
          courier.failed++;
        }
        if (order.status == OrderStatus.returned) courier.returned++;
        if (order.status == OrderStatus.delivered) {
          courier.delivered++;
          if (delivered != null && !delivered.isBefore(dispatched)) {
            courier._deliveryMinutes += delivered
                .difference(dispatched)
                .inMinutes;
            courier._deliverySamples++;
          }
        }
      }
      if (order.status != OrderStatus.delivered ||
          delivered == null ||
          !window.contains(delivered)) {
        continue;
      }
      report.delivered++;
      final revenue = order.totals.total;
      final cost = order.lines.fold<int>(
        0,
        (amount, line) => amount + line.cost * line.quantity,
      );
      final profit = order.totals.subtotal - order.totals.discount - cost;
      report.revenue += revenue;
      report.profit += profit;
      report.sources
              .putIfAbsent(sourceName, () => SourceSales(sourceName))
              .revenue +=
          revenue;
      final day = shopDay(delivered);
      final sales = report.daily.putIfAbsent(day, () => DailySales(day));
      sales.revenue += revenue;
      sales.profit += profit;
      for (final line in order.lines) {
        final category = line.category.isNotEmpty
            ? line.category
            : currentCategory[line.productId] ?? 'Uncategorized';
        final product = report.products.putIfAbsent(
          line.productId,
          () => ItemSales(line.name, code: line.sku),
        );
        final group = report.categories.putIfAbsent(
          category,
          () => ItemSales(category),
        );
        final value = line.price * line.quantity;
        product.units += line.quantity;
        product.value += value;
        group.units += line.quantity;
        group.value += value;
      }
    }
    return report;
  }

  List<DailySales> trend() => List.generate(window.days, (index) {
    final day = window.start.add(Duration(days: index));
    return daily[day] ?? DailySales(day);
  });
}
