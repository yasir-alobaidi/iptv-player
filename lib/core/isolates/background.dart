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
BackgroundJob<P, R> startBackgroundJob<P, R>(
  FutureOr<R> Function(void Function(P progress) report) task, {
  Duration? timeout,
  String debugName = 'background-job',
}) {
  final job = BackgroundJob<P, R>._(debugName);
  unawaited(job._start(task, timeout));
  return job;
}

final class BackgroundJob<P, R> {
  new _(this.debugName);

  final String debugName;
  final _progress = StreamController<P>.broadcast();
  final _result = Completer<Result<R>>();
  final _port = RawReceivePort();
  Isolate? _isolate;
  Timer? _timeoutTimer;

  /// Progress values in the order the task reported them. Closes when the
  /// job finishes.
  Stream<P> get progress => _progress.stream;

  /// Completes once, with the value or a failure.
  Future<Result<R>> get result => _result.future;

  bool get isFinished => _result.isCompleted;

  /// Stops the job; [result] completes with a [CancelledFailure].
  void cancel() => _finish(Err(CancelledFailure('$debugName cancelled')));

  Future<void> _start(
    FutureOr<R> Function(void Function(P progress) report) task,
    Duration? timeout,
  ) async {
    _port.handler = _onMessage;
    if (timeout != null) {
      _timeoutTimer = Timer(timeout, () {
        _finish(
          Err(
            TimeoutFailure('$debugName exceeded ${timeout.inMilliseconds} ms'),
          ),
        );
      });
    }
    try {
      final isolate = await Isolate.spawn(
        _jobMain<P, R>,
        _JobStart<P, R>(task, _port.sendPort, debugName),
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
    switch (message) {
      case _Progress(:final value):
        if (!_result.isCompleted) _progress.add(value as P);
      case _Done(:final value):
        _finish(Ok(value as R));
      case _Failed(:final failure):
        _finish(Err(failure));
      case [final Object? error, _]:
        // Uncaught error inside the isolate (onError sends [error, stack]).
        _finish(Err(UnexpectedFailure('$debugName: $error')));
      case null:
        // onExit without a result.
        _finish(Err(UnexpectedFailure('$debugName exited without a result')));
    }
  }

  void _finish(Result<R> result) {
    if (_result.isCompleted) return;
    _timeoutTimer?.cancel();
    _isolate?.kill(priority: Isolate.immediate);
    _port.close();
    unawaited(_progress.close());
    _result.complete(result);
  }
}

final class _JobStart<P, R> {
  const new(this.task, this.port, this.debugName);

  final FutureOr<R> Function(void Function(P progress) report) task;
  final SendPort port;
  final String debugName;
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

Future<void> _jobMain<P, R>(_JobStart<P, R> start) async {
  final port = start.port;
  final R value;
  try {
    value = await start.task((progress) => port.send(_Progress(progress)));
  } on Object catch (error) {
    port.send(_Failed(AppFailure.fromError(error)));
    return;
  }
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
