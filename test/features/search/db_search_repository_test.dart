import 'dart:math';

import 'package:drift/drift.dart' hide isNull;
import 'package:flutter_test/flutter_test.dart';
import 'package:iptv_player/data/db/app_database.dart';
import 'package:iptv_player/data/db/catalogue_tables.dart';
import 'package:iptv_player/data/db/epg_tables.dart';
import 'package:iptv_player/data/db/tables.dart';
import 'package:iptv_player/data/db/user_tables.dart';
import 'package:iptv_player/data/settings/settings_repository.dart';
import 'package:iptv_player/data/sync/channel_rows.dart';
import 'package:iptv_player/features/search/data/db_search_repository.dart';
import 'package:iptv_player/features/search/domain/search.dart';

final _now = DateTime.utc(2026, 9, 29, 20);

/// A catalogue with every case the groups rank and filter on: two
/// sources, a hidden category with one favorite in it, a channel hidden
/// itself, an HD/SD pair on one guide id, programmes on now, later and
/// finished, and movies and series in visible and hidden categories.
final class _Catalogue {
  new _(this.db) : repo = DbSearchRepository(db, SettingsRepository(db));

  final AppDatabase db;
  final DbSearchRepository repo;
  final ids = <String, int>{};

  static Future<_Catalogue> open() async {
    final db = AppDatabase.memory();
    addTearDown(db.close);
    final catalogue = _Catalogue._(db);
    await catalogue._seed();
    return catalogue;
  }

  Future<void> _source(String id, String name) => db
      .into(db.sources)
      .insert(
        SourcesCompanion.insert(
          id: id,
          type: SourceType.xtream,
          name: name,
          url: 'http://$id.test',
          createdAt: _now,
          updatedAt: _now,
        ),
      );

  Future<int> _category(
    String source,
    CatalogueKind kind,
    String key,
    String name, {
    bool hidden = false,
  }) => db
      .into(db.categories)
      .insert(
        CategoriesCompanion.insert(
          sourceId: source,
          kind: kind,
          remoteKey: key,
          name: name,
          isHidden: Value(hidden),
        ),
      );

  Future<void> _channel(
    String source,
    String key,
    String name, {
    int? category,
    bool hidden = false,
  }) async {
    await db.channelsDao.upsertAll([
      withCleanName(
        ChannelsCompanion.insert(
          sourceId: source,
          remoteKey: key,
          name: name,
          categoryId: Value(category),
          number: Value(int.tryParse(key)),
          isHidden: Value(hidden),
        ),
      ),
    ]);
    ids['$source/$key'] = (await db.channelsDao.byRemoteKey(source, key))!.id;
  }

  Future<void> favorite(String source, String key, UserItemType type) =>
      db.favoritesDao.add(type, source, key, _now);

  Future<void> _match(String source, String key, String xmltvId) => db
      .into(db.epgMatches)
      .insert(
        EpgMatchesCompanion.insert(
          channelId: Value(ids['$source/$key']!),
          sourceId: source,
          xmltvId: xmltvId,
          rule: EpgMatchRule.exactId,
        ),
      );

  final _guide = <EpgProgramsCompanion>[];

  /// Queues a programme; [putGuide] writes them.
  void programme(
    String source,
    String xmltvId,
    String title, {
    required Duration from,
    required Duration to,
    String? subtitle,
    String? description,
  }) => _guide.add(
    EpgProgramsCompanion.insert(
      sourceId: source,
      epgChannelId: xmltvId,
      startUtc: _now.add(from).millisecondsSinceEpoch,
      endUtc: _now.add(to).millisecondsSinceEpoch,
      title: title,
      subtitle: Value(subtitle),
      description: Value(description),
    ),
  );

  /// The queued programmes, by start, as the guide's swap writes them.
  Future<void> putGuide() async {
    _guide.sort((a, b) => a.startUtc.value.compareTo(b.startUtc.value));
    await db.batch((b) => b.insertAll(db.epgPrograms, _guide));
    _guide.clear();
  }

  Future<void> _movie(String source, String key, String name, int? category) =>
      db.moviesDao.upsertAll([
        MoviesCompanion.insert(
          sourceId: source,
          remoteKey: key,
          name: name,
          categoryId: Value(category),
          year: const Value(2024),
        ),
      ]);

  Future<void> _series(String source, String key, String name, int? category) =>
      db.seriesDao.upsertAll([
        SeriesCompanion.insert(
          sourceId: source,
          remoteKey: key,
          name: name,
          categoryId: Value(category),
        ),
      ]);

  Future<void> _seed() async {
    await _source('a', 'Northwind TV');
    await _source('b', 'Harbor Cable');
    final sports = await _category('a', CatalogueKind.live, '1', 'UK | Sports');
    final news = await _category(
      'a',
      CatalogueKind.live,
      '2',
      'UK | News',
      hidden: true,
    );
    await _channel('a', '101', 'UK: Arena Sports 1 FHD', category: sports);
    await _channel('a', '102', 'UK: Arena Sports 2 HD', category: sports);
    await _channel('a', '103', 'UK: Sports Arena Extra', category: sports);
    await _channel('a', '104', 'UK: Arena Sports 1 SD', category: sports);
    await _channel('a', '201', 'UK: World News', category: news);
    await _channel('a', '202', 'UK: City News', category: news);
    await _channel(
      'a',
      '301',
      'UK: Hidden Arena',
      category: sports,
      hidden: true,
    );
    await _channel('b', '101', 'Arena Sports 1');
    await favorite('a', '202', UserItemType.live);
    await favorite('a', '301', UserItemType.live);

    await _match('a', '101', 'arena1');
    await _match('a', '104', 'arena1');
    await _match('a', '201', 'world');
    await _match('b', '101', 'arena1.b');
    programme(
      'a',
      'arena1',
      'Continental Cup',
      subtitle: 'Semi-final',
      from: const Duration(minutes: -30),
      to: const Duration(minutes: 60),
    );
    programme(
      'a',
      'arena1',
      'Continental Cup Highlights',
      from: const Duration(hours: 2),
      to: const Duration(hours: 3),
    );
    programme(
      'a',
      'arena1',
      'Continental Cup Preview',
      from: const Duration(hours: -2),
      to: const Duration(minutes: -10),
    );
    programme(
      'a',
      'world',
      'Continental Report',
      from: Duration.zero,
      to: const Duration(hours: 1),
    );
    programme(
      'b',
      'arena1.b',
      'Continental Cup',
      subtitle: 'Semi-final',
      from: const Duration(minutes: -30),
      to: const Duration(minutes: 60),
    );
    programme(
      'a',
      'arena1',
      'Late Film',
      description: 'A continental drama',
      from: const Duration(hours: 4),
      to: const Duration(hours: 6),
    );
    await putGuide();

    final films = await _category('a', CatalogueKind.movie, '10', 'Films');
    final hiddenFilms = await _category(
      'a',
      CatalogueKind.movie,
      '11',
      'Adult',
      hidden: true,
    );
    await _movie('a', 'm1', 'The Arena', films);
    await _movie('a', 'm2', 'Arena of Kings', films);
    await _movie('a', 'm3', 'Arena Hidden', hiddenFilms);
    await _movie('a', 'm4', 'Arena Starred', hiddenFilms);
    await favorite('a', 'm4', UserItemType.movie);
    final m2 = (await db.moviesDao.byRemoteKey('a', 'm2'))!;
    await db.moviesDao.saveDetails(
      MovieDetailsCompanion.insert(
        movieId: Value(m2.id),
        genre: const Value('Drama'),
        fetchedAt: _now,
      ),
    );

    final shows = await _category('a', CatalogueKind.series, '20', 'Crime');
    await _series('a', 's1', 'Arena Chronicles', shows);
    await _series('b', 's1', 'The Arena Files', null);
    final chronicles = (await db.seriesDao.byRemoteKey('a', 's1'))!;
    await db.seriesDao.replaceEpisodes(chronicles.id, [
      for (final (season, episode) in [(1, 1), (1, 2), (2, 1)])
        EpisodesCompanion.insert(
          seriesId: chronicles.id,
          remoteKey: 'e$season-$episode',
          season: season,
          episode: episode,
          title: 'Episode $episode',
        ),
    ], fetchedAt: _now);
  }

  Future<SearchResults> search(String text, {String? preferred = 'a'}) async {
    final result = await repo.search(
      text,
      preferredSourceId: preferred,
      now: _now,
    );
    return result.valueOrNull ??
        (throw StateError('search failed: ${result.failureOrNull}'));
  }
}

List<String> _channels(SearchResults results) => [
  for (final hit in results.channels.hits)
    '${hit.channel.sourceId}/${hit.channel.remoteKey}',
];

void main() {
  group('channels', () {
    test('the browsed source first, then favorites, then names that start '
        'with the text, then a word that does', () async {
      final catalogue = await _Catalogue.open();
      await catalogue.favorite('a', '102', UserItemType.live);

      final results = await catalogue.search('arena');

      expect(_channels(results), ['a/102', 'a/101', 'a/104', 'a/103', 'b/101']);
      final first = results.channels.hits.first;
      expect(first.channel.name, 'Arena Sports 2');
      expect(first.channel.isFavorite, isTrue);
      expect(first.sourceName, 'Northwind TV');
      expect(first.categoryName, 'UK | Sports');
      expect(results.sourceCount, 2);

      final other = await catalogue.search('arena', preferred: 'b');
      expect(_channels(other).first, 'b/101');
    });

    test('several words: each must start a word of the name shown', () async {
      final catalogue = await _Catalogue.open();

      // Equally close: the index's rank, then the name.
      expect(_channels(await catalogue.search('arena sp')), [
        'a/101',
        'a/104',
        'a/102',
        'a/103',
        'b/101',
      ]);
      expect(_channels(await catalogue.search('sports extra')), ['a/103']);
      expect(_channels(await catalogue.search('rena')), isEmpty);
    });

    test("the provider's tags are not searched, a rename is", () async {
      final catalogue = await _Catalogue.open();
      expect(_channels(await catalogue.search('uk')), isEmpty);
      expect(_channels(await catalogue.search('fhd')), isEmpty);

      await catalogue.db.channelsDao.rename(catalogue.ids['a/103']!, 'Mine');
      expect(_channels(await catalogue.search('mine')), ['a/103']);
    });

    test('case and accents fold', () async {
      final catalogue = await _Catalogue.open();
      expect(_channels(await catalogue.search('ÄRÉNA SPÖRTS 1')), [
        'a/101',
        'a/104',
        'b/101',
      ]);
    });

    test('hidden: a channel hidden itself is gone, favorite or not; one in '
        'a hidden category only shows as a favorite', () async {
      final catalogue = await _Catalogue.open();

      final news = await catalogue.search('news');
      expect(_channels(news), ['a/202']);
      expect(news.hiddenChannels, 0, reason: 'something visible matched');

      final world = await catalogue.search('world');
      expect(_channels(world), isEmpty);
      expect(world.hiddenChannels, 1);

      final hidden = await catalogue.search('hidden');
      expect(_channels(hidden), isEmpty);
      expect(hidden.hiddenChannels, 1);
    });

    test('five shown, and a sixth says there are more', () async {
      final catalogue = await _Catalogue.open();
      await catalogue._channel('a', '105', 'Arena Plus');
      final results = await catalogue.search('a');

      expect(results.channels.hits, hasLength(searchGroupSize));
      expect(results.channels.hasMore, isTrue);
      final few = await catalogue.search('sports extra');
      expect(few.channels.hasMore, isFalse);
    });
  });

  group('programmes', () {
    test('not finished, on a visible channel; on now first, then by start; '
        'one hit for an HD/SD pair', () async {
      final catalogue = await _Catalogue.open();

      final results = await catalogue.search('continental');
      final hits = results.programmes.hits;

      expect(
        [for (final h in hits) (h.programme.title, h.channel.sourceId)],
        [
          ('Continental Cup', 'a'),
          ('Continental Cup Highlights', 'a'),
          ('Continental Cup', 'b'),
        ],
      );
      expect(hits.first.isOnAt(_now), isTrue);
      expect(hits.first.programme.subtitle, 'Semi-final');
      expect(hits.first.channel.remoteKey, '101', reason: 'the first listed');
      expect(hits[1].isOnAt(_now), isFalse);
    });

    test('the pair goes to a favorite channel when there is one', () async {
      final catalogue = await _Catalogue.open();
      await catalogue.favorite('a', '104', UserItemType.live);

      final hits = (await catalogue.search('highlights')).programmes.hits;
      expect(hits.single.channel.remoteKey, '104');
    });

    test(
      'one-letter words only narrow: alone they find no programme',
      () async {
        final catalogue = await _Catalogue.open();

        expect((await catalogue.search('c')).programmes.hits, isEmpty);
        final narrowed = await catalogue.search('continental h');
        expect(
          [for (final h in narrowed.programmes.hits) h.programme.title],
          ['Continental Cup Highlights'],
        );
        final none = await catalogue.search('continental x');
        expect(none.programmes.hits, isEmpty);
      },
    );

    test('a programme that started long before now is still on now', () async {
      final catalogue = await _Catalogue.open();
      catalogue.programme(
        'a',
        'arena1',
        'Marathon Coverage',
        from: const Duration(hours: -20),
        to: const Duration(hours: 2),
      );
      await catalogue.putGuide();

      final hits = (await catalogue.search('marathon')).programmes.hits;
      expect(hits.single.isOnAt(_now), isTrue);
    });

    test('title and subtitle are searched, the description is not', () async {
      final catalogue = await _Catalogue.open();
      final semi = await catalogue.search('semi final');
      expect(semi.programmes.hits, hasLength(2));
      final drama = await catalogue.search('drama');
      expect(drama.programmes.hits, isEmpty);
    });
  });

  group('movies and series', () {
    test('movies: the browsed source, then names that start with the text; '
        'a hidden category only as a favorite', () async {
      final catalogue = await _Catalogue.open();
      final hits = (await catalogue.search('arena')).movies.hits;

      // Both start with it: the index's rank puts the shorter name first.
      expect(
        [for (final h in hits) h.movie.name],
        ['Arena Starred', 'Arena of Kings', 'The Arena'],
      );
      expect(hits.first.movie.isFavorite, isTrue);
      expect(hits[1].genre, 'Drama');
      expect(hits[1].categoryName, 'Films');
      expect(hits[1].movie.year, 2024);
    });

    test('series, with their seasons once the episodes are in', () async {
      final catalogue = await _Catalogue.open();
      final hits = (await catalogue.search('arena')).series.hits;

      expect(
        [for (final h in hits) h.series.name],
        ['Arena Chronicles', 'The Arena Files'],
      );
      expect(hits.first.seasons, 2);
      expect(hits.first.categoryName, 'Crime');
      expect(hits.last.seasons, isNull);
      expect(hits.last.sourceName, 'Harbor Cable');
    });
  });

  group('text', () {
    test('blank or wordless finds nothing, and asks nothing', () async {
      final catalogue = await _Catalogue.open();
      for (final text in ['', '   ', '"*-()', '😀']) {
        final results = await catalogue.search(text);
        expect(results.isEmpty, isTrue, reason: text);
        expect(results.text, text);
      }
    });

    test('no text makes a query fail', () async {
      final catalogue = await _Catalogue.open();
      const pieces = [
        '"',
        "'",
        '*',
        '-',
        '+',
        '^',
        ':',
        '(',
        ')',
        '{',
        '}',
        '[',
        ']',
        'NEAR',
        'NEAR(',
        'AND',
        'OR',
        'NOT',
        'title:',
        '%',
        '_',
        r'\',
        '\ud800',
        '\udfff',
        '😀',
        '\u0000',
        'é',
        'a',
        ' ',
        'arena',
        '1',
        'ا',
        'к',
      ];
      final random = Random(11);
      for (var i = 0; i < 300; i++) {
        final text = [
          for (var j = random.nextInt(8); j >= 0; j--)
            pieces[random.nextInt(pieces.length)],
        ].join();
        final result = await catalogue.repo.search(
          text,
          preferredSourceId: 'a',
          now: _now,
        );
        expect(result.isOk, isTrue, reason: '$text: ${result.failureOrNull}');
      }
    });

    test('LIKE characters in the text are only themselves', () async {
      final catalogue = await _Catalogue.open();
      final results = await catalogue.search('arena_%');
      // The words are "arena": found by the index, none ranked as
      // starting with "arena_%".
      expect(_channels(results).first, 'a/101');
    });
  });

  group('recent searches', () {
    test('newest first, once each, eight at most; forget and clear', () async {
      final catalogue = await _Catalogue.open();
      final repo = catalogue.repo;
      Future<List<String>> recent() async =>
          (await repo.recentSearches()).valueOrNull!;

      expect(await recent(), isEmpty);
      for (final text in ['one', 'two', ' three ', '', 'TWO']) {
        await repo.rememberSearch(text);
      }
      expect(await recent(), ['TWO', 'three', 'one']);

      for (var i = 0; i < 10; i++) {
        await repo.rememberSearch('q$i');
      }
      expect(await recent(), hasLength(recentSearchLimit));
      expect((await recent()).first, 'q9');

      await repo.forgetSearch('q9');
      expect((await recent()).first, 'q8');
      await repo.clearRecentSearches();
      expect(await recent(), isEmpty);
    });

    test('anything stored that is not a list of text reads as none', () async {
      final catalogue = await _Catalogue.open();
      final settings = SettingsRepository(catalogue.db);
      for (final stored in ['{"a":1}', '[1, "ok", null, ""]', 'not json']) {
        await settings.writeJsonText(DbSearchRepository.recentKey, stored);
        final recent = await catalogue.repo.recentSearches();
        expect(recent.isOk, isTrue);
        expect(
          recent.valueOrNull,
          stored.startsWith('[') ? ['ok'] : isEmpty,
          reason: stored,
        );
      }
    });
  });
}
