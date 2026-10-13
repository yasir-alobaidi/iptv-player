import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:iptv_player/features/diagnostics/data/file_log_reader.dart';
import 'package:iptv_player/features/diagnostics/domain/log_lines.dart';
import 'package:path/path.dart' as p;

/// `2026-10-13T09:00:07.000Z INFO [tag] line 7`.
String line(int n, {String level = 'INFO', String tag = 'tag', String? text}) {
  final at = DateTime.utc(2026, 10, 13, 9).add(Duration(seconds: n));
  return '${at.toIso8601String()} $level [$tag] ${text ?? 'line $n'}';
}

void main() {
  late Directory folder;

  setUp(() {
    folder = Directory.systemTemp.createTempSync('log_reader_');
    addTearDown(() => folder.deleteSync(recursive: true));
  });

  File file(int index) =>
      File(p.join(folder.path, index == 0 ? 'app.log' : 'app.$index.log'));

  void write(int index, List<String> lines, {bool newline = true}) =>
      file(index).writeAsStringSync(
        lines.join('\n') + (newline && lines.isNotEmpty ? '\n' : ''),
      );

  LogPage page({
    bool problemsOnly = false,
    String text = '',
    LogCursor? before,
    int limit = 2000,
  }) => readLogPage(
    folder.path,
    problemsOnly: problemsOnly,
    text: text,
    beforeFile: before?.file,
    beforeOffset: before?.offset,
    limit: limit,
  );

  List<String> texts(LogPage page) => [for (final row in page.rows) row.text];

  group('the newest lines', () {
    test('oldest first, up to the limit, with where older ones start', () {
      write(0, [for (var i = 0; i < 10; i++) line(i)]);

      final newest = page(limit: 4);

      expect(texts(newest), ['line 6', 'line 7', 'line 8', 'line 9']);
      expect(newest.older, isNotNull);
      expect(newest.end, LogCursor(0, file(0).lengthSync()));

      final older = page(before: newest.older, limit: 4);
      expect(texts(older), ['line 2', 'line 3', 'line 4', 'line 5']);

      final oldest = page(before: older.older, limit: 4);
      expect(texts(oldest), ['line 0', 'line 1']);
      expect(oldest.older, isNull, reason: 'nothing before the first line');
    });

    test('a page that takes exactly what is left says there is no more', () {
      write(0, [for (var i = 0; i < 4; i++) line(i)]);

      final all = page(limit: 4);

      expect(texts(all), hasLength(4));
      expect(all.older, isNull);
    });

    test('older files follow the one being written: app.log, app.1.log, '
        'app.2.log', () {
      write(2, [for (var i = 0; i < 3; i++) line(i)]);
      write(1, [for (var i = 3; i < 6; i++) line(i)]);
      write(0, [for (var i = 6; i < 9; i++) line(i)]);

      final newest = page(limit: 5);
      expect(texts(newest), [for (var i = 4; i < 9; i++) 'line $i']);

      final rest = page(before: newest.older, limit: 5);
      expect(texts(rest), [for (var i = 0; i < 4; i++) 'line $i']);
      expect(rest.older, isNull);
    });

    test('a whole log in one page, across files', () {
      write(1, [line(0), line(1)]);
      write(0, [line(2)]);

      final all = page();

      expect(texts(all), ['line 0', 'line 1', 'line 2']);
      expect(all.older, isNull);
    });

    test('no folder, no file, an empty file: nothing, and no error', () {
      expect(readLogPage(p.join(folder.path, 'missing')).rows, isEmpty);
      expect(page().rows, isEmpty);
      write(0, []);
      expect(page().rows, isEmpty);
      expect(page().older, isNull);
    });

    test('a last line still being written is left for the next look', () {
      write(0, [
        line(0),
        line(1),
        '2026-10-13T09:00:02.000Z INFO [tag] hal',
      ], newline: false);

      final newest = page();

      expect(texts(newest), ['line 0', 'line 1']);
      expect(
        newest.end.offset,
        '${line(0)}\n${line(1)}\n'.length,
        reason: 'what comes after is new',
      );
    });
  });

  group('a record with lines under it', () {
    final lines = [
      line(0),
      line(1, level: 'ERROR', tag: 'sync', text: 'The sync failed'),
      '  error: SocketException: Connection refused',
      '  #0      SyncEngine.run (sync_engine.dart:120:9)',
      '  #1      main (main.dart:5:3)',
      line(2),
    ];

    test('stays whole and in order, each line at the record’s level', () {
      write(0, lines);

      final rows = page().rows;

      expect(
        [for (final row in rows) row.text],
        [
          'line 0',
          'The sync failed',
          'error: SocketException: Connection refused',
          '#0      SyncEngine.run (sync_engine.dart:120:9)',
          '#1      main (main.dart:5:3)',
          'line 2',
        ],
      );
      expect(
        [for (final row in rows) row.continuation],
        [false, false, true, true, true, false],
      );
      expect([
        for (final row in rows.sublist(1, 5)) row.level,
      ], everyElement(LogLevel.error));
    });

    test('is never cut in two by the limit, nor by a page’s start', () {
      write(0, lines);

      final newest = page(limit: 2);

      // "line 2" is one; the record before it is taken whole.
      expect(texts(newest), hasLength(5));
      expect(newest.rows.first.text, 'The sync failed');
      final older = page(before: newest.older, limit: 2);
      expect(texts(older), ['line 0']);
    });

    test('lines at the top of a file with no record over them are still '
        'shown', () {
      write(0, ['  left over from a record', line(0)]);

      expect(texts(page()), ['left over from a record', 'line 0']);
    });
  });

  group('the filters', () {
    setUp(() {
      write(1, [
        line(0, tag: 'playback', text: 'Opening channel 147'),
        line(1, level: 'WARN', tag: 'watchdog', text: 'Stalled for 4 s'),
      ]);
      write(0, [
        line(2, tag: 'playback', text: 'First frame after 961 ms'),
        line(3, level: 'ERROR', tag: 'sync', text: 'The sync failed'),
        '  error: TimeoutException after 0:00:30',
        line(4, tag: 'epg', text: 'Guide updated'),
        line(5, level: 'FATAL', tag: 'boot', text: 'No database'),
      ]);
    });

    test('Warnings and errors, across files', () {
      final problems = page(problemsOnly: true);

      expect(texts(problems), [
        'Stalled for 4 s',
        'The sync failed',
        'error: TimeoutException after 0:00:30',
        'No database',
      ]);
    });

    test('text, in any case, in the message, the tag or a line under it', () {
      expect(texts(page(text: 'FRAME')), ['First frame after 961 ms']);
      expect(texts(page(text: 'playback')), [
        'Opening channel 147',
        'First frame after 961 ms',
      ]);
      // Found in the line under it: the whole record is shown.
      expect(texts(page(text: 'timeoutexception')), [
        'The sync failed',
        'error: TimeoutException after 0:00:30',
      ]);
      expect(texts(page(text: 'nothing has this')), isEmpty);
    });

    test('both at once, and paged', () {
      LogPage problemsWith(String text, {LogCursor? before}) =>
          page(problemsOnly: true, text: text, before: before, limit: 1);

      // Every problem has an "a"; "Guide updated" has one too and isn't
      // a problem.
      final newest = problemsWith('a');
      expect(texts(newest), ['No database']);
      final older = problemsWith('a', before: newest.older);
      expect(texts(older), [
        'The sync failed',
        'error: TimeoutException after 0:00:30',
      ]);
      final oldest = problemsWith('a', before: older.older);
      expect(texts(oldest), ['Stalled for 4 s']);
    });
  });

  group('following the file', () {
    test('what was written since, and where to look from next', () {
      write(0, [line(0), line(1)]);
      final start = page().end;

      file(0)
          .writeAsStringSync('${line(2)}\n${line(3)}\n', mode: FileMode.append);
      final more = readLogSince(folder.path, offset: start.offset);

      expect([for (final row in more.rows) row.text], ['line 2', 'line 3']);
      expect(more.rotated, isFalse);
      expect(more.end, LogCursor(0, file(0).lengthSync()));
      expect(readLogSince(folder.path, offset: more.end.offset).rows, isEmpty);
    });

    test('a line half written waits until it is whole', () {
      write(0, [line(0)]);
      final start = page().end;
      file(0).writeAsStringSync(
        '2026-10-13T09:00:01.000Z INFO [t] ha',
        mode: FileMode.append,
      );

      final half = readLogSince(folder.path, offset: start.offset);
      expect(half.rows, isEmpty);
      expect(half.end, start);

      file(0).writeAsStringSync('lf\n', mode: FileMode.append);
      final whole = readLogSince(folder.path, offset: half.end.offset);
      expect(whole.rows.single.text, 'half');
    });

    test('the filters apply to what is new, with records kept whole', () {
      write(0, [line(0)]);
      final start = page().end;
      file(0).writeAsStringSync(
        [
          line(1),
          line(2, level: 'ERROR', text: 'Boom'),
          '  error: x',
          line(3),
          '',
        ].join('\n'),
        mode: FileMode.append,
      );

      final problems = readLogSince(
        folder.path,
        offset: start.offset,
        problemsOnly: true,
      );

      expect([for (final row in problems.rows) row.text], ['Boom', 'error: x']);
      expect(problems.end, LogCursor(0, file(0).lengthSync()));
    });

    test('a file that filled up and was replaced says so, so the viewer '
        'reads from the end again', () {
      write(0, [for (var i = 0; i < 50; i++) line(i)]);
      final start = page().end;

      // What RotatingFileOutput does: the full file becomes app.1.log and
      // a new app.log starts.
      file(0).renameSync(file(1).path);
      write(0, [line(50)]);

      final after = readLogSince(folder.path, offset: start.offset);
      expect(after.rotated, isTrue);
      expect(after.rows, isEmpty);
      expect(texts(page(limit: 3)), ['line 48', 'line 49', 'line 50']);
    });
  });

  group('through the reader, in an isolate', () {
    test('a page, older lines, and what is new', () async {
      write(0, [for (var i = 0; i < 6; i++) line(i)]);
      final reader = FileLogReader(directory: folder);
      expect(reader.currentFile, file(0).path);

      final newest = (await reader.page(
        const LogQuery(),
        limit: 3,
      )).valueOrNull!;
      expect(texts(newest), ['line 3', 'line 4', 'line 5']);
      final older = (await reader.page(
        const LogQuery(),
        before: newest.older,
        limit: 3,
      )).valueOrNull!;
      expect(texts(older), ['line 0', 'line 1', 'line 2']);

      file(
        0,
      ).writeAsStringSync('${line(6, level: 'WARN')}\n', mode: FileMode.append);
      final more = (await reader.since(
        newest.end,
        const LogQuery(problemsOnly: true),
      )).valueOrNull!;
      expect(more.rows.single.level, LogLevel.warning);
    });

    test('bytes that aren’t text don’t stop the lines around them', () async {
      file(0).writeAsBytesSync([
        ...'${line(0)}\n'.codeUnits,
        0xff,
        0xfe,
        0x80,
        0x0a,
        ...'${line(1)}\n'.codeUnits,
      ]);

      final all = (await FileLogReader(
        directory: folder,
      ).page(const LogQuery())).valueOrNull!;

      expect(all.rows.first.text, 'line 0');
      expect(all.rows.last.text, 'line 1');
      expect(all.rows, hasLength(3));
    });
  });
}
