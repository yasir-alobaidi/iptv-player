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
}
