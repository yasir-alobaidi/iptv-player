import 'package:drift/drift.dart';
import 'package:iptv_player/data/db/app_database.dart';
import 'package:iptv_player/data/db/library_tables.dart';

part 'library_dao.g.dart';

/// How many videos a folder holds and how big they are, for the folder
/// rows ("1,204 videos · 186 GB").
typedef FolderTotals = ({int items, int bytes});

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

  /// The items of [kind] by title (episodes by show, season, episode),
  /// hidden ones only when [hidden].
  Stream<List<LibraryItemRow>> watchItems({
    required LibraryKind kind,
    bool hidden = false,
    int? folderId,
  }) =>
      (select(libraryItems)
            ..where((t) {
              var where = t.kind.equalsValue(kind) & t.isHidden.equals(hidden);
              if (folderId != null) where &= t.folderId.equals(folderId);
              return where;
            })
            ..orderBy([
              (t) =>
                  OrderingTerm(expression: t.showTitle.collate(Collate.noCase)),
              (t) => OrderingTerm(expression: t.season),
              (t) => OrderingTerm(expression: t.episode),
              (t) => OrderingTerm(expression: t.title.collate(Collate.noCase)),
              (t) => OrderingTerm(expression: t.id),
            ]))
          .watch();

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
