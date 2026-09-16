import 'dart:io';

import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:iptv_player/data/db/daos/settings_dao.dart';
import 'package:iptv_player/data/db/daos/sources_dao.dart';
import 'package:iptv_player/data/db/tables.dart';
import 'package:path/path.dart' as p;

part 'app_database.g.dart';

/// The file the database lives in, inside the app support directory.
const appDatabaseFileName = 'iptv_player.sqlite';

@DriftDatabase(tables: [Sources, Settings], daos: [SettingsDao, SourcesDao])
class AppDatabase extends _$AppDatabase {
  new(super.e);

  /// A throwaway database for tests. Each call gets its own empty one.
  factory memory() => AppDatabase(NativeDatabase.memory());

  @override
  int get schemaVersion => 1;

  @override
  MigrationStrategy get migration => MigrationStrategy(
    onCreate: (m) async {
      await m.createAll();
    },
    beforeOpen: (details) async {
      // Off by default in SQLite, and every child table added from
      // Phase 2 on relies on it.
      await customStatement('PRAGMA foreign_keys = ON');
    },
  );
}

/// Opens the database file lazily, on a background isolate, so neither
/// opening it nor any later query touches the UI isolate (hard rule 2).
///
/// [directory] is created when it does not exist yet.
QueryExecutor openAppDatabase(Directory directory) => LazyDatabase(() async {
  await directory.create(recursive: true);
  final file = File(p.join(directory.path, appDatabaseFileName));
  return NativeDatabase.createInBackground(file);
});
