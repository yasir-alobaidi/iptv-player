// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'categories_dao.dart';

// ignore_for_file: type=lint
mixin _$CategoriesDaoMixin on DatabaseAccessor<AppDatabase> {
  $SourcesTable get sources => attachedDatabase.sources;
  $CategoriesTable get categories => attachedDatabase.categories;
  $ChannelsTable get channels => attachedDatabase.channels;
  $MoviesTable get movies => attachedDatabase.movies;
  $SeriesTable get series => attachedDatabase.series;
  CategoriesDaoManager get managers => CategoriesDaoManager(this);
}

class CategoriesDaoManager {
  final _$CategoriesDaoMixin _db;
  CategoriesDaoManager(this._db);
  $$SourcesTableTableManager get sources =>
      $$SourcesTableTableManager(_db.attachedDatabase, _db.sources);
  $$CategoriesTableTableManager get categories =>
      $$CategoriesTableTableManager(_db.attachedDatabase, _db.categories);
  $$ChannelsTableTableManager get channels =>
      $$ChannelsTableTableManager(_db.attachedDatabase, _db.channels);
  $$MoviesTableTableManager get movies =>
      $$MoviesTableTableManager(_db.attachedDatabase, _db.movies);
  $$SeriesTableTableManager get series =>
      $$SeriesTableTableManager(_db.attachedDatabase, _db.series);
}
