// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'auth_providers.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning

@ProviderFor(authRepository)
final authRepositoryProvider = AuthRepositoryProvider._();

final class AuthRepositoryProvider
    extends $FunctionalProvider<AuthRepository, AuthRepository, AuthRepository>
    with $Provider<AuthRepository> {
  AuthRepositoryProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'authRepositoryProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$authRepositoryHash();

  @$internal
  @override
  $ProviderElement<AuthRepository> $createElement($ProviderPointer pointer) =>
      $ProviderElement(pointer);

  @override
  AuthRepository create(Ref ref) {
    return authRepository(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(AuthRepository value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<AuthRepository>(value),
    );
  }
}

String _$authRepositoryHash() => r'087ece9249815a072d83fd6a674a79a54fb51ee3';

@ProviderFor(ownerSession)
final ownerSessionProvider = OwnerSessionProvider._();

final class OwnerSessionProvider
    extends $FunctionalProvider<AsyncValue<Owner?>, Owner?, Stream<Owner?>>
    with $FutureModifier<Owner?>, $StreamProvider<Owner?> {
  OwnerSessionProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'ownerSessionProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$ownerSessionHash();

  @$internal
  @override
  $StreamProviderElement<Owner?> $createElement($ProviderPointer pointer) =>
      $StreamProviderElement(pointer);

  @override
  Stream<Owner?> create(Ref ref) {
    return ownerSession(ref);
  }
}

String _$ownerSessionHash() => r'aed372871ed2fa648255165917c88b98b308543c';
