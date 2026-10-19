// fakeAsync drives these futures by elapsing time, not by awaiting them.
// ignore_for_file: discarded_futures

import 'package:fake_async/fake_async.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:iptv_player/core/core_providers.dart';
import 'package:iptv_player/core/logging/app_log.dart';
import 'package:iptv_player/core/logging/secret_registry.dart';
import 'package:iptv_player/core/platform/display_modes.dart';
import 'package:iptv_player/core/player/decoder_notes.dart';
import 'package:iptv_player/core/player/fake_player_engine.dart';
import 'package:iptv_player/core/player/player_engine.dart';
import 'package:iptv_player/core/player/player_providers.dart';
import 'package:iptv_player/core/result.dart';
import 'package:iptv_player/features/live_tv/data/live_tv_providers.dart';
import 'package:iptv_player/features/playback/data/playback_providers.dart';
import 'package:iptv_player/features/playback/domain/playable.dart';
import 'package:iptv_player/features/playback/domain/playback.dart';
import 'package:iptv_player/features/playback/domain/playback_state.dart';
import 'package:iptv_player/features/sources/data/source_providers.dart';
import 'package:iptv_player/features/vod/data/vod_providers.dart';
import 'package:logger/logger.dart';

import '../onboarding/onboarding_fakes.dart';
import 'support/display_fakes.dart';
import 'support/playback_fakes.dart';

/// The app's one coordinator gets a TV's Match frame rate from the
/// display `bootstrap()` gives it, and none from the desktop's.
void main() {
  /// The coordinator's provider as the app builds it, on [display], with
  /// Settings → Playback saying [settings].
  (ProviderContainer, FakePlayerEngine) app(
    DisplayModes display, {
    PlaybackSettings settings = const PlaybackSettings(matchFrameRate: true),
  }) {
    final fakes = Rig();
    final engine = FakePlayerEngine();
    final container = ProviderContainer(
      overrides: [
        sourceRepositoryProvider.overrideWithValue(OnboardingFakes().sources),
        playerEngineProvider.overrideWithValue(engine),
        streamResolverProvider.overrideWithValue(fakes.resolver),
        playbackHistoryProvider.overrideWithValue(fakes.history),
        channelRepositoryProvider.overrideWithValue(fakes.channels),
        watchProgressProvider.overrideWithValue(fakes.progress),
        decoderNotesProvider.overrideWithValue(const NoDecoderNotes()),
        appLogProvider.overrideWithValue(
          AppLog(output: MemoryOutput(), secrets: SecretRegistry()),
        ),
        playbackSettingsStoreProvider.overrideWithValue(_Stored(settings)),
        displayModesProvider.overrideWithValue(display),
      ],
    );
    addTearDown(container.dispose);
    return (container, engine);
  }

  /// A 100-minute film at 23.976 fps, to its first frame.
  void filmToFirstFrame(
    FakeAsync async,
    ProviderContainer container,
    FakePlayerEngine engine,
  ) {
    // The stored settings, read as the app starts.
    container.read(playbackSettingsControllerProvider);
    async.flushMicrotasks();
    container
        .read(playbackCoordinatorProvider)
        .playVod(PlayableMovie(movie(1)));
    async.flushMicrotasks();
    engine
      ..info = const StreamInfo(width: 1920, height: 1080, fps: 23.976)
      ..duration(const Duration(minutes: 100))
      ..firstFrame();
    async.flushMicrotasks();
  }

  test("a TV's display: a film's first frame asks for its rate", () {
    fakeAsync((async) {
      final display = FakeDisplayModes();
      final (container, engine) = app(display);

      filmToFirstFrame(async, container, engine);
      expect(display.requests, [uhd23976.id]);
      expect(
        container.read(playbackCoordinatorProvider).state,
        isA<PlaybackOpening>(),
      );

      async.elapse(const Duration(seconds: 4));
      expect(
        container.read(playbackCoordinatorProvider).state,
        isA<PlaybackPlaying>(),
      );
    });
  });

  test('Settings → Playback → Match frame rate off: the film plays as it '
      'is', () {
    fakeAsync((async) {
      final display = FakeDisplayModes();
      final (container, engine) = app(
        display,
        settings: const PlaybackSettings(),
      );

      filmToFirstFrame(async, container, engine);
      expect(display.requests, isEmpty);
      expect(
        container.read(playbackCoordinatorProvider).state,
        isA<PlaybackPlaying>(),
      );
    });
  });

  test("the desktop's display: nothing to match, the film plays at once", () {
    fakeAsync((async) {
      final (container, engine) = app(const NoDisplayModes());

      filmToFirstFrame(async, container, engine);
      expect(engine.calls, isEmpty);
      expect(
        container.read(playbackCoordinatorProvider).state,
        isA<PlaybackPlaying>(),
      );
    });
  });

  test("the app closing lets the TV's mode go", () {
    fakeAsync((async) {
      final display = FakeDisplayModes();
      final (container, engine) = app(display);
      filmToFirstFrame(async, container, engine);
      async.elapse(const Duration(seconds: 4));

      container.dispose();
      async.flushMicrotasks();
      expect(display.requests, [uhd23976.id, 0]);
    });
  });
}

final class _Stored implements PlaybackSettingsStore {
  const new(this._settings);

  final PlaybackSettings _settings;

  @override
  Future<Result<PlaybackSettings>> load() async => Ok(_settings);

  @override
  Future<Result<void>> save(PlaybackSettings settings) async => const Ok(null);
}
