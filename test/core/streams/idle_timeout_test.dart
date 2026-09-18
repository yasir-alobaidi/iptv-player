import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:iptv_player/core/streams/idle_timeout.dart';

void main() {
  const idle = Duration(milliseconds: 200);

  test('a stream that keeps talking is passed through whole', () async {
    final source = Stream<int>.periodic(
      const Duration(milliseconds: 20),
      (i) => i,
    ).take(20);

    expect(
      await source.idleTimeout(idle).toList(),
      List.generate(20, (i) => i),
    );
  });

  test('a stream that goes quiet ends with a TimeoutException', () async {
    final source = StreamController<int>();
    addTearDown(source.close);
    final events = <Object>[];

    final done = Completer<void>();
    source.stream
        .idleTimeout(idle)
        .listen(events.add, onError: events.add, onDone: done.complete);
    source.add(1);

    await done.future.timeout(const Duration(seconds: 2));
    expect(events.first, 1);
    expect(events.last, isA<TimeoutException>());
  });

  test('time the listener spends paused does not count', () async {
    final source = StreamController<int>();
    addTearDown(source.close);
    final events = <Object>[];

    final subscription =
        source.stream.idleTimeout(idle).listen(events.add, onError: events.add)
          ..pause();
    await Future<void>.delayed(idle * 3);
    subscription.resume();
    source.add(1);
    await Future<void>.delayed(const Duration(milliseconds: 50));
    await subscription.cancel();

    expect(events, [1]);
  });

  test('cancelling stops the watchdog and the source', () async {
    var cancelled = false;
    final source = StreamController<int>(onCancel: () => cancelled = true);

    final subscription = source.stream.idleTimeout(idle).listen((_) {});
    await subscription.cancel();

    expect(cancelled, isTrue);
  });
}
