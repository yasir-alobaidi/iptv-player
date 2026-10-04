// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'downloads_dao.dart';

// ignore_for_file: type=lint
mixin _$DownloadsDaoMixin on DatabaseAccessor<AppDatabase> {
  $SourcesTable get sources => attachedDatabase.sources;
  $LibraryFoldersTable get libraryFolders => attachedDatabase.libraryFolders;
  $LibraryItemsTable get libraryItems => attachedDatabase.libraryItems;
  $DownloadsTable get downloads => attachedDatabase.downloads;
  DownloadsDaoManager get managers => DownloadsDaoManager(this);
}

class DownloadsDaoManager {
  final _$DownloadsDaoMixin _db;
  DownloadsDaoManager(this._db);
  $$SourcesTableTableManager get sources =>
      $$SourcesTableTableManager(_db.attachedDatabase, _db.sources);
  $$LibraryFoldersTableTableManager get libraryFolders =>
      $$LibraryFoldersTableTableManager(
        _db.attachedDatabase,
        _db.libraryFolders,
      );
  $$LibraryItemsTableTableManager get libraryItems =>
      $$LibraryItemsTableTableManager(_db.attachedDatabase, _db.libraryItems);
  $$DownloadsTableTableManager get downloads =>
      $$DownloadsTableTableManager(_db.attachedDatabase, _db.downloads);
}
