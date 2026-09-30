import 'package:drift/drift.dart';
import 'package:iptv_player/core/cast/cast_device.dart';

export 'package:iptv_player/core/cast/cast_device.dart' show HevcSupport;

/// The Cast devices the app keeps (schema v8, docs/02): added by
/// address, cast to, or set up in Settings → Casting. A device only seen
/// on the network gets no row.
@DataClassName('CastDeviceRow')
class CastDevices extends Table {
  /// The device's own id (TXT `id`).
  TextColumn get deviceId => text()();

  TextColumn get name => text()();

  TextColumn get model => text().nullable()();

  /// Where it was last seen or used.
  TextColumn get lastHost => text()();

  /// 8009 (`castPort`, written out: the generated code copies the
  /// literal) for every real device; another only for a test receiver
  /// added by address (`127.0.0.1:<port>`).
  IntColumn get lastPort => integer().withDefault(const Constant(8009))();

  BoolColumn get isManual => boolean().withDefault(const Constant(false))();

  TextColumn get hevcSupport =>
      textEnum<HevcSupport>().withDefault(Constant(HevcSupport.auto.name))();

  /// What was learned from refusals (`CastLearned`), as JSON; null is
  /// nothing yet.
  TextColumn get learnedJson => text().nullable()();

  DateTimeColumn get lastUsedAt => dateTime().nullable()();

  @override
  Set<Column<Object>> get primaryKey => {deviceId};
}
