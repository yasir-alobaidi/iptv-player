import 'dart:async';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:iptv_player/core/logging/app_log.dart';
import 'package:iptv_player/core/logging/secret_registry.dart';
import 'package:iptv_player/core/secure/credential_store.dart';
import 'package:iptv_player/data/db/app_database.dart';
import 'package:iptv_player/data/settings/settings_repository.dart';
import 'package:iptv_player/data/sync/channel_name_fill.dart';
import 'package:iptv_player/data/sync/epg_importer.dart';
import 'package:iptv_player/data/sync/epg_match_service.dart';
import 'package:iptv_player/data/sync/sync_engine.dart';
import 'package:iptv_player/features/guide/data/db_epg_repository.dart';
import 'package:iptv_player/features/search/data/db_search_repository.dart';
import 'package:iptv_player/features/search/domain/search.dart';
import 'package:iptv_player/features/sources/data/db_source_repository.dart';
import 'package:iptv_player/features/sources/domain/source.dart';
import 'package:logger/logger.dart';

/// Phase 6 step 3's measurement: a search over the fake panel's `large`
/// catalogue (50,000 channels, 30,000 movies, 3,000 series) and a guide
/// for its first 2,150 channels, 7 days ahead and 1 behind (about 600,000
/// programmes), on a file database as the app has. Each text from 1 to 20
/// characters is searched several times; the time is the whole
/// `search()`, all four groups. The fake panel runs in its own process.
/// Skipped unless asked for:
///
///     flutter test --tags benchmark --run-skipped \
///       test/features/search/search_benchmark_test.dart
void main() {
  setUpAll(() => HttpOverrides.global = null);

  test(
    'benchmark: search over the large catalogue and a 7-day guide',
    () async {
      final port = await _freePort();
      final scratch = await Directory.systemTemp.createTemp('search_bench_run');
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

      // SEARCH_BENCH_DIR keeps the database there, to study the queries
      // with sqlite3 afterwards.
      final keep = Platform.environment['SEARCH_BENCH_DIR'];
      final directory = keep == null
          ? await Directory.systemTemp.createTemp('search_bench')
          : await Directory(keep).create(recursive: true);
      if (keep == null) addTearDown(() => directory.delete(recursive: true));
      final db = AppDatabase(await openAppDatabase(directory));
      final log = AppLog(output: MemoryOutput(), secrets: SecretRegistry());
      final sources = DbSourceRepository(
        database: db,
        store: InMemoryCredentialStore(),
        secrets: SecretRegistry(),
        log: log,
      );
      final origin = 'http://127.0.0.1:$port';
      final id = (await sources.add(
        SourceDraft(
          type: SourceType.xtream,
          name: 'Large',
          url: origin,
          username: 'test',
          password: 'test',
          epgUrl:
              '$origin/xmltv.php?username=test&password=test'
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
      final imported = await importer.importGuide(id);
      expect(imported.isOk, isTrue, reason: '${imported.failureOrNull}');
      // Nothing to fill after a v7 sync; proves it costs one query.
      final fill = ChannelNameFill(database: db, log: log);
      expect((await fill.run()).valueOrNull, 0);

      final repo = DbSearchRepository(db, SettingsRepository(db));
      final now = DateTime.now().toUtc();
      const phrases = [
        'compass tonight special',
        'the silent harbour',
        'sports arena cobalt',
        'news',
      ];
      final texts = <String>{
        for (final phrase in phrases)
          for (var n = 1; n <= 20 && n <= phrase.length; n++)
            phrase.substring(0, n).trimRight(),
      }..removeWhere((t) => t.isEmpty);

      // Warm the page cache the way a first keystroke would.
      await repo.search('a', now: now, preferredSourceId: id);

      var last = DateTime.now();
      var worstGap = Duration.zero;
      final ticker = Timer.periodic(const Duration(milliseconds: 4), (_) {
        final at = DateTime.now();
        if (at.difference(last) > worstGap) worstGap = at.difference(last);
        last = at;
      });
      final byLength = <int, List<int>>{};
      final slowest = <(int, String)>[];
      for (var round = 0; round < 3; round++) {
        for (final text in texts) {
          final watch = Stopwatch()..start();
          final result = await repo.search(
            text,
            now: now,
            preferredSourceId: id,
          );
          watch.stop();
          expect(result.isOk, isTrue, reason: '$text: ${result.failureOrNull}');
          final us = watch.elapsedMicroseconds;
          (byLength[text.length] ??= []).add(us);
          slowest.add((us, text));
        }
      }
      ticker.cancel();
      slowest.sort((a, b) => b.$1.compareTo(a.$1));
      final all = [for (final list in byLength.values) ...list]..sort();
      String ms(int us) => (us / 1000).toStringAsFixed(1);

      final lines = StringBuffer()
        ..writeln(
          'search: ${all.length} queries over ${texts.length} texts; '
          'median ${ms(all[all.length ~/ 2])} ms, '
          'p95 ${ms(all[(all.length * 95) ~/ 100])} ms, '
          'max ${ms(all.last)} ms; worst UI-isolate gap '
          '${worstGap.inMilliseconds} ms',
        );
      for (final length in byLength.keys.toList()..sort()) {
        final list = byLength[length]!..sort();
        lines.writeln(
          '  $length chars: median ${ms(list[list.length ~/ 2])} ms, '
          'max ${ms(list.last)} ms',
        );
      }
      final worst = [
        for (final (us, text) in slowest.take(6)) '"$text" ${ms(us)} ms',
      ];
      lines.writeln('  slowest: ${worst.join(', ')}');
      final sample = (await repo.search(
        'compass',
        now: now,
        preferredSourceId: id,
      )).valueOrNull!;
      lines.writeln(
        '  "compass": ${sample.channels.hits.length} channels, '
        '${sample.programmes.hits.length} programmes, '
        '${sample.movies.hits.length} movies, '
        '${sample.series.hits.length} series',
      );
      // The benchmark's output is its result, read by whoever runs it.
      // ignore: avoid_print
      print(lines);
      expect(searchGroupSize, 5);

      await fill.dispose();
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
