// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'settings_section.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning
/// Which section Settings shows, and which source the Categories section
/// manages. Kept for the session, so leaving Settings and coming back
/// returns to the same place.

@ProviderFor(SettingsLocation)
final settingsLocationProvider = SettingsLocationProvider._();

/// Which section Settings shows, and which source the Categories section
/// manages. Kept for the session, so leaving Settings and coming back
/// returns to the same place.
final class SettingsLocationProvider
    extends
        $NotifierProvider<
          SettingsLocation,
          ({String? categoriesSourceId, SettingsSection section})
        > {
  /// Which section Settings shows, and which source the Categories section
  /// manages. Kept for the session, so leaving Settings and coming back
  /// returns to the same place.
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
  Override overrideWithValue(
    ({String? categoriesSourceId, SettingsSection section}) value,
  ) {
    return $ProviderOverride(
      origin: this,
      providerOverride:
          $SyncValueProvider<
            ({String? categoriesSourceId, SettingsSection section})
          >(value),
    );
  }
}

String _$settingsLocationHash() => r'2510ea10dcb622c0a80de3ca9e21a07d7db78d8b';

/// Which section Settings shows, and which source the Categories section
/// manages. Kept for the session, so leaving Settings and coming back
/// returns to the same place.

abstract class _$SettingsLocation
    extends $Notifier<({String? categoriesSourceId, SettingsSection section})> {
  ({String? categoriesSourceId, SettingsSection section}) build();
  @$mustCallSuper
  @override
  WhenComplete runBuild() {
    final ref =
        this.ref
            as $Ref<
              ({String? categoriesSourceId, SettingsSection section}),
              ({String? categoriesSourceId, SettingsSection section})
            >;
    final element =
        ref.element
            as $ClassProviderElement<
              AnyNotifier<
                ({String? categoriesSourceId, SettingsSection section}),
                ({String? categoriesSourceId, SettingsSection section})
              >,
              ({String? categoriesSourceId, SettingsSection section}),
              Object?,
              Object?
            >;
    return element.handleCreate(ref, build);
  }
}
