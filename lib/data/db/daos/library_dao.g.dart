// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'library_dao.dart';

// ignore_for_file: type=lint
mixin _$LibraryDaoMixin on DatabaseAccessor<AppDatabase> {
  $LibraryFoldersTable get libraryFolders => attachedDatabase.libraryFolders;
  $SourcesTable get sources => attachedDatabase.sources;
  $LibraryItemsTable get libraryItems => attachedDatabase.libraryItems;
  LibraryDaoManager get managers => LibraryDaoManager(this);
}

class LibraryDaoManager {
  final _$LibraryDaoMixin _db;
  LibraryDaoManager(this._db);
  $$LibraryFoldersTableTableManager get libraryFolders =>
      $$LibraryFoldersTableTableManager(
        _db.attachedDatabase,
        _db.libraryFolders,
      );
  $$SourcesTableTableManager get sources =>
      $$SourcesTableTableManager(_db.attachedDatabase, _db.sources);
  $$LibraryItemsTableTableManager get libraryItems =>
      $$LibraryItemsTableTableManager(_db.attachedDatabase, _db.libraryItems);
}
