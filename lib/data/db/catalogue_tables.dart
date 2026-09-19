import 'package:drift/drift.dart';
import 'package:iptv_player/core/catalogue_kind.dart';
import 'package:iptv_player/data/db/tables.dart';

export 'package:iptv_player/core/catalogue_kind.dart';

/// How a sync run ended. A run that is still `running` when the app
/// starts was interrupted, and is treated as failed.
enum SyncOutcome { running, succeeded, failed, cancelled }

/// One attempt to sync a source. Its id is the run marker that
/// mark-and-sweep compares against: every row a run upserts gets
/// `seen_run = id`, and only a run that succeeded sweeps the rows it did
/// not see (docs/02).
@DataClassName('SyncRunRow')
class SyncRuns extends Table {
  IntColumn get id => integer().autoIncrement()();

  TextColumn get sourceId =>
      text().references(Sources, #id, onDelete: KeyAction.cascade)();

  DateTimeColumn get startedAt => dateTime()();

  DateTimeColumn get finishedAt => dateTime().nullable()();

  TextColumn get outcome =>
      textEnum<SyncOutcome>().withDefault(const Constant('running'))();

  /// A failure kind for the UI to phrase (`failureMessage()`), never raw
  /// exception text, which can carry a credential-bearing URL.
  TextColumn get failure => text().nullable()();

  /// The HTTP status the server answered a failed run with, if any, so
  /// Settings can say what the server said (schema v3). Only the number:
  /// the failure's detail text can carry a credential.
  IntColumn get failureStatus => integer().nullable()();

  /// Item counts per stage, for Settings → Sources and the diagnostics
  /// export.
  TextColumn get countsJson => text().nullable()();
}

/// Columns every synced provider item has. `remote_key` is the provider's
/// id, or the stable identity hash for M3U items (docs/02); with
/// `source_id` it is what user data is keyed by, so it survives re-syncs.
mixin _ProviderItem on Table {
  TextColumn get sourceId =>
      text().references(Sources, #id, onDelete: KeyAction.cascade)();

  TextColumn get remoteKey => text()();

  /// The provider's own order, rewritten by every sync.
  IntColumn get position => integer().withDefault(const Constant(0))();

  /// The sync run that last saw this row. See [SyncRuns].
  IntColumn get seenRun => integer().nullable()();
}

@DataClassName('CategoryRow')
@TableIndex(name: 'categories_source_kind', columns: {#sourceId, #kind})
class Categories extends Table with _ProviderItem {
  IntColumn get id => integer().autoIncrement()();

  TextColumn get kind => textEnum<CatalogueKind>()();

  TextColumn get name => text()();

  /// The user's rename. Sync never writes it.
  TextColumn get displayName => text().nullable()();

  /// Sync never writes it.
  BoolColumn get isHidden => boolean().withDefault(const Constant(false))();

  /// The user's order, set by the Categories manager; null until the user
  /// reorders, and categories without one follow in [position] order.
  /// Sync never writes it.
  IntColumn get sortOrder => integer().nullable()();

  @override
  List<Set<Column<Object>>> get uniqueKeys => [
    {sourceId, kind, remoteKey},
  ];
}

@DataClassName('ChannelRow')
@TableIndex(name: 'channels_category', columns: {#categoryId})
class Channels extends Table with _ProviderItem {
  IntColumn get id => integer().autoIncrement()();

  /// Null when the provider gave none or pointed at a category it does
  /// not have; the UI files those under "Uncategorized".
  IntColumn get categoryId => integer().nullable().references(
    Categories,
    #id,
    onDelete: KeyAction.setNull,
  )();

  IntColumn get number => integer().nullable()();

  TextColumn get name => text()();

  /// The user's rename. Sync never writes it.
  TextColumn get displayName => text().nullable()();

  TextColumn get logoUrl => text().nullable()();

  /// Xtream `epg_channel_id` or M3U `tvg-id`.
  TextColumn get epgKey => text().nullable()();

  IntColumn get archiveDays => integer().withDefault(const Constant(0))();

  /// M3U only: the stream URL with the source's credentials replaced by
  /// placeholders. Xtream URLs are built from the source instead.
  TextColumn get streamUrl => text().nullable()();

  /// M3U only: per-item options (`#EXTVLCOPT` user agent and referrer,
  /// catch-up attributes), as JSON.
  TextColumn get extrasJson => text().nullable()();

  /// Sync never writes it.
  BoolColumn get isHidden => boolean().withDefault(const Constant(false))();

  DateTimeColumn get addedAt => dateTime().nullable()();

  @override
  List<Set<Column<Object>>> get uniqueKeys => [
    {sourceId, remoteKey},
  ];
}

@DataClassName('MovieRow')
@TableIndex(name: 'movies_category', columns: {#categoryId})
class Movies extends Table with _ProviderItem {
  IntColumn get id => integer().autoIncrement()();

  IntColumn get categoryId => integer().nullable().references(
    Categories,
    #id,
    onDelete: KeyAction.setNull,
  )();

  TextColumn get name => text()();

  TextColumn get posterUrl => text().nullable()();

  /// Out of 10, as Xtream sends it.
  RealColumn get rating => real().nullable()();

  IntColumn get year => integer().nullable()();

  /// The container extension (`mkv`, `mp4`), which the stream URL needs.
  TextColumn get ext => text().nullable()();

  /// See [Channels.streamUrl].
  TextColumn get streamUrl => text().nullable()();

  TextColumn get extrasJson => text().nullable()();

  DateTimeColumn get addedAt => dateTime().nullable()();

  @override
  List<Set<Column<Object>>> get uniqueKeys => [
    {sourceId, remoteKey},
  ];
}

/// `get_vod_info`, fetched lazily when a details page opens. Keyed by the
/// movie's row id, so it lives exactly as long as the movie does.
@DataClassName('MovieDetailsRow')
class MovieDetails extends Table {
  IntColumn get movieId =>
      integer().references(Movies, #id, onDelete: KeyAction.cascade)();

  TextColumn get plot => text().nullable()();

  /// `cast` in the Xtream payload; not a column name, because CAST is SQL.
  TextColumn get castNames => text().nullable()();

  TextColumn get director => text().nullable()();

  TextColumn get genre => text().nullable()();

  IntColumn get runtimeMinutes => integer().nullable()();

  TextColumn get backdropUrl => text().nullable()();

  DateTimeColumn get fetchedAt => dateTime()();

  @override
  Set<Column<Object>> get primaryKey => {movieId};
}

@DataClassName('SeriesRow')
@TableIndex(name: 'series_category', columns: {#categoryId})
class Series extends Table with _ProviderItem {
  IntColumn get id => integer().autoIncrement()();

  IntColumn get categoryId => integer().nullable().references(
    Categories,
    #id,
    onDelete: KeyAction.setNull,
  )();

  TextColumn get name => text()();

  TextColumn get posterUrl => text().nullable()();

  RealColumn get rating => real().nullable()();

  IntColumn get year => integer().nullable()();

  TextColumn get plot => text().nullable()();

  /// The provider's `last_modified`: when it changes, the cached episodes
  /// are stale.
  DateTimeColumn get updatedAt => dateTime().nullable()();

  /// When the episodes were last fetched (`get_series_info` is lazy).
  DateTimeColumn get episodesFetchedAt => dateTime().nullable()();

  @override
  List<Set<Column<Object>>> get uniqueKeys => [
    {sourceId, remoteKey},
  ];
}

@DataClassName('EpisodeRow')
class Episodes extends Table {
  IntColumn get id => integer().autoIncrement()();

  IntColumn get seriesId =>
      integer().references(Series, #id, onDelete: KeyAction.cascade)();

  TextColumn get remoteKey => text()();

  IntColumn get season => integer()();

  IntColumn get episode => integer()();

  TextColumn get title => text()();

  TextColumn get ext => text().nullable()();

  IntColumn get durationSeconds => integer().nullable()();

  TextColumn get plot => text().nullable()();

  TextColumn get stillUrl => text().nullable()();

  /// See [Channels.streamUrl].
  TextColumn get streamUrl => text().nullable()();

  TextColumn get extrasJson => text().nullable()();

  /// Set when an M3U sync created the episode; Xtream episodes are
  /// replaced as a set when `get_series_info` is fetched again.
  IntColumn get seenRun => integer().nullable()();

  @override
  List<Set<Column<Object>>> get uniqueKeys => [
    {seriesId, remoteKey},
  ];
}
