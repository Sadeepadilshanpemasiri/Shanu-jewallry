// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'dashboard_providers.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning

@ProviderFor(dashboardSettings)
final dashboardSettingsProvider = DashboardSettingsProvider._();

final class DashboardSettingsProvider
    extends
        $FunctionalProvider<
          DashboardSettings,
          DashboardSettings,
          DashboardSettings
        >
    with $Provider<DashboardSettings> {
  DashboardSettingsProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'dashboardSettingsProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$dashboardSettingsHash();

  @$internal
  @override
  $ProviderElement<DashboardSettings> $createElement(
    $ProviderPointer pointer,
  ) => $ProviderElement(pointer);

  @override
  DashboardSettings create(Ref ref) {
    return dashboardSettings(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(DashboardSettings value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<DashboardSettings>(value),
    );
  }
}

String _$dashboardSettingsHash() => r'940814505e17db997e23f5157deeeec6bd00cd39';

@ProviderFor(attentionThresholds)
final attentionThresholdsProvider = AttentionThresholdsProvider._();

final class AttentionThresholdsProvider
    extends
        $FunctionalProvider<
          AsyncValue<AttentionThresholds>,
          AttentionThresholds,
          Stream<AttentionThresholds>
        >
    with
        $FutureModifier<AttentionThresholds>,
        $StreamProvider<AttentionThresholds> {
  AttentionThresholdsProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'attentionThresholdsProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$attentionThresholdsHash();

  @$internal
  @override
  $StreamProviderElement<AttentionThresholds> $createElement(
    $ProviderPointer pointer,
  ) => $StreamProviderElement(pointer);

  @override
  Stream<AttentionThresholds> create(Ref ref) {
    return attentionThresholds(ref);
  }
}

String _$attentionThresholdsHash() =>
    r'27ff943825c70504fea34f0238f9d895f3b73afa';
