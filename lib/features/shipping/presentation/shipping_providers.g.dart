// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'shipping_providers.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning

@ProviderFor(courierRepository)
final courierRepositoryProvider = CourierRepositoryProvider._();

final class CourierRepositoryProvider
    extends
        $FunctionalProvider<
          CourierRepository,
          CourierRepository,
          CourierRepository
        >
    with $Provider<CourierRepository> {
  CourierRepositoryProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'courierRepositoryProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$courierRepositoryHash();

  @$internal
  @override
  $ProviderElement<CourierRepository> $createElement(
    $ProviderPointer pointer,
  ) => $ProviderElement(pointer);

  @override
  CourierRepository create(Ref ref) {
    return courierRepository(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(CourierRepository value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<CourierRepository>(value),
    );
  }
}

String _$courierRepositoryHash() => r'1aa8917cb89c40bf942c439ef4e6266df458808d';

@ProviderFor(couriers)
final couriersProvider = CouriersProvider._();

final class CouriersProvider
    extends
        $FunctionalProvider<
          AsyncValue<List<Courier>>,
          List<Courier>,
          Stream<List<Courier>>
        >
    with $FutureModifier<List<Courier>>, $StreamProvider<List<Courier>> {
  CouriersProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'couriersProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$couriersHash();

  @$internal
  @override
  $StreamProviderElement<List<Courier>> $createElement(
    $ProviderPointer pointer,
  ) => $StreamProviderElement(pointer);

  @override
  Stream<List<Courier>> create(Ref ref) {
    return couriers(ref);
  }
}

String _$couriersHash() => r'30a606fdc649350f91b645e0891279d227538ae4';
