import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:iptv_player/core/logging/app_log.dart';
import 'package:iptv_player/core/logging/secret_registry.dart';
import 'package:iptv_player/core/secure/credential_store.dart';
import 'package:iptv_player/data/db/app_database.dart';
import 'package:iptv_player/data/db/catalogue_tables.dart';
import 'package:iptv_player/data/db/daos/sync_runs_dao.dart';
import 'package:iptv_player/data/sync/sync_engine.dart';
import 'package:iptv_player/features/sources/data/db_source_repository.dart';
import 'package:iptv_player/features/sources/domain/source.dart';
import 'package:logger/logger.dart';

/// docs/06's kill-the-app-mid-sync test, with a real kill: a separate
/// process (`support/sync_victim.dart`) re-syncs a big playlist over an
/// existing catalogue and gets SIGKILL part-way, database isolate and all.
/// The next launch must find the file intact, the old catalogue whole,
/// the user's choices kept, and the dead run failed as interrupted.
void main() {
  final skip = _whyNot();

  test(
    'killing the app mid-sync loses nothing',
    () async {
      final directory = await Directory.systemTemp.createTemp('sync_kill');
      addTearDown(() => directory.delete(recursive: true));
      final playlist = File('${directory.path}/list.m3u')
        ..writeAsStringSync(_playlist(1000));

      // A first, complete sync, and a category the user hid.
      var app = await _App.open(directory);
      final id = (await app.repository.add(
        SourceDraft(type: SourceType.m3uFile, name: 'List', url: playlist.path),
      )).valueOrNull!.id;
      expect((await app.engine.sync(id)).isOk, isTrue);
      final hidden =
          (await app.db.categoriesDao
                  .watchForSource(id, CatalogueKind.live)
                  .first)
              .first;
      await app.db.categoriesDao.setHidden(hidden.id, hidden: true);
      await app.close();

      // The provider's list grows 60-fold; the re-sync dies part-way.
      playlist.writeAsStringSync(_playlist(60000));
      final written = await _syncAndKill(directory, id, afterRows: 5000);
      expect(written, lessThan(60000), reason: 'killed before the end');

      app = await _App.open(directory);
      final db = app.db;
      final check = await db.customSelect('PRAGMA integrity_check').get();
      expect(check.single.read<String>('integrity_check'), 'ok');
      for (final table in ['channels_fts', 'movies_fts', 'series_fts']) {
        await db.customStatement(
          "INSERT INTO $table($table, rank) VALUES ('integrity-check', 1)",
        );
      }
      expect((await db.syncRunsDao.latest(id))!.outcome, SyncOutcome.running);

      await app.engine.startUp();

      final dead = (await db.syncRunsDao.latest(id))!;
      expect(dead.outcome, SyncOutcome.failed);
      expect(dead.failure, syncInterruptedFailure);
      final channels = await db.channelsDao.countFor(id);
      expect(channels, greaterThanOrEqualTo(written));
      expect(channels, lessThan(60000));
      final categories = await db.categoriesDao
          .watchForSource(id, CatalogueKind.live)
          .first;
      expect(categories.singleWhere((c) => c.id == hidden.id).isHidden, isTrue);

      // The next sync finishes the job.
      expect((await app.engine.sync(id)).valueOrNull!.channels, 60000);
      await app.close();
    },
    skip: skip,
    timeout: const Timeout(Duration(minutes: 3)),
  );
}

/// The app's own stack over one database file.
final class _App {
  new _(this.db)
    : log = AppLog(output: MemoryOutput(), secrets: SecretRegistry()) {
    repository = DbSourceRepository(
      database: db,
      store: InMemoryCredentialStore(),
      secrets: SecretRegistry(),
      log: log,
    );
    engine = SyncEngine(database: db, sources: repository, log: log);
  }

  static Future<_App> open(Directory directory) async =>
      _App._(AppDatabase(await openAppDatabase(directory)));

  final AppDatabase db;
  final AppLog log;
  late final DbSourceRepository repository;
  late final SyncEngine engine;

  Future<void> close() async {
    await engine.dispose();
    await log.close();
    await db.close();
  }
}

/// Starts the victim, waits until it has written [afterRows] channels,
/// and kills it. Returns the last count it reported.
Future<int> _syncAndKill(
  Directory directory,
  String sourceId, {
  required int afterRows,
}) async {
  final process = await Process.start('dart', [
    'run',
    'test/data/sync/support/sync_victim.dart',
    directory.path,
    sourceId,
  ]);
  var written = 0;
  var finished = false;
  final reachedTarget = Completer<void>();
  final output = process.stdout
      .transform(utf8.decoder)
      .transform(const LineSplitter())
      .listen((line) {
        if (line.startsWith('finished')) finished = true;
        if (line.startsWith('written ')) {
          written = int.parse(line.substring(8));
          if (written >= afterRows && !reachedTarget.isCompleted) {
            process.kill(ProcessSignal.sigkill);
            reachedTarget.complete();
          }
        }
      });
  final errors = StringBuffer();
  unawaited(process.stderr.transform(utf8.decoder).forEach(errors.write));

  final exitCode = await process.exitCode.timeout(
    const Duration(minutes: 2),
    onTimeout: () {
      process.kill(ProcessSignal.sigkill);
      return -1;
    },
  );
  await output.cancel();
  expect(finished, isFalse, reason: 'the sync ended before the kill');
  expect(reachedTarget.isCompleted, isTrue, reason: 'stderr: $errors');
  // 128 + SIGKILL, as the shell reports it; negative from dart:io.
  expect(exitCode, anyOf(-9, 137));
  return written;
}

String _playlist(int channels) {
  final text = StringBuffer('#EXTM3U\n');
  for (var i = 0; i < channels; i++) {
    text
      ..writeln(
        '#EXTINF:-1 tvg-id="c$i" group-title="Group ${i % 25}",Channel $i',
      )
      ..writeln('http://tv.test/live/$i.ts');
  }
  return '$text';
}

/// A kill needs POSIX signals and a `dart` to run the victim with.
String? _whyNot() {
  if (Platform.isWindows) {
    return 'SIGKILL is POSIX; SQLite recovers the same way on Windows';
  }
  try {
    final version = Process.runSync('dart', ['--version']);
    if (version.exitCode != 0) return 'no working `dart` on PATH';
  } on ProcessException {
    return 'no `dart` on PATH';
  }
  return null;
}
