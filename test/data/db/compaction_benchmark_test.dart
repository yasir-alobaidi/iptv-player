import 'dart:async';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:iptv_player/core/logging/app_log.dart';
import 'package:iptv_player/core/logging/secret_registry.dart';
import 'package:iptv_player/core/secure/credential_store.dart';
import 'package:iptv_player/data/db/app_database.dart';
import 'package:iptv_player/data/sync/epg_importer.dart';
import 'package:iptv_player/data/sync/epg_match_service.dart';
import 'package:iptv_player/data/sync/sync_engine.dart';
import 'package:iptv_player/features/guide/data/db_epg_repository.dart';
import 'package:iptv_player/features/settings/data/db_data_upkeep.dart';
import 'package:iptv_player/features/sources/data/db_source_repository.dart';
import 'package:iptv_player/features/sources/domain/source.dart';
import 'package:logger/logger.dart';

/// ADR-031's compaction, timed on a file database as the app has it (on
/// its own isolate): the fake panel's `large` catalogue (50,000 channels,
/// 30,000 movies, 3,000 series) with a 7-day guide for 2,150 channels.
/// Compacted twice: with the guide (the most there is to rewrite), then
/// once the guide is cleared (what switching the guide off leaves: the
/// room the launch gives back). The UI isolate's longest pause is
/// measured beside each. Skipped unless asked for:
///
///     flutter test --tags benchmark --run-skipped \
///       test/data/db/compaction_benchmark_test.dart
void main() {
  setUpAll(() => HttpOverrides.global = null);

  test(
    'benchmark: VACUUM of the large catalogue, with its guide and after',
    () async {
      final port = await _freePort();
      final scratch = await Directory.systemTemp.createTemp('vacuum_run');
      addTearDown(() => scratch.delete(recursive: true));
      final server = await Process.start('dart', [
        'run',
        'tools/fake_provider/bin/server.dart',
        ...['--profile', 'large', '--port', '$port'],
        ...['--samples', scratch.path, '--run-dir', scratch.path],
      ]);
      addTearDown(server.kill);
      unawaited(server.stdout.drain<void>());
      unawaited(server.stderr.drain<void>());
      await _waitForServer(port);

      final directory = await Directory.systemTemp.createTemp('vacuum_bench');
      addTearDown(() => directory.delete(recursive: true));
      final db = AppDatabase(await openAppDatabase(directory));
      final log = AppLog(output: MemoryOutput(), secrets: SecretRegistry());
      final sources = DbSourceRepository(
        database: db,
        store: InMemoryCredentialStore(),
        secrets: SecretRegistry(),
        log: log,
      );
      final panel = 'http://127.0.0.1:$port';
      final id = (await sources.add(
        SourceDraft(
          type: SourceType.xtream,
          name: 'Large',
          url: panel,
          username: 'test',
          password: 'test',
          epgUrl:
              '$panel/xmltv.php?username=test&password=test'
              '&channels=2150&days=7',
        ),
      )).valueOrNull!.id;
      final sync = SyncEngine(database: db, sources: sources, log: log);
      expect((await sync.sync(id)).isOk, isTrue);
      final guide = DbEpgRepository(db);
      final matches = EpgMatchService(database: db, log: log);
      final importer = EpgImporter(
        database: db,
        guide: guide,
        sources: sources,
        log: log,
        matches: matches,
      );
      expect((await importer.importGuide(id)).isOk, isTrue);

      final upkeep = DbDataUpkeep(db);
      Future<void> compact(String label) async {
        final before = (await upkeep.measure()).valueOrNull!;
        var last = DateTime.now();
        var worst = Duration.zero;
        final baseline = ProcessInfo.currentRss;
        var peak = baseline;
        final ticker = Timer.periodic(const Duration(milliseconds: 16), (_) {
          final now = DateTime.now();
          if (now.difference(last) > worst) worst = now.difference(last);
          last = now;
          final rss = ProcessInfo.currentRss;
          if (rss > peak) peak = rss;
        });
        final clock = Stopwatch()..start();
        final compacted = await upkeep.compact();
        clock.stop();
        ticker.cancel();
        expect(compacted.isOk, isTrue, reason: '${compacted.failureOrNull}');
        const mb = 1024 * 1024;
        // The benchmark's output is its result, read by whoever runs it.
        // ignore: avoid_print
        print(
          '$label: ${clock.elapsedMilliseconds} ms; '
          '${before.bytes ~/ mb} MB (${before.freeBytes ~/ mb} MB free, '
          'log ${before.logBytes ~/ mb} MB) → '
          '${compacted.valueOrNull!.after ~/ mb} MB; worst UI-isolate gap '
          '${worst.inMilliseconds} ms; peak RSS +${(peak - baseline) ~/ mb} '
          'MB',
        );
      }

      await compact('with the guide');
      expect((await guide.clearGuide(id)).isOk, isTrue);
      final cleared = (await upkeep.measure()).valueOrNull!;
      expect(cleared.worthCompacting, isTrue);
      await compact('guide cleared');

      await importer.dispose();
      await matches.dispose();
      await guide.dispose();
      await sync.dispose();
      await log.close();
      await db.close();
    },
    tags: ['benchmark'],
    timeout: const Timeout(Duration(minutes: 15)),
  );
}

Future<int> _freePort() async {
  final socket = await ServerSocket.bind(InternetAddress.loopbackIPv4, 0);
  final port = socket.port;
  await socket.close();
  return port;
}

Future<void> _waitForServer(int port) async {
  final client = HttpClient();
  try {
    for (var attempt = 0; attempt < 240; attempt++) {
      try {
        final request = await client.get('127.0.0.1', port, '/');
        await (await request.close()).drain<void>();
        return;
      } on SocketException {
        await Future<void>.delayed(const Duration(milliseconds: 250));
      }
    }
    fail('the fake provider did not start');
  } finally {
    client.close(force: true);
  }
}
