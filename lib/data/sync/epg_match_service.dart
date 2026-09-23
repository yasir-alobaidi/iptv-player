import 'dart:async';

import 'package:drift/isolate.dart';
import 'package:iptv_player/core/logging/app_log.dart';
import 'package:iptv_player/core/result.dart';
import 'package:iptv_player/data/db/app_database.dart';
import 'package:iptv_player/data/sync/epg_match_work.dart';
import 'package:iptv_player/features/guide/domain/epg_match_summary.dart';

/// One run of the match for a source, start to result. [stop] completes
/// when the run is to be cancelled. The service's own starts the guarded
/// job ([startEpgMatchJob]); tests pass one they control.
typedef EpgMatchRunner = Future<Result<EpgMatchSummary>> Function(
  String sourceId,
  Future<void> stop,
);

/// Keeps a source's `epg_matches` in step with its channels, its guide
/// and the user's mappings, by running the match job (`runEpgMatchWork`)
/// in a background isolate whenever one of them may have changed: after
/// an import's swap and after a sync.
///
/// One run per source at a time. Asking while one runs does not join it —
/// its inputs may have changed after it read them — but queues a single
/// follow-up run, which every call made meanwhile shares. So each caller
/// gets the result of a run that started after it asked, and a burst of
/// calls costs two runs, not one each.
final class EpgMatchService {
  new({
    required AppDatabase database,
    required this._log,
    this.timeout = const Duration(minutes: 2),
    this._runner,
  }) : _db = database;

  final AppDatabase _db;
  final AppLog _log;
  final EpgMatchRunner? _runner;

  /// A run still going after this is stopped and fails with a
  /// `TimeoutFailure`. A run reads and writes a few rows per channel, so
  /// even 50,000 channels take seconds; this is the backstop.
  final Duration timeout;

  static const _tag = 'epg';

  final _sources = <String, _Source>{};
  var _disposed = false;

  /// True while a run for [sourceId] is running or queued.
  bool isMatching(String sourceId) => _sources.containsKey(sourceId);

  /// Rematches [sourceId]'s channels against its guide and returns what
  /// the run attached. Never throws.
  Future<Result<EpgMatchSummary>> rematch(String sourceId) {
    if (_disposed) {
      return Future.value(Err(CancelledFailure('the app is closing')));
    }
    final source = _sources[sourceId];
    if (source != null) return (source.next ??= _Pass()).result.future;
    final pass = _Pass();
    _sources[sourceId] = _Source(pass);
    _start(sourceId, pass);
    return pass.result.future;
  }

  /// Stops every run, drops the follow-ups, and waits for the runs to
  /// end; for when the app closes.
  Future<void> dispose() async {
    _disposed = true;
    final running = <Future<void>>[];
    for (final source in _sources.values) {
      source.next?.result.complete(Err(CancelledFailure('the app is closing')));
      source.next = null;
      source.running.cancel();
      running.add(source.running.result.future);
    }
    await Future.wait(running);
  }

  void _start(String sourceId, _Pass pass) {
    unawaited(
      _run(sourceId, pass)
          .catchError(
            // _run guards every step; this is the last line of defence.
            (Object error) => Err<EpgMatchSummary>(AppFailure.fromError(error)),
          )
          .then((result) {
            pass.result.complete(result);
            final source = _sources[sourceId];
            final next = source?.next;
            if (source == null || next == null) {
              _sources.remove(sourceId);
              return;
            }
            source
              ..running = next
              ..next = null;
            _start(sourceId, next);
          }),
    );
  }

  Future<Result<EpgMatchSummary>> _run(String sourceId, _Pass pass) async {
    final clock = Stopwatch()..start();
    final result = await (_runner ?? _runJob)(sourceId, pass.stop.future);
    final elapsed = clock.elapsed.inMilliseconds;
    switch (result) {
      case Ok(:final value):
        _log.info(_tag, 'Guide match $sourceId in $elapsed ms: $value');
        if (value.skipped > 0) {
          _log.warning(
            _tag,
            'Guide match $sourceId: ${value.skipped} channels could not be '
            'read or matched, and have no guide',
          );
        }
      case Err(failure: CancelledFailure()):
        _log.info(_tag, 'Guide match $sourceId cancelled');
      case Err(:final failure):
        // The job's failures carry no statement and no value.
        _log.warning(
          _tag,
          'Guide match $sourceId failed after $elapsed ms: $failure',
        );
    }
    return result;
  }

  /// The real run: the guarded job over the app's database.
  Future<Result<EpgMatchSummary>> _runJob(
    String sourceId,
    Future<void> stop,
  ) async {
    final DriftIsolate connection;
    try {
      connection = await _db.serializableConnection();
    } on Object catch (error) {
      return Err(epgMatchFailure(error));
    }
    final job = startEpgMatchJob(
      EpgMatchWork(sourceId: sourceId, connection: connection),
      timeout: timeout,
    );
    // A stop asked for while the connection was being set up lands at
    // once: the future has already completed.
    unawaited(stop.then((_) => job.cancel()));
    return switch (await job.result) {
      Ok(:final value) => value,
      Err(:final failure) => Err(failure),
    };
  }
}

/// A source's run, and the one follow-up queued behind it.
final class _Source {
  new(this.running);

  _Pass running;
  _Pass? next;
}

/// One run: what its callers wait for, and how to stop it.
final class _Pass {
  final result = Completer<Result<EpgMatchSummary>>();
  final stop = Completer<void>();

  void cancel() {
    if (!stop.isCompleted) stop.complete();
  }
}
