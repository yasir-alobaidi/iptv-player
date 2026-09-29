import 'dart:async';

import 'package:drift/isolate.dart';
import 'package:iptv_player/core/logging/app_log.dart';
import 'package:iptv_player/core/result.dart';
import 'package:iptv_player/data/db/app_database.dart';
import 'package:iptv_player/data/sync/channel_name_work.dart';

/// One run of the fill, start to result. [stop] completes when the run is
/// to be cancelled. The service's own starts the guarded job
/// ([startChannelNameJob]); tests pass one they control.
typedef ChannelNameRunner = Future<Result<int>> Function(
  AppDatabase database,
  Future<void> stop,
);

/// Gives the channels of a catalogue synced before schema v7 their
/// cleaned names and badges, once, after the upgrade (ADR-013 step 1).
/// Sync writes both for every channel it touches, so after the first run
/// on an upgraded database there is nothing left to do, and [run] costs
/// one query.
///
/// Rows show the provider's name until the fill reaches them. It runs in
/// a guarded background isolate (`runChannelNameWork`), never on the UI
/// isolate (hard rule 2).
final class ChannelNameFill {
  new({
    required AppDatabase database,
    required this._log,
    this.timeout = const Duration(minutes: 5),
    this._runner,
  }) : _db = database;

  final AppDatabase _db;
  final AppLog _log;
  final ChannelNameRunner? _runner;

  /// A run still going after this is stopped. 50,000 names take seconds;
  /// this is the backstop.
  final Duration timeout;

  static const _tag = 'names';

  Future<Result<int>>? _running;
  Completer<void>? _stop;
  var _disposed = false;

  /// Fills what is missing and returns how many channels it named; 0,
  /// without starting anything, when every channel has its name. Calls
  /// made while a run is going share it. Never throws.
  Future<Result<int>> run() {
    if (_disposed) {
      return Future.value(Err(CancelledFailure('the app is closing')));
    }
    return _running ??= _run().whenComplete(() => _running = null);
  }

  /// Stops a run and waits for it; for when the app closes.
  Future<void> dispose() async {
    _disposed = true;
    final stop = _stop;
    if (stop != null && !stop.isCompleted) stop.complete();
    await _running;
  }

  Future<Result<int>> _run() async {
    try {
      final pending = await _db
          .customSelect(
            'SELECT EXISTS (SELECT 1 FROM channels WHERE clean_name IS NULL) '
            'AS pending',
          )
          .getSingle();
      if (!pending.read<bool>('pending')) return const Ok(0);
    } on Object catch (error) {
      final failure = channelNameFailure(error);
      _log.warning(_tag, 'Channel names: the check failed: $failure');
      return Err(failure);
    }
    final stop = _stop = Completer<void>();
    final clock = Stopwatch()..start();
    final result = await (_runner ?? _runJob)(_db, stop.future);
    final elapsed = clock.elapsed.inMilliseconds;
    switch (result) {
      case Ok(:final value):
        _log.info(_tag, 'Channel names: $value cleaned in $elapsed ms');
      case Err(failure: CancelledFailure()):
        _log.info(_tag, 'Channel names: stopped; the next launch goes on');
      case Err(:final failure):
        // The job's failures carry no statement and no value.
        _log.warning(_tag, 'Channel names: failed after $elapsed ms: $failure');
    }
    return result;
  }

  /// The real run: the guarded job over the app's database.
  Future<Result<int>> _runJob(AppDatabase database, Future<void> stop) async {
    final DriftIsolate connection;
    try {
      connection = await database.serializableConnection();
    } on Object catch (error) {
      return Err(channelNameFailure(error));
    }
    final job = startChannelNameJob(
      ChannelNameWork(connection: connection),
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
