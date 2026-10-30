// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'picture_in_picture.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning
/// `bootstrap()` gives a phone's, a tablet's and a Chromebook's
/// (`AndroidPictureInPicture`).

@ProviderFor(pictureInPicture)
final pictureInPictureProvider = PictureInPictureProvider._();

/// `bootstrap()` gives a phone's, a tablet's and a Chromebook's
/// (`AndroidPictureInPicture`).

final class PictureInPictureProvider
    extends
        $FunctionalProvider<
          PictureInPicture,
          PictureInPicture,
          PictureInPicture
        >
    with $Provider<PictureInPicture> {
  /// `bootstrap()` gives a phone's, a tablet's and a Chromebook's
  /// (`AndroidPictureInPicture`).
  PictureInPictureProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'pictureInPictureProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$pictureInPictureHash();

  @$internal
  @override
  $ProviderElement<PictureInPicture> $createElement($ProviderPointer pointer) =>
      $ProviderElement(pointer);

  @override
  PictureInPicture create(Ref ref) {
    return pictureInPicture(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(PictureInPicture value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<PictureInPicture>(value),
    );
  }
}

String _$pictureInPictureHash() => r'8dc44c6800ea4ff803efee48513b9100b955f1e1';

/// Whether the app is the small window now: the player draws the picture
/// alone in it.

@ProviderFor(InPictureInPicture)
final inPictureInPictureProvider = InPictureInPictureProvider._();

/// Whether the app is the small window now: the player draws the picture
/// alone in it.
final class InPictureInPictureProvider
    extends $NotifierProvider<InPictureInPicture, bool> {
  /// Whether the app is the small window now: the player draws the picture
  /// alone in it.
  InPictureInPictureProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'inPictureInPictureProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$inPictureInPictureHash();

  @$internal
  @override
  InPictureInPicture create() => InPictureInPicture();

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(bool value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<bool>(value),
    );
  }
}

String _$inPictureInPictureHash() =>
    r'c6ab2b57d2c2a3685c449c29c9ff559809e2b055';

/// Whether the app is the small window now: the player draws the picture
/// alone in it.

abstract class _$InPictureInPicture extends $Notifier<bool> {
  bool build();
  @$mustCallSuper
  @override
  WhenComplete runBuild() {
    final ref = this.ref as $Ref<bool, bool>;
    final element =
        ref.element
            as $ClassProviderElement<
              AnyNotifier<bool, bool>,
              bool,
              Object?,
              Object?
            >;
    return element.handleCreate(ref, build);
  }
}
