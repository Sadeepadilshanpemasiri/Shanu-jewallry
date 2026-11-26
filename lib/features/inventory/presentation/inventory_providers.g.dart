// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'inventory_providers.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning

@ProviderFor(inventoryRepository)
final inventoryRepositoryProvider = InventoryRepositoryProvider._();

final class InventoryRepositoryProvider
    extends
        $FunctionalProvider<
          InventoryRepository,
          InventoryRepository,
          InventoryRepository
        >
    with $Provider<InventoryRepository> {
  InventoryRepositoryProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'inventoryRepositoryProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$inventoryRepositoryHash();

  @$internal
  @override
  $ProviderElement<InventoryRepository> $createElement(
    $ProviderPointer pointer,
  ) => $ProviderElement(pointer);

  @override
  InventoryRepository create(Ref ref) {
    return inventoryRepository(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(InventoryRepository value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<InventoryRepository>(value),
    );
  }
}

String _$inventoryRepositoryHash() =>
    r'484678db9d285287e4ed74c6947358e794f43d03';

@ProviderFor(products)
final productsProvider = ProductsProvider._();

final class ProductsProvider
    extends
        $FunctionalProvider<
          AsyncValue<List<InventoryProduct>>,
          List<InventoryProduct>,
          Stream<List<InventoryProduct>>
        >
    with
        $FutureModifier<List<InventoryProduct>>,
        $StreamProvider<List<InventoryProduct>> {
  ProductsProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'productsProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$productsHash();

  @$internal
  @override
  $StreamProviderElement<List<InventoryProduct>> $createElement(
    $ProviderPointer pointer,
  ) => $StreamProviderElement(pointer);

  @override
  Stream<List<InventoryProduct>> create(Ref ref) {
    return products(ref);
  }
}

String _$productsHash() => r'e7051846d6e0fde3e94aa119412a2229819e4938';

@ProviderFor(stockMovements)
final stockMovementsProvider = StockMovementsFamily._();

final class StockMovementsProvider
    extends
        $FunctionalProvider<
          AsyncValue<List<StockMovement>>,
          List<StockMovement>,
          Stream<List<StockMovement>>
        >
    with
        $FutureModifier<List<StockMovement>>,
        $StreamProvider<List<StockMovement>> {
  StockMovementsProvider._({
    required StockMovementsFamily super.from,
    required String super.argument,
  }) : super(
         retry: null,
         name: r'stockMovementsProvider',
         isAutoDispose: true,
         dependencies: null,
         $allTransitiveDependencies: null,
       );

  @override
  String debugGetCreateSourceHash() => _$stockMovementsHash();

  @override
  String toString() {
    return r'stockMovementsProvider'
        ''
        '($argument)';
  }

  @$internal
  @override
  $StreamProviderElement<List<StockMovement>> $createElement(
    $ProviderPointer pointer,
  ) => $StreamProviderElement(pointer);

  @override
  Stream<List<StockMovement>> create(Ref ref) {
    final argument = this.argument as String;
    return stockMovements(ref, argument);
  }

  @override
  bool operator ==(Object other) {
    return other is StockMovementsProvider && other.argument == argument;
  }

  @override
  int get hashCode {
    return argument.hashCode;
  }
}

String _$stockMovementsHash() => r'292bc6abe23cbe99b87324d0dcfb11ac39af5989';

final class StockMovementsFamily extends $Family
    with $FunctionalFamilyOverride<Stream<List<StockMovement>>, String> {
  StockMovementsFamily._()
    : super(
        retry: null,
        name: r'stockMovementsProvider',
        dependencies: null,
        $allTransitiveDependencies: null,
        isAutoDispose: true,
      );

  StockMovementsProvider call(String productId) =>
      StockMovementsProvider._(argument: productId, from: this);

  @override
  String toString() => r'stockMovementsProvider';
}
