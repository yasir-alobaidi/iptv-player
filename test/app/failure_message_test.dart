import 'package:flutter_test/flutter_test.dart';
import 'package:iptv_player/app/failure_message.dart';
import 'package:iptv_player/core/result.dart';

void main() {
  test('every failure has a human message', () {
    final failures = <AppFailure>[
      NetworkFailure('http://user:secret@host/live/u/p/1.ts'),
      AuthFailure('401'),
      NotFoundFailure('404'),
      ParseFailure('unexpected character'),
      StorageFailure('ENOSPC'),
      SecureStorageFailure('Libsecret error'),
      InvalidInputFailure('server'),
      TimeoutFailure('after 10s'),
      CancelledFailure(),
      UnexpectedFailure('null check'),
    ];

    for (final failure in failures) {
      final message = failureMessage(failure);

      expect(message, isNotEmpty);
      expect(
        message,
        isNot(contains(failure.code)),
        reason: 'hard rule 4: no technical text in the UI',
      );
    }
  });

  test('the message never carries the technical detail', () {
    final failure = NetworkFailure('SocketException: host lookup failed');

    expect(failureMessage(failure), isNot(contains('SocketException')));
  });

  group('serverAnswer', () {
    test('says what the server answered, with the reason phrase', () {
      expect(
        serverAnswer(NotFoundFailure('x', 404)),
        'The server answered HTTP 404 (Not Found).',
      );
      expect(
        serverAnswer(NetworkFailure('x', 503)),
        'The server answered HTTP 503 (Service Unavailable).',
      );
      expect(
        serverAnswer(AuthFailure('x', 403)),
        'The server answered HTTP 403 (Forbidden).',
      );
      expect(
        serverAnswer(NetworkFailure('x', 599)),
        'The server answered '
        'HTTP 599.',
      );
    });

    test('an empty 404 read as a refused sign-in says both', () {
      final answer = serverAnswer(AuthFailure('x', 404))!;

      expect(answer, contains('HTTP 404 with an empty page'));
      expect(answer, contains('wrong username or password'));
    });

    test('no status, no answer: the message alone', () {
      final failure = TimeoutFailure('after 30s');

      expect(serverAnswer(failure), isNull);
      expect(failureWithAnswer(failure), failureMessage(failure));
    });

    test('a stored code comes back with its status', () {
      final failure = AppFailure.fromCode('network', statusCode: 502);

      expect(failure.statusCode, 502);
      expect(
        failureWithAnswer(failure),
        '${failureMessage(failure)} The server answered HTTP 502 '
        '(Bad Gateway).',
      );
    });
  });
}
