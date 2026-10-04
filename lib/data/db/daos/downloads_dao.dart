import 'package:drift/drift.dart';
import 'package:iptv_player/data/db/app_database.dart';
import 'package:iptv_player/data/db/library_tables.dart';

part 'downloads_dao.g.dart';

/// Raw access to `downloads` (schema v9): the queue's order and every
/// download's state. The queue (step 3) owns the rules.
@DriftAccessor(tables: [Downloads])
class DownloadsDao extends DatabaseAccessor<AppDatabase>
    with _$DownloadsDaoMixin {
  new(super.attachedDatabase);

  /// The queue's order.
  Stream<List<DownloadRow>> watchAll() => _ordered().watch();

  Future<List<DownloadRow>> all() => _ordered().get();

  SimpleSelectStatement<$DownloadsTable, DownloadRow> _ordered() =>
      select(downloads)..orderBy([
        (t) => OrderingTerm(expression: t.sortOrder),
        (t) => OrderingTerm(expression: t.id),
      ]);

  Future<DownloadRow?> byId(int id) =>
      (select(downloads)..where((t) => t.id.equals(id))).getSingleOrNull();

  Future<DownloadRow?> byTitle(String sourceId, VodType type, String key) =>
      (select(downloads)..where(
            (t) =>
                t.sourceId.equals(sourceId) &
                t.itemType.equalsValue(type) &
                t.remoteKey.equals(key),
          ))
          .getSingleOrNull();

  /// Puts [download] at the end of the queue; its id, or null when the
  /// title is already in it.
  Future<int?> enqueue(DownloadsCompanion download) => transaction(() async {
    final queued = await byTitle(
      download.sourceId.value,
      download.itemType.value,
      download.remoteKey.value,
    );
    if (queued != null) return null;
    final last = downloads.sortOrder.max();
    final top = await (selectOnly(
      downloads,
    )..addColumns([last])).map((row) => row.read(last)).getSingle();
    return await into(downloads)
        .insert(download.copyWith(sortOrder: Value((top ?? -1) + 1)));
  });

  /// Changes the fields [values] sets; the number of rows changed.
  Future<int> change(int id, DownloadsCompanion values) =>
      (update(downloads)..where((t) => t.id.equals(id))).write(values);

  Future<void> remove(int id) =>
      (delete(downloads)..where((t) => t.id.equals(id))).go();

  /// Takes the completed downloads off the list.
  Future<void> removeCompleted() => (delete(
    downloads,
  )..where((t) => t.state.equalsValue(DownloadTaskState.completed))).go();

  /// Puts [id] at [index] in the queue's order (clamped), and numbers
  /// the queue 0, 1, 2 … again.
  Future<void> move(int id, int index) => transaction(() async {
    final order = [for (final row in await all()) row.id];
    if (!order.remove(id)) return;
    order.insert(index.clamp(0, order.length), id);
    for (final (place, rowId) in order.indexed) {
      await change(rowId, DownloadsCompanion(sortOrder: Value(place)));
    }
  });
}
