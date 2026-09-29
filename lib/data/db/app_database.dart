import 'dart:io';

import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:iptv_player/data/db/app_database.steps.dart';
import 'package:iptv_player/data/db/catalogue_tables.dart';
import 'package:iptv_player/data/db/daos/categories_dao.dart';
import 'package:iptv_player/data/db/daos/channels_dao.dart';
import 'package:iptv_player/data/db/daos/epg_dao.dart';
import 'package:iptv_player/data/db/daos/favorites_dao.dart';
import 'package:iptv_player/data/db/daos/movies_dao.dart';
import 'package:iptv_player/data/db/daos/series_dao.dart';
import 'package:iptv_player/data/db/daos/settings_dao.dart';
import 'package:iptv_player/data/db/daos/sources_dao.dart';
import 'package:iptv_player/data/db/daos/sync_runs_dao.dart';
import 'package:iptv_player/data/db/daos/watch_history_dao.dart';
import 'package:iptv_player/data/db/epg_tables.dart';
import 'package:iptv_player/data/db/tables.dart';
import 'package:iptv_player/data/db/user_tables.dart';
import 'package:path/path.dart' as p;
import 'package:sqlite3/sqlite3.dart' show Database;

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
    FavoriteGroups,
    Favorites,
    WatchHistory,
    EpgImports,
    EpgChannels,
    EpgPrograms,
    EpgChannelsStaging,
    EpgProgramsStaging,
    EpgMappings,
    EpgMatches,
  ],
  include: {'search.drift'},
  daos: [
    SettingsDao,
    SourcesDao,
    SyncRunsDao,
    CategoriesDao,
    ChannelsDao,
    FavoritesDao,
    WatchHistoryDao,
    MoviesDao,
    SeriesDao,
    EpgDao,
  ],
)
class AppDatabase extends _$AppDatabase {
  new(super.e);

  /// A throwaway database for tests. Each call gets its own empty one.
  factory memory() => AppDatabase(NativeDatabase.memory());

  @override
  int get schemaVersion => 7;

  @override
  MigrationStrategy get migration => MigrationStrategy(
    onCreate: (m) async {
      await m.createAll();
    },
    onUpgrade: (m, from, to) async {
      await _upgradeStepByStep(m, from, to);
      // Only when the database ends up at the version this build knows.
      // The app always upgrades all the way; the schema verifier stops
      // at intermediate versions, where a trigger of a later version
      // would be created on a table that does not exist yet.
      if (to == schemaVersion) await _recreateTriggers(m);
    },
    beforeOpen: (details) async {
      // Off by default in SQLite, and every child table added from
      // Phase 2 on relies on it.
      await customStatement('PRAGMA foreign_keys = ON');
    },
  );

  /// Triggers are derived state: they only keep the FTS indexes in step
  /// with the catalogue and the guide. drift's versioned schemas leave
  /// them out, so instead of creating them inside a step, every upgrade
  /// drops them all and creates the current ones once the tables are
  /// final.
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
  from2To3: (m, schema) async {
    // Phase 2 step 8: the HTTP status a failed sync was answered with.
    await m.addColumn(schema.syncRuns, schema.syncRuns.failureStatus);
  },
  from3To4: (m, schema) async {
    // Phase 3: favorites and watch history (docs/02).
    await m.createTable(schema.favorites);
    await m.createTable(schema.watchHistory);
    await m.createIndex(schema.watchHistoryRecent);
  },
  from4To5: (m, schema) async {
    // Phase 4: the EPG store. Parents before children, as above.
    await m.createTable(schema.epgImports);
    await m.createTable(schema.epgChannels);
    await m.createTable(schema.epgPrograms);
    await m.createTable(schema.epgChannelsStaging);
    await m.createTable(schema.epgProgramsStaging);
    await m.createTable(schema.epgMappings);
    await m.createTable(schema.epgMatches);
    await m.createIndex(schema.epgProgramsChannelStart);
    await m.createIndex(schema.epgProgramsStagingRun);
    await m.createIndex(schema.epgMatchesSource);
    await m.create(schema.programsFts);
  },
  from5To6: (m, schema) async {
    // Phase 5: what the details pages and Continue watching need.
    await m.addColumn(schema.series, schema.series.genre);
    await m.addColumn(schema.series, schema.series.castNames);
    await m.addColumn(schema.series, schema.series.director);
    await m.addColumn(schema.series, schema.series.backdropUrl);
    await m.addColumn(schema.movieDetails, schema.movieDetails.videoHeight);
    await m.addColumn(schema.movieDetails, schema.movieDetails.audioChannels);
    await m.addColumn(schema.watchHistory, schema.watchHistory.seriesKey);
    await m.addColumn(schema.watchHistory, schema.watchHistory.dismissed);
    await m.createIndex(schema.moviesAdded);
    await m.createIndex(schema.moviesName);
    await m.createIndex(schema.moviesRating);
  },
  from6To7: (m, schema) async {
    // Phase 6: cleaned channel names, and favorite groups. The names are
    // filled after the upgrade, off this isolate (`ChannelNameFill`).
    await m.addColumn(schema.channels, schema.channels.cleanName);
    await m.addColumn(schema.channels, schema.channels.quality);
    await m.createTable(schema.favoriteGroups);
    // `group_name` goes (nothing ever wrote it) and `group_id` comes, with
    // its foreign key: SQLite adds neither in place, so the table is
    // copied.
    await m.alterTable(
      TableMigration(schema.favorites, newColumns: [schema.favorites.groupId]),
    );
    // The index now holds the shown name. Rebuilt from the table, which
    // has no cleaned name yet: each row joins it as the fill reaches it.
    await m.drop(schema.channelsFts);
    await m.create(schema.channelsFts);
    await m.database.customStatement(
      "INSERT INTO channels_fts(channels_fts) VALUES ('rebuild')",
    );
  },
);

/// Opens the database file on a background isolate, so neither opening
/// it nor any later query touches the UI isolate (hard rule 2).
///
/// A `createBackgroundConnection` rather than a `LazyDatabase` around
/// `createInBackground`: the connection keeps the `DriftIsolate` it talks
/// to, which is what lets the sync isolate connect to the same database
/// directly (`serializableConnection()`). Behind a `LazyDatabase` drift
/// can't see that isolate, and relays every sync write through a proxy
/// on the UI isolate instead (ADR-009, step 5 spike).
///
/// [directory] is created when it does not exist yet; that is the one
/// step that can throw here. A file SQLite can't open fails the first
/// query instead.
Future<DatabaseConnection> openAppDatabase(Directory directory) async {
  await directory.create(recursive: true);
  return NativeDatabase.createBackgroundConnection(
    File(p.join(directory.path, appDatabaseFileName)),
    setup: configureAppDatabase,
  );
}

/// How the app's database file is kept (ADR-013, alongside):
/// - **write-ahead logging** with `synchronous = NORMAL`: a commit waits
///   for no disk sync (the rollback journal waited for several each —
///   slow on Windows, where the CI's sync and import tests ran out of
///   time). A crash of the app loses nothing committed; a power cut may
///   lose the last commits, never the file's consistency;
/// - the log cut back to 64 MB after a checkpoint, as a guide's swap
///   writes hundreds of MB in one transaction.
void configureAppDatabase(Database database) {
  database
    ..execute('PRAGMA journal_mode = WAL')
    ..execute('PRAGMA synchronous = NORMAL')
    ..execute('PRAGMA journal_size_limit = ${64 * 1024 * 1024}');
}
