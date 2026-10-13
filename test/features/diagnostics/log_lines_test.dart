import 'package:flutter_test/flutter_test.dart';
import 'package:iptv_player/features/diagnostics/domain/log_lines.dart';

void main() {
  test('a record’s first line gives its time, level, tag and message', () {
    final row = parseLogLine(
      '2026-10-12T05:53:02.069823Z WARN [watchdog] Stalled for 4 s, '
      'reconnecting (1 of 6)',
    );

    expect(row.continuation, isFalse);
    expect(row.time, DateTime.utc(2026, 10, 12, 5, 53, 2, 69, 823));
    expect(row.level, LogLevel.warning);
    expect(row.tag, 'watchdog');
    expect(row.text, 'Stalled for 4 s, reconnecting (1 of 6)');
  });

  test('every level the log writes is read', () {
    for (final level in LogLevel.values) {
      final row = parseLogLine('2026-10-12T05:53:02.000Z ${level.label} [t] m');
      expect(row.level, level, reason: level.label);
    }
    expect(LogLevel.warning.isProblem, isTrue);
    expect(LogLevel.error.isProblem, isTrue);
    expect(LogLevel.fatal.isProblem, isTrue);
    expect(LogLevel.info.isProblem, isFalse);
  });

  test('a tag with dots, an empty message, and a message with brackets', () {
    expect(
      parseLogLine('2026-10-12T05:54:17.836146Z INFO [cast.discovery] x').tag,
      'cast.discovery',
    );
    expect(parseLogLine('2026-10-12T05:54:17.836Z INFO [boot] ').text, '');
    final brackets = parseLogLine(
      '2026-10-12T05:54:17.836Z INFO [epg] matched [4 of 12601] channels',
    );
    expect(brackets.tag, 'epg');
    expect(brackets.text, 'matched [4 of 12601] channels');
  });

  test('a line under a record is its continuation, at its level, without '
      'the indent', () {
    final error = parseLogLine(
      '  error: SocketException: Connection refused',
      under: LogLevel.error,
    );
    final stack = parseLogLine('  #0      main (file.dart:1:1)');

    expect(error.continuation, isTrue);
    expect(error.level, LogLevel.error);
    expect(error.time, isNull);
    expect(error.text, 'error: SocketException: Connection refused');
    expect(stack.level, LogLevel.info, reason: 'nothing above it is known');
  });

  test('a line in no format we write is kept as it is, never dropped', () {
    final odd = parseLogLine('[relay] ffmpeg said something');

    expect(odd.continuation, isTrue);
    expect(odd.text, '[relay] ffmpeg said something');
  });

  test('a row gives back the line the file has', () {
    const lines = [
      '2026-10-12T05:53:02.069823Z WARN [watchdog] Stalled for 4 s',
      '2026-10-12T05:59:54.985Z INFO [bootstrap] Quit in 1 ms',
    ];
    for (final line in lines) {
      expect(parseLogLine(line).raw, line);
    }
    expect(parseLogLine('  error: boom').raw, '  error: boom');
  });

  test('a query with nothing asked is empty', () {
    expect(const LogQuery().isEmpty, isTrue);
    expect(const LogQuery(text: '  ').isEmpty, isTrue);
    expect(const LogQuery(problemsOnly: true).isEmpty, isFalse);
    expect(const LogQuery(text: 'x').isEmpty, isFalse);
  });
}
