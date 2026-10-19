import 'package:drift/drift.dart';
import 'package:iptv_player/core/result.dart';
import 'package:iptv_player/data/db/app_database.dart';
import 'package:iptv_player/data/db/table_changes.dart';
import 'package:iptv_player/features/home/domain/home.dart';
import 'package:iptv_player/features/live_tv/data/db_channel_repository.dart';
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
  ) => tableChanges(_db, tables);

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

  /// One statement: the history joined to the channels it still finds.
  /// Gone from the provider's list, or hidden (itself, or its category
  /// unless it is a favorite, as `ChannelItem.isVisible`): not on Home.
  ///
  /// Of the channels shown by one name, in any capitals, only the most
  /// recently watched stays, in its place. Panels list one channel as
  /// several streams (`beIN SP 1 FHD`, `beIN SP 1 HD`, or one per
  /// category); the cleaned name drops the quality, and a tile shows no
  /// badge, so both were "beIN SP 1" twice. A name the user gave one tells
  /// it apart. The limit counts what is left.
  @override
  Stream<List<ChannelItem>> recentChannels(String sourceId, {int limit = 20}) =>
      _changes({
        _db.watchHistory,
        _db.channels,
        _db.categories,
        _db.favorites,
      }).asyncMap(
        (_) => Result.guard(() async {
          final rows = await _db
              .customSelect(
                'SELECT * FROM (SELECT $channelColumns, '
                'h.updated_at AS watched_at, h.id AS watch_id, '
                'ROW_NUMBER() OVER (PARTITION BY LOWER($channelShownName) '
                'ORDER BY h.updated_at DESC, h.id DESC) AS n '
                'FROM watch_history h '
                'JOIN channels c ON c.source_id = h.source_id '
                'AND c.remote_key = h.remote_key '
                'LEFT JOIN categories k ON k.id = c.category_id '
                "LEFT JOIN favorites f ON f.item_type = 'live' "
                'AND f.source_id = c.source_id AND f.remote_key = c.remote_key '
                "WHERE h.item_type = 'live' AND h.source_id = ? "
                'AND c.is_hidden = 0 '
                'AND (COALESCE(k.is_hidden, 0) = 0 OR f.id IS NOT NULL)) '
                'WHERE n = 1 ORDER BY watched_at DESC, watch_id DESC LIMIT ?',
                variables: [
                  Variable.withString(sourceId),
                  Variable.withInt(limit),
                ],
                readsFrom: {
                  _db.watchHistory,
                  _db.channels,
                  _db.categories,
                  _db.favorites,
                },
              )
              .get();
          return [for (final row in rows) channelFromRow(row)];
        }).then(_valueOf),
      );

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
