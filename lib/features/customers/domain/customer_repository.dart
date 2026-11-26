import '../../../core/data/cursor_page.dart';

import 'customer.dart';

abstract interface class CustomerRepository {
  Future<CursorPage<Customer>> readCustomers();
  Stream<List<Customer>> watchCustomers();
  Future<void> saveCustomer(Customer customer, {required bool editing});
}
