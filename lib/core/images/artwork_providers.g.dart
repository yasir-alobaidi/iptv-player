// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'artwork_providers.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning
/// Where screens get their pictures. Plain network images unless
/// `bootstrap()` puts the disk cache behind it (Phase 5 decision 6).

@ProviderFor(artworkImages)
final artworkImagesProvider = ArtworkImagesProvider._();

/// Where screens get their pictures. Plain network images unless
/// `bootstrap()` puts the disk cache behind it (Phase 5 decision 6).

final class ArtworkImagesProvider
    extends $FunctionalProvider<ArtworkImages, ArtworkImages, ArtworkImages>
    with $Provider<ArtworkImages> {
  /// Where screens get their pictures. Plain network images unless
  /// `bootstrap()` puts the disk cache behind it (Phase 5 decision 6).
  ArtworkImagesProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'artworkImagesProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$artworkImagesHash();

  @$internal
  @override
  $ProviderElement<ArtworkImages> $createElement($ProviderPointer pointer) =>
      $ProviderElement(pointer);

  @override
  ArtworkImages create(Ref ref) {
    return artworkImages(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(ArtworkImages value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<ArtworkImages>(value),
    );
  }
}

String _$artworkImagesHash() => r'395e1ce164b827c830c662ea75c35ddbc5a34897';
