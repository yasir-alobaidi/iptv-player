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
}
