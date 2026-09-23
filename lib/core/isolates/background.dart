import 'dart:async';
import 'dart:isolate';

import 'package:iptv_player/core/result.dart';

/// Runs [task] in a new isolate and returns its value, or a failure when it
/// throws, exceeds [timeout] (the isolate is killed), or can't send its
/// result back. Never throws.
///
/// [task] and its result must be sendable between isolates, as with
/// `Isolate.run`.
Future<Result<R>> runInBackground<R>(
  FutureOr<R> Function() task, {
  required Duration timeout,
  String debugName = 'background',
}) => startBackgroundJob<Never, R>(
  (_) => task(),
  timeout: timeout,
  debugName: debugName,
).result;

/// Starts long work (sync, parsing, bulk writes) in a new isolate. [task]
/// reports progress through its callback; the job can be cancelled, which
/// kills the isolate.
///
/// Work that writes to the database uses [startGuardedJob] instead: a kill
/// must never land inside a transaction.
BackgroundJob<P, R> startBackgroundJob<P, R>(
  FutureOr<R> Function(void Function(P progress) report) task, {
  Duration? timeout,
  String debugName = 'background-job',
}) {
  final job = BackgroundJob<P, R>._(debugName, null);
  unawaited(job._start((report, _) => task(report), timeout, guarded: false));
  return job;
}

/// Starts work like [startBackgroundJob], but stops it without ever
/// killing it inside the work [JobCancellation.enter] and
/// [JobCancellation.leave] mark — a database transaction.
///
/// Cancel and the timeout first ask the isolate to stop. It answers as
/// soon as nothing marked is running — at once when it is waiting on the
/// network, or when the batch it is writing commits — and is killed then.
/// Once asked, it starts nothing new that is marked. [cancelGrace] is the
/// last resort: a job that has not answered by then is killed anyway.
///
/// Why not just kill it: drift writes a batch as a transaction the client
/// opens and commits, one request at a time, and its database isolate
/// never rolls back a transaction whose client died. An isolate killed in
/// between leaves that transaction open, and every other query in the app
/// waits behind it for good (ADR-011 step 3).
BackgroundJob<P, R> startGuardedJob<P, R>(
  FutureOr<R> Function(
    void Function(P progress) report,
    JobCancellation cancellation,
  )
  task, {
  Duration? timeout,
  Duration cancelGrace = const Duration(seconds: 30),
  String debugName = 'background-job',
}) {
  final job = BackgroundJob<P, R>._(debugName, cancelGrace);
  unawaited(
    job._start(
      (report, cancel) => task(report, cancel!),
      timeout,
      guarded: true,
    ),
  );
  return job;
}

/// A guarded job's side of being stopped (see [startGuardedJob]): it marks
/// the work that must not be cut in half, and learns that it has been
/// asked to stop.
final class JobCancellation {
  /// The callback, when there is one, is told once that the job has been
  /// asked to stop and nothing marked is running. A cancellation made
  /// directly (a guarded task run in the calling isolate, as tests do)
  /// needs none.
  new([this._onKillable]);

  final void Function()? _onKillable;
  var _requested = false;
  var _depth = 0;
  var _answered = false;

  bool get isRequested => _requested;

  /// Starts work that must not be cut in half. Throws a
  /// [CancelledFailure] once the job has been asked to stop, so nothing
  /// new begins.
  void enter() {
    if (_requested) throw CancelledFailure('stopping');
    _depth++;
  }

  /// Ends the work the matching [enter] started.
  void leave() {
    if (_depth > 0) _depth--;
    _answerIfIdle();
  }

  /// Asks the job to stop.
  void request() {
    _requested = true;
    _answerIfIdle();
  }

  void _answerIfIdle() {
    if (!_requested || _depth > 0 || _answered) return;
    _answered = true;
    _onKillable?.call();
  }
}

final class BackgroundJob<P, R> {
  new _(this.debugName, this._cancelGrace);

  final String debugName;

  /// Null: stopping kills at once. Otherwise the job is guarded
  /// ([startGuardedJob]) and this is how long it may take to answer.
  final Duration? _cancelGrace;

  final _progress = StreamController<P>.broadcast();
  final _result = Completer<Result<R>>();
  final _port = RawReceivePort();
  Isolate? _isolate;
  Timer? _timeoutTimer;

  /// A guarded job's control port, once its isolate has sent it.
  SendPort? _control;

  /// What the job finishes with once a guarded one answers: set when it
  /// is asked to stop.
  AppFailure? _stopping;
  Timer? _graceTimer;

  /// Progress values in the order the task reported them. Closes when the
  /// job finishes.
  Stream<P> get progress => _progress.stream;

  /// Completes once, with the value or a failure.
  Future<Result<R>> get result => _result.future;

  bool get isFinished => _result.isCompleted;

  /// Stops the job; [result] completes with a [CancelledFailure]. A guarded
  /// job is stopped the careful way ([startGuardedJob]).
  void cancel() => _stop(CancelledFailure('$debugName cancelled'));

  void _stop(AppFailure failure) {
    if (_result.isCompleted || _stopping != null) return;
    final grace = _cancelGrace;
    if (grace == null) {
      _finish(Err(failure));
      return;
    }
    _stopping = failure;
    _graceTimer = Timer(grace, () => _finish(Err(failure)));
    // Before its control port arrives, the isolate may still be starting,
    // or may already be at work with the port on its way: ask as soon as
    // it is here rather than guess.
    _control?.send(const _StopRequest());
  }

  Future<void> _start(
    FutureOr<R> Function(
      void Function(P progress) report,
      JobCancellation? cancellation,
    )
    task,
    Duration? timeout, {
    required bool guarded,
  }) async {
    _port.handler = _onMessage;
    if (timeout != null) {
      _timeoutTimer = Timer(timeout, () {
        _stop(
          TimeoutFailure('$debugName exceeded ${timeout.inMilliseconds} ms'),
        );
      });
    }
    try {
      final isolate = await Isolate.spawn(
        _jobMain<P, R>,
        _JobStart<P, R>(task, _port.sendPort, debugName, guarded: guarded),
        onExit: _port.sendPort,
        onError: _port.sendPort,
        debugName: debugName,
      );
      if (_result.isCompleted) {
        isolate.kill(priority: Isolate.immediate);
      } else {
        _isolate = isolate;
      }
    } on Object catch (error) {
      _finish(Err(AppFailure.fromError(error)));
    }
  }

  void _onMessage(Object? message) {
    final stopping = _stopping;
    switch (message) {
      case _Control(:final port):
        _control = port;
        if (stopping != null) port.send(const _StopRequest());
      case _Killable():
        if (stopping != null) _finish(Err(stopping));
      case _Progress(:final value):
        if (!_result.isCompleted) _progress.add(value as P);
      case _Done(:final value):
        // Asked to stop, the job ends as stopped whatever it managed.
        _finish(stopping != null ? Err(stopping) : Ok(value as R));
      case _Failed(:final failure):
        _finish(Err(stopping ?? failure));
      case [final Object? error, _]:
        // Uncaught error inside the isolate (onError sends [error, stack]).
        _finish(Err(stopping ?? UnexpectedFailure('$debugName: $error')));
      case null:
        // onExit without a result.
        _finish(
          Err(
            stopping ?? UnexpectedFailure('$debugName exited without a result'),
          ),
        );
    }
  }

  void _finish(Result<R> result) {
    if (_result.isCompleted) return;
    _timeoutTimer?.cancel();
    _graceTimer?.cancel();
    _isolate?.kill(priority: Isolate.immediate);
    _port.close();
    unawaited(_progress.close());
    _result.complete(result);
  }
}

final class _JobStart<P, R> {
  const new(this.task, this.port, this.debugName, {required this.guarded});

  final FutureOr<R> Function(
    void Function(P progress) report,
    JobCancellation? cancellation,
  )
  task;
  final SendPort port;
  final String debugName;
  final bool guarded;
}

final class _Progress {
  const new(this.value);

  final Object? value;
}

final class _Done {
  const new(this.value);

  final Object? value;
}

final class _Failed {
  const new(this.failure);

  final AppFailure failure;
}

/// A guarded job's port for [_StopRequest], sent before its task starts.
final class _Control {
  const new(this.port);

  final SendPort port;
}

final class _StopRequest {
  const new();
}

/// A guarded job asked to stop has nothing marked running: kill it.
final class _Killable {
  const new();
}

Future<void> _jobMain<P, R>(_JobStart<P, R> start) async {
  final port = start.port;
  RawReceivePort? control;
  JobCancellation? cancellation;
  if (start.guarded) {
    final cancel = cancellation = JobCancellation(
      () => port.send(const _Killable()),
    );
    control = RawReceivePort((Object? message) {
      if (message is _StopRequest) cancel.request();
    }, '${start.debugName}-control');
    port.send(_Control(control.sendPort));
  }
  final R value;
  try {
    value = await start.task(
      (progress) => port.send(_Progress(progress)),
      cancellation,
    );
  } on Object catch (error) {
    control?.close();
    port.send(
      _Failed(error is AppFailure ? error : AppFailure.fromError(error)),
    );
    return;
  }
  control?.close();
  try {
    Isolate.exit(port, _Done(value));
  } on Object catch (error) {
    port.send(
      _Failed(
        UnexpectedFailure('${start.debugName} result not sendable: $error'),
      ),
    );
  }
}
