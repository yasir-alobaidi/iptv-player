import 'package:flutter/foundation.dart';
import 'package:iptv_player/core/library/library_item.dart';
import 'package:iptv_player/features/live_tv/domain/channels.dart';
import 'package:iptv_player/features/vod/domain/titles.dart';
import 'package:iptv_player/features/vod/domain/watch_progress.dart';

/// What the coordinator plays (docs/01's `PlayableSource`): a live channel,
/// a movie, an episode, or a file of the user's own from the library
/// (Phase 8). A downloaded movie or episode plays as itself, from its
/// file (Phase 8 decision 8).
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

/// A video of the user's own from the library (Phase 8 decision 8): no
/// source, no connection, no reconnects. History keys it by its quick
/// hash ([LocalRef]); a download keeps its title's ([libraryVodRef]).
final class PlayableLibraryItem extends Playable {
  const new(this.item);

  final LibraryItem item;

  /// No source: nothing on the network.
  @override
  String get sourceId => '';

  @override
  String get remoteKey => item.quickHash;

  @override
  bool get live => false;

  @override
  VodRef get vodRef => libraryVodRef(item);

  @override
  bool operator ==(Object other) =>
      other is PlayableLibraryItem && other.item.id == item.id;

  @override
  int get hashCode => Object.hash('library', item.id);
}

/// Where a library item's place is kept: a download's under its title at
/// the provider — the same place its page and Continue watching read,
/// however it was played — and a file of the user's own by its quick
/// hash.
VodRef libraryVodRef(LibraryItem item) => switch (item.provider) {
  ProviderLink(:final sourceId, type: VodType.movie, :final remoteKey) =>
    MovieRef(sourceId, remoteKey),
  ProviderLink(
    :final sourceId,
    type: VodType.episode,
    :final remoteKey,
    :final seriesKey?,
  ) =>
    EpisodeRef(sourceId, remoteKey, seriesKey: seriesKey),
  _ => LocalRef(item.quickHash),
};
