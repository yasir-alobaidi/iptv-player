import 'dart:convert';

import 'package:drift/drift.dart';
import 'package:iptv_player/core/cast/cast_device.dart';
import 'package:iptv_player/core/cast/cast_device_store.dart';
import 'package:iptv_player/core/result.dart';
import 'package:iptv_player/data/db/app_database.dart';

/// [CastDeviceStore] on the `cast_devices` table.
final class DbCastDeviceStore implements CastDeviceStore {
  new(this._db);

  final AppDatabase _db;

  @override
  Stream<List<KnownCastDevice>> watchAll() => _db.castDevicesDao.watchAll().map(
    (rows) => [for (final row in rows) _toDevice(row)],
  );

  @override
  Future<Result<KnownCastDevice?>> byId(String id) => _guard('read', () async {
    final row = await _db.castDevicesDao.byId(id);
    return row == null ? null : _toDevice(row);
  });

  @override
  Future<Result<void>> addManual(CastDevice device) => _guard(
    'add',
    () => _db.castDevicesDao.upsertSeen(
      id: device.id,
      name: device.name,
      model: device.model,
      host: device.host,
      port: device.port,
      manual: true,
    ),
  );

  @override
  Future<Result<void>> markUsed(CastDevice device, DateTime at) => _guard(
    'mark used',
    () => _db.castDevicesDao.upsertSeen(
      id: device.id,
      name: device.name,
      model: device.model,
      host: device.host,
      port: device.port,
      usedAt: at.toUtc(),
    ),
  );

  @override
  Future<Result<void>> refresh(CastDevice device) => _guard(
    'refresh',
    () => _db.castDevicesDao.refresh(
      id: device.id,
      name: device.name,
      model: device.model,
      host: device.host,
      port: device.port,
    ),
  );

  @override
  Future<Result<void>> setHevcSupport(String id, HevcSupport value) => _guard(
    'set HEVC',
    () => _db.castDevicesDao.change(
      id,
      CastDevicesCompanion(hevcSupport: Value(value)),
    ),
  );

  @override
  Future<Result<void>> setLearned(String id, CastLearned learned) => _guard(
    'set learned',
    () => _db.castDevicesDao.change(
      id,
      CastDevicesCompanion(learnedJson: Value(encodeCastLearned(learned))),
    ),
  );

  @override
  Future<Result<void>> forget(String id) =>
      _guard('forget', () => _db.castDevicesDao.remove(id));

  static KnownCastDevice _toDevice(CastDeviceRow row) => KnownCastDevice(
    id: row.deviceId,
    name: row.name,
    model: row.model,
    host: row.lastHost,
    port: row.lastPort,
    manual: row.isManual,
    hevc: row.hevcSupport,
    learned: decodeCastLearned(row.learnedJson),
    lastUsedAt: row.lastUsedAt,
  );

  Future<Result<T>> _guard<T>(String what, Future<T> Function() body) async {
    try {
      return Ok(await body());
    } on Object catch (error) {
      return Err(StorageFailure('$what cast device: $error'));
    }
  }
}

/// [learned] as stored; null when nothing was learned.
String? encodeCastLearned(CastLearned learned) {
  if (learned == const CastLearned()) return null;
  return jsonEncode({
    if (learned.maxHeight != null) 'max_height': learned.maxHeight,
    if (learned.refusedCodecs.isNotEmpty)
      'refused_codecs': [...learned.refusedCodecs]..sort(),
    if (learned.directRefusedSources.isNotEmpty)
      'direct_refused_sources': [...learned.directRefusedSources]..sort(),
    if (learned.refusedInterlaced) 'refused_interlaced': true,
  });
}

/// What was learned, from what [encodeCastLearned] stored. Anything
/// that isn't what it wrote reads as nothing learned, field by field.
CastLearned decodeCastLearned(String? json) {
  if (json == null) return const CastLearned();
  Object? value;
  try {
    value = jsonDecode(json);
  } on FormatException {
    return const CastLearned();
  }
  if (value is! Map) return const CastLearned();
  final height = value['max_height'];
  Set<String> texts(Object? list) => {
    if (list is List)
      for (final item in list)
        if (item is String && item.isNotEmpty) item,
  };
  return CastLearned(
    maxHeight: height is int && height > 0 ? height : null,
    refusedCodecs: texts(value['refused_codecs']),
    directRefusedSources: texts(value['direct_refused_sources']),
    refusedInterlaced: value['refused_interlaced'] == true,
  );
}
