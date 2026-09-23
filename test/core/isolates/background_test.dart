import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:iptv_player/core/isolates/background.dart';
import 'package:iptv_player/core/result.dart';

const _timeout = Duration(seconds: 10);

void main() {
  group('runInBackground', () {
    test('returns the value', () async {
      expect(
        await runInBackground(() => 21 * 2, timeout: _timeout),
        const Ok(42),
      );
    });

    test('returns a failure for a thrown error', () async {
      final result = await runInBackground<int>(
        () => throw const FormatException('bad M3U line'),
        timeout: _timeout,
      );

      expect(result.failureOrNull, isA<ParseFailure>());
    });

    test('kills a task that exceeds the timeout', () async {
      final watch = Stopwatch()..start();
      final result = await runInBackground<int>(() {
        while (true) {}
      }, timeout: const Duration(milliseconds: 300));

      expect(result.failureOrNull, isA<TimeoutFailure>());
      expect(watch.elapsed, lessThan(const Duration(seconds: 5)));
    });

    test('returns a failure for an uncaught async error', () async {
      final result = await runInBackground<int>(() async {
        unawaited(Future<void>(() => throw StateError('lost')));
        await Completer<void>().future;
        return 1;
      }, timeout: _timeout);

      expect(result.failureOrNull, isA<UnexpectedFailure>());
      expect(result.failureOrNull!.detail, contains('lost'));
    });
  });

  group('startBackgroundJob', () {
    test('reports progress in order, then the result', () async {
      final job = startBackgroundJob<int, String>((report) {
        for (var i = 1; i <= 3; i++) {
          report(i);
        }
        return 'done';
      }, timeout: _timeout);
      final progress = job.progress.toList();

      expect(await job.result, const Ok('done'));
      expect(await progress, [1, 2, 3]);
      expect(job.isFinished, isTrue);
    });

    test('cancel kills the isolate and returns CancelledFailure', () async {
      final job = startBackgroundJob<int, int>((report) async {
        for (var i = 0; ; i++) {
          report(i);
          await Future<void>.delayed(const Duration(milliseconds: 10));
        }
      });

      await job.progress.first;
      job.cancel();

      expect((await job.result).failureOrNull, isA<CancelledFailure>());
    });

    test('cancel before the isolate starts still finishes', () async {
      final job = startBackgroundJob<int, int>((report) => 1)..cancel();

      expect((await job.result).failureOrNull, isA<CancelledFailure>());
    });
  });

  group('JobCancellation', () {
    test('answers once asked and idle, and begins nothing after', () {
      var answers = 0;
      final cancellation = JobCancellation(() => answers++)
        ..enter()
        ..request();

      expect(answers, 0, reason: 'marked work is still running');
      expect(cancellation.enter, throwsA(isA<CancelledFailure>()));

      cancellation.leave();
      expect(answers, 1);
      cancellation
        ..request()
        ..leave();
      expect(answers, 1, reason: 'it answers once');
    });

    test('asked while idle, it answers at once', () {
      var answers = 0;
      JobCancellation(() => answers++).request();

      expect(answers, 1);
    });
  });

  group('startGuardedJob', () {
    test('stopped while nothing is marked, it is killed at once', () async {
      final job = startGuardedJob<int, int>((report, _) async {
        for (var i = 0; ; i++) {
          report(i);
          await Future<void>.delayed(const Duration(milliseconds: 10));
        }
      }, timeout: _timeout);

      await job.progress.first;
      final clock = Stopwatch()..start();
      job.cancel();

      expect((await job.result).failureOrNull, isA<CancelledFailure>());
      expect(clock.elapsed, lessThan(const Duration(seconds: 2)));
    });

    test(
      'never killed inside marked work: it goes when the work ends',
      () async {
        final job = startGuardedJob<int, int>(
          _markedThenIdle,
          timeout: _timeout,
        );

        await job.progress.first;
        final clock = Stopwatch()..start();
        job.cancel();

        expect((await job.result).failureOrNull, isA<CancelledFailure>());
        expect(
          clock.elapsed,
          greaterThanOrEqualTo(const Duration(milliseconds: 250)),
          reason: 'the marked work runs 300 ms after the first report',
        );
      },
    );

    test('the timeout stops it the same careful way', () async {
      final clock = Stopwatch()..start();
      final job = startGuardedJob<int, int>(
        _markedThenIdle,
        timeout: const Duration(milliseconds: 50),
      );

      expect((await job.result).failureOrNull, isA<TimeoutFailure>());
      expect(
        clock.elapsed,
        greaterThanOrEqualTo(const Duration(milliseconds: 250)),
      );
    });

    test('work that never ends is killed after the grace period', () async {
      final job = startGuardedJob<int, int>((report, cancellation) async {
        cancellation.enter();
        report(0);
        await Completer<void>().future;
        return 0;
      }, cancelGrace: const Duration(milliseconds: 200));

      await job.progress.first;
      job.cancel();

      expect((await job.result).failureOrNull, isA<CancelledFailure>());
    });

    test('cancel before the isolate starts still finishes', () async {
      final job = startGuardedJob<int, int>((report, _) => 1)..cancel();

      expect((await job.result).failureOrNull, isA<CancelledFailure>());
    });

    test('a guarded job that finishes returns its value', () async {
      final job = startGuardedJob<int, String>((report, cancellation) {
        cancellation
          ..enter()
          ..leave();
        report(1);
        return 'done';
      }, timeout: _timeout);

      expect(await job.result, const Ok('done'));
    });
  });
}

/// Marked work for 300 ms after its first report, then idle for good.
/// Top level, so the closure sent to the isolate captures nothing.
Future<int> _markedThenIdle(
  void Function(int progress) report,
  JobCancellation cancellation,
) async {
  cancellation.enter();
  report(0);
  await Future<void>.delayed(const Duration(milliseconds: 300));
  cancellation.leave();
  await Completer<void>().future;
  return 0;
}
