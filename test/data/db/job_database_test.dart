import 'dart:io';

import 'package:drift/isolate.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:iptv_player/core/isolates/background.dart';
import 'package:iptv_player/core/result.dart';
import 'package:iptv_player/data/db/app_database.dart';
import 'package:iptv_player/data/db/job_database.dart';

/// Rows per batch: enough that the batch is still being written when the
/// app receives the report sent just before it, and cancels.
const _rowsPerBatch = 20000;

/// The regression test for ADR-011 step 3's deadlock: drift writes a batch
/// as a transaction its client opens and commits, and a client isolate
/// killed in between left it open in the database isolate, so every query
/// the app made afterwards waited for good. A guarded job is only ever
/// killed between batches.
void main() {
  test('cancelling a job in the middle of a batch leaves the database '
      'usable, with whole batches only', () async {
    final directory = await Directory.systemTemp.createTemp('job_database');
    final db = AppDatabase(await openAppDatabase(directory));
    addTearDown(() async {
      await db.close();
      await directory.delete(recursive: true);
    });
    await db.customStatement(
      'CREATE TABLE job_guard_rows (n INTEGER NOT NULL)',
    );

    for (var round = 0; round < 5; round++) {
      final job = _startWriter(await db.serializableConnection());
      // Report 1 is sent as the second batch begins: the cancel lands
      // while it is being written.
      await job.progress.firstWhere((batch) => batch >= 1);
      job.cancel();
      expect((await job.result).failureOrNull, isA<CancelledFailure>());

      final rows = await db
          .customSelect('SELECT COUNT(*) AS n FROM job_guard_rows')
          .getSingle()
          .timeout(const Duration(seconds: 10))
          .then((row) => row.read<int>('n'));
      expect(rows % _rowsPerBatch, 0, reason: 'a batch lands whole or not');
      await db
          .customStatement('INSERT INTO job_guard_rows (n) VALUES (-1)')
          .timeout(const Duration(seconds: 10));
      await db.customStatement('DELETE FROM job_guard_rows WHERE n = -1');
    }
  });
}

/// Top level, so the closure sent to the isolate captures [connection]
/// and nothing else.
BackgroundJob<int, void> _startWriter(DriftIsolate connection) =>
    startGuardedJob<int, void>(
      (report, cancellation) => _writeForever(connection, report, cancellation),
      timeout: const Duration(seconds: 30),
    );

Future<void> _writeForever(
  DriftIsolate connection,
  void Function(int batch) report,
  JobCancellation cancellation,
) async {
  final db = await openJobDatabase(connection, cancellation);
  for (var batch = 0; ; batch++) {
    report(batch);
    await db.batch((b) {
      for (var n = 0; n < _rowsPerBatch; n++) {
        b.customStatement('INSERT INTO job_guard_rows (n) VALUES (?)', [n]);
      }
    });
  }
}
