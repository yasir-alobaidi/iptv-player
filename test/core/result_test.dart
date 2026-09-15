import 'dart:async';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:iptv_player/core/result.dart';

void main() {
  group('Result', () {
    test('Ok exposes its value', () {
      const result = Result<int>.ok(3);

      expect(result.isOk, isTrue);
      expect(result.valueOrNull, 3);
      expect(result.failureOrNull, isNull);
      expect(result.map((v) => v * 2), const Ok(6));
      expect(result.fold((v) => 'value $v', (f) => f.code), 'value 3');
    });

    test('Err exposes its failure and skips map', () {
      final result = Result<int>.err(NotFoundFailure('channel 9'));

      expect(result.isOk, isFalse);
      expect(result.valueOrNull, isNull);
      expect(result.failureOrNull, isA<NotFoundFailure>());
      expect(result.map((v) => v * 2).failureOrNull, isA<NotFoundFailure>());
      expect(result.fold((v) => 'value', (f) => f.code), 'not_found');
    });

    test('guard returns Ok for a value', () async {
      expect(await Result.guard(() async => 'ok'), const Ok('ok'));
    });

    test('guard maps thrown errors to failures', () async {
      Future<AppFailure?> failureOf(Object error) async =>
          // The cases include Error types, not only Exceptions.
          // ignore: only_throw_errors
          (await Result.guard<void>(() => throw error)).failureOrNull;

      expect(await failureOf(TimeoutException('slow')), isA<TimeoutFailure>());
      expect(
        await failureOf(const SocketException('refused')),
        isA<NetworkFailure>(),
      );
      expect(
        await failureOf(const FileSystemException('disk full')),
        isA<StorageFailure>(),
      );
      expect(
        await failureOf(const FormatException('bad')),
        isA<ParseFailure>(),
      );
      expect(await failureOf(StateError('bug')), isA<UnexpectedFailure>());
    });
  });

  group('AppFailure', () {
    test('redacts its detail', () {
      final failure = NetworkFailure(
        'GET http://p.example/live/john/s3cret/1.ts: 403',
        403,
      );

      expect(failure.detail, 'GET http://p.example/live/***/***/1.ts: 403');
      expect(failure.statusCode, 403);
      expect(failure.toString(), startsWith('network: GET'));
    });

    test('fromError redacts the error text', () {
      final failure = AppFailure.fromError(
        const SocketException('connect to http://john:pw@p.example failed'),
      );

      expect(failure.detail, isNot(contains('john')));
      expect(failure.detail, isNot(contains(':pw@')));
    });

    test('toString without detail is the code', () {
      expect(CancelledFailure().toString(), 'cancelled');
    });
  });
}
