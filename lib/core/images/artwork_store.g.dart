// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'artwork_store.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning
/// `bootstrap()` gives the real one.

@ProviderFor(artworkStore)
final artworkStoreProvider = ArtworkStoreProvider._();

/// `bootstrap()` gives the real one.

final class ArtworkStoreProvider
    extends $FunctionalProvider<ArtworkStore, ArtworkStore, ArtworkStore>
    with $Provider<ArtworkStore> {
  /// `bootstrap()` gives the real one.
  ArtworkStoreProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'artworkStoreProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$artworkStoreHash();

  @$internal
  @override
  $ProviderElement<ArtworkStore> $createElement($ProviderPointer pointer) =>
      $ProviderElement(pointer);

  @override
  ArtworkStore create(Ref ref) {
    return artworkStore(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(ArtworkStore value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<ArtworkStore>(value),
    );
  }
}

String _$artworkStoreHash() => r'70e38070370513db2db1ac902d72c73b59f39d2e';
