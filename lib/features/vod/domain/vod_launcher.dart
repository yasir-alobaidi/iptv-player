import 'package:iptv_player/features/vod/domain/titles.dart';

/// Starts a movie or an episode in the full-screen player (Phase 5 step
/// 6). `from` is where to start: a saved position to resume, or null for
/// the start.
abstract interface class VodLauncher {
  Future<void> playMovie(MovieItem movie, {Duration? from});

  Future<void> playEpisode(
    SeriesItem series,
    EpisodeItem episode, {
    Duration? from,
  });
}
