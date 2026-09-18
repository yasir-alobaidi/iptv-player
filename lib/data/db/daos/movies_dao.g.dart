// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'movies_dao.dart';

// ignore_for_file: type=lint
mixin _$MoviesDaoMixin on DatabaseAccessor<AppDatabase> {
  $SourcesTable get sources => attachedDatabase.sources;
  $CategoriesTable get categories => attachedDatabase.categories;
  $MoviesTable get movies => attachedDatabase.movies;
  $MovieDetailsTable get movieDetails => attachedDatabase.movieDetails;
  MoviesDaoManager get managers => MoviesDaoManager(this);
}

class MoviesDaoManager {
  final _$MoviesDaoMixin _db;
  MoviesDaoManager(this._db);
  $$SourcesTableTableManager get sources =>
      $$SourcesTableTableManager(_db.attachedDatabase, _db.sources);
  $$CategoriesTableTableManager get categories =>
      $$CategoriesTableTableManager(_db.attachedDatabase, _db.categories);
  $$MoviesTableTableManager get movies =>
      $$MoviesTableTableManager(_db.attachedDatabase, _db.movies);
  $$MovieDetailsTableTableManager get movieDetails =>
      $$MovieDetailsTableTableManager(_db.attachedDatabase, _db.movieDetails);
}
