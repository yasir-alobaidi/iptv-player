@Tags(['benchmark'])
library;

import 'dart:async';
import 'dart:io';

import 'package:drift/isolate.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:iptv_player/core/result.dart';
import 'package:iptv_player/data/db/app_database.dart';
import 'package:iptv_player/data/library/library_scan.dart';
import 'package:path/path.dart' as p;

import '../data/cast/relay/relay_rig.dart' show relayBinaries;

/// docs/06's library budgets, measured as the app runs the scan: a
/// guarded job on a file database, ffprobe through the bundled binary.
/// A scan of 5,000 new files ≤ 5 min, browsable while it runs, no UI
/// frame over 32 ms; a rescan of 5,000 unchanged files ≤ 5 s. Skipped
/// unless run with `flutter test --tags benchmark --run-skipped
/// test/tools/library_scan_measure_test.dart`.
void main() {
  test('scanning 5,000 new files, and 5,000 unchanged', () async {
    final binaries = relayBinaries()!;
    final temp = Directory.systemTemp.createTempSync('library_measure_');
    addTearDown(() => temp.deleteSync(recursive: true));
    final tree = p.join(temp.path, 'Library');
    final made = await Process.run(
      'tools/media_samples/library_tree.sh',
      [tree, '5000'],
      environment: {'FFMPEG': binaries.ffmpeg},
    );
    expect(made.exitCode, 0, reason: '${made.stderr}');
    final db = AppDatabase(
      await openAppDatabase(Directory(p.join(temp.path, 'db'))),
    );
    addTearDown(db.close);
    final folder = await db.libraryDao.addFolder(
      path: tree,
      label: 'Library',
      at: DateTime.utc(2026),
    );

    // The UI isolate's longest pause while the scan runs.
    var longest = Duration.zero;
    final lag = Stopwatch()..start();
    final ticker = Timer.periodic(const Duration(milliseconds: 4), (_) {
      final gap = lag.elapsed;
      if (gap > longest) longest = gap;
      lag.reset();
    });

    Future<(Duration, Duration?, LibraryScanResult)> run() async {
      final clock = Stopwatch()..start();
      Duration? firstRows;
      final job = startLibraryScanJob(
        LibraryScanWork(
          now: DateTime.now(),
          connection: await db.serializableConnection(),
          minBytes: 10 * 1024,
          ffprobe: binaries.ffprobe,
          processFolder: p.join(temp.path, 'processes'),
        ),
      );
      final listening = job.progress.listen((progress) {
        if (progress.written > 0) firstRows ??= clock.elapsed;
      });
      final result = await job.result;
      clock.stop();
      await listening.cancel();
      // The job's own result, around the scan's.
      final scan = switch (result) {
        Ok(:final value) => value,
        Err(:final failure) => Err<LibraryScanResult>(failure),
      };
      expect(scan.failureOrNull, isNull);
      return (clock.elapsed, firstRows, scan.valueOrNull!);
    }

    longest = Duration.zero;
    lag.reset();
    final (fresh, firstRows, scanned) = await run();
    final freshPause = longest;
    longest = Duration.zero;
    lag.reset();
    final (again, _, unchanged) = await run();
    final againPause = longest;
    ticker.cancel();
    // Read after the clock: 5,000 rows mapped here would be the test's
    // own pause, not the scan's.
    final rows = await db.libraryDao.itemsIn(folder);

    final report = StringBuffer()
      ..writeln('# The library scan, measured\n')
      ..writeln(
        '- 5,000 new files: **${_s(fresh)}** (budget ≤ 5 min); the '
        'first rows written after ${_s(firstRows!)}; $scanned',
      )
      ..writeln(
        "  - the UI isolate's longest pause: "
        '**${freshPause.inMilliseconds} ms** (budget: no frame over 32 ms)',
      )
      ..writeln(
        '- 5,000 unchanged: **${_s(again)}** (budget ≤ 5 s); $unchanged',
      )
      ..writeln(
        "  - the UI isolate's longest pause: "
        '**${againPause.inMilliseconds} ms**',
      );
    final out = Directory('build/library_measure')..createSync(recursive: true);
    File(p.join(out.path, 'report.md')).writeAsStringSync('$report');
    // The report is the point of this test.
    // ignore: avoid_print
    print(report);

    expect(rows, hasLength(5000));
    expect(scanned.added, 5000);
    expect(unchanged.added + unchanged.changed + unchanged.removed, 0);
    expect(fresh, lessThan(const Duration(minutes: 5)));
    expect(again, lessThan(const Duration(seconds: 5)));
    expect(freshPause, lessThan(const Duration(milliseconds: 32)));
  }, timeout: const Timeout(Duration(minutes: 15)));
}

String _s(Duration d) => '${(d.inMilliseconds / 1000).toStringAsFixed(1)} s';
