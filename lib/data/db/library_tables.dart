import 'package:drift/drift.dart';
import 'package:iptv_player/core/downloads/download_task.dart';
import 'package:iptv_player/core/library/library_item.dart';
import 'package:iptv_player/data/db/tables.dart';

export 'package:iptv_player/core/downloads/download_task.dart'
    show DownloadProblem, DownloadTaskState;
export 'package:iptv_player/core/library/library_item.dart'
    show LibraryKind, VodType;

/// The folders whose videos are in the library (schema v9, docs/09): the
/// download folder and the ones the user added.
@DataClassName('LibraryFolderRow')
class LibraryFolders extends Table {
  IntColumn get id => integer().autoIncrement()();

  /// Absolute, as the system gave it.
  TextColumn get path => text().unique()();

  /// What the screens call it ("Movies HDD"; the canvas's, v9).
  TextColumn get label => text()();

  BoolColumn get isDownloadFolder =>
      boolean().withDefault(const Constant(false))();

  BoolColumn get isAvailable => boolean().withDefault(const Constant(true))();

  DateTimeColumn get lastScanAt => dateTime().nullable()();

  DateTimeColumn get addedAt => dateTime()();
}

/// The videos found in the library's folders, and the downloads that
/// finished (schema v9, docs/09).
///
/// [title], [year], [kind], [showTitle], [season] and [episode] hold what
/// the screens show — the user's edit ([userEditsJson]) when there is
/// one, else what the name said — so lists sort, filter and search on one
/// set of columns, and a rescan writes only fields the user didn't set.
@DataClassName('LibraryItemRow')
@TableIndex(name: 'library_items_hash', columns: {#quickHash})
@TableIndex(name: 'library_items_kind_title', columns: {#kind, #title})
@TableIndex(
  name: 'library_items_provider',
  columns: {#providerSourceId, #providerItemType, #providerRemoteKey},
)
class LibraryItems extends Table {
  IntColumn get id => integer().autoIncrement()();

  IntColumn get folderId =>
      integer().references(LibraryFolders, #id, onDelete: KeyAction.cascade)();

  /// Inside its folder, with `/` between parts on every system.
  TextColumn get relPath => text()();

  IntColumn get sizeBytes => integer()();

  /// The file's modification time, in milliseconds since the epoch: a
  /// file with the same path, size and time is never read again.
  IntColumn get mtime => integer()();

  /// Size + the first and last 64 KB (docs/09).
  TextColumn get quickHash => text()();

  TextColumn get kind => textEnum<LibraryKind>()();

  TextColumn get title => text()();

  IntColumn get year => integer().nullable()();

  TextColumn get showTitle => text().nullable()();

  IntColumn get season => integer().nullable()();

  IntColumn get episode => integer().nullable()();

  IntColumn get episodeEnd => integer().nullable()();

  IntColumn get durationMs => integer().nullable()();

  /// What ffprobe said of it (step 4); null until it was probed.
  TextColumn get probeJson => text().nullable()();

  TextColumn get thumbnailPath => text().nullable()();

  TextColumn get artworkPath => text().nullable()();

  /// The subtitle files beside it (`ExternalSubtitle`s), as JSON.
  TextColumn get subtitlesJson => text().nullable()();

  /// What the user set in Edit details (`LibraryItemEdit`), as JSON.
  TextColumn get userEditsJson => text().nullable()();

  /// A download's copy of its title's details (plot, rating, genres,
  /// cast; an episode's title and still), so its page works offline and
  /// after the provider drops the title (v9, Phase 8 decision 5).
  TextColumn get detailsJson => text().nullable()();

  /// A download's title at its source. Removing the source leaves the
  /// file in the library, unlinked.
  TextColumn get providerSourceId =>
      text().nullable().references(Sources, #id, onDelete: KeyAction.setNull)();

  TextColumn get providerItemType => textEnum<VodType>().nullable()();

  TextColumn get providerRemoteKey => text().nullable()();

  /// An episode's series at its source (v9: its history key needs it).
  TextColumn get providerSeriesKey => text().nullable()();

  BoolColumn get isHidden => boolean().withDefault(const Constant(false))();

  /// When its folder stopped being readable (docs/09: 30 days, then it
  /// goes).
  DateTimeColumn get unavailableSince => dateTime().nullable()();

  DateTimeColumn get addedAt => dateTime()();

  @override
  List<Set<Column<Object>>> get uniqueKeys => [
    {folderId, relPath},
  ];
}

/// The download queue (schema v9, docs/09): the order, each download's
/// state and how far it got. Never a URL: it is built from the source at
/// every start.
@DataClassName('DownloadRow')
class Downloads extends Table {
  IntColumn get id => integer().autoIncrement()();

  TextColumn get sourceId =>
      text().references(Sources, #id, onDelete: KeyAction.cascade)();

  TextColumn get itemType => textEnum<VodType>()();

  TextColumn get remoteKey => text()();

  TextColumn get seriesRemoteKey => text().nullable()();

  IntColumn get season => integer().nullable()();

  IntColumn get episode => integer().nullable()();

  /// A movie's title, or an episode's own.
  TextColumn get title => text()();

  /// An episode's series name (v9: the Downloads list shows it).
  TextColumn get showTitle => text().nullable()();

  /// A movie's year (v9: the Downloads list shows it).
  IntColumn get year => integer().nullable()();

  TextColumn get artworkUrl => text().nullable()();

  /// The file it becomes; `<target_path>.part` until it is verified.
  TextColumn get targetPath => text()();

  IntColumn get totalBytes => integer().nullable()();

  IntColumn get downloadedBytes => integer().withDefault(const Constant(0))();

  /// What a resume's `If-Range` sends: the ETag, else Last-Modified.
  TextColumn get etag => text().nullable()();

  TextColumn get lastModified => text().nullable()();

  TextColumn get state => textEnum<DownloadTaskState>()();

  TextColumn get errorClass => textEnum<DownloadProblem>().nullable()();

  /// Redacted before it is written (hard rule 3).
  TextColumn get errorDetail => text().nullable()();

  IntColumn get attempts => integer().withDefault(const Constant(0))();

  IntColumn get libraryItemId => integer().nullable().references(
    LibraryItems,
    #id,
    onDelete: KeyAction.setNull,
  )();

  /// Its place in the queue, lower first (v9: docs/05's drag to
  /// reorder).
  IntColumn get sortOrder => integer()();

  DateTimeColumn get createdAt => dateTime()();

  DateTimeColumn get completedAt => dateTime().nullable()();

  @override
  List<Set<Column<Object>>> get uniqueKeys => [
    {sourceId, itemType, remoteKey},
  ];
}
