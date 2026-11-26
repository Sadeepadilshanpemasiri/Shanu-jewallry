// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'theme_provider.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning

@ProviderFor(Appearance)
final appearanceProvider = AppearanceProvider._();

final class AppearanceProvider
    extends $AsyncNotifierProvider<Appearance, ThemeMode> {
  AppearanceProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'appearanceProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$appearanceHash();

  @$internal
  @override
  Appearance create() => Appearance();
}

String _$appearanceHash() => r'6c363102025fedea15e75267ea42ceb2fb0f4a05';

abstract class _$Appearance extends $AsyncNotifier<ThemeMode> {
  FutureOr<ThemeMode> build();
  @$mustCallSuper
  @override
  void runBuild() {
    final ref = this.ref as $Ref<AsyncValue<ThemeMode>, ThemeMode>;
    final element =
        ref.element
            as $ClassProviderElement<
              AnyNotifier<AsyncValue<ThemeMode>, ThemeMode>,
              AsyncValue<ThemeMode>,
              Object?,
              Object?
            >;
    element.handleCreate(ref, build);
  }
}
