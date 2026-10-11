import 'package:flutter/foundation.dart';
import 'package:iptv_player/features/vod/domain/titles.dart';
import 'package:iptv_player/features/vod/domain/watch_progress.dart';

/// What a series page's primary action plays (canvas: "Continue S2 · E4").
enum NextUpKind {
  /// Nothing watched yet: the first episode.
  start,

  /// An episode in progress, from where it was left.
  resume,

  /// The one after the last finished.
  next,

  /// Every episode watched: the first again, from its start.
  again,
}

@immutable
final class NextUp {
  const new(this.kind, this.episode, {this.from});

  final NextUpKind kind;
  final EpisodeItem episode;

  /// Where [NextUpKind.resume] starts; null for the others.
  final Duration? from;
}

/// The episode to continue, by the rule Continue watching uses (Phase 5
/// decision 5): the newest episode that counts — past a minute, or
/// finished — is resumed when it is in progress, or its next is played
/// when it was finished; with none, the first; after the last, the first
/// again. Null when the series has no episodes.
NextUp? nextUpFor(SeriesDetails details, Map<String, WatchMark> marks) {
  final next = nextUpAmong([
    for (final season in details.seasons) ...season.episodes,
  ], (episode) => marks[episode.remoteKey]);
  return next == null ? null : NextUp(next.kind, next.episode, from: next.from);
}

/// The rule itself, over any show's [episodes] in their order — a
/// provider's, or the files of a show in the library (sketch B).
({NextUpKind kind, T episode, Duration? from})? nextUpAmong<T>(
  List<T> episodes,
  WatchMark? Function(T episode) markOf,
) {
  if (episodes.isEmpty) return null;
  int? newest;
  WatchMark? newestMark;
  for (final (i, episode) in episodes.indexed) {
    final mark = markOf(episode);
    if (mark == null || !(mark.completed || mark.position >= resumeAfter)) {
      continue;
    }
    if (newestMark == null || mark.updatedAt.isAfter(newestMark.updatedAt)) {
      newest = i;
      newestMark = mark;
    }
  }
  if (newest == null || newestMark == null) {
    return (kind: NextUpKind.start, episode: episodes.first, from: null);
  }
  if (!newestMark.completed && newestMark.resumable) {
    return (
      kind: NextUpKind.resume,
      episode: episodes[newest],
      from: newestMark.position,
    );
  }
  if (newest + 1 < episodes.length) {
    return (kind: NextUpKind.next, episode: episodes[newest + 1], from: null);
  }
  return (kind: NextUpKind.again, episode: episodes.first, from: null);
}
