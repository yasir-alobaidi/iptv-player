import 'dart:io';

import 'package:iptv_player/core/result.dart';
import 'package:iptv_player/data/db/app_database.dart';
import 'package:iptv_player/data/db/user_tables.dart';
import 'package:iptv_player/features/settings/domain/data_upkeep.dart';
import 'package:iptv_player/features/vod/domain/watch_progress.dart'
    show resumeAfter;

/// [DataUpkeep] on the app's database.
///
/// Every statement runs on the database's own isolate (`openAppDatabase`),
/// a compaction too: the UI isolate only waits for its answer (hard
/// rule 2). Other queries wait behind a compaction meanwhile, which is
/// why it runs only when nothing else is at work.
final class DbDataUpkeep implements DataUpkeep {
  new(this._db);

  final AppDatabase _db;

  /// The compaction under way, which a second one joins.
  Future<Result<Compacted>>? _compacting;

  @override
  Future<Result<TidyCounts>> prune(DateTime now) => Result.guard(() async {
    final history = await _db.watchHistoryDao.prune(
      channelsBefore: now.subtract(Upkeep.channels),
      finishedBefore: now.subtract(Upkeep.finished),
      startedBefore: now.subtract(Upkeep.started),
      countsFromMs: resumeAfter.inMilliseconds,
    );
    final syncRuns = await _db.syncRunsDao.prune(kept: Upkeep.runsKept);
    final guideImports = await _db.maintenanceDao.pruneGuideImports(
      kept: Upkeep.runsKept,
    );
    return (
      channels: history.channels,
      titles: history.titles,
      syncRuns: syncRuns,
      guideImports: guideImports,
    );
  });

  @override
  Stream<HistoryCounts> watchHistoryCounts() =>
      _db.watchHistoryDao.watchCounts().handleError(
        (Object error) => throw StorageFailure('history counts: $error'),
        test: (error) => error is! AppFailure,
      );

  @override
  Future<Result<int>> clearHistory(HistoryChoice what) => Result.guard(
    () => _db.watchHistoryDao.clear(switch (what) {
      HistoryChoice.channels => {UserItemType.live},
      HistoryChoice.titles => _titles,
      HistoryChoice.everything => {UserItemType.live, ..._titles},
    }),
  );

  static const Set<UserItemType> _titles = {
    UserItemType.movie,
    UserItemType.episode,
    UserItemType.local,
  };

  @override
  Future<Result<DatabaseRoom>> measure() => Result.guard(_measure);

  Future<DatabaseRoom> _measure() async {
    final pages = await _db.maintenanceDao.pages();
    final hasGuide = await _db.maintenanceDao.hasGuide();
    final pagesBytes = pages.pages * pages.pageSize;
    final freeBytes = pages.freePages * pages.pageSize;
    final file = pages.file;
    if (file == null) {
      return DatabaseRoom(
        bytes: pagesBytes,
        pagesBytes: pagesBytes,
        freeBytes: freeBytes,
        hasGuide: hasGuide,
      );
    }
    final main = await _length(file);
    final log = await _length('$file-wal');
    return DatabaseRoom(
      bytes: main + log,
      pagesBytes: pagesBytes,
      freeBytes: freeBytes,
      logBytes: log,
      hasGuide: hasGuide,
    );
  }

  /// A file's length; 0 when it isn't there (no log yet).
  static Future<int> _length(String path) async {
    try {
      return await File(path).length();
    } on FileSystemException {
      return 0;
    }
  }

  @override
  Future<Result<Compacted>> compact() =>
      _compacting ??= _rewrite(vacuum: true)
          .whenComplete(() => _compacting = null);

  @override
  Future<Result<Compacted>> trimLog() => _compacting ?? _rewrite(vacuum: false);

  Future<Result<Compacted>> _rewrite({required bool vacuum}) =>
      Result.guard(() async {
        final before = await _measure();
        if (vacuum) await _db.maintenanceDao.vacuum();
        // After a VACUUM in WAL mode the new file is all in the log.
        await _db.maintenanceDao.truncateLog();
        final after = await _measure();
        return (before: before.bytes, after: after.bytes);
      });
}
