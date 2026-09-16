// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'sources_dao.dart';

// ignore_for_file: type=lint
mixin _$SourcesDaoMixin on DatabaseAccessor<AppDatabase> {
  $SourcesTable get sources => attachedDatabase.sources;
  SourcesDaoManager get managers => SourcesDaoManager(this);
}

class SourcesDaoManager {
  final _$SourcesDaoMixin _db;
  SourcesDaoManager(this._db);
  $$SourcesTableTableManager get sources =>
      $$SourcesTableTableManager(_db.attachedDatabase, _db.sources);
}
