// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'maintenance_dao.dart';

// ignore_for_file: type=lint
mixin _$MaintenanceDaoMixin on DatabaseAccessor<AppDatabase> {
  $SourcesTable get sources => attachedDatabase.sources;
  $EpgImportsTable get epgImports => attachedDatabase.epgImports;
  $EpgChannelsStagingTable get epgChannelsStaging =>
      attachedDatabase.epgChannelsStaging;
  $EpgProgramsStagingTable get epgProgramsStaging =>
      attachedDatabase.epgProgramsStaging;
  MaintenanceDaoManager get managers => MaintenanceDaoManager(this);
}

class MaintenanceDaoManager {
  final _$MaintenanceDaoMixin _db;
  MaintenanceDaoManager(this._db);
  $$SourcesTableTableManager get sources =>
      $$SourcesTableTableManager(_db.attachedDatabase, _db.sources);
  $$EpgImportsTableTableManager get epgImports =>
      $$EpgImportsTableTableManager(_db.attachedDatabase, _db.epgImports);
  $$EpgChannelsStagingTableTableManager get epgChannelsStaging =>
      $$EpgChannelsStagingTableTableManager(
        _db.attachedDatabase,
        _db.epgChannelsStaging,
      );
  $$EpgProgramsStagingTableTableManager get epgProgramsStaging =>
      $$EpgProgramsStagingTableTableManager(
        _db.attachedDatabase,
        _db.epgProgramsStaging,
      );
}
