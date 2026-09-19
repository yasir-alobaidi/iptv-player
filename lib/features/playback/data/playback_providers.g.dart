// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'playback_providers.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning
/// Settings → Playback (step 7 stores them; defaults until then).

@ProviderFor(playbackSettings)
final playbackSettingsProvider = PlaybackSettingsProvider._();

/// Settings → Playback (step 7 stores them; defaults until then).

final class PlaybackSettingsProvider
    extends
        $FunctionalProvider<
          PlaybackSettings,
          PlaybackSettings,
          PlaybackSettings
        >
    with $Provider<PlaybackSettings> {
  /// Settings → Playback (step 7 stores them; defaults until then).
  PlaybackSettingsProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'playbackSettingsProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$playbackSettingsHash();

  @$internal
  @override
  $ProviderElement<PlaybackSettings> $createElement($ProviderPointer pointer) =>
      $ProviderElement(pointer);

  @override
  PlaybackSettings create(Ref ref) {
    return playbackSettings(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(PlaybackSettings value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<PlaybackSettings>(value),
    );
  }
}

String _$playbackSettingsHash() => r'b7c6fd24227750afbc82fe557af0c739389c63c7';

/// The app's one playback owner (docs/03).

@ProviderFor(playbackCoordinator)
final playbackCoordinatorProvider = PlaybackCoordinatorProvider._();

/// The app's one playback owner (docs/03).

final class PlaybackCoordinatorProvider
    extends
        $FunctionalProvider<
          PlaybackCoordinator,
          PlaybackCoordinator,
          PlaybackCoordinator
        >
    with $Provider<PlaybackCoordinator> {
  /// The app's one playback owner (docs/03).
  PlaybackCoordinatorProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'playbackCoordinatorProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$playbackCoordinatorHash();

  @$internal
  @override
  $ProviderElement<PlaybackCoordinator> $createElement(
    $ProviderPointer pointer,
  ) => $ProviderElement(pointer);

  @override
  PlaybackCoordinator create(Ref ref) {
    return playbackCoordinator(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(PlaybackCoordinator value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<PlaybackCoordinator>(value),
    );
  }
}

String _$playbackCoordinatorHash() =>
    r'121969251bf2495d01dd680a3eb1e62830392526';

/// What plays, as it changes.

@ProviderFor(playbackState)
final playbackStateProvider = PlaybackStateProvider._();

/// What plays, as it changes.

final class PlaybackStateProvider
    extends
        $FunctionalProvider<
          AsyncValue<PlaybackState>,
          PlaybackState,
          Stream<PlaybackState>
        >
    with $FutureModifier<PlaybackState>, $StreamProvider<PlaybackState> {
  /// What plays, as it changes.
  PlaybackStateProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'playbackStateProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$playbackStateHash();

  @$internal
  @override
  $StreamProviderElement<PlaybackState> $createElement(
    $ProviderPointer pointer,
  ) => $StreamProviderElement(pointer);

  @override
  Stream<PlaybackState> create(Ref ref) {
    return playbackState(ref);
  }
}

String _$playbackStateHash() => r'e2580c6462b0085057e71cd841b62a8419d25f65';

/// The picture's size while something plays; null between streams.

@ProviderFor(videoSize)
final videoSizeProvider = VideoSizeProvider._();

/// The picture's size while something plays; null between streams.

final class VideoSizeProvider
    extends
        $FunctionalProvider<
          AsyncValue<(int, int)?>,
          (int, int)?,
          Stream<(int, int)?>
        >
    with $FutureModifier<(int, int)?>, $StreamProvider<(int, int)?> {
  /// The picture's size while something plays; null between streams.
  VideoSizeProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'videoSizeProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$videoSizeHash();

  @$internal
  @override
  $StreamProviderElement<(int, int)?> $createElement(
    $ProviderPointer pointer,
  ) => $StreamProviderElement(pointer);

  @override
  Stream<(int, int)?> create(Ref ref) {
    return videoSize(ref);
  }
}

String _$videoSizeHash() => r'f9ae8541f6540798fe3044f713417ba65fdded84';
