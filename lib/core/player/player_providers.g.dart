// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'player_providers.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning
/// The app's one player: `MediaKitPlayerEngine`, created in bootstrap();
/// `FakePlayerEngine` in tests.

@ProviderFor(playerEngine)
final playerEngineProvider = PlayerEngineProvider._();

/// The app's one player: `MediaKitPlayerEngine`, created in bootstrap();
/// `FakePlayerEngine` in tests.

final class PlayerEngineProvider
    extends $FunctionalProvider<PlayerEngine, PlayerEngine, PlayerEngine>
    with $Provider<PlayerEngine> {
  /// The app's one player: `MediaKitPlayerEngine`, created in bootstrap();
  /// `FakePlayerEngine` in tests.
  PlayerEngineProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'playerEngineProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$playerEngineHash();

  @$internal
  @override
  $ProviderElement<PlayerEngine> $createElement($ProviderPointer pointer) =>
      $ProviderElement(pointer);

  @override
  PlayerEngine create(Ref ref) {
    return playerEngine(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(PlayerEngine value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<PlayerEngine>(value),
    );
  }
}

String _$playerEngineHash() => r'00fada53cfbaa1a4a59e4ed1af48526ba215c332';
