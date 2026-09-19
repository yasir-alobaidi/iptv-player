import 'dart:convert';

import 'package:iptv_player/core/result.dart';
import 'package:iptv_player/data/db/app_database.dart';
import 'package:iptv_player/data/db/daos/settings_dao.dart';

/// Every key the `settings` table holds. One place, so a typo can't
/// quietly create a second setting that nothing reads.
abstract final class SettingsKeys {
  static const windowBounds = 'window.bounds';
  static const railExpanded = 'shell.rail_expanded';
  static const currentSource = 'shell.current_source';
  static const playback = 'playback.settings';
}

/// Reads and writes the `settings` table.
///
/// Nothing throws across this boundary: a failed query comes back as an
/// [Err] holding a [StorageFailure], and a value that isn't the JSON the
/// caller expected reads as missing rather than as an error (hard rule 1),
/// so one corrupt row can't stop the app from starting.
final class SettingsRepository {
  new(this._db);

  final AppDatabase _db;

  SettingsDao get _dao => _db.settingsDao;

  /// The stored JSON text for [key], exactly as written.
  Future<Result<String?>> readJsonText(String key) =>
      _guard(() => _dao.read(key), 'read $key');

  /// Stores [jsonText] verbatim. The caller guarantees it is valid JSON;
  /// use [writeValue] for anything else.
  Future<Result<void>> writeJsonText(String key, String jsonText) =>
      _guard(() => _dao.write(key, jsonText), 'write $key');

  /// Encodes [value] and stores it. [value] must be JSON-encodable.
  Future<Result<void>> writeValue(String key, Object? value) =>
      _guard(() => _dao.write(key, jsonEncode(value)), 'write $key');

  Future<Result<void>> remove(String key) =>
      _guard(() => _dao.remove(key), 'remove $key');

  /// Every setting at once, for the diagnostics export.
  Future<Result<Map<String, String>>> readAll() =>
      _guard(_dao.readAll, 'read all settings');

  /// The decoded value for [key], or [fallback] when it is missing, isn't
  /// valid JSON, or isn't a [T].
  Future<Result<T>> readValue<T>(String key, T fallback) async {
    final stored = await readJsonText(key);
    return stored.map((text) {
      if (text == null) return fallback;
      try {
        final decoded = jsonDecode(text);
        return decoded is T ? decoded : fallback;
      } on FormatException {
        return fallback;
      }
    });
  }

  Future<Result<bool>> readBool(String key, {bool fallback = false}) =>
      readValue<bool>(key, fallback);

  Future<Result<T>> _guard<T>(Future<T> Function() body, String what) async {
    try {
      return Ok(await body());
    } on Object catch (error) {
      // Anything sqlite or drift throws is a storage problem as far as
      // the rest of the app is concerned.
      return Err(StorageFailure('$what: $error'));
    }
  }
}
