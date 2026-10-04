import 'package:drift/drift.dart';
import 'package:iptv_player/data/db/app_database.dart';
import 'package:iptv_player/data/db/library_tables.dart';

part 'library_dao.g.dart';

/// How many videos a folder holds and how big they are, for the folder
/// rows ("1,204 videos · 186 GB").
typedef FolderTotals = ({int items, int bytes});

/// A show of the Library's Series tab: the user's own episodes by show
/// title, or one provider series' downloaded episodes.
typedef LibraryShowRow = ({
  String key,
  String title,
  int episodes,
  int seasons,
  int bytes,
  String? artworkPath,
  int folders,
  int folderId,
  bool downloaded,
  String? sourceId,
  String? seriesKey,
  int available,
});

/// Raw access to `library_folders` and `library_items` (schema v9). The
/// library repository (step 4) adds the `Result` wrapper and maps rows to
/// the domain's types.
@DriftAccessor(tables: [LibraryFolders, LibraryItems])
class LibraryDao extends DatabaseAccessor<AppDatabase> with _$LibraryDaoMixin {
  new(super.attachedDatabase);

  // Folders.

  /// The download folder first, then the user's by name.
  Stream<List<LibraryFolderRow>> watchFolders() => _folders().watch();

  Future<List<LibraryFolderRow>> folders() => _folders().get();

  SimpleSelectStatement<$LibraryFoldersTable, LibraryFolderRow> _folders() =>
      select(libraryFolders)..orderBy([
        (t) => OrderingTerm.desc(t.isDownloadFolder),
        (t) => OrderingTerm(expression: t.label.collate(Collate.noCase)),
        (t) => OrderingTerm(expression: t.id),
      ]);

  Future<LibraryFolderRow?> folderById(int id) =>
      (select(libraryFolders)..where((t) => t.id.equals(id))).getSingleOrNull();

  Future<LibraryFolderRow?> folderByPath(String path) => (select(
    libraryFolders,
  )..where((t) => t.path.equals(path))).getSingleOrNull();

  /// Adds a folder the user chose; its id.
  Future<int> addFolder({
    required String path,
    required String label,
    required DateTime at,
  }) => into(libraryFolders).insert(
    LibraryFoldersCompanion.insert(path: path, label: label, addedAt: at),
  );

  /// Makes [path] the download folder: added when it isn't a library
  /// folder yet, and the one marked as such. A folder that was the
  /// download folder stays in the library as an ordinary one (docs/09:
  /// its files stay listed).
  Future<LibraryFolderRow> makeDownloadFolder(
    String path, {
    required String label,
    required DateTime at,
  }) => transaction(() async {
    await (update(libraryFolders)
          ..where((t) => t.isDownloadFolder & t.path.equals(path).not()))
        .write(const LibraryFoldersCompanion(isDownloadFolder: Value(false)));
    final kept = await folderByPath(path);
    if (kept == null) {
      await into(libraryFolders).insert(
        LibraryFoldersCompanion.insert(
          path: path,
          label: label,
          isDownloadFolder: const Value(true),
          addedAt: at,
        ),
      );
    } else if (!kept.isDownloadFolder) {
      await changeFolder(
        kept.id,
        const LibraryFoldersCompanion(isDownloadFolder: Value(true)),
      );
    }
    return (await folderByPath(path))!;
  });

  /// Changes the fields [values] sets; the number of rows changed.
  Future<int> changeFolder(int id, LibraryFoldersCompanion values) =>
      (update(libraryFolders)..where((t) => t.id.equals(id))).write(values);

  /// Takes the folder and its items out of the library (the files stay).
  Future<void> removeFolder(int id) =>
      (delete(libraryFolders)..where((t) => t.id.equals(id))).go();

  /// Every folder's video count and size, kept current.
  Stream<Map<int, FolderTotals>> watchFolderTotals() =>
      customSelect(
        'SELECT folder_id, COUNT(*) AS items, '
        'COALESCE(SUM(size_bytes), 0) AS bytes '
        'FROM library_items GROUP BY folder_id',
        readsFrom: {libraryItems},
      ).watch().map(
        (rows) => {
          for (final row in rows)
            row.read<int>('folder_id'): (
              items: row.read<int>('items'),
              bytes: row.read<int>('bytes'),
            ),
        },
      );

  // Items.

  Future<LibraryItemRow?> itemById(int id) =>
      (select(libraryItems)..where((t) => t.id.equals(id))).getSingleOrNull();

  Future<List<LibraryItemRow>> itemsIn(int folderId) =>
      (select(libraryItems)..where((t) => t.folderId.equals(folderId))).get();

  /// Items whose file has [quickHash]: a file moved or renamed is found
  /// by it.
  Future<List<LibraryItemRow>> itemsWithHash(String quickHash) =>
      (select(libraryItems)..where((t) => t.quickHash.equals(quickHash))).get();

  /// The downloaded file of a provider's title, when there is one.
  Future<LibraryItemRow?> itemForTitle(
    String sourceId,
    VodType type,
    String remoteKey,
  ) =>
      (select(libraryItems)
            ..where(
              (t) =>
                  t.providerSourceId.equals(sourceId) &
                  t.providerItemType.equalsValue(type) &
                  t.providerRemoteKey.equals(remoteKey),
            )
            ..orderBy([(t) => OrderingTerm.desc(t.id)])
            ..limit(1))
          .getSingleOrNull();

  /// The items of [kind] (every kind when null) by title, episodes by
  /// show, season and episode; hidden ones only when [hidden]; only
  /// downloads or only the user's files when [downloaded] says.
  Stream<List<LibraryItemRow>> watchItems({
    LibraryKind? kind,
    bool hidden = false,
    int? folderId,
    bool? downloaded,
  }) => _items(
    kind: kind,
    hidden: hidden,
    folderId: folderId,
    downloaded: downloaded,
  ).watch();

  /// A window of [watchItems]' list: [limit] items from [offset].
  Future<List<LibraryItemRow>> itemWindow({
    required int offset,
    required int limit,
    LibraryKind? kind,
    bool hidden = false,
    int? folderId,
    bool? downloaded,
  }) => (_items(
    kind: kind,
    hidden: hidden,
    folderId: folderId,
    downloaded: downloaded,
  )..limit(limit, offset: offset)).get();

  /// How many items [watchItems] lists and their size, kept current.
  Stream<FolderTotals> watchTotals({
    LibraryKind? kind,
    bool hidden = false,
    int? folderId,
    bool? downloaded,
  }) {
    final (where, variables) = _whereSql(
      kind: kind,
      hidden: hidden,
      folderId: folderId,
      downloaded: downloaded,
    );
    return customSelect(
      'SELECT COUNT(*) AS items, COALESCE(SUM(size_bytes), 0) AS bytes '
      'FROM library_items WHERE $where',
      variables: variables,
      readsFrom: {libraryItems},
    ).watchSingle().map(
      (row) => (items: row.read<int>('items'), bytes: row.read<int>('bytes')),
    );
  }

  /// The shows of the Series tab, by title: the user's own episodes
  /// grouped by show title (case aside) across folders, a provider
  /// series' downloads by their series. Hidden episodes are left out;
  /// [downloaded] keeps only downloads, or only the user's files.
  Stream<List<LibraryShowRow>> watchShows({bool? downloaded}) {
    final (where, variables) = _whereSql(
      kind: LibraryKind.episode,
      downloaded: downloaded,
    );
    return customSelect(
      'SELECT $_showKey AS show_key, '
      'MIN(show_title) AS title, COUNT(*) AS episodes, '
      'COUNT(DISTINCT COALESCE(season, 1)) AS seasons, '
      'COALESCE(SUM(size_bytes), 0) AS bytes, '
      'MAX(artwork_path) AS artwork, '
      'COUNT(DISTINCT folder_id) AS folders, MIN(folder_id) AS folder_id, '
      'MAX(provider_remote_key IS NOT NULL) AS downloaded, '
      'MIN(provider_source_id) AS source_id, '
      'MIN(provider_series_key) AS series_key, '
      'SUM(unavailable_since IS NULL) AS available '
      'FROM library_items WHERE $where AND show_title IS NOT NULL '
      'GROUP BY show_key ORDER BY title COLLATE NOCASE, show_key',
      variables: variables,
      readsFrom: {libraryItems},
    ).watch().map(
      (rows) => [
        for (final row in rows)
          (
            key: row.read<String>('show_key'),
            title: row.read<String>('title'),
            episodes: row.read<int>('episodes'),
            seasons: row.read<int>('seasons'),
            bytes: row.read<int>('bytes'),
            artworkPath: row.readNullable<String>('artwork'),
            folders: row.read<int>('folders'),
            folderId: row.read<int>('folder_id'),
            downloaded: row.read<int>('downloaded') == 1,
            sourceId: row.readNullable<String>('source_id'),
            seriesKey: row.readNullable<String>('series_key'),
            available: row.read<int>('available'),
          ),
      ],
    );
  }

  /// The episodes of the show [watchShows] keyed [key], by season and
  /// episode.
  Stream<List<LibraryItemRow>> watchShowEpisodes(String key) {
    final (where, variables) = _whereSql(kind: LibraryKind.episode);
    return customSelect(
      'SELECT * FROM library_items WHERE $where AND show_title IS NOT NULL '
      'AND $_showKey = ?${variables.length + 1} '
      'ORDER BY COALESCE(season, 1), episode, title COLLATE NOCASE, id',
      variables: [...variables, Variable.withString(key)],
      readsFrom: {libraryItems},
    ).asyncMap((row) => libraryItems.mapFromRow(row)).watch();
  }

  /// What a show is keyed by: `l:` and its title in lower case for the
  /// user's own episodes, `p:`, the source and the series for downloads.
  static const _showKey =
      "CASE WHEN provider_remote_key IS NULL THEN 'l:' || lower(show_title) "
      "ELSE 'p:' || COALESCE(provider_source_id, '') || ':' || "
      'COALESCE(provider_series_key, lower(show_title)) END';

  SimpleSelectStatement<$LibraryItemsTable, LibraryItemRow> _items({
    LibraryKind? kind,
    bool hidden = false,
    int? folderId,
    bool? downloaded,
  }) => select(libraryItems)
    ..where((t) {
      var where = t.isHidden.equals(hidden);
      if (kind != null) where &= t.kind.equalsValue(kind);
      if (folderId != null) where &= t.folderId.equals(folderId);
      if (downloaded != null) {
        where &= downloaded
            ? t.providerRemoteKey.isNotNull()
            : t.providerRemoteKey.isNull();
      }
      return where;
    })
    ..orderBy([
      (t) => OrderingTerm(expression: t.showTitle.collate(Collate.noCase)),
      (t) => OrderingTerm(expression: t.season),
      (t) => OrderingTerm(expression: t.episode),
      (t) => OrderingTerm(expression: t.title.collate(Collate.noCase)),
      (t) => OrderingTerm(expression: t.id),
    ]);

  /// [_items]' filter as SQL, with its variables numbered from ?1.
  (String, List<Variable<Object>>) _whereSql({
    LibraryKind? kind,
    bool hidden = false,
    int? folderId,
    bool? downloaded,
  }) {
    final parts = <String>['is_hidden = ${hidden ? 1 : 0}'];
    final variables = <Variable<Object>>[];
    if (kind != null) {
      variables.add(Variable.withString(kind.name));
      parts.add('kind = ?${variables.length}');
    }
    if (folderId != null) {
      variables.add(Variable.withInt(folderId));
      parts.add('folder_id = ?${variables.length}');
    }
    if (downloaded != null) {
      parts.add(
        downloaded
            ? 'provider_remote_key IS NOT NULL'
            : 'provider_remote_key IS NULL',
      );
    }
    return (parts.join(' AND '), variables);
  }

  /// Items whose title or show matches [match], an FTS5 query the caller
  /// built from typed words (never raw text), best first.
  Future<List<LibraryItemRow>> search(String match, {int limit = 20}) =>
      customSelect(
        'SELECT i.* FROM library_fts f '
        'JOIN library_items i ON i.id = f.rowid '
        'WHERE library_fts MATCH ?1 AND i.is_hidden = 0 '
        'ORDER BY f.rank LIMIT ?2',
        variables: [Variable.withString(match), Variable.withInt(limit)],
        readsFrom: {libraryItems},
      ).asyncMap((row) => libraryItems.mapFromRow(row)).get();

  Future<int> insertItem(LibraryItemsCompanion item) =>
      into(libraryItems).insert(item);

  /// Changes the fields [values] sets; the number of rows changed.
  Future<int> changeItem(int id, LibraryItemsCompanion values) =>
      (update(libraryItems)..where((t) => t.id.equals(id))).write(values);

  Future<void> removeItem(int id) =>
      (delete(libraryItems)..where((t) => t.id.equals(id))).go();
}
