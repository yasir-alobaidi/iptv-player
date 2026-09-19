// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'watch_history_dao.dart';

// ignore_for_file: type=lint
mixin _$WatchHistoryDaoMixin on DatabaseAccessor<AppDatabase> {
  $SourcesTable get sources => attachedDatabase.sources;
  $WatchHistoryTable get watchHistory => attachedDatabase.watchHistory;
  WatchHistoryDaoManager get managers => WatchHistoryDaoManager(this);
}

class WatchHistoryDaoManager {
  final _$WatchHistoryDaoMixin _db;
  WatchHistoryDaoManager(this._db);
  $$SourcesTableTableManager get sources =>
      $$SourcesTableTableManager(_db.attachedDatabase, _db.sources);
  $$WatchHistoryTableTableManager get watchHistory =>
      $$WatchHistoryTableTableManager(_db.attachedDatabase, _db.watchHistory);
}
