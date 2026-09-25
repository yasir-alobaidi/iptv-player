/// The Match… picker's ranking for a large guide, in an isolate that
/// lives as long as the guide is being matched against (hard rule 2).
///
/// The worker reads the source's guide channels itself, through its own
/// connection to the database, and prepares them once
/// (`prepareGuideChannels`). After that, a keystroke sends it the
/// channel's name, the query and a limit, and gets back at most that many
/// candidates: the guide itself never crosses to or from the app's
/// isolate, where copying 50,000 prepared channels took longer than
/// ranking them (ADR-011 step 5).
///
/// It is a plain isolate, killed rather than asked to stop. Only a
/// transaction makes a kill unsafe (see `openJobDatabase`), and the
/// worker never begins one: it runs plain reads, and closes its
/// connection as soon as the guide is read, before it prepares anything.
library;

import 'dart:async';
import 'dart:isolate';

import 'package:drift/drift.dart';
import 'package:drift/isolate.dart';
import 'package:iptv_player/core/result.dart';
import 'package:iptv_player/data/db/app_database.dart';
import 'package:iptv_player/features/guide/domain/epg.dart';
import 'package:iptv_player/features/guide/domain/guide_channel_ranking.dart';
import 'package:iptv_player/features/guide/domain/guide_matching.dart';

/// A worker isolate's entry point: [runGuideRankingWorker], or a test's
/// wrapper round it. Top level, as `Isolate.spawn` requires.
typedef GuideRankingWorkerMain = void Function(Object start);

/// One source's guide, read and prepared in its own isolate, answering
/// ranking queries until it is stopped, falls idle, or dies.
///
/// Nothing here throws at the caller except through [ready] and [rank],
/// whose errors are always [AppFailure]s.
final class GuideRankingWorker {
  /// Starts the isolate. [ready] completes once it has read and prepared
  /// the source's guide channels through `connection`.
  ///
  /// `onStopped` is told once, whatever stopped it: [stop], `idleAfter`
  /// with no query, a query unanswered after `queryTimeout`, a guide not
  /// ready after `startTimeout`, or the isolate dying.
  new({
    required DriftIsolate connection,
    required String sourceId,
    required this._idleAfter,
    required this._queryTimeout,
    required Duration startTimeout,
    this._onStopped,
    GuideRankingWorkerMain main = runGuideRankingWorker,
    int pageSize = 5000,
  }) {
    _inbox.handler = _receive;
    // Whoever awaits [ready] sees its failure; this keeps one nobody
    // awaited any more (a stop during the start) from being reported as
    // unhandled.
    _ready.future.ignore();
    _startTimer = Timer(
      startTimeout,
      () => _fail(
        TimeoutFailure(
          'guide ranking: the guide was not ready in '
          '${startTimeout.inSeconds} s',
        ),
      ),
    );
    unawaited(
      _spawn(
        main,
        _WorkerStart(_inbox.sendPort, connection, sourceId, pageSize),
      ),
    );
  }

  final Duration _idleAfter;
  final Duration _queryTimeout;
  final void Function()? _onStopped;

  final _inbox = RawReceivePort(null, 'guide-ranking');
  final _ready = Completer<void>();
  final _pending = <int, Completer<List<GuideChannelCandidate>>>{};
  late final Timer _startTimer;
  Timer? _idle;
  Isolate? _isolate;
  SendPort? _worker;
  var _nextQuery = 0;
  var _stopped = false;
  var _channels = 0;

  /// Completes once the guide is read and prepared; fails with an
  /// [AppFailure] when it could not be, or the worker stopped first.
  Future<void> get ready => _ready.future;

  bool get isStopped => _stopped;

  /// How many guide channels the worker holds, once [ready].
  int get channels => _channels;

  /// The isolate, once spawned and until stopped. For tests, which watch
  /// it exit.
  Isolate? get isolate => _stopped ? null : _isolate;

  /// The guide channels to offer for [channelName], as
  /// `rankGuideChannels` ranks them over the worker's guide. Throws an
  /// [AppFailure] when the worker is gone, dies meanwhile, or doesn't
  /// answer within the query timeout (it is then stopped).
  Future<List<GuideChannelCandidate>> rank({
    required String channelName,
    required String query,
    required int limit,
  }) async {
    await ready;
    final worker = _worker;
    if (_stopped || worker == null) {
      throw CancelledFailure('guide ranking: the worker stopped');
    }
    _idle?.cancel();
    _idle = null;
    final id = _nextQuery++;
    final answer = _pending[id] = Completer<List<GuideChannelCandidate>>();
    worker.send(_WorkerQuery(id, channelName, query, limit));
    return await answer.future.timeout(
      _queryTimeout,
      onTimeout: () {
        _pending.remove(id);
        final failure = TimeoutFailure(
          'guide ranking: no answer in ${_queryTimeout.inSeconds} s',
        );
        _fail(failure);
        throw failure;
      },
    );
  }

  /// Kills the worker. Queries still waiting fail with a
  /// `CancelledFailure`.
  void stop() => _fail(CancelledFailure('guide ranking: stopped'));

  Future<void> _spawn(GuideRankingWorkerMain main, _WorkerStart start) async {
    try {
      final isolate = await Isolate.spawn<Object>(
        main,
        start,
        onExit: _inbox.sendPort,
        onError: _inbox.sendPort,
        debugName: 'guide-ranking',
      );
      if (_stopped) {
        isolate.kill(priority: Isolate.immediate);
      } else {
        _isolate = isolate;
      }
    } on Object catch (error) {
      _fail(
        UnexpectedFailure(
          'guide ranking: the worker did not start (${error.runtimeType})',
        ),
      );
    }
  }

  void _receive(Object? message) {
    switch (message) {
      case _WorkerReady(:final inbox, :final channels):
        _worker = inbox;
        _channels = channels;
        _startTimer.cancel();
        if (!_ready.isCompleted) _ready.complete();
        _armIdle();
      case _WorkerAnswer(:final id, :final candidates, :final error):
        final answer = _pending.remove(id);
        if (answer != null) {
          if (candidates != null) {
            answer.complete(candidates);
          } else {
            answer.completeError(UnexpectedFailure('guide ranking: $error'));
          }
        }
        if (_pending.isEmpty) _armIdle();
      case _WorkerFailed(:final reason):
        _fail(StorageFailure('guide ranking: $reason'));
      case [final Object? error, _]:
        // An error nothing in the worker caught: errors are fatal, so its
        // exit follows.
        _fail(
          UnexpectedFailure('guide ranking: ${'$error'.split('\n').first}'),
        );
      case null:
        _fail(UnexpectedFailure('guide ranking: the worker exited'));
    }
  }

  void _armIdle() {
    _idle?.cancel();
    _idle = Timer(_idleAfter, stop);
  }

  void _fail(AppFailure failure) {
    if (_stopped) return;
    _stopped = true;
    _startTimer.cancel();
    _idle?.cancel();
    _isolate?.kill(priority: Isolate.immediate);
    _inbox.close();
    if (!_ready.isCompleted) _ready.completeError(failure);
    final waiting = _pending.values.toList();
    _pending.clear();
    for (final answer in waiting) {
      answer.completeError(failure);
    }
    _onStopped?.call();
  }
}

/// A worker's body: reads the guide, prepares it, says it is ready, then
/// answers queries until it is killed. [beforeRanking] is a test's hook,
/// called with each query's channel name before it is ranked.
Future<void> runGuideRankingWorker(
  Object message, {
  void Function(String channelName)? beforeRanking,
}) async {
  final start = message as _WorkerStart;
  final List<RankableGuideChannel> guide;
  try {
    guide = prepareGuideChannels(
      await _readGuide(start.connection, start.sourceId, start.pageSize),
    );
  } on Object catch (error) {
    // Only the first line: SQLite's next one quotes the statement.
    start.reply.send(_WorkerFailed('$error'.split('\n').first));
    return;
  }
  void answer(Object? message) {
    if (message is! _WorkerQuery) return;
    beforeRanking?.call(message.channelName);
    try {
      start.reply.send(
        _WorkerAnswer(
          message.id,
          rankGuideChannels(
            guide,
            channelName: message.channelName,
            query: message.query,
            limit: message.limit,
          ),
        ),
      );
    } on Object catch (error) {
      start.reply.send(
        _WorkerAnswer(message.id, null, '$error'.split('\n').first),
      );
    }
  }

  // Open until the isolate is killed: it keeps the worker alive.
  final inbox = RawReceivePort(answer, 'guide-ranking-queries');
  start.reply.send(_WorkerReady(inbox.sendPort, guide.length));
}

/// Every channel of [sourceId]'s live guide, a page at a time in row id
/// order (each page is one message out of the database isolate, which
/// other queries wait behind). Plain reads, no transaction; the
/// connection is closed before this returns.
Future<List<GuideChannel>> _readGuide(
  DriftIsolate connection,
  String sourceId,
  int pageSize,
) async {
  final size = pageSize < 1 ? 1 : pageSize;
  final db = AppDatabase(await connection.connect());
  try {
    final guide = <GuideChannel>[];
    int? after;
    while (true) {
      final rows = await db
          .customSelect(
            'SELECT id, xmltv_id, display_name, icon_url FROM epg_channels '
            'WHERE source_id = ?1${after == null ? '' : ' AND id > ?3'} '
            'ORDER BY id LIMIT ?2',
            variables: [
              Variable.withString(sourceId),
              Variable.withInt(size),
              if (after != null) Variable.withInt(after),
            ],
          )
          .get();
      for (final row in rows) {
        final id = row.readNullable<String>('xmltv_id');
        if (id == null) continue;
        guide.add(
          GuideChannel(
            xmltvId: id,
            displayName: row.readNullable<String>('display_name'),
            iconUrl: row.readNullable<String>('icon_url'),
          ),
        );
      }
      if (rows.length < size) return guide;
      after = rows.last.read<int>('id');
    }
  } finally {
    await db.close();
  }
}

// The messages. Plain values, so they cross isolates; none carries the
// guide.

final class _WorkerStart {
  const new(this.reply, this.connection, this.sourceId, this.pageSize);

  final SendPort reply;
  final DriftIsolate connection;
  final String sourceId;
  final int pageSize;
}

final class _WorkerReady {
  const new(this.inbox, this.channels);

  final SendPort inbox;
  final int channels;
}

final class _WorkerFailed {
  const new(this.reason);

  final String reason;
}

final class _WorkerQuery {
  const new(this.id, this.channelName, this.query, this.limit);

  final int id;
  final String channelName;
  final String query;
  final int limit;
}

final class _WorkerAnswer {
  const new(this.id, this.candidates, [this.error]);

  final int id;
  final List<GuideChannelCandidate>? candidates;
  final String? error;
}
