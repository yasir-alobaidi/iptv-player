import 'package:drift/drift.dart';
import 'package:iptv_player/data/db/app_database.dart';
import 'package:iptv_player/data/db/tables.dart';

part 'sources_dao.g.dart';

/// Raw access to the `sources` table. Phase 2 puts a repository in front
/// of it that maps rows to domain models and pairs them with the
/// credentials in secure storage.
@DriftAccessor(tables: [Sources])
class SourcesDao extends DatabaseAccessor<AppDatabase> with _$SourcesDaoMixin {
  new(super.attachedDatabase);

  Future<List<SourceRow>> all() =>
      (select(sources)..orderBy([(t) => OrderingTerm.asc(t.sortOrder)])).get();

  Stream<List<SourceRow>> watchAll() => (select(
    sources,
  )..orderBy([(t) => OrderingTerm.asc(t.sortOrder)])).watch();

  Future<SourceRow?> byId(String id) =>
      (select(sources)..where((t) => t.id.equals(id))).getSingleOrNull();

  Future<int> count() {
    final total = sources.id.count();
    return (selectOnly(
      sources,
    )..addColumns([total])).map((row) => row.read(total) ?? 0).getSingle();
  }

  /// Inserts the source, or replaces the row that already has its id.
  Future<void> upsert(SourcesCompanion source) =>
      into(sources).insert(source, mode: InsertMode.insertOrReplace);

  /// Changes only the columns [source] sets.
  Future<void> patch(String id, SourcesCompanion source) =>
      (update(sources)..where((t) => t.id.equals(id))).write(source);

  Future<void> remove(String id) =>
      (delete(sources)..where((t) => t.id.equals(id))).go();

  Future<void> markSynced(String id, DateTime at) => patch(
    id,
    SourcesCompanion(lastSyncedAt: Value(at), updatedAt: Value(at)),
  );
}
