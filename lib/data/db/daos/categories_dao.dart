import 'package:drift/drift.dart';
import 'package:iptv_player/data/db/app_database.dart';
import 'package:iptv_player/data/db/catalogue_tables.dart';

part 'categories_dao.g.dart';

@DriftAccessor(tables: [Categories, Channels, Movies, Series])
class CategoriesDao extends DatabaseAccessor<AppDatabase>
    with _$CategoriesDaoMixin {
  new(super.attachedDatabase);

  /// Inserts new categories and refreshes the ones already known, in one
  /// transaction. Only the columns the provider owns are rewritten: the
  /// user's rename, hidden flag and order survive (docs/02).
  Future<void> upsertAll(List<CategoriesCompanion> rows) => batch(
    (b) => b.insertAll(
      categories,
      rows,
      onConflict: DoUpdate<$CategoriesTable, CategoryRow>.withExcluded(
        (old, excluded) => CategoriesCompanion.custom(
          name: excluded.name,
          position: excluded.position,
          seenRun: excluded.seenRun,
        ),
        target: [categories.sourceId, categories.kind, categories.remoteKey],
      ),
    ),
  );

  /// Deletes the source's categories that sync run [runId] did not see,
  /// of the [kinds] given (all when null): a run that kept a list it could
  /// not refresh keeps that list's categories too. Items in them fall back
  /// to "Uncategorized"; the sync engine sweeps items first, so in
  /// practice none are left.
  Future<int> sweep(String sourceId, int runId, {Set<CatalogueKind>? kinds}) =>
      (delete(categories)..where(
            (t) =>
                t.sourceId.equals(sourceId) &
                (t.seenRun.isNull() | t.seenRun.equals(runId).not()) &
                (kinds == null
                    ? const Constant(true)
                    : t.kind.isInValues(kinds)),
          ))
          .go();

  /// Remote key → row id, for filing the items the same run upserts next.
  Future<Map<String, int>> idsByRemoteKey(
    String sourceId,
    CatalogueKind kind,
  ) async {
    final query = selectOnly(categories)
      ..addColumns([categories.remoteKey, categories.id])
      ..where(categories.sourceId.equals(sourceId) & _isKind(kind));
    return {
      for (final row in await query.get())
        row.read(categories.remoteKey)!: row.read(categories.id)!,
    };
  }

  /// In display order: the user's order where they set one, then the
  /// provider's.
  Stream<List<CategoryRow>> watchForSource(
    String sourceId,
    CatalogueKind kind, {
    bool includeHidden = true,
  }) {
    final query = select(categories)
      ..where(
        (t) =>
            t.sourceId.equals(sourceId) &
            _isKind(kind) &
            (includeHidden ? const Constant(true) : t.isHidden.not()),
      )
      ..orderBy([
        (t) => OrderingTerm.asc(t.sortOrder.isNull()),
        (t) => OrderingTerm.asc(t.sortOrder),
        (t) => OrderingTerm.asc(t.position),
      ]);
    return query.watch();
  }

  /// Items per category id for the pickers' "412 channels". The null key
  /// counts the uncategorized items.
  Future<Map<int?, int>> itemCounts(String sourceId, CatalogueKind kind) async {
    final table = switch (kind) {
      CatalogueKind.live => 'channels',
      CatalogueKind.movie => 'movies',
      CatalogueKind.series => 'series',
    };
    final rows = await customSelect(
      'SELECT category_id, COUNT(*) AS n FROM $table '
      'WHERE source_id = ? GROUP BY category_id',
      variables: [Variable.withString(sourceId)],
      readsFrom: {channels, movies, series},
    ).get();
    return {
      for (final row in rows) row.read<int?>('category_id'): row.read<int>('n'),
    };
  }

  Future<void> setHidden(int id, {required bool hidden}) =>
      (update(categories)..where((t) => t.id.equals(id))).write(
        CategoriesCompanion(isHidden: Value(hidden)),
      );

  /// The pickers' "Select all" and "Select none".
  Future<void> setAllHidden(
    String sourceId,
    CatalogueKind kind, {
    required bool hidden,
  }) =>
      (update(categories)
            ..where((t) => t.sourceId.equals(sourceId) & _isKind(kind)))
          .write(CategoriesCompanion(isHidden: Value(hidden)));

  /// Null or blank restores the provider's name.
  Future<void> rename(int id, String? displayName) {
    final trimmed = displayName?.trim();
    return (update(categories)..where((t) => t.id.equals(id))).write(
      CategoriesCompanion(
        displayName: Value(trimmed == null || trimmed.isEmpty ? null : trimmed),
      ),
    );
  }

  /// Stores [idsInOrder] as the user's order, in one transaction.
  Future<void> reorder(List<int> idsInOrder) => batch((b) {
    for (final (index, id) in idsInOrder.indexed) {
      b.update(
        categories,
        CategoriesCompanion(sortOrder: Value(index)),
        where: (t) => t.id.equals(id),
      );
    }
  });

  Expression<bool> _isKind(CatalogueKind kind) =>
      categories.kind.equalsValue(kind);
}
