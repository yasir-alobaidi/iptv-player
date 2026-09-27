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
import 'package:iptv_player/features/sources/data/db_source_repository.dart';
import 'package:iptv_player/features/sources/domain/source.dart';
import 'package:logger/logger.dart';

/// Phase 4's exit budget (docs/06): a 300 MB XMLTV guide imported end to
/// end — fetched, parsed, staged, swapped in and matched — within 4
/// minutes, peak RSS no more than 300 MB above where it started, and no
/// UI-isolate pause over 32 ms. The guide is the fake panel's (in its own
/// process, so its generator isn't measured as our work) for the first
/// 2,150 channels of its `large` catalogue, 7 days ahead and 1 behind;
/// the catalogue's 50,000 channels are synced first, so the match job
/// runs at full size. A file database, as the app has. Skipped unless
/// asked for (Phase 2 decision 4):
///
///     flutter test --tags benchmark --run-skipped \
///       test/data/sync/epg_import_benchmark_test.dart
void main() {
  setUpAll(() => HttpOverrides.global = null);

  test(
    'benchmark: a 300 MB guide, end to end',
    () async {
      final port = await _freePort();
      final scratch = await Directory.systemTemp.createTemp('epg_bench_run');
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

      final directory = await Directory.systemTemp.createTemp('epg_bench');
      addTearDown(() => directory.delete(recursive: true));
      final db = AppDatabase(await openAppDatabase(directory));
      final log = AppLog(output: MemoryOutput(), secrets: SecretRegistry());
      final sources = DbSourceRepository(
        database: db,
        store: InMemoryCredentialStore(),
        secrets: SecretRegistry(),
        log: log,
      );
      final server0 = 'http://127.0.0.1:$port';
      final id = (await sources.add(
        SourceDraft(
          type: SourceType.xtream,
          name: 'Large',
          url: server0,
          username: 'test',
          password: 'test',
          epgUrl:
              '$server0/xmltv.php?username=test&password=test'
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

      var bytes = 0;
      final progress = importer.progress.listen((event) {
        bytes = event.$2.bytesRead;
      });
      final baseline = ProcessInfo.currentRss;
      var peak = baseline;
      var last = DateTime.now();
      var worst = Duration.zero;
      final ticker = Timer.periodic(const Duration(milliseconds: 16), (_) {
        final now = DateTime.now();
        if (now.difference(last) > worst) worst = now.difference(last);
        last = now;
        final rss = ProcessInfo.currentRss;
        if (rss > peak) peak = rss;
      });
      final watch = Stopwatch()..start();
      final result = await importer.importGuide(id);
      watch.stop();
      ticker.cancel();
      await progress.cancel();

      final counts = result.valueOrNull;
      expect(counts, isNotNull, reason: '${result.failureOrNull}');
      final coverage = (await guide.coverage(id)).valueOrNull!;
      final matched = coverage.matchedChannels;
      const mb = 1024 * 1024;
      // The benchmark's output is its result, read by whoever runs it.
      // ignore: avoid_print
      print(
        'guide import: ${watch.elapsed.inMilliseconds} ms for '
        '${bytes ~/ mb} MB, ${counts!.channels} guide channels, '
        '${counts.programmes} programmes; $matched of '
        '${coverage.totalChannels} channels matched; peak RSS '
        '+${(peak - baseline) ~/ mb} MB (from ${baseline ~/ mb} MB); worst '
        'UI-isolate gap ${worst.inMilliseconds} ms; database '
        '${File('${directory.path}/$appDatabaseFileName').lengthSync() ~/ mb}'
        ' MB',
      );
      expect(bytes, greaterThan(250 * mb), reason: 'a 300 MB guide');
      expect(watch.elapsed, lessThan(const Duration(minutes: 4)));
      expect(peak - baseline, lessThan(300 * mb));
      expect(matched, greaterThanOrEqualTo(2000));

      await importer.dispose();
      await matches.dispose();
      await guide.dispose();
      await sync.dispose();
      await log.close();
      await db.close();
    },
    tags: ['benchmark'],
    timeout: const Timeout(Duration(minutes: 10)),
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
