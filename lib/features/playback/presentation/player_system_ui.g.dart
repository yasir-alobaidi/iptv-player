// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'player_system_ui.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning

@ProviderFor(playerSystemUi)
final playerSystemUiProvider = PlayerSystemUiProvider._();

final class PlayerSystemUiProvider
    extends $FunctionalProvider<PlayerSystemUi, PlayerSystemUi, PlayerSystemUi>
    with $Provider<PlayerSystemUi> {
  PlayerSystemUiProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'playerSystemUiProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$playerSystemUiHash();

  @$internal
  @override
  $ProviderElement<PlayerSystemUi> $createElement($ProviderPointer pointer) =>
      $ProviderElement(pointer);

  @override
  PlayerSystemUi create(Ref ref) {
    return playerSystemUi(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(PlayerSystemUi value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<PlayerSystemUi>(value),
    );
  }
}

String _$playerSystemUiHash() => r'5ff84b8d0a4957d990a106ee6618c6c63a6c4c49';
