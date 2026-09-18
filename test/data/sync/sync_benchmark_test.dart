import 'dart:async';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:iptv_player/core/logging/app_log.dart';
import 'package:iptv_player/core/logging/secret_registry.dart';
import 'package:iptv_player/core/secure/credential_store.dart';
import 'package:iptv_player/data/db/app_database.dart';
import 'package:iptv_player/data/sync/sync_engine.dart';
import 'package:iptv_player/features/sources/data/db_source_repository.dart';
import 'package:iptv_player/features/sources/domain/source.dart';
import 'package:iptv_player/features/sources/domain/sync.dart';
import 'package:logger/logger.dart';

/// docs/06's sync budget: the `large` profile (50k channels, 30k movies,
/// 3k series) synced end to end within 60 s, measured with the fake
/// provider in its own process — in-process, its JSON encoding would
/// count as our jank. Skipped unless asked for (Phase 2 decision 4):
///
///     flutter test --tags benchmark --run-skipped \
///       test/data/sync/sync_benchmark_test.dart
void main() {
  setUpAll(() => HttpOverrides.global = null);

  test(
    'benchmark: the large profile, first sync and re-sync',
    () async {
      final port = await _freePort();
      final server = await Process.start('dart', [
        'run',
        'tools/fake_provider/bin/server.dart',
        '--profile',
        'large',
        '--port',
        '$port',
      ]);
      addTearDown(server.kill);
      unawaited(server.stdout.drain<void>());
      unawaited(server.stderr.drain<void>());
      await _waitForServer(port);

      final directory = await Directory.systemTemp.createTemp('sync_bench');
      addTearDown(() => directory.delete(recursive: true));
      final db = AppDatabase(await openAppDatabase(directory));
      final log = AppLog(output: MemoryOutput(), secrets: SecretRegistry());
      final repository = DbSourceRepository(
        database: db,
        store: InMemoryCredentialStore(),
        secrets: SecretRegistry(),
        log: log,
      );
      final engine = SyncEngine(database: db, sources: repository, log: log);
      final id = (await repository.add(
        SourceDraft(
          type: SourceType.xtream,
          name: 'Large',
          url: 'http://127.0.0.1:$port',
          username: 'test',
          password: 'test',
        ),
      )).valueOrNull!.id;

      for (final label in ['first sync', 're-sync']) {
        var last = DateTime.now();
        var worst = Duration.zero;
        final ticker = Timer.periodic(const Duration(milliseconds: 16), (_) {
          final now = DateTime.now();
          if (now.difference(last) > worst) worst = now.difference(last);
          last = now;
        });
        final result = await engine.sync(id);
        ticker.cancel();
        final report = result.valueOrNull;
        expect(report, isNotNull, reason: '${result.failureOrNull}');
        _print(label, report!, worst);
        expect(report.channels, 50000);
        expect(report.movies, 30000);
        expect(report.duration, lessThan(const Duration(seconds: 60)));
      }

      await engine.dispose();
      await log.close();
      await db.close();
      final size = File('${directory.path}/$appDatabaseFileName').lengthSync();
      // The benchmark's output is its result, read by whoever runs it.
      // ignore: avoid_print
      print(
        'database ${size ~/ (1024 * 1024)} MB; max RSS '
        '${ProcessInfo.maxRss ~/ (1024 * 1024)} MB',
      );
    },
    tags: ['benchmark'],
    timeout: const Timeout(Duration(minutes: 5)),
  );

  test(
    'benchmark: a 200k-entry playlist file',
    () async {
      final directory = await Directory.systemTemp.createTemp('sync_bench');
      addTearDown(() => directory.delete(recursive: true));
      final playlist = File('${directory.path}/big.m3u');
      final sink = playlist.openWrite()..writeln('#EXTM3U');
      for (var i = 0; i < 200000; i++) {
        final (name, path) = switch (i % 10) {
          0 => ('Film $i (2020)', 'movie/u/p/$i.mkv'),
          1 => ('Show ${i ~/ 100} S01 E${i % 100 ~/ 10}', 'series/u/p/$i.mkv'),
          _ => ('Channel $i', 'live/u/p/$i.ts'),
        };
        sink
          ..writeln(
            '#EXTINF:-1 tvg-id="c$i" tvg-logo="http://logo.test/$i.png" '
            'group-title="Group ${i % 300}",$name',
          )
          ..writeln('http://tv.test:8080/$path');
      }
      await sink.close();

      final db = AppDatabase(await openAppDatabase(directory));
      final log = AppLog(output: MemoryOutput(), secrets: SecretRegistry());
      final repository = DbSourceRepository(
        database: db,
        store: InMemoryCredentialStore(),
        secrets: SecretRegistry(),
        log: log,
      );
      final engine = SyncEngine(database: db, sources: repository, log: log);
      final id = (await repository.add(
        SourceDraft(type: SourceType.m3uFile, name: 'Big', url: playlist.path),
      )).valueOrNull!.id;

      var last = DateTime.now();
      var worst = Duration.zero;
      final ticker = Timer.periodic(const Duration(milliseconds: 16), (_) {
        final now = DateTime.now();
        if (now.difference(last) > worst) worst = now.difference(last);
        last = now;
      });
      final result = await engine.sync(id);
      ticker.cancel();
      final report = result.valueOrNull;
      expect(report, isNotNull, reason: '${result.failureOrNull}');
      final megabytes = playlist.lengthSync() ~/ (1024 * 1024);
      _print('M3U $megabytes MB', report!, worst);
      // ignore: avoid_print, the benchmark's output is its result.
      print(
        '  and ${report.episodes} episodes; max RSS '
        '${ProcessInfo.maxRss ~/ (1024 * 1024)} MB',
      );
      expect(report.channels + report.movies + report.episodes, 200000);

      await engine.dispose();
      await log.close();
      await db.close();
    },
    tags: ['benchmark'],
    timeout: const Timeout(Duration(minutes: 5)),
  );
}

void _print(String label, SyncReport report, Duration worst) {
  // ignore: avoid_print, the benchmark's output is its result.
  print(
    '$label: ${report.duration.inMilliseconds} ms for ${report.channels} '
    'channels, ${report.movies} movies, ${report.series} series, '
    '${report.categories} categories; removed ${report.removed}; worst '
    'UI-isolate gap ${worst.inMilliseconds} ms',
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
    for (var attempt = 0; attempt < 120; attempt++) {
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
