// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'channels_dao.dart';

// ignore_for_file: type=lint
mixin _$ChannelsDaoMixin on DatabaseAccessor<AppDatabase> {
  $SourcesTable get sources => attachedDatabase.sources;
  $CategoriesTable get categories => attachedDatabase.categories;
  $ChannelsTable get channels => attachedDatabase.channels;
  ChannelsDaoManager get managers => ChannelsDaoManager(this);
}

class ChannelsDaoManager {
  final _$ChannelsDaoMixin _db;
  ChannelsDaoManager(this._db);
  $$SourcesTableTableManager get sources =>
      $$SourcesTableTableManager(_db.attachedDatabase, _db.sources);
  $$CategoriesTableTableManager get categories =>
      $$CategoriesTableTableManager(_db.attachedDatabase, _db.categories);
  $$ChannelsTableTableManager get channels =>
      $$ChannelsTableTableManager(_db.attachedDatabase, _db.channels);
}
