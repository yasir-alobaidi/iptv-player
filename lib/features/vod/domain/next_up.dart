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
  final episodes = [for (final season in details.seasons) ...season.episodes];
  if (episodes.isEmpty) return null;
  int? newest;
  for (final (i, episode) in episodes.indexed) {
    final mark = marks[episode.remoteKey];
    if (mark == null || !(mark.completed || mark.position >= resumeAfter)) {
      continue;
    }
    final best = newest == null ? null : marks[episodes[newest].remoteKey];
    if (best == null || mark.updatedAt.isAfter(best.updatedAt)) newest = i;
  }
  if (newest == null) return NextUp(NextUpKind.start, episodes.first);
  final episode = episodes[newest];
  final mark = marks[episode.remoteKey]!;
  if (!mark.completed && mark.resumable) {
    return NextUp(NextUpKind.resume, episode, from: mark.position);
  }
  if (newest + 1 < episodes.length) {
    return NextUp(NextUpKind.next, episodes[newest + 1]);
  }
  return NextUp(NextUpKind.again, episodes.first);
}
