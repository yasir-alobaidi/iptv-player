import 'dart:async';

/// Stops a stream that goes quiet.
extension IdleTimeout<T> on Stream<T> {
  /// This stream, ending with a [TimeoutException] when no event arrives
  /// for [idle] — between events, not in total, so a big download on a
  /// slow line is fine and a stalled one is not. Time spent paused by the
  /// listener doesn't count.
  ///
  /// Not `Stream.timeout`, and not dio's `receiveTimeout`: both replace a
  /// `Timer` on every event, which on a 50k-row body blocked the UI
  /// isolate for about a second (ADR-009). Here each event only stamps a
  /// stopwatch, and one periodic timer checks it.
  Stream<T> idleTimeout(Duration idle) {
    late final StreamController<T> controller;
    StreamSubscription<T>? subscription;
    Timer? watchdog;
    final clock = Stopwatch();
    var last = Duration.zero;
    final period = idle ~/ 4 < const Duration(milliseconds: 50)
        ? const Duration(milliseconds: 50)
        : idle ~/ 4;

    void watch() {
      watchdog?.cancel();
      last = clock.elapsed;
      watchdog = Timer.periodic(period, (timer) {
        if (clock.elapsed - last < idle) return;
        timer.cancel();
        unawaited(subscription?.cancel());
        controller.addError(TimeoutException('no data', idle));
        unawaited(controller.close());
      });
    }

    controller = StreamController<T>(
      onListen: () {
        clock.start();
        watch();
        subscription = listen(
          (event) {
            last = clock.elapsed;
            controller.add(event);
          },
          onError: (Object error, StackTrace stack) {
            last = clock.elapsed;
            controller.addError(error, stack);
          },
          onDone: () {
            watchdog?.cancel();
            unawaited(controller.close());
          },
        );
      },
      onPause: () {
        watchdog?.cancel();
        subscription?.pause();
      },
      onResume: () {
        subscription?.resume();
        watch();
      },
      onCancel: () {
        watchdog?.cancel();
        return subscription?.cancel();
      },
    );
    return controller.stream;
  }
}
