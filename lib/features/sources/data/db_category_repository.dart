import 'dart:async';

import 'package:iptv_player/core/result.dart';
import 'package:iptv_player/data/db/app_database.dart';
import 'package:iptv_player/features/sources/domain/categories.dart';

/// [CategoryRepository] over the catalogue tables.
final class DbCategoryRepository implements CategoryRepository {
  new(AppDatabase database) : _db = database;

  final AppDatabase _db;

  @override
  Stream<CategoryList> watch(String sourceId, CatalogueKind kind) async* {
    // The counts don't change while the picker is open (a sync would
    // replace the screen's data anyway), so they are read once rather
    // than on every toggle.
    final Map<int?, int> counts;
    try {
      counts = await _db.categoriesDao.itemCounts(sourceId, kind);
    } on Object catch (error) {
      throw StorageFailure('category counts: $error');
    }
    final known = <int>{};
    yield* _db.categoriesDao
        .watchForSource(sourceId, kind)
        .map((rows) {
          known
            ..clear()
            ..addAll(rows.map((row) => row.id));
          return CategoryList(
            categories: [
              for (final row in rows)
                CategoryChoice(
                  id: row.id,
                  name: row.displayName ?? row.name,
                  isHidden: row.isHidden,
                  itemCount: counts[row.id] ?? 0,
                ),
            ],
            uncategorized: counts.entries
                .where((e) => e.key == null || !known.contains(e.key))
                .fold(0, (sum, e) => sum + e.value),
          );
        })
        .handleError(
          (Object error) => throw StorageFailure('categories: $error'),
          test: (error) => error is! AppFailure,
        );
  }

  @override
  Future<Result<void>> setHidden(int id, {required bool hidden}) =>
      _guard(() => _db.categoriesDao.setHidden(id, hidden: hidden));

  @override
  Future<Result<void>> setHiddenMany(
    Iterable<int> ids, {
    required bool hidden,
  }) => _guard(() => _db.categoriesDao.setHiddenMany(ids, hidden: hidden));

  @override
  Future<Result<void>> setAllHidden(
    String sourceId,
    CatalogueKind kind, {
    required bool hidden,
  }) => _guard(
    () => _db.categoriesDao.setAllHidden(sourceId, kind, hidden: hidden),
  );

  static Future<Result<void>> _guard(Future<void> Function() write) async {
    try {
      await write();
      return const Ok(null);
    } on Object catch (error) {
      return Err(StorageFailure('categories: $error'));
    }
  }
}
