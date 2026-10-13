// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'player_sound.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning
/// How loud the player is (ADR-017): one engine, so one volume for the
/// full-screen player and the preview alike, kept across restarts. The
/// engine is told the stored level when this is first read (`bootstrap()`
/// reads it), then every change.

@ProviderFor(PlayerSoundController)
final playerSoundControllerProvider = PlayerSoundControllerProvider._();

/// How loud the player is (ADR-017): one engine, so one volume for the
/// full-screen player and the preview alike, kept across restarts. The
/// engine is told the stored level when this is first read (`bootstrap()`
/// reads it), then every change.
final class PlayerSoundControllerProvider
    extends $NotifierProvider<PlayerSoundController, PlayerSound> {
  /// How loud the player is (ADR-017): one engine, so one volume for the
  /// full-screen player and the preview alike, kept across restarts. The
  /// engine is told the stored level when this is first read (`bootstrap()`
  /// reads it), then every change.
  PlayerSoundControllerProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'playerSoundControllerProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$playerSoundControllerHash();

  @$internal
  @override
  PlayerSoundController create() => PlayerSoundController();

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(PlayerSound value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<PlayerSound>(value),
    );
  }
}

String _$playerSoundControllerHash() =>
    r'c37fc92354dee0cc1c069b1a827f47b851656ca6';

/// How loud the player is (ADR-017): one engine, so one volume for the
/// full-screen player and the preview alike, kept across restarts. The
/// engine is told the stored level when this is first read (`bootstrap()`
/// reads it), then every change.

abstract class _$PlayerSoundController extends $Notifier<PlayerSound> {
  PlayerSound build();
  @$mustCallSuper
  @override
  WhenComplete runBuild() {
    final ref = this.ref as $Ref<PlayerSound, PlayerSound>;
    final element =
        ref.element
            as $ClassProviderElement<
              AnyNotifier<PlayerSound, PlayerSound>,
              PlayerSound,
              Object?,
              Object?
            >;
    return element.handleCreate(ref, build);
  }
}
