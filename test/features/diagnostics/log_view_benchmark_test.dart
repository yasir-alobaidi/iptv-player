// The log viewer's reads on a full set of log files: 5 × 5 MB, as
// docs/06 keeps. Phase 9 step 4: the newest lines within 100 ms, and no
// pause of the UI isolate over 16 ms while they are read.
@Tags(['benchmark'])
library;

import 'dart:async';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:iptv_player/features/diagnostics/data/file_log_reader.dart';
import 'package:iptv_player/features/diagnostics/domain/log_lines.dart';
import 'package:path/path.dart' as p;

void main() {
  test('25 MB of log: the first page, older pages, and both filters', () async {
    final folder = Directory.systemTemp.createTempSync('log_benchmark_');
    addTearDown(() => folder.deleteSync(recursive: true));
    const fileBytes = 5 * 1024 * 1024;
    var second = 0;
    var lines = 0;
    for (var index = 4; index >= 0; index--) {
      final text = StringBuffer();
      while (text.length < fileBytes) {
        final at = DateTime.utc(2026, 10, 13).add(Duration(seconds: second++));
        final problem = second % 40 == 0;
        text.writeln(
          '${at.toIso8601String()} ${problem ? 'WARN' : 'INFO'} '
          '[${problem ? 'watchdog' : 'playback'}] '
          '${problem ? 'Stalled for 4 s, reconnecting' : 'Opening channel'} '
          '$second of the list the user is zapping through tonight',
        );
        lines++;
        if (problem) {
          text
            ..writeln('  error: SocketException: Connection reset by peer')
            ..writeln('  #0      Watchdog.run (watchdog.dart:120:9)');
          lines += 2;
        }
      }
      File(p.join(folder.path, index == 0 ? 'app.log' : 'app.$index.log'))
          .writeAsStringSync(text.toString());
    }
    final reader = FileLogReader(directory: folder);

    var last = DateTime.now();
    var worstGap = Duration.zero;
    final ticker = Timer.periodic(const Duration(milliseconds: 2), (_) {
      final at = DateTime.now();
      if (at.difference(last) > worstGap) worstGap = at.difference(last);
      last = at;
    });

    Future<(Duration, LogPage)> timed(
      LogQuery query, {
      LogCursor? before,
    }) async {
      final watch = Stopwatch()..start();
      final page = (await reader.page(query, before: before)).valueOrNull!;
      return (watch.elapsed, page);
    }

    // Warm: the first isolate of a process costs more than the rest.
    await timed(const LogQuery());
    final firsts = <Duration>[];
    late LogPage newest;
    for (var i = 0; i < 5; i++) {
      final (took, page) = await timed(const LogQuery());
      firsts.add(took);
      newest = page;
    }
    final (older, olderPage) = await timed(
      const LogQuery(),
      before: newest.older,
    );
    final (problems, problemsPage) = await timed(
      const LogQuery(problemsOnly: true),
    );
    final (text, textPage) = await timed(const LogQuery(text: 'reconnecting'));
    final (none, nonePage) = await timed(
      const LogQuery(text: 'a phrase no line of this log holds'),
    );
    final follow = Stopwatch()..start();
    await reader.since(newest.end, const LogQuery());
    follow.stop();
    ticker.cancel();

    firsts.sort();
    // The measurement is this test's output.
    // ignore: avoid_print
    print(
      'log viewer on 25 MB ($lines lines): first page '
      '${firsts[firsts.length ~/ 2].inMilliseconds} ms (median of 5, worst '
      '${firsts.last.inMilliseconds} ms, ${newest.rows.length} lines), an '
      'older page ${older.inMilliseconds} ms (${olderPage.rows.length}), '
      'warnings and errors ${problems.inMilliseconds} ms '
      '(${problemsPage.rows.length}), a text filter ${text.inMilliseconds} '
      'ms (${textPage.rows.length}), a filter nothing matches (all 25 MB '
      'read) ${none.inMilliseconds} ms (${nonePage.rows.length}), a look '
      'for new lines ${follow.elapsedMilliseconds} ms; worst UI-isolate gap '
      '${worstGap.inMilliseconds} ms',
    );
    expect(newest.rows, hasLength(greaterThanOrEqualTo(2000)));
    expect(
      firsts[firsts.length ~/ 2],
      lessThan(const Duration(milliseconds: 100)),
    );
    expect(worstGap, lessThan(const Duration(milliseconds: 16)));
  });
}
