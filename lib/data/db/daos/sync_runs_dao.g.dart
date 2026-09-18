// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'sync_runs_dao.dart';

// ignore_for_file: type=lint
mixin _$SyncRunsDaoMixin on DatabaseAccessor<AppDatabase> {
  $SourcesTable get sources => attachedDatabase.sources;
  $SyncRunsTable get syncRuns => attachedDatabase.syncRuns;
  SyncRunsDaoManager get managers => SyncRunsDaoManager(this);
}

class SyncRunsDaoManager {
  final _$SyncRunsDaoMixin _db;
  SyncRunsDaoManager(this._db);
  $$SourcesTableTableManager get sources =>
      $$SourcesTableTableManager(_db.attachedDatabase, _db.sources);
  $$SyncRunsTableTableManager get syncRuns =>
      $$SyncRunsTableTableManager(_db.attachedDatabase, _db.syncRuns);
}
