// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'favorites_dao.dart';

// ignore_for_file: type=lint
mixin _$FavoritesDaoMixin on DatabaseAccessor<AppDatabase> {
  $SourcesTable get sources => attachedDatabase.sources;
  $FavoriteGroupsTable get favoriteGroups => attachedDatabase.favoriteGroups;
  $FavoritesTable get favorites => attachedDatabase.favorites;
  FavoritesDaoManager get managers => FavoritesDaoManager(this);
}

class FavoritesDaoManager {
  final _$FavoritesDaoMixin _db;
  FavoritesDaoManager(this._db);
  $$SourcesTableTableManager get sources =>
      $$SourcesTableTableManager(_db.attachedDatabase, _db.sources);
  $$FavoriteGroupsTableTableManager get favoriteGroups =>
      $$FavoriteGroupsTableTableManager(
        _db.attachedDatabase,
        _db.favoriteGroups,
      );
  $$FavoritesTableTableManager get favorites =>
      $$FavoritesTableTableManager(_db.attachedDatabase, _db.favorites);
}
