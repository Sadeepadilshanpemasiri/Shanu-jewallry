import 'package:intl/intl.dart';

import '../../customers/data/firestore_customer_repository.dart';
import '../../inventory/presentation/inventory_format.dart';
import '../domain/shop_order.dart';

String orderDate(DateTime? date) => date == null
    ? 'Syncing date'
    : DateFormat('dd MMM yyyy, HH:mm').format(date.toLocal());

String orderError(Object error) => switch (error) {
  OrderFailure() => error.message,
  CustomerFailure() => error.message,
  _ => inventoryError(error),
};
