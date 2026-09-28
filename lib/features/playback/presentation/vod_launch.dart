import 'dart:async';

import 'package:go_router/go_router.dart';
import 'package:iptv_player/app/router.dart';
import 'package:iptv_player/features/live_tv/presentation/live_tv_screen.dart';
import 'package:iptv_player/features/playback/data/playback_providers.dart';
import 'package:iptv_player/features/playback/domain/playable.dart';
import 'package:iptv_player/features/playback/domain/playback_coordinator.dart';
import 'package:iptv_player/features/vod/domain/titles.dart';
import 'package:iptv_player/features/vod/domain/vod_launcher.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'vod_launch.g.dart';

/// Starts a movie or an episode full screen: Play, Resume and Continue on
/// the details pages, Home's cards (Phase 5 step 7).
@Riverpod(keepAlive: true)
VodLauncher vodLauncher(Ref ref) => PlayerVodLauncher(
  ref.watch(playbackCoordinatorProvider),
  () => ref.read(routerProvider),
);

/// [VodLauncher] on the coordinator and the full-screen player: Esc in the
/// player comes back to the page it was opened from.
final class PlayerVodLauncher implements VodLauncher {
  new(this._coordinator, this._router);

  final PlaybackCoordinator _coordinator;
  final GoRouter Function() _router;

  @override
  Future<void> playMovie(MovieItem movie, {Duration? from}) =>
      _start(PlayableMovie(movie), from);

  @override
  Future<void> playEpisode(
    SeriesItem series,
    EpisodeItem episode, {
    Duration? from,
  }) => _start(PlayableEpisode(series, episode), from);

  Future<void> _start(Playable item, Duration? from) async {
    // The player opens on the new item's Opening, not on what played last.
    final playing = _coordinator.playVod(item, from: from);
    final router = _router();
    if (router.state.uri.path != playerRoutePath) {
      unawaited(router.push<void>(playerRoutePath));
    }
    await playing;
  }
}
