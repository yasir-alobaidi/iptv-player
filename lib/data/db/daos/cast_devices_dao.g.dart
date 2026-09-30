// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'cast_devices_dao.dart';

// ignore_for_file: type=lint
mixin _$CastDevicesDaoMixin on DatabaseAccessor<AppDatabase> {
  $CastDevicesTable get castDevices => attachedDatabase.castDevices;
  CastDevicesDaoManager get managers => CastDevicesDaoManager(this);
}

class CastDevicesDaoManager {
  final _$CastDevicesDaoMixin _db;
  CastDevicesDaoManager(this._db);
  $$CastDevicesTableTableManager get castDevices =>
      $$CastDevicesTableTableManager(_db.attachedDatabase, _db.castDevices);
}
