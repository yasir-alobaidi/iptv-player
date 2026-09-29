import 'dart:convert';

import 'package:drift/drift.dart';
import 'package:iptv_player/core/result.dart';
import 'package:iptv_player/data/db/app_database.dart';
import 'package:iptv_player/data/settings/settings_repository.dart';
import 'package:iptv_player/features/guide/domain/epg.dart';
import 'package:iptv_player/features/live_tv/data/db_channel_repository.dart';
import 'package:iptv_player/features/live_tv/domain/channels.dart';
import 'package:iptv_player/features/search/domain/search.dart';
import 'package:iptv_player/features/search/domain/search_words.dart';
import 'package:iptv_player/features/vod/data/vod_rows.dart';

/// [SearchRepository] over the FTS5 indexes (`search.drift`): one query
/// per group, run as SQL on the database isolate (hard rule 2). Each
/// picks its group's ids with only the joins its filter and order need,
/// then reads the rows for those few (the pattern of the Movies grid's
/// window).
///
/// **Visible** is decision 8's rule, the one Live TV, the Guide and Home
/// share: a channel the user hid is left out; one in a hidden category
/// is left out unless it is a favorite. Movies and series follow their
/// category the same way.
final class DbSearchRepository implements SearchRepository {
  new(this._db, this._settings);

  final AppDatabase _db;
  final SettingsRepository _settings;

  /// Where the recent searches are kept.
  static const recentKey = 'search.recent';

  /// Rows read per group: one more than shown says whether there are more.
  static const int _read = searchGroupSize + 1;

  @override
  Future<Result<SearchResults>> search(
    String text, {
    required DateTime now,
    String? preferredSourceId,
  }) => Result.guard(() async {
    final words = searchWords(text);
    if (words.isEmpty) return SearchResults(text: text);
    final query = _Query(
      words: words,
      text: text.trim().replaceAll(_spaces, ' '),
      preferred: preferredSourceId ?? '',
      now: now.millisecondsSinceEpoch,
    );
    final sources = await _sourceIds(query.preferred);
    // Sent together, so the database isolate runs them back to back; the
    // first failure is the search's.
    final found = await Future.wait<Object>([
      _channels(query),
      _programmes(query, sources),
      _movies(query),
      _series(query),
    ]);
    final channels = found[0] as SearchGroup<ChannelHit>;
    return SearchResults(
      text: text,
      channels: channels,
      programmes: found[1] as SearchGroup<ProgrammeHit>,
      movies: found[2] as SearchGroup<MovieHit>,
      series: found[3] as SearchGroup<SeriesHit>,
      hiddenChannels: channels.isEmpty ? await _hiddenChannels(query) : 0,
      sourceCount: sources.length,
    );
  });

  static final _spaces = RegExp(r'\s+');

  // ---------------------------------------------------------------- groups

  /// Channels: the browsed source first, then favorites, then names that
  /// start with the text, then a word that does, then the index's rank.
  Future<SearchGroup<ChannelHit>> _channels(_Query query) async {
    final rows = await _db
        .customSelect(
          'WITH hit AS ( '
          'SELECT c.id AS id, c.source_id = ?2 AS preferred, '
          'f.id IS NOT NULL AS favorite, '
          '${_closeness(channelShownName)} AS closeness, '
          'channels_fts.rank AS score, '
          '$channelShownName COLLATE NOCASE AS sort_name '
          'FROM channels_fts JOIN channels c ON c.id = channels_fts.rowid '
          '$_channelFilterJoins '
          'WHERE channels_fts MATCH ?1 AND $_visibleChannel '
          'ORDER BY ${_channelOrder('')} LIMIT $_read) '
          'SELECT $channelColumns, ${_categoryColumns('k')}, '
          'src.name AS source_name '
          'FROM hit JOIN channels c ON c.id = hit.id '
          'JOIN sources src ON src.id = c.source_id '
          '$_channelFilterJoins '
          "ORDER BY ${_channelOrder('hit.')}",
          variables: query.variables,
          readsFrom: {_db.channels, _db.categories, _db.favorites, _db.sources},
        )
        .get();
    return _group([
      for (final row in rows)
        ChannelHit(
          channel: channelFromRow(row),
          sourceName: row.read<String>('source_name'),
          categoryName: _category(row),
        ),
    ]);
  }

  /// Inside the `hit` query its own columns ([of] empty), outside it
  /// `hit.`'s.
  static String _channelOrder(String of) =>
      '${of}preferred DESC, ${of}favorite DESC, ${of}closeness, ${of}score, '
      '${of}sort_name, ${of}id';

  static const _channelFilterJoins =
      'LEFT JOIN categories k ON k.id = c.category_id '
      "LEFT JOIN favorites f ON f.item_type = 'live' "
      'AND f.source_id = c.source_id AND f.remote_key = c.remote_key';

  static const _visibleChannel =
      'c.is_hidden = 0 AND (k.id IS NULL OR k.is_hidden = 0 OR f.id IS NOT '
      'NULL)';

  /// Programmes not finished, on a visible channel: the browsed source
  /// first, then the others; in each, by start, which puts what is on now
  /// first. One hit per programme: of the channels it is on (an HD/SD pair
  /// shares a guide id), a favorite first, else the first the provider
  /// listed.
  ///
  /// **The guide's row ids follow its schedule** (the swap inserts by
  /// start), so each source's matches are read in row id order from the
  /// first programme on now ([_firstLive]) and the read stops at the few
  /// shown. Sorting every match by time instead cost 0.8–5 s for the
  /// short words of a 600,000-programme guide (ADR-013 step 3).
  ///
  /// Words of one letter are too common to look up in the index (every
  /// word that starts with it, over the whole guide): they only narrow
  /// what longer words found, and a text with no longer word finds no
  /// programme.
  Future<SearchGroup<ProgrammeHit>> _programmes(
    _Query query,
    List<String> sources,
  ) async {
    final long = [
      for (final w in query.words)
        if (w.length > 1) '"$w"*',
    ];
    if (long.isEmpty) return const SearchGroup.empty();
    final short = [
      for (final w in query.words)
        if (w.length == 1) '% ${w.replaceAll(r'\', r'\\')}%',
    ];
    // The browsed source's hits first; the others' merged by start.
    final preferred = <ProgrammeHit>[];
    final others = <ProgrammeHit>[];
    for (final source in sources) {
      final found = await _programmesOf(
        source,
        match: long.join(' '),
        shortWords: short,
        now: query.now,
      );
      (source == query.preferred ? preferred : others).addAll(found);
    }
    others.sort((a, b) => a.programme.start.compareTo(b.programme.start));
    final hits = [...preferred, ...others];
    return _group(hits.take(_read).toList());
  }

  Future<List<ProgrammeHit>> _programmesOf(
    String sourceId, {
    required String match,
    required List<String> shortWords,
    required int now,
  }) async {
    final from = await _firstLive(sourceId, now);
    const words = "' ' || p.title || ' ' || COALESCE(p.subtitle, '')";
    final narrowed = [
      for (var i = 0; i < shortWords.length; i++)
        "AND ($words) LIKE ?${i + 5} ESCAPE '\\' ",
    ].join();
    final rows = await _db
        .customSelect(
          'SELECT * FROM ( '
          'SELECT p.id AS programme_id, p.epg_channel_id, p.start_utc, '
          'p.end_utc, p.title, p.subtitle, p.category AS programme_category, '
          '(SELECT c.id FROM epg_matches mt '
          'JOIN channels c ON c.id = mt.channel_id $_channelFilterJoins '
          'WHERE mt.source_id = p.source_id '
          'AND mt.xmltv_id = p.epg_channel_id AND $_visibleChannel '
          'ORDER BY f.id IS NULL, c.id LIMIT 1) AS channel_id '
          'FROM programs_fts JOIN epg_programs p ON p.id = programs_fts.rowid '
          "WHERE programs_fts MATCH '{title subtitle} : (' || ?1 || ')' "
          'AND programs_fts.rowid >= ?2 AND p.source_id = ?3 '
          'AND p.end_utc > ?4 $narrowed'
          'ORDER BY programs_fts.rowid) '
          'WHERE channel_id IS NOT NULL LIMIT $_read',
          variables: [
            Variable.withString(match),
            Variable.withInt(from),
            Variable.withString(sourceId),
            Variable.withInt(now),
            for (final pattern in shortWords) Variable.withString(pattern),
          ],
          readsFrom: {
            _db.epgPrograms,
            _db.epgMatches,
            _db.channels,
            _db.categories,
            _db.favorites,
          },
        )
        .get();
    if (rows.isEmpty) return const [];
    final channels = await _channelsById({
      for (final row in rows) row.read<int>('channel_id'),
    });
    return [
      for (final row in rows)
        if (channels[row.read<int>('channel_id')] case (
          final channel,
          final sourceName,
        ))
          ProgrammeHit(
            programme: EpgProgramme(
              id: row.read<int>('programme_id'),
              channelId: row.read<String>('epg_channel_id'),
              start: _utc(row.read<int>('start_utc')),
              end: _utc(row.read<int>('end_utc')),
              title: row.read<String>('title'),
              subtitle: row.read<String?>('subtitle'),
              category: row.read<String?>('programme_category'),
            ),
            channel: channel,
            sourceName: sourceName,
          ),
    ];
  }

  Future<Map<int, (ChannelItem, String)>> _channelsById(Set<int> ids) async {
    final rows = await _db
        .customSelect(
          'SELECT $channelColumns, src.name AS source_name FROM channels c '
          'JOIN sources src ON src.id = c.source_id '
          '$_channelFilterJoins '
          'WHERE c.id IN (${List.filled(ids.length, '?').join(', ')})',
          variables: [for (final id in ids) Variable.withInt(id)],
          readsFrom: {_db.channels, _db.categories, _db.favorites, _db.sources},
        )
        .get();
    return {
      for (final row in rows)
        row.read<int>('id'): (
          channelFromRow(row),
          row.read<String>('source_name'),
        ),
    };
  }

  /// A row id no programme of [sourceId] still on at [now] or later is
  /// below: the lowest id of the programme each matched guide channel
  /// started last. Remembered for five minutes: row ids only grow and time
  /// only moves on, so an older answer is still below every programme
  /// not finished — only a little further back.
  Future<int> _firstLive(String sourceId, int now) async {
    final held = _firstLiveCache[sourceId];
    if (held != null && now - held.at < _firstLiveFor && now >= held.at) {
      return held.id;
    }
    final row = await _db
        .customSelect(
          'SELECT MIN(id) AS first FROM (SELECT (SELECT p.id FROM '
          'epg_programs p WHERE p.source_id = ?1 '
          'AND p.epg_channel_id = g.xmltv_id AND p.start_utc <= ?2 '
          'ORDER BY p.start_utc DESC LIMIT 1) AS id '
          'FROM (SELECT DISTINCT xmltv_id FROM epg_matches '
          'WHERE source_id = ?1) g)',
          variables: [Variable.withString(sourceId), Variable.withInt(now)],
          readsFrom: {_db.epgPrograms, _db.epgMatches},
        )
        .getSingle();
    final first = row.read<int?>('first') ?? 0;
    _firstLiveCache[sourceId] = (id: first, at: now);
    return first;
  }

  final Map<String, ({int id, int at})> _firstLiveCache = {};
  static const int _firstLiveFor = 5 * 60 * 1000;

  /// Movies in a visible category (or favorites): the browsed source
  /// first, then names that start with the text, then a word that does,
  /// then the index's rank.
  Future<SearchGroup<MovieHit>> _movies(_Query query) async {
    final rows = await _db
        .customSelect(
          'WITH hit AS ( '
          'SELECT m.id AS id, m.source_id = ?2 AS preferred, '
          '${_closeness('m.name')} AS closeness, '
          'movies_fts.rank AS score, m.name COLLATE NOCASE AS sort_name '
          'FROM movies_fts JOIN movies m ON m.id = movies_fts.rowid '
          'LEFT JOIN categories k ON k.id = m.category_id '
          "LEFT JOIN favorites f ON f.item_type = 'movie' "
          'AND f.source_id = m.source_id AND f.remote_key = m.remote_key '
          'WHERE movies_fts MATCH ?1 AND $_visibleTitle '
          'ORDER BY ${_titleOrder('')} LIMIT $_read) '
          'SELECT $movieColumns, d.genre AS genre, '
          '${_categoryColumns('k')}, src.name AS source_name '
          'FROM hit JOIN movies m ON m.id = hit.id '
          'JOIN sources src ON src.id = m.source_id '
          '$movieJoins '
          "ORDER BY ${_titleOrder('hit.')}",
          variables: query.variables,
          readsFrom: {
            _db.movies,
            _db.movieDetails,
            _db.categories,
            _db.favorites,
            _db.watchHistory,
            _db.sources,
          },
        )
        .get();
    return _group([
      for (final row in rows)
        MovieHit(
          movie: movieFromRow(row),
          sourceName: row.read<String>('source_name'),
          categoryName: _category(row),
          genre: _blankToNull(row.read<String?>('genre')),
        ),
    ]);
  }

  Future<SearchGroup<SeriesHit>> _series(_Query query) async {
    final rows = await _db
        .customSelect(
          'WITH hit AS ( '
          'SELECT s.id AS id, s.source_id = ?2 AS preferred, '
          '${_closeness('s.name')} AS closeness, '
          'series_fts.rank AS score, s.name COLLATE NOCASE AS sort_name '
          'FROM series_fts JOIN series s ON s.id = series_fts.rowid '
          'LEFT JOIN categories k ON k.id = s.category_id '
          "LEFT JOIN favorites f ON f.item_type = 'series' "
          'AND f.source_id = s.source_id AND f.remote_key = s.remote_key '
          'WHERE series_fts MATCH ?1 AND $_visibleTitle '
          'ORDER BY ${_titleOrder('')} LIMIT $_read) '
          'SELECT $seriesColumns, ${_categoryColumns('k')}, '
          'src.name AS source_name, '
          '(SELECT COUNT(DISTINCT e.season) FROM episodes e '
          'WHERE e.series_id = s.id) AS seasons '
          'FROM hit JOIN series s ON s.id = hit.id '
          'JOIN sources src ON src.id = s.source_id '
          '$seriesJoins '
          "ORDER BY ${_titleOrder('hit.')}",
          variables: query.variables,
          readsFrom: {
            _db.series,
            _db.episodes,
            _db.categories,
            _db.favorites,
            _db.sources,
          },
        )
        .get();
    return _group([
      for (final row in rows)
        SeriesHit(
          series: seriesFromRow(row),
          sourceName: row.read<String>('source_name'),
          categoryName: _category(row),
          seasons: switch (row.read<int>('seasons')) {
            0 => null,
            final n => n,
          },
        ),
    ]);
  }

  static const _visibleTitle =
      '(k.id IS NULL OR k.is_hidden = 0 OR f.id IS '
      'NOT NULL)';

  static String _titleOrder(String of) =>
      '${of}preferred DESC, ${of}closeness, ${of}score, ${of}sort_name, '
      '${of}id';

  /// Channels that match but aren't visible, for the empty state.
  Future<int> _hiddenChannels(_Query query) async {
    final row = await _db
        .customSelect(
          'SELECT COUNT(*) AS n '
          'FROM channels_fts JOIN channels c ON c.id = channels_fts.rowid '
          '$_channelFilterJoins '
          'WHERE channels_fts MATCH ?1 AND NOT ($_visibleChannel)',
          variables: [Variable.withString(query.match)],
          readsFrom: {_db.channels, _db.categories, _db.favorites},
        )
        .getSingle();
    return row.read<int>('n');
  }

  /// Every source's id, [preferred] first, then in the user's order.
  Future<List<String>> _sourceIds(String preferred) async {
    final rows = await _db
        .customSelect(
          'SELECT id FROM sources ORDER BY id = ?1 DESC, sort_order, id',
          variables: [Variable.withString(preferred)],
          readsFrom: {_db.sources},
        )
        .get();
    return [for (final row in rows) row.read<String>('id')];
  }

  // -------------------------------------------------------------- recent

  @override
  Future<Result<List<String>>> recentSearches() async =>
      (await _settings.readJsonText(recentKey)).map(_decodeRecent);

  @override
  Future<Result<void>> rememberSearch(String text) async {
    final trimmed = text.trim();
    if (trimmed.isEmpty) return const Ok(null);
    return await _updateRecent(
      (recent) => [
        trimmed,
        ...recent.where((r) => r.toLowerCase() != trimmed.toLowerCase()),
      ].take(recentSearchLimit).toList(),
    );
  }

  @override
  Future<Result<void>> forgetSearch(String text) =>
      _updateRecent((recent) => [...recent.where((r) => r != text)]);

  @override
  Future<Result<void>> clearRecentSearches() => _settings.remove(recentKey);

  Future<Result<void>> _updateRecent(
    List<String> Function(List<String> recent) change,
  ) async {
    final read = await recentSearches();
    return switch (read) {
      Ok(:final value) => await _settings.writeValue(recentKey, change(value)),
      Err(:final failure) => Err(failure),
    };
  }

  /// Anything but a list of strings reads as none (hard rule 1).
  static List<String> _decodeRecent(String? stored) {
    if (stored == null) return const [];
    try {
      final decoded = jsonDecode(stored);
      if (decoded is! List) return const [];
      return [
        for (final item in decoded)
          if (item is String && item.trim().isNotEmpty) item,
      ].take(recentSearchLimit).toList();
    } on FormatException {
      return const [];
    }
  }

  // ------------------------------------------------------------- helpers

  /// 0 when [name] starts with the text typed, 1 when a word in it does,
  /// 2 otherwise (the index matched it word by word).
  static String _closeness(String name) =>
      "CASE WHEN $name LIKE ?3 ESCAPE '\\' THEN 0 "
      "WHEN $name LIKE ?4 ESCAPE '\\' THEN 1 ELSE 2 END";

  static String _categoryColumns(String alias) =>
      '$alias.name AS category_name, '
      '$alias.display_name AS category_display_name';

  static String? _category(QueryRow row) =>
      row.read<String?>('category_display_name') ??
      row.read<String?>('category_name');

  static String? _blankToNull(String? text) =>
      text == null || text.trim().isEmpty ? null : text;

  static DateTime _utc(int ms) =>
      DateTime.fromMillisecondsSinceEpoch(ms, isUtc: true);

  static SearchGroup<T> _group<T>(List<T> rows) => rows.length > searchGroupSize
      ? SearchGroup(rows.sublist(0, searchGroupSize), hasMore: true)
      : SearchGroup(rows);
}

/// One search's bound values, in the order the channel, movie and series
/// queries number them: ?1 the FTS query, ?2 the browsed source, ?3 and
/// ?4 the LIKE patterns for "starts with" and "a word starts with".
final class _Query {
  const new({
    required this.words,
    required this.text,
    required this.preferred,
    required this.now,
  });

  final List<String> words;
  final String text;
  final String preferred;

  /// Epoch milliseconds.
  final int now;

  /// Every word as a prefix term, all required.
  String get match => [for (final word in words) '"$word"*'].join(' ');

  List<Variable<Object>> get variables {
    final escaped = text
        .replaceAll(r'\', r'\\')
        .replaceAll('%', r'\%')
        .replaceAll('_', r'\_');
    return [
      Variable.withString(match),
      Variable.withString(preferred),
      Variable.withString('$escaped%'),
      Variable.withString('% $escaped%'),
    ];
  }
}
