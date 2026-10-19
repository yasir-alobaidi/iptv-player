import 'dart:async';

import 'package:fake_async/fake_async.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:iptv_player/core/logging/app_log.dart';
import 'package:iptv_player/core/logging/launch_mark.dart';
import 'package:iptv_player/core/logging/secret_registry.dart';
import 'package:logger/logger.dart';

void main() {
  late MemoryOutput memory;
  late AppLog log;

  setUp(() {
    memory = MemoryOutput();
    log = AppLog(output: memory, secrets: SecretRegistry());
  });

  tearDown(() => log.close());

  List<String> lines() => [for (final e in memory.buffer) ...e.lines];

  test("Home's first frame is logged once, with the time since main()", () {
    LaunchMark(log, Stopwatch()..start())
      ..homeShown()
      ..homeShown();

    final logged = lines().where((l) => l.contains('[startup]')).toList();
    expect(logged, hasLength(1));
    expect(
      logged.single,
      matches(RegExp(r'\[startup\] Home is on screen, \d+ ms after main\(\)')),
    );
  });

  test('none() marks nothing', () {
    LaunchMark.none().homeShown();

    expect(lines(), isEmpty);
  });

  // The Bedroom TV: the launch's sync started 2 s after the first frame,
  // before Home had read its rows, which then waited behind the sync's
  // batches (Home 19.9 s after main()).
  group("settled: Home's rows on screen, or at most a cap", () {
    test('ends when Home is shown', () {
      fakeAsync((async) {
        final mark = LaunchMark(log, Stopwatch()..start());
        var settled = false;
        unawaited(
          mark.settled(cap: const Duration(seconds: 15)).then((_) {
            settled = true;
          }),
        );
        async.elapse(const Duration(seconds: 5));
        expect(settled, isFalse);
        mark.homeShown();
        async.flushMicrotasks();
        expect(settled, isTrue);
      });
    });

    test('ends at the cap with no Home (a launch elsewhere, or none())', () {
      fakeAsync((async) {
        var settled = false;
        unawaited(
          LaunchMark.none().settled(cap: const Duration(seconds: 15)).then((_) {
            settled = true;
          }),
        );
        async.elapse(const Duration(seconds: 14));
        expect(settled, isFalse);
        async.elapse(const Duration(seconds: 1));
        expect(settled, isTrue);
      });
    });

    test('a Home shown before the wait ends it at once', () {
      fakeAsync((async) {
        final mark = LaunchMark(log, Stopwatch()..start())..homeShown();
        var settled = false;
        unawaited(
          mark.settled(cap: const Duration(seconds: 15)).then((_) {
            settled = true;
          }),
        );
        async.flushMicrotasks();
        expect(settled, isTrue);
      });
    });
  });
}
