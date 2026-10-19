import 'dart:async';
import 'dart:io';

import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:iptv_player/core/logging/app_log.dart';
import 'package:iptv_player/core/logging/secret_registry.dart';
import 'package:iptv_player/core/secure/credential_store.dart';
import 'package:iptv_player/data/db/app_database.dart';
import 'package:iptv_player/data/sync/sync_engine.dart';
import 'package:iptv_player/features/sources/data/db_source_repository.dart';
import 'package:iptv_player/features/sources/domain/source.dart';
import 'package:logger/logger.dart';
import 'package:path/path.dart' as p;

/// ADR-041's read pool, timed: a screen's page of channels read every
/// 100 ms while the fake panel's `large` catalogue (50,000 channels,
/// 30,000 movies, 3,000 series) syncs, as Live TV reads during a sync.
/// Once on one connection (as before), once as the app opens its
/// database now. Skipped unless asked for:
///
///     flutter test --tags benchmark --run-skipped \
///       test/data/db/read_pool_benchmark_test.dart
void main() {
  setUpAll(() => HttpOverrides.global = null);

  test(
    "benchmark: a screen's reads during a large sync, one connection and "
    'the read pool',
    () async {
      final port = await _freePort();
      final scratch = await Directory.systemTemp.createTemp('read_pool_run');
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

      Future<void> run(
        String label,
        Future<DatabaseConnection> Function(Directory) open,
      ) async {
        final directory = await Directory.systemTemp.createTemp('read_pool');
        final db = AppDatabase(await open(directory));
        final log = AppLog(output: MemoryOutput(), secrets: SecretRegistry());
        final sources = DbSourceRepository(
          database: db,
          store: InMemoryCredentialStore(),
          secrets: SecretRegistry(),
          log: log,
        );
        final id = (await sources.add(
          SourceDraft(
            type: SourceType.xtream,
            name: 'Large',
            url: 'http://127.0.0.1:$port',
            username: 'test',
            password: 'test',
          ),
        )).valueOrNull!.id;
        final sync = SyncEngine(database: db, sources: sources, log: log);

        final reads = <int>[];
        var syncing = true;
        final reading = () async {
          while (syncing) {
            final clock = Stopwatch()..start();
            await db
                .customSelect(
                  'SELECT id, name FROM channels WHERE source_id = ? '
                  'ORDER BY position, id LIMIT 50',
                  variables: [Variable.withString(id)],
                )
                .get();
            reads.add(clock.elapsedMilliseconds);
            await Future<void>.delayed(const Duration(milliseconds: 100));
          }
        }();
        final clock = Stopwatch()..start();
        expect((await sync.sync(id)).isOk, isTrue);
        clock.stop();
        syncing = false;
        await reading;

        reads.sort();
        int at(double q) => reads[((reads.length - 1) * q).round()];
        // The benchmark's output is its result, read by whoever runs it.
        // ignore: avoid_print
        print(
          '$label: sync ${clock.elapsedMilliseconds} ms; ${reads.length} '
          'reads, median ${at(0.5)} ms, 95th ${at(0.95)} ms, longest '
          '${reads.last} ms',
        );
        await sync.dispose();
        await log.close();
        await db.close();
        await directory.delete(recursive: true);
      }

      await run(
        'one connection',
        (directory) async => NativeDatabase.createBackgroundConnection(
          File(p.join(directory.path, appDatabaseFileName)),
          setup: configureAppDatabase,
        ),
      );
      await run('the read pool', openAppDatabase);
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
