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

/// docs/06: idle memory after a sync with a guide, ≤ 450 MB.
///
/// The app's own profile build, launched as a person launches it, on a
/// data folder holding the `large` catalogue (50,000 channels, 30,000
/// movies, 3,000 series) synced and a ~300 MB guide imported (about
/// 600,000 programmes), and left alone on Home. Its resident memory is
/// read from `/proc/<pid>/status` once a minute for IDLE_MINUTES
/// (default 10); the number is the last minute's.
///
///     flutter build linux --profile
///     flutter test --tags benchmark --run-skipped \
///       test/app/idle_memory_benchmark_test.dart
///
/// Run it on the real display: the app's window stays open for the ten
/// minutes. The launched app gets a D-Bus session address that leads
/// nowhere, so it can't reach the keyring (see the cold start's note),
/// and the fake panel is stopped before the launch, so the app's own
/// launch sync and guide refresh find nobody and nothing is added to what
/// was prepared.
void main() {
  setUpAll(() => HttpOverrides.global = null);

  final minutes =
      int.tryParse(Platform.environment['IDLE_MINUTES'] ?? '') ?? 10;

  test(
    'benchmark: idle memory on Home, the large catalogue and its guide',
    () async {
      final binary = File('build/linux/x64/profile/bundle/iptv_player');
      expect(
        binary.existsSync(),
        isTrue,
        reason: 'build it first: flutter build linux --profile',
      );

      final port = await _freePort();
      final panel = await Process.start('dart', [
        'run',
        'tools/fake_provider/bin/server.dart',
        ...['--profile', 'large', '--port', '$port'],
      ]);
      unawaited(panel.stdout.drain<void>());
      unawaited(panel.stderr.drain<void>());
      addTearDown(panel.kill);
      await _waitForServer(port);

      final root = await Directory.systemTemp.createTemp('idle_memory');
      addTearDown(() => root.delete(recursive: true));
      final dataHome = Directory('${root.path}/data');
      final appDirectory = Directory('${dataHome.path}/$_applicationId');
      await appDirectory.create(recursive: true);
      final prepared = await _prepare(appDirectory, 'http://127.0.0.1:$port');
      // The app finds nobody to sync from: what it holds is what it idles
      // with.
      panel.kill();
      await panel.exitCode;

      final process = await Process.start(
        binary.absolute.path,
        const [],
        environment: {
          'XDG_DATA_HOME': dataHome.path,
          'XDG_CACHE_HOME': '${root.path}/cache',
          'DBUS_SESSION_BUS_ADDRESS': 'unix:path=${root.path}/no-bus',
        },
      );
      unawaited(process.stdout.drain<void>());
      unawaited(process.stderr.drain<void>());
      final samples = <int>[];
      try {
        for (var minute = 1; minute <= minutes; minute++) {
          await Future<void>.delayed(const Duration(minutes: 1));
          final rss = _rssMb(process.pid);
          expect(rss, isNotNull, reason: 'the app is gone at minute $minute');
          samples.add(rss!);
          // The measurement is this test's output, read by whoever runs it.
          // ignore: avoid_print
          print('idle minute $minute: $rss MB');
        }
      } finally {
        process.kill();
        await process.exitCode.timeout(
          const Duration(seconds: 5),
          onTimeout: () {
            process.kill(ProcessSignal.sigkill);
            return -1;
          },
        );
      }
      // ignore: avoid_print, the measurement is this test's output
      print(
        'idle memory on Home after $minutes min: ${samples.last} MB '
        '(highest ${samples.reduce((a, b) => a > b ? a : b)} MB; $prepared; '
        'profile build)',
      );
      expect(samples.last, lessThanOrEqualTo(450));
    },
    tags: ['benchmark'],
    timeout: Timeout(Duration(minutes: minutes + 8)),
  );
}

/// The Linux runner's application id: the app's folders are named by it.
const _applicationId = 'io.github.yasiralobaidi.iptvplayer';

/// The catalogue synced and the guide imported into the app's own
/// database file. Returns what it holds, in words.
Future<String> _prepare(Directory directory, String panelUrl) async {
  final db = AppDatabase(await openAppDatabase(directory));
  final log = AppLog(output: MemoryOutput(), secrets: SecretRegistry());
  final sources = DbSourceRepository(
    database: db,
    store: InMemoryCredentialStore(),
    secrets: SecretRegistry(),
    log: log,
  );
  final engine = SyncEngine(database: db, sources: sources, log: log);
  final id = (await sources.add(
    SourceDraft(
      type: SourceType.xtream,
      name: 'Large',
      url: panelUrl,
      username: 'test',
      password: 'test',
      epgUrl:
          '$panelUrl/xmltv.php?username=test&password=test'
          '&channels=2150&days=7',
    ),
  )).valueOrNull!.id;
  final synced = await engine.sync(id);
  expect(synced.valueOrNull, isNotNull, reason: '${synced.failureOrNull}');

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
  final counts = imported.valueOrNull;
  expect(counts, isNotNull, reason: '${imported.failureOrNull}');
  final holds =
      '50,000 channels, ${counts!.programmes} programmes on '
      '${counts.channels} guide channels';
  await importer.dispose();
  await matches.dispose();
  await guide.dispose();
  await engine.dispose();
  await log.close();
  await db.close();
  return holds;
}

/// The resident memory of [pid] in MB, from the kernel; null when it is
/// gone.
int? _rssMb(int pid) {
  final status = File('/proc/$pid/status');
  if (!status.existsSync()) return null;
  for (final line in status.readAsLinesSync()) {
    if (!line.startsWith('VmRSS:')) continue;
    final kb = int.tryParse(line.split(RegExp(r'\s+'))[1]);
    return kb == null ? null : kb ~/ 1024;
  }
  return null;
}

Future<int> _freePort() async {
  final socket = await ServerSocket.bind(InternetAddress.loopbackIPv4, 0);
  final port = socket.port;
  await socket.close();
  return port;
}

Future<void> _waitForServer(int port) async {
  final deadline = DateTime.now().add(const Duration(seconds: 60));
  while (DateTime.now().isBefore(deadline)) {
    try {
      final socket = await Socket.connect(
        InternetAddress.loopbackIPv4,
        port,
        timeout: const Duration(seconds: 1),
      );
      socket.destroy();
      return;
    } on Object {
      await Future<void>.delayed(const Duration(milliseconds: 200));
    }
  }
  fail('the fake panel never answered on port $port');
}
