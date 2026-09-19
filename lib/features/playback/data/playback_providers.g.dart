// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'playback_providers.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning

@ProviderFor(playbackSettingsStore)
final playbackSettingsStoreProvider = PlaybackSettingsStoreProvider._();

final class PlaybackSettingsStoreProvider
    extends
        $FunctionalProvider<
          PlaybackSettingsStore,
          PlaybackSettingsStore,
          PlaybackSettingsStore
        >
    with $Provider<PlaybackSettingsStore> {
  PlaybackSettingsStoreProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'playbackSettingsStoreProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$playbackSettingsStoreHash();

  @$internal
  @override
  $ProviderElement<PlaybackSettingsStore> $createElement(
    $ProviderPointer pointer,
  ) => $ProviderElement(pointer);

  @override
  PlaybackSettingsStore create(Ref ref) {
    return playbackSettingsStore(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(PlaybackSettingsStore value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<PlaybackSettingsStore>(value),
    );
  }
}

String _$playbackSettingsStoreHash() =>
    r'95ae781b7306ee84ba8bfde99822a05b66998d50';

/// Settings → Playback: the defaults at once, the stored choices as soon
/// as they are read; a change is saved and applies to the next stream
/// opened.

@ProviderFor(PlaybackSettingsController)
final playbackSettingsControllerProvider =
    PlaybackSettingsControllerProvider._();

/// Settings → Playback: the defaults at once, the stored choices as soon
/// as they are read; a change is saved and applies to the next stream
/// opened.
final class PlaybackSettingsControllerProvider
    extends $NotifierProvider<PlaybackSettingsController, PlaybackSettings> {
  /// Settings → Playback: the defaults at once, the stored choices as soon
  /// as they are read; a change is saved and applies to the next stream
  /// opened.
  PlaybackSettingsControllerProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'playbackSettingsControllerProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$playbackSettingsControllerHash();

  @$internal
  @override
  PlaybackSettingsController create() => PlaybackSettingsController();

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(PlaybackSettings value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<PlaybackSettings>(value),
    );
  }
}

String _$playbackSettingsControllerHash() =>
    r'be0a94a954429478b745edfee89efed5a9535437';

/// Settings → Playback: the defaults at once, the stored choices as soon
/// as they are read; a change is saved and applies to the next stream
/// opened.

abstract class _$PlaybackSettingsController
    extends $Notifier<PlaybackSettings> {
  PlaybackSettings build();
  @$mustCallSuper
  @override
  WhenComplete runBuild() {
    final ref = this.ref as $Ref<PlaybackSettings, PlaybackSettings>;
    final element =
        ref.element
            as $ClassProviderElement<
              AnyNotifier<PlaybackSettings, PlaybackSettings>,
              PlaybackSettings,
              Object?,
              Object?
            >;
    return element.handleCreate(ref, build);
  }
}

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
    r'6bb66ca7fa6ecbafd9b42101ec843ab9467fd837';

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

/// The stream's audio and subtitle tracks, and which are on.

@ProviderFor(playerTracks)
final playerTracksProvider = PlayerTracksProvider._();

/// The stream's audio and subtitle tracks, and which are on.

final class PlayerTracksProvider
    extends
        $FunctionalProvider<
          AsyncValue<PlayerTracks?>,
          PlayerTracks?,
          Stream<PlayerTracks?>
        >
    with $FutureModifier<PlayerTracks?>, $StreamProvider<PlayerTracks?> {
  /// The stream's audio and subtitle tracks, and which are on.
  PlayerTracksProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'playerTracksProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$playerTracksHash();

  @$internal
  @override
  $StreamProviderElement<PlayerTracks?> $createElement(
    $ProviderPointer pointer,
  ) => $StreamProviderElement(pointer);

  @override
  Stream<PlayerTracks?> create(Ref ref) {
    return playerTracks(ref);
  }
}

String _$playerTracksHash() => r'0d9141746c47513f32acaf4fd77d8c523708ddcb';
