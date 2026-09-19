import 'package:iptv_player/core/core_providers.dart';
import 'package:iptv_player/core/player/player_engine.dart';
import 'package:iptv_player/core/player/player_providers.dart';
import 'package:iptv_player/data/db/db_providers.dart';
import 'package:iptv_player/features/live_tv/data/live_tv_providers.dart';
import 'package:iptv_player/features/playback/data/db_playback_history.dart';
import 'package:iptv_player/features/playback/data/db_stream_resolver.dart';
import 'package:iptv_player/features/playback/data/http_stream_prober.dart';
import 'package:iptv_player/features/playback/domain/playback.dart';
import 'package:iptv_player/features/playback/domain/playback_coordinator.dart';
import 'package:iptv_player/features/playback/domain/playback_state.dart';
import 'package:iptv_player/features/sources/data/source_providers.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'playback_providers.g.dart';

/// Settings → Playback (step 7 stores them; defaults until then).
@Riverpod(keepAlive: true)
PlaybackSettings playbackSettings(Ref ref) => const PlaybackSettings();

/// The app's one playback owner (docs/03).
@Riverpod(keepAlive: true)
PlaybackCoordinator playbackCoordinator(Ref ref) {
  final database = ref.watch(appDatabaseProvider);
  final sources = ref.watch(sourceRepositoryProvider);
  final coordinator = PlaybackCoordinator(
    engine: ref.watch(playerEngineProvider),
    resolver: DbStreamResolver(database, sources),
    prober: HttpStreamProber(sources),
    history: DbPlaybackHistory(database),
    channels: ref.watch(channelRepositoryProvider),
    log: ref.watch(appLogProvider),
    settings: () => ref.read(playbackSettingsProvider),
  );
  ref.onDispose(coordinator.dispose);
  return coordinator;
}

/// What plays, as it changes.
@Riverpod(keepAlive: true)
Stream<PlaybackState> playbackState(Ref ref) async* {
  final coordinator = ref.watch(playbackCoordinatorProvider);
  yield coordinator.state;
  yield* coordinator.states;
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
