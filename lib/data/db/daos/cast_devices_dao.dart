import 'package:drift/drift.dart';
import 'package:iptv_player/data/db/app_database.dart';
import 'package:iptv_player/data/db/cast_tables.dart';

part 'cast_devices_dao.g.dart';

/// Raw access to `cast_devices` (schema v8). `DbCastDeviceStore` adds the
/// `Result` wrapper and maps rows to `KnownCastDevice`.
@DriftAccessor(tables: [CastDevices])
class CastDevicesDao extends DatabaseAccessor<AppDatabase>
    with _$CastDevicesDaoMixin {
  new(super.attachedDatabase);

  Stream<List<CastDeviceRow>> watchAll() =>
      (select(castDevices)..orderBy([
            (t) => OrderingTerm(expression: t.name.collate(Collate.noCase)),
            (t) => OrderingTerm(expression: t.deviceId),
          ]))
          .watch();

  Future<CastDeviceRow?> byId(String id) => (select(
    castDevices,
  )..where((t) => t.deviceId.equals(id))).getSingleOrNull();

  /// Inserts a row, or rewrites a kept one's name, model and address;
  /// [manual] and [usedAt] only ever turn on or move forward, and the
  /// user's settings and what was learned are left alone.
  Future<void> upsertSeen({
    required String id,
    required String name,
    required String host,
    required int port,
    String? model,
    bool manual = false,
    DateTime? usedAt,
  }) => into(castDevices).insert(
    CastDevicesCompanion.insert(
      deviceId: id,
      name: name,
      model: Value(model),
      lastHost: host,
      lastPort: Value(port),
      isManual: Value(manual),
      lastUsedAt: Value(usedAt),
    ),
    onConflict: DoUpdate<$CastDevicesTable, CastDeviceRow>.withExcluded(
      (old, excluded) => CastDevicesCompanion.custom(
        name: excluded.name,
        model: excluded.model,
        lastHost: excluded.lastHost,
        lastPort: excluded.lastPort,
        isManual: old.isManual | excluded.isManual,
        lastUsedAt: coalesce([excluded.lastUsedAt, old.lastUsedAt]),
      ),
    ),
  );

  /// Rewrites a kept row's name, model and address; nothing when there
  /// is no row.
  Future<void> refresh({
    required String id,
    required String name,
    required String host,
    required int port,
    String? model,
  }) => (update(castDevices)..where((t) => t.deviceId.equals(id))).write(
    CastDevicesCompanion(
      name: Value(name),
      model: Value(model),
      lastHost: Value(host),
      lastPort: Value(port),
    ),
  );

  /// Changes the fields [values] sets on a kept row; the number of rows
  /// changed (0 when there is none).
  Future<int> change(String id, CastDevicesCompanion values) =>
      (update(castDevices)..where((t) => t.deviceId.equals(id))).write(values);

  Future<void> remove(String id) =>
      (delete(castDevices)..where((t) => t.deviceId.equals(id))).go();
}
