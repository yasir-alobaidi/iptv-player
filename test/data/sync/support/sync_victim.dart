// Not a test: the process `sync_kill_test.dart` starts and then kills with
// SIGKILL in the middle of a sync, to prove a crash can't corrupt the
// database. Plain Dart (`dart run`), like everything under lib/data.
import 'dart:io';

import 'package:iptv_player/core/logging/app_log.dart';
import 'package:iptv_player/core/logging/secret_registry.dart';
import 'package:iptv_player/core/secure/credential_store.dart';
import 'package:iptv_player/data/db/app_database.dart';
import 'package:iptv_player/data/sync/sync_engine.dart';
import 'package:iptv_player/features/sources/data/db_source_repository.dart';
import 'package:iptv_player/features/sources/domain/sync.dart';
import 'package:logger/logger.dart';

/// `dart run …/sync_victim.dart <database dir> <source id>`: syncs the
/// source, printing `written <n>` after every batch, and exits 0 when the
/// sync ends (which the test never lets it reach).
Future<void> main(List<String> args) async {
  final db = AppDatabase(await openAppDatabase(Directory(args[0])));
  final log = AppLog(output: _Silent(), secrets: SecretRegistry());
  final engine = SyncEngine(
    database: db,
    sources: DbSourceRepository(
      database: db,
      store: InMemoryCredentialStore(),
      secrets: SecretRegistry(),
      log: log,
    ),
    log: log,
    batchSize: 1000,
  );
  engine.watch(args[1]).listen((status) {
    if (status case SyncRunning(:final progress)) {
      stdout.writeln('written ${progress.channels}');
    }
  });
  final result = await engine.sync(args[1]);
  stdout.writeln('finished ${result.isOk}');
  await db.close();
  exit(0);
}

final class _Silent extends LogOutput {
  @override
  void output(OutputEvent event) {}
}
