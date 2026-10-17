import 'package:iptv_player/core/logging/app_log.dart';
import 'package:iptv_player/core/result.dart';
import 'package:meta/meta.dart';

/// How long the tidy-up keeps things (ADR-031, the user's choice of
/// 2026-10-17). Favorites, sources, settings, hidden and renamed items,
/// guide matches, reminders, downloads and the library are never touched.
abstract final class Upkeep {
  /// A channel not watched since.
  static const channels = Duration(days: 90);

  /// A film or an episode watched to the end.
  static const finished = Duration(days: 120);

  /// A film or an episode started and never finished.
  static const started = Duration(days: 365);

  /// Run records of the catalogue's syncs and the guide's imports, a
  /// source.
  static const runsKept = 30;

  /// The least free room worth a compaction, and the least share of the
  /// file it must be: below that, rewriting the file costs more than the
  /// room is worth.
  static const int compactFrom = 8 * 1024 * 1024;
  static const double compactShare = 0.25;

  /// The share while a guide is in place. Each import stages the new
  /// guide beside the old one and drops the staging once swapped in: it
  /// leaves about a guide's worth of room free, which the next day's
  /// import takes again. That room is never more than the guide itself,
  /// so never half the file: a rewrite for it would be undone daily.
  /// Without a guide (switched off, cleared), nothing takes it again.
  static const double compactShareWithGuide = 0.5;
}

/// What Settings → Data's Clear watch history forgets.
enum HistoryChoice {
  /// Recently watched channels: Home's row, and what Last channel reads.
  channels,

  /// Continue watching and the watched marks of films, episodes and the
  /// user's own videos.
  titles,

  everything,
}

/// What was watched, as Settings → Data counts it: channels, and films,
/// episodes and videos of the user's own.
typedef HistoryCounts = ({int channels, int titles});

/// What one tidy-up took away.
typedef TidyCounts = ({
  int channels,
  int titles,
  int syncRuns,
  int guideImports,
});

/// A compaction's sizes: before it, and after.
typedef Compacted = ({int before, int after});

/// The database file as it stands.
@immutable
final class DatabaseRoom {
  const new({
    required this.bytes,
    required this.pagesBytes,
    required this.freeBytes,
    this.logBytes = 0,
    this.hasGuide = false,
  });

  /// What it takes on disk: the file and its write-ahead log.
  final int bytes;

  /// The database itself, as SQLite counts it: its pages, free ones too.
  final int pagesBytes;

  /// Pages nothing uses any more, which a compaction gives back.
  final int freeBytes;

  /// The write-ahead log beside the file, which a compaction empties.
  final int logBytes;

  /// An imported guide is in place: its next import takes back about a
  /// guide's worth of the free room ([Upkeep.compactShareWithGuide]).
  final bool hasGuide;

  /// A lot of free room, by both measures: worth rewriting the file.
  /// With a guide in place, more than its next import takes again.
  bool get worthCompacting =>
      freeBytes >= Upkeep.compactFrom &&
      freeBytes >=
          pagesBytes *
              (hasGuide ? Upkeep.compactShareWithGuide : Upkeep.compactShare);

  /// A log a big write left long: emptying it alone is quick.
  bool get worthTrimmingLog => logBytes >= Upkeep.compactFrom;

  @override
  bool operator ==(Object other) =>
      other is DatabaseRoom &&
      other.bytes == bytes &&
      other.pagesBytes == pagesBytes &&
      other.freeBytes == freeBytes &&
      other.logBytes == logBytes &&
      other.hasGuide == hasGuide;

  @override
  int get hashCode =>
      Object.hash(bytes, pagesBytes, freeBytes, logBytes, hasGuide);
}

/// What keeps a compaction from running now: it holds the database for
/// as long as it takes, so it never runs beside these.
enum UpkeepBlocker { playing, syncing, importing, downloading }

/// The tidy-up of the database (ADR-031): history and run records by age,
/// and the file's free room given back. Nothing throws across it.
abstract interface class DataUpkeep {
  /// Forgets what is older than [Upkeep]'s ages, as at [now].
  Future<Result<TidyCounts>> prune(DateTime now);

  /// What was watched, now and at every change.
  Stream<HistoryCounts> watchHistoryCounts();

  /// Forgets [what]; returns how many rows went. Home's rows follow at
  /// once.
  Future<Result<int>> clearHistory(HistoryChoice what);

  Future<Result<DatabaseRoom>> measure();

  /// Rewrites the file without its free room, then empties the log. The
  /// caller makes sure nothing else is at work ([UpkeepBlocker]); one
  /// asked for while another runs joins it.
  Future<Result<Compacted>> compact();

  /// Empties the log alone: quick, for when the file has little free room.
  Future<Result<Compacted>> trimLog();
}

/// Once a launch, after its syncs and guide imports (ADR-031): prunes,
/// then compacts the file when it has a lot of free room and nothing is
/// at work, or only empties a long log. Something at work leaves the
/// compaction to the next launch. Never throws: a failure is logged.
final class LaunchTidyUp {
  new({
    required this._upkeep,
    required this._blocker,
    required this._log,
    DateTime Function()? clock,
  }) : _clock = clock ?? DateTime.now;

  final DataUpkeep _upkeep;

  /// What is at work now, if anything.
  final Future<UpkeepBlocker?> Function() _blocker;
  final AppLog _log;
  final DateTime Function() _clock;

  static const _tag = 'upkeep';

  Future<void> run() async {
    try {
      await _prune();
      await _compact();
    } on Object catch (error, stackTrace) {
      _log.error(
        _tag,
        'The tidy-up failed',
        error: error,
        stackTrace: stackTrace,
      );
    }
  }

  Future<void> _prune() async {
    switch (await _upkeep.prune(_clock())) {
      case Ok(:final value):
        _log.info(
          _tag,
          'Pruned ${value.channels} channel(s) and ${value.titles} '
          'title(s) from the history, ${value.syncRuns} sync run(s), '
          '${value.guideImports} guide import(s)',
        );
      case Err(:final failure):
        _log.warning(_tag, 'Pruning failed (${failure.code})');
    }
  }

  Future<void> _compact() async {
    final DatabaseRoom room;
    switch (await _upkeep.measure()) {
      case Ok(:final value):
        room = value;
      case Err(:final failure):
        _log.warning(
          _tag,
          'The database could not be measured '
          '(${failure.code})',
        );
        return;
    }
    final full = room.worthCompacting;
    if (!full && !room.worthTrimmingLog) {
      _log.debug(
        _tag,
        'Nothing to compact: ${_mb(room.freeBytes)} free, '
        'log ${_mb(room.logBytes)}',
      );
      return;
    }
    if (await _blocker() case final blocker?) {
      _log.info(
        _tag,
        'Compaction left to the next launch: ${blocker.name} '
        '(${_mb(room.freeBytes)} free of ${_mb(room.bytes)})',
      );
      return;
    }
    final clock = Stopwatch()..start();
    switch (await (full ? _upkeep.compact() : _upkeep.trimLog())) {
      case Ok(:final value):
        _log.info(
          _tag,
          '${full ? 'Compacted' : 'Log emptied'} in '
          '${clock.elapsedMilliseconds} ms: ${_mb(value.before)} → '
          '${_mb(value.after)}',
        );
      case Err(:final failure):
        _log.warning(_tag, 'Compaction failed (${failure.code})');
    }
  }

  static String _mb(int bytes) =>
      '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
}
