import 'package:flutter/widgets.dart';
import 'package:iptv_player/core/text/format.dart';
import 'package:iptv_player/design/components.dart';
import 'package:iptv_player/features/sources/domain/sync.dart';
import 'package:iptv_player/features/sources/presentation/wait_tips.dart';

/// What a screen waiting on a sync is waiting for: Live TV its channels,
/// Movies and Series theirs, Home and Search everything.
enum SyncWaitFor { channels, movies, series, catalogue }

/// How far the sync has come, said for a screen waiting for [waitFor]:
/// "12,340 of 20,000 channels", "Channels first · 12,340 so far" while
/// Movies waits, "Downloading the movie list" until the list is in.
String syncWaitDetail(SyncProgress progress, SyncWaitFor waitFor) {
  final total = progress.stageTotal;

  String counted(int done, String one, String many) {
    if (total != null) {
      return '${formatCount(done)} of ${formatCount(total)} $many';
    }
    if (done == 0) return 'Downloading the $one list';
    return '${formatCount(done)} ${done == 1 ? one : many} so far';
  }

  String stage(SyncWaitFor kind, int done, String one, String many) {
    // Another list comes before the one this screen waits for: say so,
    // or the wait looks stuck.
    if (waitFor != SyncWaitFor.catalogue && waitFor.index > kind.index) {
      final first = '${many[0].toUpperCase()}${many.substring(1)} first';
      return done == 0 ? first : '$first · ${formatCount(done)} so far';
    }
    return counted(done, one, many);
  }

  return switch (progress.stage) {
    SyncStage.account => 'Signing in to your provider',
    SyncStage.categories => 'Getting the categories',
    SyncStage.live => stage(
      SyncWaitFor.channels,
      progress.channels,
      'channel',
      'channels',
    ),
    SyncStage.movies => stage(
      SyncWaitFor.movies,
      progress.movies,
      'movie',
      'movies',
    ),
    SyncStage.series => stage(
      SyncWaitFor.series,
      progress.series,
      'series',
      'series',
    ),
    SyncStage.playlist => _playlist(progress, waitFor),
    SyncStage.finishing => 'Almost done',
  };
}

/// A playlist is one stage: its channels, movies and series arrive mixed,
/// and its length is only known at its end.
String _playlist(SyncProgress progress, SyncWaitFor waitFor) {
  String? part(int count, String one, String many) =>
      count == 0 ? null : '${formatCount(count)} ${count == 1 ? one : many}';
  final parts = [
    if (waitFor case SyncWaitFor.channels || SyncWaitFor.catalogue)
      part(progress.channels, 'channel', 'channels'),
    if (waitFor case SyncWaitFor.movies || SyncWaitFor.catalogue)
      part(progress.movies, 'movie', 'movies'),
    if (waitFor case SyncWaitFor.series || SyncWaitFor.catalogue)
      part(progress.series, 'series', 'series'),
  ].nonNulls;
  return parts.isEmpty ? 'Reading the playlist' : '${parts.join(' · ')} so far';
}

/// How much of what the screen waits for is in, 0..1; null while that
/// can't be said (the list still downloading, or another list first).
double? syncWaitFraction(SyncProgress progress, SyncWaitFor waitFor) {
  final total = progress.stageTotal;
  if (total == null) return null;
  final (kind, done) = switch (progress.stage) {
    SyncStage.live => (SyncWaitFor.channels, progress.channels),
    SyncStage.movies => (SyncWaitFor.movies, progress.movies),
    SyncStage.series => (SyncWaitFor.series, progress.series),
    _ => (null, 0),
  };
  if (kind == null) return null;
  if (waitFor != SyncWaitFor.catalogue && waitFor.index > kind.index) {
    return null;
  }
  return total == 0 ? 1 : (done / total).clamp(0, 1).toDouble();
}

/// A screen that a running sync is still filling: the loading stage, with
/// how far the sync has come and tips for the wait.
class SyncWaitStage extends StatelessWidget {
  const new({
    required this.title,
    required this.progress,
    required this.waitFor,
    super.key,
  });

  /// "Getting your channels…"
  final String title;
  final SyncProgress progress;
  final SyncWaitFor waitFor;

  @override
  Widget build(BuildContext context) => LoadingStage(
    title: title,
    detail: syncWaitDetail(progress, waitFor),
    bar: true,
    progress: syncWaitFraction(progress, waitFor),
    // Each screen opens on its own tip: Live TV, Movies and Home can
    // all be waiting during one first sync.
    tips: waitTips(context, from: waitFor.index * 2),
  );
}
