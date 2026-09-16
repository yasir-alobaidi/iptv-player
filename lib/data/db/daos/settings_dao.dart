import 'package:drift/drift.dart';
import 'package:iptv_player/data/db/app_database.dart';
import 'package:iptv_player/data/db/tables.dart';

part 'settings_dao.g.dart';

/// Raw access to the `settings` table. Callers go through
/// `SettingsRepository`, which adds the `Result` wrapper and the typed
/// readers; this layer only speaks JSON text.
@DriftAccessor(tables: [Settings])
class SettingsDao extends DatabaseAccessor<AppDatabase>
    with _$SettingsDaoMixin {
  new(super.attachedDatabase);

  /// The stored JSON for [key], or null when nothing was written yet.
  Future<String?> read(String key) async {
    final row = await (select(
      settings,
    )..where((t) => t.key.equals(key))).getSingleOrNull();
    return row?.valueJson;
  }

  Future<void> write(String key, String valueJson) => into(settings).insert(
    SettingsCompanion.insert(
      key: key,
      valueJson: valueJson,
      updatedAt: DateTime.now().toUtc(),
    ),
    mode: InsertMode.insertOrReplace,
  );

  Future<void> remove(String key) =>
      (delete(settings)..where((t) => t.key.equals(key))).go();

  /// Emits on every change to [key], starting with the current value.
  Stream<String?> watch(String key) =>
      (select(settings)..where((t) => t.key.equals(key)))
          .watchSingleOrNull()
          .map((row) => row?.valueJson);

  /// Every setting at once, for the diagnostics export.
  Future<Map<String, String>> readAll() async {
    final rows = await select(settings).get();
    return {for (final row in rows) row.key: row.valueJson};
  }
}
