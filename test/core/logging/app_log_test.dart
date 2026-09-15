import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:iptv_player/core/logging/app_log.dart';
import 'package:iptv_player/core/logging/error_reporter.dart';
import 'package:iptv_player/core/logging/secret_registry.dart';
import 'package:iptv_player/core/result.dart';
import 'package:logger/logger.dart';

void main() {
  late MemoryOutput memory;
  late SecretRegistry secrets;
  late AppLog log;

  setUp(() {
    memory = MemoryOutput();
    secrets = SecretRegistry();
    log = AppLog(output: memory, secrets: secrets);
  });

  tearDown(() => log.close());

  List<String> lines() => [for (final e in memory.buffer) ...e.lines];

  group('AppLog', () {
    test('formats time, level, tag, and message', () {
      log.info('sync', 'Categories done');

      expect(
        lines().single,
        matches(
          RegExp(
            r'^\d{4}-\d\d-\d\dT\d\d:\d\d:\d\d\.\d+Z INFO \[sync\] '
            r'Categories done$',
          ),
        ),
      );
    });

    test('redacts the message, error, and stack trace', () {
      secrets.add('hunter22');
      log.error(
        'player',
        'Open http://p.example/live/john/s3cret/1.ts failed',
        error: Exception('GET http://p.example/get.php?password=s3cret'),
        stackTrace: StackTrace.fromString('#0 open (hunter22.dart:1)'),
      );

      final text = lines().join('\n');
      expect(text, isNot(contains('s3cret')));
      expect(text, isNot(contains('john')));
      expect(text, isNot(contains('hunter22')));
      expect(text, contains('ERROR [player] Open http://p.example/live/***'));
      expect(text, contains('  error: Exception: GET'));
      expect(text, contains('  #0 open (***.dart:1)'));
    });

    test('drops records below the level', () {
      log
        ..debug('ui', 'hidden')
        ..warning('ui', 'shown');

      expect(lines().single, contains('WARN [ui] shown'));
    });
  });

  group('ErrorReporter', () {
    test('logs framework errors redacted and publishes a failure', () async {
      final reporter = ErrorReporter(log);
      final published = reporter.nonFatalErrors.first;

      reporter.handleFlutterError(
        FlutterErrorDetails(
          exception: const FormatException(
            'bad JSON from http://john:s3cret@p.example/player_api.php',
          ),
          stack: StackTrace.current,
          library: 'widgets library',
        ),
      );

      final failure = await published;
      expect(failure, isA<ParseFailure>());
      expect(failure.detail, isNot(contains('s3cret')));
      expect(lines().first, contains('ERROR [widgets library]'));
      expect(lines().join('\n'), isNot(contains('s3cret')));
      await reporter.dispose();
    });

    test('ignores reports after dispose', () async {
      final reporter = ErrorReporter(log);
      await reporter.dispose();

      reporter.report(StateError('late'), null, source: 'test');

      expect(lines().first, contains('ERROR [test] Unhandled error'));
      expect(lines().join('\n'), contains('error: Bad state: late'));
    });
  });
}
