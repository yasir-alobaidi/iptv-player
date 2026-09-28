/// The SQL and row mappers the movie and series repositories and Continue
/// watching share. Every list is one statement over the catalogue, its
/// categories, the favorites and the history (hard rule 2).
library;

import 'package:drift/drift.dart';
import 'package:iptv_player/data/db/app_database.dart';
import 'package:iptv_player/features/vod/domain/catalogue.dart';
import 'package:iptv_player/features/vod/domain/titles.dart';
import 'package:iptv_player/features/vod/domain/watch_progress.dart';

/// `movies m`, with its category `k`, favorite `f` and history `h`.
const movieColumns =
    'm.id, m.source_id, m.remote_key, m.name, m.poster_url, m.rating, '
    'm.year, m.ext, m.category_id, m.added_at, '
    'f.id IS NOT NULL AS is_favorite, h.position_ms, h.duration_ms, '
    'h.completed, h.updated_at AS watched_at, d.runtime_minutes';

const movieJoins =
    'LEFT JOIN categories k ON k.id = m.category_id '
    "LEFT JOIN favorites f ON f.item_type = 'movie' "
    'AND f.source_id = m.source_id AND f.remote_key = m.remote_key '
    "LEFT JOIN watch_history h ON h.item_type = 'movie' "
    'AND h.source_id = m.source_id AND h.remote_key = m.remote_key '
    'LEFT JOIN movie_details d ON d.movie_id = m.id';

const movieFrom = 'FROM movies m $movieJoins';

/// `series s`, with its category `k` and favorite `f`.
const seriesColumns =
    's.id, s.source_id, s.remote_key, s.name, s.poster_url, s.rating, '
    's.year, s.plot, s.genre, s.backdrop_url, s.category_id, s.updated_at, '
    'f.id IS NOT NULL AS is_favorite';

const seriesJoins =
    'LEFT JOIN categories k ON k.id = s.category_id '
    "LEFT JOIN favorites f ON f.item_type = 'series' "
    'AND f.source_id = s.source_id AND f.remote_key = s.remote_key';

const seriesFrom = 'FROM series s $seriesJoins';

/// The tables [query] filters on, without what only the page shows:
/// counting and picking a window need no history, and no favorites unless
/// the filter is Favorites.
String titleFilterFrom(
  TitleQuery query, {
  required String table,
  required String alias,
  required String favoriteType,
}) => [
  'FROM $table $alias',
  'LEFT JOIN categories k ON k.id = $alias.category_id',
  if (query.filter is FavoriteTitles) _favoriteJoin(favoriteType, alias),
].join(' ');

String _favoriteJoin(String type, String alias) =>
    "JOIN favorites f ON f.item_type = '$type' "
    'AND f.source_id = $alias.source_id AND f.remote_key = $alias.remote_key';

/// A window of [columns]: the page's ids picked on the filtered table
/// alone, in an order an index can walk (`movies_added`, `movies_name`,
/// `movies_rating`), then only those rows joined for the page (Phase 5
/// step 2: 0.4–17 ms for 120 of 30,000, against 27–60 ms joining first).
String titleWindow(
  TitleQuery query, {
  required String table,
  required String alias,
  required String favoriteType,
  required String columns,
  required String joins,
  required String added,
}) {
  final (where, _) = titleWhere(query, alias);
  final order = titleOrder(query.sort, alias, added: added);
  final from = titleFilterFrom(
    query,
    table: table,
    alias: alias,
    favoriteType: favoriteType,
  );
  return 'WITH page AS (SELECT $alias.id AS id $from $where $order '
      'LIMIT ? OFFSET ?) '
      'SELECT $columns FROM page JOIN $table $alias ON $alias.id = page.id '
      '$joins $order';
}

/// `WHERE …` for [query] over the table aliased [alias] (`m` or `s`).
(String, List<Variable<Object>>) titleWhere(TitleQuery query, String alias) {
  final clauses = <String>['$alias.source_id = ?'];
  final variables = <Variable<Object>>[Variable.withString(query.sourceId)];
  switch (query.filter) {
    case AllTitles():
      clauses.add('(k.id IS NULL OR k.is_hidden = 0)');
    case FavoriteTitles():
      clauses.add('f.id IS NOT NULL');
    case CategoryTitles(:final categoryId):
      clauses.add('$alias.category_id = ?');
      variables.add(Variable.withInt(categoryId));
    case UncategorizedTitles():
      clauses.add('k.id IS NULL');
  }
  final text = query.text.trim();
  if (text.isNotEmpty) {
    clauses.add("$alias.name LIKE ? ESCAPE '\\'");
    final escaped = text
        .replaceAll(r'\', r'\\')
        .replaceAll('%', r'\%')
        .replaceAll('_', r'\_');
    variables.add(Variable.withString('%$escaped%'));
  }
  return ('WHERE ${clauses.join(' AND ')}', variables);
}

/// `ORDER BY …` for [sort]; [added] is the column "recently added" reads.
/// SQLite sorts NULLs last when descending: an undated title comes after
/// the dated ones, by when the app first saw it (its row id), and an
/// unrated one after the rated.
String titleOrder(TitleSort sort, String alias, {required String added}) =>
    switch (sort) {
      TitleSort.recentlyAdded => 'ORDER BY $alias.$added DESC, $alias.id DESC',
      TitleSort.name => 'ORDER BY $alias.name COLLATE NOCASE, $alias.id',
      TitleSort.rating =>
        'ORDER BY $alias.rating DESC, $alias.name COLLATE NOCASE, $alias.id',
    };

MovieItem movieFromRow(QueryRow row) => MovieItem(
  id: row.read<int>('id'),
  sourceId: row.read<String>('source_id'),
  remoteKey: row.read<String>('remote_key'),
  name: row.read<String>('name'),
  posterUrl: row.readNullable<String>('poster_url'),
  rating: row.readNullable<double>('rating'),
  year: row.readNullable<int>('year'),
  ext: row.readNullable<String>('ext'),
  categoryId: row.readNullable<int>('category_id'),
  addedAt: row.readNullable<DateTime>('added_at'),
  isFavorite: row.read<bool>('is_favorite'),
  watch: markFromRow(row, updatedAt: 'watched_at'),
  runtime: switch (row.readNullable<int>('runtime_minutes')) {
    final minutes? when minutes > 0 => Duration(minutes: minutes),
    _ => null,
  },
);

SeriesItem seriesFromRow(QueryRow row) => SeriesItem(
  id: row.read<int>('id'),
  sourceId: row.read<String>('source_id'),
  remoteKey: row.read<String>('remote_key'),
  name: row.read<String>('name'),
  posterUrl: row.readNullable<String>('poster_url'),
  rating: row.readNullable<double>('rating'),
  year: row.readNullable<int>('year'),
  plot: row.readNullable<String>('plot'),
  genre: row.readNullable<String>('genre'),
  backdropUrl: row.readNullable<String>('backdrop_url'),
  categoryId: row.readNullable<int>('category_id'),
  updatedAt: row.readNullable<DateTime>('updated_at'),
  isFavorite: row.read<bool>('is_favorite'),
);

/// The history columns of [row], or null when it was never played.
WatchMark? markFromRow(QueryRow row, {String updatedAt = 'updated_at'}) {
  final at = row.readNullable<DateTime>(updatedAt);
  final position = row.readNullable<int>('position_ms');
  if (at == null || position == null) return null;
  final duration = row.readNullable<int>('duration_ms');
  return WatchMark(
    position: Duration(milliseconds: position),
    duration: duration == null ? null : Duration(milliseconds: duration),
    completed: row.readNullable<bool>('completed') ?? false,
    updatedAt: at,
  );
}

WatchMark markFromHistory(WatchHistoryRow row) => WatchMark(
  position: Duration(milliseconds: row.positionMs),
  duration: row.durationMs == null
      ? null
      : Duration(milliseconds: row.durationMs!),
  completed: row.completed,
  updatedAt: row.updatedAt,
);

EpisodeItem episodeFromRow(
  EpisodeRow row, {
  required String sourceId,
  required String seriesKey,
}) => EpisodeItem(
  id: row.id,
  sourceId: sourceId,
  seriesKey: seriesKey,
  remoteKey: row.remoteKey,
  season: row.season,
  episode: row.episode,
  title: row.title,
  ext: row.ext,
  duration: row.durationSeconds == null
      ? null
      : Duration(seconds: row.durationSeconds!),
  plot: row.plot,
  stillUrl: row.stillUrl,
);

/// [episodes] (in season, then episode order) grouped into seasons.
List<Season> seasonsOf(List<EpisodeItem> episodes) {
  final bySeason = <int, List<EpisodeItem>>{};
  for (final episode in episodes) {
    (bySeason[episode.season] ??= []).add(episode);
  }
  return [
    for (final MapEntry(key: number, value: list) in bySeason.entries)
      Season(number: number, episodes: List.unmodifiable(list)),
  ];
}
