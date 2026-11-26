// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'order_providers.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning

@ProviderFor(orderRepository)
final orderRepositoryProvider = OrderRepositoryProvider._();

final class OrderRepositoryProvider
    extends
        $FunctionalProvider<OrderRepository, OrderRepository, OrderRepository>
    with $Provider<OrderRepository> {
  OrderRepositoryProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'orderRepositoryProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$orderRepositoryHash();

  @$internal
  @override
  $ProviderElement<OrderRepository> $createElement($ProviderPointer pointer) =>
      $ProviderElement(pointer);

  @override
  OrderRepository create(Ref ref) {
    return orderRepository(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(OrderRepository value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<OrderRepository>(value),
    );
  }
}

String _$orderRepositoryHash() => r'34a68635ea1ae159928541c3580f4d99396f48b9';

@ProviderFor(orders)
final ordersProvider = OrdersFamily._();

final class OrdersProvider
    extends
        $FunctionalProvider<
          AsyncValue<List<ShopOrder>>,
          List<ShopOrder>,
          Stream<List<ShopOrder>>
        >
    with $FutureModifier<List<ShopOrder>>, $StreamProvider<List<ShopOrder>> {
  OrdersProvider._({
    required OrdersFamily super.from,
    required String? super.argument,
  }) : super(
         retry: null,
         name: r'ordersProvider',
         isAutoDispose: true,
         dependencies: null,
         $allTransitiveDependencies: null,
       );

  @override
  String debugGetCreateSourceHash() => _$ordersHash();

  @override
  String toString() {
    return r'ordersProvider'
        ''
        '($argument)';
  }

  @$internal
  @override
  $StreamProviderElement<List<ShopOrder>> $createElement(
    $ProviderPointer pointer,
  ) => $StreamProviderElement(pointer);

  @override
  Stream<List<ShopOrder>> create(Ref ref) {
    final argument = this.argument as String?;
    return orders(ref, phone: argument);
  }

  @override
  bool operator ==(Object other) {
    return other is OrdersProvider && other.argument == argument;
  }

  @override
  int get hashCode {
    return argument.hashCode;
  }
}

String _$ordersHash() => r'5d1487572263253f206a8df75f90d5443916da4e';

final class OrdersFamily extends $Family
    with $FunctionalFamilyOverride<Stream<List<ShopOrder>>, String?> {
  OrdersFamily._()
    : super(
        retry: null,
        name: r'ordersProvider',
        dependencies: null,
        $allTransitiveDependencies: null,
        isAutoDispose: true,
      );

  OrdersProvider call({String? phone}) =>
      OrdersProvider._(argument: phone, from: this);

  @override
  String toString() => r'ordersProvider';
}
