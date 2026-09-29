import 'package:drift/drift.dart';
import 'package:iptv_player/core/result.dart';
import 'package:iptv_player/data/db/app_database.dart';
import 'package:iptv_player/data/db/user_tables.dart';
import 'package:iptv_player/features/home/domain/home.dart';
import 'package:iptv_player/features/live_tv/domain/channels.dart';
import 'package:iptv_player/features/vod/domain/catalogue.dart';
import 'package:iptv_player/features/vod/domain/titles.dart';

/// [HomeRepository] over the catalogue's own repositories: each row is
/// their query, read again when one of the tables behind it changes.
final class DbHomeRepository implements HomeRepository {
  new(
    this._db, {
    required this._channels,
    required this._movies,
    required this._series,
  });

  final AppDatabase _db;
  final ChannelRepository _channels;
  final MovieRepository _movies;
  final SeriesRepository _series;

  /// Fires once at once, then after every write to [tables].
  Stream<void> _changes(
    Set<ResultSetImplementation<dynamic, dynamic>> tables,
  ) => _db.customSelect('SELECT 1', readsFrom: tables).watch();

  static T _valueOf<T>(Result<T> result) => switch (result) {
    Ok(:final value) => value,
    Err(:final failure) => throw failure,
  };

  @override
  Stream<List<ChannelItem>> favoriteChannels(
    String sourceId, {
    int limit = 20,
  }) => _changes({_db.channels, _db.favorites, _db.categories}).asyncMap(
    (_) => _channels
        .range(
          ChannelQuery(sourceId: sourceId, filter: const FavoriteChannels()),
          0,
          limit,
        )
        .then(_valueOf),
  );

  @override
  Stream<List<ChannelItem>> recentChannels(String sourceId, {int limit = 20}) =>
      _changes({
        _db.watchHistory,
        _db.channels,
        _db.categories,
        _db.favorites,
      }).asyncMap((_) async {
        final rows = await Result.guard(
          () => _db.watchHistoryDao.recent(
            UserItemType.live,
            sourceId,
            limit: limit,
          ),
        );
        final recent = <ChannelItem>[];
        for (final row in _valueOf(rows)) {
          final found = await _channels.byRemoteKey(sourceId, row.remoteKey);
          // Gone from the provider's list, or hidden (itself, or its
          // category unless it is a favorite): not on Home.
          if (found.valueOrNull case final channel? when channel.isVisible) {
            recent.add(channel);
          }
        }
        return recent;
      });

  @override
  Stream<List<MovieItem>> recentMovies(String sourceId, {int limit = 20}) =>
      _changes({
        _db.movies,
        _db.movieDetails,
        _db.favorites,
        _db.watchHistory,
        _db.categories,
      }).asyncMap(
        (_) => _movies
            .range(TitleQuery(sourceId: sourceId), 0, limit)
            .then(_valueOf),
      );

  @override
  Stream<List<SeriesItem>> recentSeries(String sourceId, {int limit = 20}) =>
      _changes({_db.series, _db.favorites, _db.categories}).asyncMap(
        (_) => _series
            .range(TitleQuery(sourceId: sourceId), 0, limit)
            .then(_valueOf),
      );

  @override
  Stream<bool> watchedAnything() => _db
      .customSelect(
        'SELECT EXISTS (SELECT 1 FROM watch_history) AS watched',
        readsFrom: {_db.watchHistory},
      )
      .watchSingle()
      .map((row) => row.read<bool>('watched'));
}
