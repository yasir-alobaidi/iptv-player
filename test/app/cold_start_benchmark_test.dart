import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:iptv_player/core/logging/app_log.dart';
import 'package:iptv_player/core/logging/secret_registry.dart';
import 'package:iptv_player/core/secure/credential_store.dart';
import 'package:iptv_player/data/db/app_database.dart';
import 'package:iptv_player/data/db/user_tables.dart';
import 'package:iptv_player/data/sync/sync_engine.dart';
import 'package:iptv_player/features/sources/data/db_source_repository.dart';
import 'package:iptv_player/features/sources/domain/source.dart';
import 'package:logger/logger.dart';

/// docs/06: cold start to an interactive Home with cached data, ≤ 2.0 s.
///
/// The app's own profile build, launched as a person launches it, on one
/// data folder holding the `large` catalogue (50,000 channels, 30,000
/// movies, 3,000 series) synced, three movies in Continue watching,
/// favorite and recently watched channels, and Home's pictures cached by
/// a first launch that isn't counted. Each launch is timed from
/// `Process.start` to the line Home logs on its first frame with its rows
/// (`LaunchMark`), by the log line's own timestamp: the same clock, so the
/// log's half-second flush doesn't count.
///
///     flutter build linux --profile
///     flutter test --tags benchmark --run-skipped \
///       test/app/cold_start_benchmark_test.dart
///
/// Run it on the real display: the app's window opens and closes six
/// times. The launched app gets a D-Bus session address that leads
/// nowhere, so it can't reach the keyring: a sync there would prune the
/// real app's secrets as orphans of this database.
void main() {
  setUpAll(() => HttpOverrides.global = null);

  test(
    'benchmark: cold start to Home with the large catalogue cached',
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
      addTearDown(panel.kill);
      unawaited(panel.stdout.drain<void>());
      unawaited(panel.stderr.drain<void>());
      await _waitForServer(port);

      final root = await Directory.systemTemp.createTemp('cold_start');
      addTearDown(() => root.delete(recursive: true));
      final dataHome = Directory('${root.path}/data');
      final appDirectory = Directory('${dataHome.path}/$_applicationId');
      await appDirectory.create(recursive: true);
      await _prepare(appDirectory, 'http://127.0.0.1:$port');

      final environment = {
        'XDG_DATA_HOME': dataHome.path,
        'XDG_CACHE_HOME': '${root.path}/cache',
        'DBUS_SESSION_BUS_ADDRESS': 'unix:path=${root.path}/no-bus',
      };
      final log = File('${appDirectory.path}/logs/app.log');

      final launches = <_Launch>[];
      for (var i = 0; i <= _measured; i++) {
        // The first launch fills the picture cache and isn't counted.
        final warmUp = i == 0;
        final launch = await _launch(binary, environment, log, warmUp: warmUp);
        if (!warmUp) launches.add(launch);
        // The measurement is this test's output, read by whoever runs it.
        // ignore: avoid_print
        print('${warmUp ? 'warm-up' : 'launch $i'}: $launch');
      }

      final toHome = [for (final l in launches) l.toHome]..sort();
      final toMain = [for (final l in launches) l.toMain]..sort();
      final median = toHome[toHome.length ~/ 2];
      // ignore: avoid_print, the measurement is this test's output
      print(
        'cold start to Home: median ${median.inMilliseconds} ms, worst '
        '${toHome.last.inMilliseconds} ms; to main(): median '
        '${toMain[toMain.length ~/ 2].inMilliseconds} ms '
        '($_measured launches, profile build)',
      );
      expect(median, lessThanOrEqualTo(const Duration(seconds: 2)));
    },
    tags: ['benchmark'],
    timeout: const Timeout(Duration(minutes: 6)),
  );
}

/// The Linux runner's application id: the app's folders are named by it.
const _applicationId = 'io.github.yasiralobaidi.iptvplayer';

const _measured = 5;

/// The catalogue synced into the app's own database file, and something
/// in every Home row.
Future<void> _prepare(Directory directory, String panelUrl) async {
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
    ),
  )).valueOrNull!.id;
  final synced = await engine.sync(id);
  expect(synced.valueOrNull, isNotNull, reason: '${synced.failureOrNull}');

  Future<List<String>> keys(String table) async => [
    for (final row
        in await db
            .customSelect('SELECT remote_key FROM $table ORDER BY id LIMIT 8')
            .get())
      row.read<String>('remote_key'),
  ];
  final now = DateTime.now();
  final channels = await keys('channels');
  for (final (i, key) in channels.indexed) {
    await db.favoritesDao.add(UserItemType.live, id, key, now);
    if (i.isEven) {
      await db.watchHistoryDao.touch(
        UserItemType.live,
        id,
        key,
        now.subtract(Duration(minutes: i)),
      );
    }
  }
  for (final (i, key) in (await keys('movies')).take(3).indexed) {
    await db.watchHistoryDao.touch(
      UserItemType.movie,
      id,
      key,
      now.subtract(Duration(hours: i + 1)),
      positionMs: (20 + i * 10) * 60000,
      durationMs: 100 * 60000,
      completed: false,
    );
  }
  await engine.dispose();
  await log.close();
  await db.close();
}

/// One launch: started, timed to Home's line, stopped.
Future<_Launch> _launch(
  File binary,
  Map<String, String> environment,
  File log, {
  required bool warmUp,
}) async {
  final from = log.existsSync() ? log.lengthSync() : 0;
  final started = DateTime.now();
  final process = await Process.start(
    binary.absolute.path,
    const [],
    environment: environment,
  );
  unawaited(process.stdout.drain<void>());
  unawaited(process.stderr.drain<void>());
  try {
    final deadline = started.add(const Duration(seconds: 30));
    while (DateTime.now().isBefore(deadline)) {
      final lines = log.existsSync() ? _linesFrom(log, from) : const <String>[];
      final home = lines.where((l) => l.contains(_homeLine)).firstOrNull;
      final main = lines.where((l) => l.contains(_mainLine)).firstOrNull;
      if (home != null && main != null) {
        // Home's pictures are fetched after its first frame: a moment for
        // the cache, then out before the launch sync would start.
        if (warmUp) await Future<void>.delayed(const Duration(seconds: 3));
        return _Launch(
          toMain: _timeOf(main).difference(started),
          toHome: _timeOf(home).difference(started),
          reported: home.substring(home.indexOf(_homeLine)),
        );
      }
      await Future<void>.delayed(const Duration(milliseconds: 25));
    }
    fail('Home never logged "$_homeLine" (exit ${await _exitCode(process)})');
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
}

const _homeLine = '[startup] Home is on screen';
const _mainLine = '[bootstrap] Starting IPTV Player';

List<String> _linesFrom(File log, int offset) {
  final bytes = log.readAsBytesSync();
  if (bytes.length <= offset) return const [];
  return const LineSplitter().convert(
    utf8.decode(bytes.sublist(offset), allowMalformed: true),
  );
}

/// A log line starts with its UTC time (`AppLog`).
DateTime _timeOf(String line) => DateTime.parse(line.split(' ').first);

Future<String> _exitCode(Process process) => process.exitCode
    .timeout(const Duration(milliseconds: 1), onTimeout: () => -1)
    .then((code) => code < 0 ? 'still running' : '$code');

final class _Launch {
  const new({
    required this.toMain,
    required this.toHome,
    required this.reported,
  });

  final Duration toMain;
  final Duration toHome;

  /// The app's own line, with its time since main().
  final String reported;

  @override
  String toString() =>
      'Home ${toHome.inMilliseconds} ms after the launch, main() at '
      '${toMain.inMilliseconds} ms ("$reported")';
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
  } finally {
    client.close(force: true);
  }
  fail('the fake provider did not start');
}
