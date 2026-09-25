// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'settings_section.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning
/// Which section Settings shows, and which source the Categories and
/// Guide sections manage.

@ProviderFor(SettingsLocation)
final settingsLocationProvider = SettingsLocationProvider._();

/// Which section Settings shows, and which source the Categories and
/// Guide sections manage.
final class SettingsLocationProvider
    extends $NotifierProvider<SettingsLocation, SettingsPlace> {
  /// Which section Settings shows, and which source the Categories and
  /// Guide sections manage.
  SettingsLocationProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'settingsLocationProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$settingsLocationHash();

  @$internal
  @override
  SettingsLocation create() => SettingsLocation();

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(SettingsPlace value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<SettingsPlace>(value),
    );
  }
}

String _$settingsLocationHash() => r'cc55822e8d6f6de872c160ad84cd9103c2e7dc82';

/// Which section Settings shows, and which source the Categories and
/// Guide sections manage.

abstract class _$SettingsLocation extends $Notifier<SettingsPlace> {
  SettingsPlace build();
  @$mustCallSuper
  @override
  WhenComplete runBuild() {
    final ref = this.ref as $Ref<SettingsPlace, SettingsPlace>;
    final element =
        ref.element
            as $ClassProviderElement<
              AnyNotifier<SettingsPlace, SettingsPlace>,
              SettingsPlace,
              Object?,
              Object?
            >;
    return element.handleCreate(ref, build);
  }
}
