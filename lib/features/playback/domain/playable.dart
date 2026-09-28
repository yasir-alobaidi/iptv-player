import 'package:flutter/foundation.dart';
import 'package:iptv_player/features/live_tv/domain/channels.dart';
import 'package:iptv_player/features/vod/domain/titles.dart';
import 'package:iptv_player/features/vod/domain/watch_progress.dart';

/// What the coordinator plays (docs/01's `PlayableSource`): a live channel,
/// a movie or an episode. Phase 8 adds a file from the library.
@immutable
sealed class Playable {
  const new();

  String get sourceId;

  /// The item's key at its source; with [sourceId], what history keys it
  /// by.
  String get remoteKey;

  /// False for a file: it has a length, seeks, and saves where it was
  /// left.
  bool get live;

  /// How watch history keys a movie or an episode; null for live.
  VodRef? get vodRef;
}

final class PlayableChannel extends Playable {
  const new(this.channel);

  final ChannelItem channel;

  @override
  String get sourceId => channel.sourceId;

  @override
  String get remoteKey => channel.remoteKey;

  @override
  bool get live => true;

  @override
  VodRef? get vodRef => null;

  @override
  bool operator ==(Object other) =>
      other is PlayableChannel && other.channel == channel;

  @override
  int get hashCode => channel.hashCode;
}

final class PlayableMovie extends Playable {
  const new(this.movie);

  final MovieItem movie;

  @override
  String get sourceId => movie.sourceId;

  @override
  String get remoteKey => movie.remoteKey;

  @override
  bool get live => false;

  @override
  VodRef get vodRef => movie.ref;

  @override
  bool operator ==(Object other) =>
      other is PlayableMovie && other.movie == movie;

  @override
  int get hashCode => movie.hashCode;
}

final class PlayableEpisode extends Playable {
  const new(this.series, this.episode);

  final SeriesItem series;
  final EpisodeItem episode;

  @override
  String get sourceId => episode.sourceId;

  @override
  String get remoteKey => episode.remoteKey;

  @override
  bool get live => false;

  @override
  VodRef get vodRef => episode.ref;

  @override
  bool operator ==(Object other) =>
      other is PlayableEpisode &&
      other.series == series &&
      other.episode == episode;

  @override
  int get hashCode => Object.hash(series, episode);
}
