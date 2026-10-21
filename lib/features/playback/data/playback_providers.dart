import 'dart:async';

import 'package:iptv_player/core/core_providers.dart';
import 'package:iptv_player/core/platform/display_modes.dart';
import 'package:iptv_player/core/platform/network_status.dart';
import 'package:iptv_player/core/player/decoder_notes.dart';
import 'package:iptv_player/core/player/player_engine.dart';
import 'package:iptv_player/core/player/player_providers.dart';
import 'package:iptv_player/core/result.dart';
import 'package:iptv_player/core/streams/current_state_stream.dart';
import 'package:iptv_player/data/db/db_providers.dart';
import 'package:iptv_player/features/diagnostics/data/db_decoder_notes.dart';
import 'package:iptv_player/features/live_tv/data/live_tv_providers.dart';
import 'package:iptv_player/features/playback/data/db_playback_history.dart';
import 'package:iptv_player/features/playback/data/db_playback_settings_store.dart';
import 'package:iptv_player/features/playback/data/db_stream_resolver.dart';
import 'package:iptv_player/features/playback/data/http_stream_prober.dart';
import 'package:iptv_player/features/playback/domain/frame_rate_match.dart';
import 'package:iptv_player/features/playback/domain/playback.dart';
import 'package:iptv_player/features/playback/domain/playback_coordinator.dart';
import 'package:iptv_player/features/playback/domain/playback_state.dart';
import 'package:iptv_player/features/sources/data/source_providers.dart';
import 'package:iptv_player/features/vod/data/vod_providers.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'playback_providers.g.dart';

@Riverpod(keepAlive: true)
PlaybackSettingsStore playbackSettingsStore(Ref ref) =>
    DbPlaybackSettingsStore(ref.watch(settingsRepositoryProvider));

/// Settings → Playback: the defaults at once, the stored choices as soon
/// as they are read; a change is saved and applies to the next stream
/// opened (the subtitles' size and the time on screen at once: the
/// picture and the player watch them).
@Riverpod(keepAlive: true)
class PlaybackSettingsController extends _$PlaybackSettingsController {
  @override
  PlaybackSettings build() {
    unawaited(_load());
    return const PlaybackSettings();
  }

  var _changed = false;

  Future<void> _load() async {
    final stored = await ref.read(playbackSettingsStoreProvider).load();
    // A choice made while loading wins over what was stored.
    if (!_changed) state = stored.valueOrNull ?? const PlaybackSettings();
  }

  Future<Result<void>> update(PlaybackSettings settings) {
    _changed = true;
    state = settings;
    return ref.read(playbackSettingsStoreProvider).save(settings);
  }

  /// Reads the stored choices again: an import replaced them (Settings →
  /// Data).
  Future<void> reload() {
    _changed = false;
    return _load();
  }
}

/// What decoded each kind of video last, kept for the diagnostics report
/// (Phase 9 decision 9).
@Riverpod(keepAlive: true)
DecoderNotes decoderNotes(Ref ref) => DbDecoderNotes(
  ref.watch(settingsRepositoryProvider),
  clock: ref.watch(appClockProvider),
);

/// Stream URLs built from their source at play time (docs/02).
@Riverpod(keepAlive: true)
StreamResolver streamResolver(Ref ref) => DbStreamResolver(
  ref.watch(appDatabaseProvider),
  ref.watch(sourceRepositoryProvider),
);

@Riverpod(keepAlive: true)
PlaybackHistory playbackHistory(Ref ref) =>
    DbPlaybackHistory(ref.watch(appDatabaseProvider));

/// The app's one playback owner (docs/03), with a TV's Match frame rate
/// (ADR-035) where there is a display to ask: none on the desktop.
@Riverpod(keepAlive: true)
PlaybackCoordinator playbackCoordinator(Ref ref) {
  final sources = ref.watch(sourceRepositoryProvider);
  final log = ref.watch(appLogProvider);
  final display = ref.watch(displayModesProvider);
  final frameRate = display.available
      ? FrameRateMatcher(display: display, log: log)
      : null;
  final coordinator = PlaybackCoordinator(
    engine: ref.watch(playerEngineProvider),
    resolver: ref.watch(streamResolverProvider),
    prober: HttpStreamProber(sources),
    history: ref.watch(playbackHistoryProvider),
    channels: ref.watch(channelRepositoryProvider),
    progress: ref.watch(watchProgressProvider),
    decoders: ref.watch(decoderNotesProvider),
    frameRate: frameRate,
    log: log,
    settings: () => ref.read(playbackSettingsControllerProvider),
  );
  ref.onDispose(coordinator.dispose);
  // After the coordinator: the TV's own mode back as the app closes.
  if (frameRate != null) ref.onDispose(frameRate.dispose);
  return coordinator;
}

/// What plays, as it changes.
@Riverpod(keepAlive: true)
Stream<PlaybackState> playbackState(Ref ref) {
  final coordinator = ref.watch(playbackCoordinatorProvider);
  return currentThenChanges(() => coordinator.state, coordinator.states);
}

/// The picture's size while something plays; null between streams.
@Riverpod(keepAlive: true)
Stream<(int, int)?> videoSize(Ref ref) async* {
  yield null;
  yield* ref
      .watch(playerEngineProvider)
      .events
      .where((e) => e is PlayerOpening || e is PlayerVideoChanged)
      .map(
        (e) => switch (e) {
          PlayerVideoChanged(:final width, :final height) => (width, height),
          _ => null,
        },
      );
}

/// The stream's audio and subtitle tracks, and which are on.
@Riverpod(keepAlive: true)
Stream<PlayerTracks?> playerTracks(Ref ref) async* {
  yield null;
  yield* ref
      .watch(playerEngineProvider)
      .events
      .where((e) => e is PlayerOpening || e is PlayerTracks)
      .map((e) => e is PlayerTracks ? e : null);
}

/// What a play says about the network (Phase 8 decision 11): a source's
/// picture, or any HTTP answer, is an answer; the prober reaching nothing
/// (a network failure with no status) is none at all. A stall proves
/// neither, and a file on this computer says nothing.
bool? sourceAnswered(PlaybackState state, {required bool local}) {
  if (local) return null;
  switch (state) {
    case PlaybackPlaying():
      return true;
    case PlaybackFailed(:final problem) || PlaybackReconnecting(:final problem):
      return switch (problem.failure) {
        NetworkFailure(statusCode: null) => false,
        AppFailure(statusCode: _?) => true,
        _ => null,
      };
    case _:
      return null;
  }
}

/// Tells the network status what each play says (Phase 8 decision 11).
/// `bootstrap()` reads it once.
@Riverpod(keepAlive: true)
void playbackReachability(Ref ref) {
  final coordinator = ref.watch(playbackCoordinatorProvider);
  final status = ref.watch(networkStatusProvider);
  final listening = coordinator.states.listen((state) {
    switch (sourceAnswered(state, local: coordinator.local)) {
      case true:
        status.sourceAnswered();
      case false:
        status.sourceUnanswered();
      case null:
        break;
    }
  });
  ref.onDispose(listening.cancel);
}
