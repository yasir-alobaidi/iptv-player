import 'dart:io';

import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:iptv_player/data/db/app_database.steps.dart';
import 'package:iptv_player/data/db/catalogue_tables.dart';
import 'package:iptv_player/data/db/daos/categories_dao.dart';
import 'package:iptv_player/data/db/daos/channels_dao.dart';
import 'package:iptv_player/data/db/daos/movies_dao.dart';
import 'package:iptv_player/data/db/daos/series_dao.dart';
import 'package:iptv_player/data/db/daos/settings_dao.dart';
import 'package:iptv_player/data/db/daos/sources_dao.dart';
import 'package:iptv_player/data/db/daos/sync_runs_dao.dart';
import 'package:iptv_player/data/db/tables.dart';
import 'package:path/path.dart' as p;

part 'app_database.g.dart';

/// The file the database lives in, inside the app support directory.
const appDatabaseFileName = 'iptv_player.sqlite';

@DriftDatabase(
  tables: [
    Sources,
    Settings,
    SyncRuns,
    Categories,
    Channels,
    Movies,
    MovieDetails,
    Series,
    Episodes,
  ],
  include: {'search.drift'},
  daos: [
    SettingsDao,
    SourcesDao,
    SyncRunsDao,
    CategoriesDao,
    ChannelsDao,
    MoviesDao,
    SeriesDao,
  ],
)
class AppDatabase extends _$AppDatabase {
  new(super.e);

  /// A throwaway database for tests. Each call gets its own empty one.
  factory memory() => AppDatabase(NativeDatabase.memory());

  @override
  int get schemaVersion => 2;

  @override
  MigrationStrategy get migration => MigrationStrategy(
    onCreate: (m) async {
      await m.createAll();
    },
    onUpgrade: (m, from, to) async {
      await _upgradeStepByStep(m, from, to);
      await _recreateTriggers(m);
    },
    beforeOpen: (details) async {
      // Off by default in SQLite, and every child table added from
      // Phase 2 on relies on it.
      await customStatement('PRAGMA foreign_keys = ON');
    },
  );

  /// Triggers are derived state: they only keep the FTS indexes in step
  /// with the catalogue. drift's versioned schemas leave them out, so
  /// instead of creating them inside a step, every upgrade drops them all
  /// and creates the current ones once the tables are final.
  Future<void> _recreateTriggers(Migrator m) async {
    for (final trigger in allSchemaEntities.whereType<Trigger>()) {
      await m.drop(trigger);
      await m.create(trigger);
    }
  }
}

final OnUpgrade _upgradeStepByStep = stepByStep(
  from1To2: (m, schema) async {
    // Phase 2: the catalogue, its sync bookkeeping, and search. Order
    // matters only for foreign keys: parents before children.
    await m.createTable(schema.syncRuns);
    await m.createTable(schema.categories);
    await m.createTable(schema.channels);
    await m.createTable(schema.movies);
    await m.createTable(schema.movieDetails);
    await m.createTable(schema.series);
    await m.createTable(schema.episodes);
    await m.createIndex(schema.categoriesSourceKind);
    await m.createIndex(schema.channelsCategory);
    await m.createIndex(schema.moviesCategory);
    await m.createIndex(schema.seriesCategory);
    await m.create(schema.channelsFts);
    await m.create(schema.moviesFts);
    await m.create(schema.seriesFts);
  },
);

/// Opens the database file lazily, on a background isolate, so neither
/// opening it nor any later query touches the UI isolate (hard rule 2).
///
/// [directory] is created when it does not exist yet.
QueryExecutor openAppDatabase(Directory directory) => LazyDatabase(() async {
  await directory.create(recursive: true);
  final file = File(p.join(directory.path, appDatabaseFileName));
  return NativeDatabase.createInBackground(file);
});
