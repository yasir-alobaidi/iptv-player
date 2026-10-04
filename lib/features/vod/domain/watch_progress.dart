import 'package:flutter/foundation.dart';
import 'package:iptv_player/core/library/library_item.dart';
import 'package:iptv_player/core/result.dart';
import 'package:iptv_player/features/vod/domain/titles.dart';

/// Below this a title is "not really started": no resume prompt, and a
/// movie stays out of Continue watching (docs/03).
const resumeAfter = Duration(seconds: 60);

/// At or past this share of its length a title counts as watched (docs/03).
const completeAt = 0.95;

/// Whether [position] of [duration] counts as watched.
bool isComplete(Duration position, Duration? duration) =>
    duration != null &&
    duration > Duration.zero &&
    position.inMilliseconds >= duration.inMilliseconds * completeAt;

/// Where a movie or an episode was left.
@immutable
final class WatchMark {
  const new({
    required this.position,
    required this.updatedAt,
    this.duration,
    this.completed = false,
  });

  final Duration position;

  /// The player's own duration, which the panel's metadata may disagree
  /// with; null until it was played long enough to know.
  final Duration? duration;
  final bool completed;
  final DateTime updatedAt;

  /// 0–1 when the duration is known.
  double? get fraction => switch (duration) {
    final d? when d > Duration.zero =>
      (position.inMilliseconds / d.inMilliseconds).clamp(0.0, 1.0),
    _ => null,
  };

  Duration? get remaining => switch (duration) {
    final d? when d > position => d - position,
    final _? => Duration.zero,
    null => null,
  };

  /// Offers Resume (docs/03: past a minute, short of 95 %).
  bool get resumable =>
      !completed && position >= resumeAfter && !isComplete(position, duration);

  @override
  bool operator ==(Object other) =>
      other is WatchMark &&
      other.position == position &&
      other.duration == duration &&
      other.completed == completed &&
      other.updatedAt == updatedAt;

  @override
  int get hashCode => Object.hash(position, duration, completed, updatedAt);

  @override
  String toString() =>
      'WatchMark($position of $duration${completed ? ', watched' : ''})';
}

/// A movie or an episode, as history keys it: by source and remote key,
/// never by a row id a re-sync can renumber (docs/02).
@immutable
sealed class VodRef {
  const new(this.sourceId, this.remoteKey);

  final String sourceId;
  final String remoteKey;
}

final class MovieRef extends VodRef {
  const new(super.sourceId, super.remoteKey);

  @override
  bool operator ==(Object other) =>
      other is MovieRef &&
      other.sourceId == sourceId &&
      other.remoteKey == remoteKey;

  @override
  int get hashCode => Object.hash('movie', sourceId, remoteKey);
}

/// A file of the user's own in the library (Phase 8): no source, keyed
/// by its quick hash, so its history follows it across renames and moves
/// (docs/09).
final class LocalRef extends VodRef {
  const new(String quickHash) : super('', quickHash);

  String get quickHash => remoteKey;

  @override
  bool operator ==(Object other) =>
      other is LocalRef && other.remoteKey == remoteKey;

  @override
  int get hashCode => Object.hash('local', remoteKey);
}

final class EpisodeRef extends VodRef {
  const new(super.sourceId, super.remoteKey, {required this.seriesKey});

  /// The series' remote key: Continue watching groups by it.
  final String seriesKey;

  @override
  bool operator ==(Object other) =>
      other is EpisodeRef &&
      other.sourceId == sourceId &&
      other.remoteKey == remoteKey &&
      other.seriesKey == seriesKey;

  @override
  int get hashCode => Object.hash('episode', sourceId, remoteKey, seriesKey);
}

/// One card in Home's Continue watching (Phase 5 decision 5).
@immutable
sealed class ContinueItem {
  const new({required this.at});

  /// When it was last watched: the row is newest first.
  final DateTime at;

  String get sourceId;
}

/// A movie between a minute and 95 %.
final class ContinueMovie extends ContinueItem {
  const new({
    required this.movie,
    required this.mark,
    required super.at,
    this.backdropUrl,
  });

  final MovieItem movie;
  final WatchMark mark;

  /// From its details, when they were ever fetched; the card falls back
  /// to the poster.
  final String? backdropUrl;

  @override
  String get sourceId => movie.sourceId;

  @override
  bool operator ==(Object other) =>
      other is ContinueMovie &&
      other.movie == movie &&
      other.mark == mark &&
      other.at == at &&
      other.backdropUrl == backdropUrl;

  @override
  int get hashCode => Object.hash(movie, mark, at, backdropUrl);
}

/// A series' episode to continue: the one in progress ([mark] set), or
/// the one after the last watched ([mark] null: it starts at 0).
final class ContinueEpisode extends ContinueItem {
  const new({
    required this.series,
    required this.episode,
    required super.at,
    this.mark,
  });

  final SeriesItem series;
  final EpisodeItem episode;
  final WatchMark? mark;

  bool get upNext => mark == null;

  @override
  String get sourceId => series.sourceId;

  @override
  bool operator ==(Object other) =>
      other is ContinueEpisode &&
      other.series == series &&
      other.episode == episode &&
      other.mark == mark &&
      other.at == at;

  @override
  int get hashCode => Object.hash(series, episode, mark, at);
}

/// A video of the user's own from the library, between a minute and 95 %
/// (Phase 8).
final class ContinueLibraryFile extends ContinueItem {
  const new({required this.item, required this.mark, required super.at});

  final LibraryItem item;
  final WatchMark mark;

  @override
  String get sourceId => '';

  @override
  bool operator ==(Object other) =>
      other is ContinueLibraryFile &&
      other.item == item &&
      other.mark == mark &&
      other.at == at;

  @override
  int get hashCode => Object.hash(item, mark, at);
}

/// What was watched and where it stopped (docs/03: VOD positions every
/// 10 s and on stop). Nothing throws across this boundary.
abstract interface class WatchProgress {
  /// Saves where [ref] was left, watched once past 95 % of [duration]. A
  /// title taken out of Continue watching comes back by being watched.
  Future<Result<void>> save(
    VodRef ref, {
    required Duration position,
    Duration? duration,
  });

  /// Mark as watched, or forget it was ever played.
  Future<Result<void>> setWatched(VodRef ref, {required bool watched});

  Stream<WatchMark?> watch(VodRef ref);

  /// A series' episodes, by the episode's remote key.
  Stream<Map<String, WatchMark>> watchSeries(String sourceId, String seriesKey);

  /// Continue watching across every source, newest first (decision 5).
  Stream<List<ContinueItem>> continueWatching({int limit = 20});

  /// Takes [item] out of Continue watching; a series goes whole.
  Future<Result<void>> dismiss(ContinueItem item);
}
