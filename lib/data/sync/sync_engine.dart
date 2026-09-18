import 'dart:async';
import 'dart:convert';

import 'package:drift/isolate.dart';
import 'package:iptv_player/core/isolates/background.dart';
import 'package:iptv_player/core/logging/app_log.dart';
import 'package:iptv_player/core/result.dart';
import 'package:iptv_player/data/db/app_database.dart';
import 'package:iptv_player/data/db/catalogue_tables.dart';
import 'package:iptv_player/data/sync/sync_work.dart';
import 'package:iptv_player/features/sources/domain/source.dart';
import 'package:iptv_player/features/sources/domain/sync.dart';

/// [SyncService] over the app database and a background isolate per run.
///
/// This side (the UI isolate) only does what is small and must not be
/// interrupted: it records the run, reads the credentials (the keyring's
/// plugin answers on this isolate only), hands everything to the sync
/// isolate, relays its progress, and finishes the run — sweep, outcome,
/// `last_synced_at` — in one transaction. The isolate does the fetching,
/// parsing and upserting, and is simply killed on cancel or timeout
/// (`runSyncWork` never holds a transaction open, so killing it is safe).
final class SyncEngine implements SyncService {
  new({
    required AppDatabase database,
    required this._sources,
    required this._log,
    DateTime Function()? clock,
    this.timeout = const Duration(minutes: 20),
    this.batchSize = 5000,
  }) : _db = database,
       _clock = clock ?? _utcNow;

  final AppDatabase _db;
  final SourceRepository _sources;
  final AppLog _log;
  final DateTime Function() _clock;

  /// A run still going after this is killed and fails with a
  /// `TimeoutFailure`. Stalls are caught far sooner by the clients' idle
  /// watchdogs; this is the backstop.
  final Duration timeout;

  final int batchSize;

  static const _tag = 'sync';

  final _running = <String, _Run>{};
  final _removing = <String>{};
  final _status = <String, SyncStatus>{};
  final _changes = StreamController<(String, SyncStatus)>.broadcast();
  var _pruned = false;
  var _disposed = false;

  @override
  SyncStatus statusOf(String sourceId) => _status[sourceId] ?? const SyncIdle();

  @override
  Stream<SyncStatus> watch(String sourceId) {
    // The current status first, then changes, with nothing lost between
    // the two.
    StreamSubscription<(String, SyncStatus)>? changes;
    late final StreamController<SyncStatus> controller;
    controller = StreamController<SyncStatus>(
      onListen: () {
        controller.add(statusOf(sourceId));
        changes = _changes.stream
            .where((change) => change.$1 == sourceId)
            .listen((change) => controller.add(change.$2));
      },
      onCancel: () => changes?.cancel(),
    );
    return controller.stream;
  }

  @override
  Future<Result<SyncReport>> sync(String sourceId) {
    if (_disposed) {
      return Future.value(Err(CancelledFailure('the app is closing')));
    }
    if (_removing.contains(sourceId)) {
      return Future.value(Err(NotFoundFailure('source $sourceId')));
    }
    final running = _running[sourceId];
    if (running != null) return running.result.future;

    final run = _running[sourceId] = _Run();
    unawaited(
      _sync(sourceId, run)
          .catchError(
            // _sync guards every step; this is the last line of defence.
            (Object error) => Err<SyncReport>(AppFailure.fromError(error)),
          )
          .then((result) {
            _running.remove(sourceId);
            _set(sourceId, switch (result) {
              Ok(:final value) => SyncSucceeded(value),
              Err(failure: CancelledFailure()) => const SyncCancelled(),
              Err(:final failure) => SyncFailed(failure),
            });
            run.result.complete(result);
          }),
    );
    return run.result.future;
  }

  @override
  Future<void> cancel(String sourceId) async {
    final run = _running[sourceId];
    if (run == null) return;
    run.cancelled = true;
    run.job?.cancel();
    await run.result.future;
  }

  @override
  Future<Result<void>> removeSource(String sourceId) async {
    _removing.add(sourceId);
    try {
      await cancel(sourceId);
      final removed = await _sources.remove(sourceId);
      if (removed.isOk) {
        _status.remove(sourceId);
        if (!_changes.isClosed) _changes.add((sourceId, const SyncIdle()));
      }
      return removed;
    } finally {
      _removing.remove(sourceId);
    }
  }

  @override
  Future<void> startUp() async {
    final now = _clock();
    try {
      final interrupted = await _db.syncRunsDao.failInterrupted(now);
      if (interrupted > 0) {
        _log.warning(_tag, '$interrupted sync run(s) were interrupted');
      }
      for (final source in await _db.sourcesDao.all()) {
        if (_disposed) return;
        final last = source.lastSyncedAt;
        final stale =
            last == null ||
            now.difference(last) >= Duration(hours: source.refreshHours);
        // One after another: a launch shouldn't hit every provider and
        // the disk at once.
        if (stale) await sync(source.id);
      }
    } on Object catch (error, stackTrace) {
      _log.error(
        _tag,
        'Launch sync check failed',
        error: error,
        stackTrace: stackTrace,
      );
    }
  }

  /// Cancels every run; for when the app closes.
  Future<void> dispose() async {
    _disposed = true;
    await Future.wait([for (final id in _running.keys.toList()) cancel(id)]);
    await _changes.close();
  }

  Future<Result<SyncReport>> _sync(String sourceId, _Run run) async {
    final clock = Stopwatch()..start();
    final SourceRow? source;
    try {
      source = await _db.sourcesDao.byId(sourceId);
    } on Object catch (error) {
      return Err(StorageFailure('read source: $error'));
    }
    if (source == null) return Err(NotFoundFailure('source $sourceId'));

    final initial = SyncProgress(
      stage: source.type == SourceType.xtream
          ? SyncStage.account
          : SyncStage.playlist,
    );
    _set(sourceId, SyncRunning(initial));

    final int runId;
    try {
      runId = await _db.syncRunsDao.start(sourceId, _clock());
    } on Object catch (error) {
      return Err(StorageFailure('start sync run: $error'));
    }
    _log.info(_tag, 'Sync $sourceId started (run $runId, ${source.type.name})');

    final outcome = await _work(source, runId, run);
    final finished = switch (outcome) {
      Ok(:final value) => await _succeed(source, runId, value, clock),
      Err(:final failure) => Err<SyncReport>(failure),
    };
    if (finished case Err(:final failure)) {
      await _fail(sourceId, runId, failure, clock.elapsed);
    }
    return finished;
  }

  /// Credentials, then the isolate. Every failure comes back as a result.
  Future<Result<SyncWorkResult>> _work(
    SourceRow source,
    int runId,
    _Run run,
  ) async {
    final credentials = await _sources.credentialsFor(source.id);
    final SourceCredentials secrets;
    switch (credentials) {
      case Ok(:final value):
        secrets = value;
      case Err(:final failure):
        return Err(failure);
    }
    if (source.credentialRef != null) _pruneOnce();
    if (run.cancelled) return Err(CancelledFailure('sync ${source.id}'));

    final job = startSyncJob(
      SyncWork(
        sourceId: source.id,
        type: source.type,
        runId: runId,
        connection: await _db.serializableConnection(),
        url: secrets.url,
        username: secrets.username,
        password: secrets.password,
        userAgent: source.userAgent,
        batchSize: batchSize,
      ),
      timeout: timeout,
    );
    run.job = job;
    // A cancel that landed while the connection was being set up.
    if (run.cancelled) job.cancel();
    final progress = job.progress.listen(
      (event) => _set(source.id, SyncRunning(event)),
    );
    final result = await job.result;
    await progress.cancel();
    return switch (result) {
      Ok(:final value) => value,
      Err(:final failure) => Err(failure),
    };
  }

  /// Sweeps what the run didn't see and records the success, all or
  /// nothing: a crash here leaves the run `running` (failed as
  /// interrupted on the next launch) and the catalogue as the upserts
  /// left it, never half-swept.
  Future<Result<SyncReport>> _succeed(
    SourceRow source,
    int runId,
    SyncWorkResult work,
    Stopwatch clock,
  ) async {
    final id = source.id;
    final current = statusOf(id);
    if (current is SyncRunning) {
      _set(
        id,
        SyncRunning(current.progress.copyWith(stage: SyncStage.finishing)),
      );
    }
    final now = _clock();
    final SyncReport report;
    final Set<CatalogueKind> confirmedEmpty;
    try {
      confirmedEmpty = await _confirmedEmpty(id, runId, work.emptyLists);
      report = await _db.transaction(() async {
        var removed = 0;
        final items = {...work.sweepItems, ...confirmedEmpty};
        if (items.contains(CatalogueKind.live)) {
          removed += await _db.channelsDao.sweep(id, runId);
        }
        if (items.contains(CatalogueKind.movie)) {
          removed += await _db.moviesDao.sweep(id, runId);
        }
        if (work.sweepEpisodes) {
          removed += await _db.seriesDao.sweepEpisodes(id, runId);
        }
        if (items.contains(CatalogueKind.series)) {
          removed += await _db.seriesDao.sweep(id, runId);
        }
        final categories = {...work.sweepCategories, ...confirmedEmpty};
        if (categories.isNotEmpty) {
          removed += await _db.categoriesDao.sweep(
            id,
            runId,
            kinds: categories,
          );
        }
        final report = work.report.copyWith(
          removed: removed,
          duration: clock.elapsed,
        );
        await _db.syncRunsDao.finish(
          runId,
          outcome: SyncOutcome.succeeded,
          at: now,
          countsJson: _countsJson(report, empty: work.emptyLists),
        );
        await _db.sourcesDao.markSynced(id, now);
        return report;
      });
    } on Object catch (error) {
      return Err(StorageFailure('finish sync: $error'));
    }

    for (final warning in work.warnings) {
      _log.warning(_tag, 'Sync $id: $warning');
    }
    for (final kind in work.emptyLists) {
      _log.warning(
        _tag,
        confirmedEmpty.contains(kind)
            ? 'Sync $id: the ${kind.name} list came back empty twice in a '
                  'row; removed it'
            : 'Sync $id: the ${kind.name} list came back empty; kept the '
                  'last one',
      );
    }
    if (source.type != SourceType.xtream) {
      final saved = await _sources.setAdvertisedEpgUrls(id, work.epgUrls);
      if (saved case Err(:final failure)) {
        // The catalogue is in; only the guide's URL waits for next time.
        _log.warning(
          _tag,
          'Sync $id: could not keep the playlist EPG URLs (${failure.code})',
        );
      }
    }
    _log.info(
      _tag,
      'Sync $id succeeded in ${report.duration.inMilliseconds} ms: '
      '${report.categories} categories, ${report.channels} channels, '
      '${report.movies} movies, ${report.series} series, '
      '${report.episodes} episodes; ${report.skipped} skipped, '
      '${report.removed} removed',
    );
    return Ok(report);
  }

  Future<void> _fail(
    String sourceId,
    int runId,
    AppFailure failure,
    Duration elapsed,
  ) async {
    final cancelled = failure is CancelledFailure;
    try {
      await _db.syncRunsDao.finish(
        runId,
        outcome: cancelled ? SyncOutcome.cancelled : SyncOutcome.failed,
        at: _clock(),
        failure: cancelled ? null : failure.code,
      );
    } on Object catch (error) {
      _log.error(_tag, 'Could not record the end of sync run $runId: $error');
    }
    // `failure` is already redacted (AppFailure does it on creation).
    if (cancelled) {
      _log.info(_tag, 'Sync $sourceId cancelled');
    } else {
      _log.warning(
        _tag,
        'Sync $sourceId failed after ${elapsed.inMilliseconds} ms: $failure',
      );
    }
  }

  /// Once a session, after the keyring has answered: see
  /// `SourceRepository.pruneOrphanedSecrets`.
  void _pruneOnce() {
    if (_pruned) return;
    _pruned = true;
    unawaited(
      _sources.pruneOrphanedSecrets().then((pruned) {
        if (pruned case Err(:final failure)) {
          _log.warning(_tag, 'Could not prune secrets (${failure.code})');
        }
      }),
    );
  }

  void _set(String sourceId, SyncStatus status) {
    _status[sourceId] = status;
    if (!_changes.isClosed) _changes.add((sourceId, status));
  }

  /// The lists in [empty] that the previous successful run found empty
  /// too. One empty list is likelier a panel's hiccup than a provider
  /// that dropped every movie, so it keeps the last one; two in a row
  /// are taken at their word (ADR-009).
  Future<Set<CatalogueKind>> _confirmedEmpty(
    String sourceId,
    int runId,
    Set<CatalogueKind> empty,
  ) async {
    if (empty.isEmpty) return const {};
    final previous = await _db.syncRunsDao.lastSucceeded(
      sourceId,
      before: runId,
    );
    final before = _emptyIn(previous?.countsJson);
    return {
      for (final kind in empty)
        if (before.contains(kind)) kind,
    };
  }

  static Set<CatalogueKind> _emptyIn(String? countsJson) {
    if (countsJson == null) return const {};
    try {
      if (jsonDecode(countsJson) case {'empty': final List<Object?> names}) {
        return {
          for (final kind in CatalogueKind.values)
            if (names.contains(kind.name)) kind,
        };
      }
    } on FormatException {
      // A run from before this field, or a damaged row: nothing confirmed.
    }
    return const {};
  }

  static String _countsJson(
    SyncReport report, {
    Set<CatalogueKind> empty = const {},
  }) => jsonEncode({
    'categories': report.categories,
    'channels': report.channels,
    'movies': report.movies,
    'series': report.series,
    'episodes': report.episodes,
    'skipped': report.skipped,
    'removed': report.removed,
    'duration_ms': report.duration.inMilliseconds,
    if (empty.isNotEmpty) 'empty': [for (final kind in empty) kind.name],
  });
}

final class _Run {
  final Completer<Result<SyncReport>> result = Completer();
  BackgroundJob<SyncProgress, Result<SyncWorkResult>>? job;
  bool cancelled = false;
}

DateTime _utcNow() => DateTime.now().toUtc();
