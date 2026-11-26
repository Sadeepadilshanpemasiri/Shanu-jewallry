import 'courier.dart';

abstract interface class CourierRepository {
  Stream<List<Courier>> watchCouriers();
  Future<void> save(Courier courier, {required bool editing});
}
