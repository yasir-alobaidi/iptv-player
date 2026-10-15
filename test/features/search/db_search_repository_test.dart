import 'dart:math';

import 'package:drift/drift.dart' hide isNull;
import 'package:flutter_test/flutter_test.dart';
import 'package:iptv_player/data/db/app_database.dart';
import 'package:iptv_player/data/db/catalogue_tables.dart';
import 'package:iptv_player/data/db/epg_tables.dart';
import 'package:iptv_player/data/db/library_tables.dart';
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

  /// A folder of the library; its id.
  Future<int> folder(String label, {bool downloads = false}) async => downloads
      ? (await db.libraryDao.makeDownloadFolder(
          '/library/$label',
          label: label,
          at: _now,
        )).id
      : await db.libraryDao.addFolder(
          path: '/library/$label',
          label: label,
          at: _now,
        );

  var _videos = 0;

  /// A video in [folder]; [from] is the provider's title a download came
  /// from: its source, the title's key, and an episode's series.
  Future<int> video(
    int folder,
    String title, {
    LibraryKind kind = LibraryKind.movie,
    String? show,
    int? season,
    int? episode,
    int? year,
    bool hidden = false,
    (String source, String key, String? series)? from,
  }) => db.libraryDao.insertItem(
    LibraryItemsCompanion.insert(
      folderId: folder,
      relPath: 'video-${++_videos}.mkv',
      sizeBytes: 2100000000,
      mtime: _now.millisecondsSinceEpoch,
      quickHash: 'hash-$_videos',
      kind: kind,
      title: title,
      year: Value(year),
      showTitle: Value(show),
      season: Value(season),
      episode: Value(episode),
      durationMs: const Value(12 * 60 * 1000),
      isHidden: Value(hidden),
      providerSourceId: Value(from?.$1),
      providerItemType: Value(
        from == null
            ? null
            : kind == LibraryKind.episode
            ? VodType.episode
            : VodType.movie,
      ),
      providerRemoteKey: Value(from?.$2),
      providerSeriesKey: Value(from?.$3),
      addedAt: _now,
    ),
  );

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

/// The library group as its rows name things: a show by its name, an
/// episode by its show and its own title, anything else by its title.
List<String> _library(SearchResults results) => [
  for (final hit in results.library.hits)
    switch (hit) {
      LibraryShowHit(:final show) => 'show ${show.title}',
      LibraryItemHit(:final item) when item.kind == LibraryKind.episode =>
        'episode ${item.showTitle}: ${item.title}',
      LibraryItemHit(:final item) => item.title,
    },
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

    test('Arabic: an alef with or without its hamza, a closing ة or ه, ى or '
        'ي, and either kind of digit find the same names (ADR-027)', () async {
      final catalogue = await _Catalogue.open();
      await catalogue._movie('a', 'ar1', 'أرطغرل', null);
      await catalogue._movie('a', 'ar2', 'شديد الخطوره', null);
      await catalogue._movie('a', 'ar3', 'العميل ٧٧ (1969)', null);
      await catalogue._movie('a', 'ar4', 'مدرسة المشاغبين', null);
      await catalogue._movie('a', 'ar5', 'الأسكندرية ليه', null);
      await catalogue._movie('a', 'ar6', 'إلى الأبد', null);
      Future<List<String>> movies(String text) async => [
        for (final hit in (await catalogue.search(text)).movies.hits)
          hit.movie.name,
      ];

      expect(await movies('ارطغرل'), ['أرطغرل']);
      expect(await movies('أرطغرل'), ['أرطغرل']);
      expect(await movies('ارط'), ['أرطغرل']);
      expect(await movies('الخطورة'), ['شديد الخطوره']);
      expect(await movies('شديد الخطوره'), ['شديد الخطوره']);
      expect(await movies('العميل 77'), ['العميل ٧٧ (1969)']);
      expect(await movies('١٩٦٩'), ['العميل ٧٧ (1969)']);
      expect(await movies('مدرسه'), ['مدرسة المشاغبين']);
      expect(await movies('الاسكندريه'), ['الأسكندرية ليه']);
      expect(await movies('الابد'), ['إلى الأبد']);
      expect(await movies('اربع'), isEmpty);
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

  group('library', () {
    test('videos by their title, a show by its name with its episodes as '
        'one row, an episode by its own title', () async {
      final catalogue = await _Catalogue.open();
      final hdd = await catalogue.folder('Movies HDD');
      await catalogue.video(hdd, 'Kite Walk', year: 2021);
      await catalogue.video(hdd, 'Kite timelapse', kind: LibraryKind.unsorted);
      for (final (episode, title) in [(1, 'The Long Tide'), (2, '')]) {
        await catalogue.video(
          hdd,
          title,
          kind: LibraryKind.episode,
          show: 'Kite Nine',
          season: 1,
          episode: episode,
        );
      }
      await catalogue.video(
        hdd,
        'Kite Lights',
        kind: LibraryKind.episode,
        show: 'Kettle Bay',
        season: 2,
        episode: 3,
      );

      final kite = await catalogue.search('kite');
      expect(_library(kite), hasLength(4));
      expect(
        _library(kite),
        containsAll([
          'Kite Walk',
          'Kite timelapse',
          'show Kite Nine',
          'episode Kettle Bay: Kite Lights',
        ]),
      );
      final show = kite.library.hits.whereType<LibraryShowHit>().single;
      expect(show.show.episodes, 2);
      expect(show.show.key, 'l:kite nine');
      expect(show.folderLabel, 'Movies HDD');
      final walk = kite.library.hits.whereType<LibraryItemHit>().firstWhere(
        (hit) => hit.item.title == 'Kite Walk',
      );
      expect(walk.folderLabel, 'Movies HDD');
      expect(walk.item.year, 2021);
      expect(walk.item.duration, const Duration(minutes: 12));
      expect(walk.item.path, endsWith('.mkv'));
      expect(kite.count, 4);
      expect(kite.isEmpty, isFalse);

      expect(_library(await catalogue.search('long tide')), [
        'episode Kite Nine: The Long Tide',
      ]);
      // Words from the show's name and the episode's title: the episode.
      expect(_library(await catalogue.search('kite long')), [
        'episode Kite Nine: The Long Tide',
      ]);
      expect(_library(await catalogue.search('kettle')), ['show Kettle Bay']);
      expect(_library(await catalogue.search('ite')), isEmpty);
    });

    test('names that start with the text, then a word that does', () async {
      final catalogue = await _Catalogue.open();
      final hdd = await catalogue.folder('Movies HDD');
      await catalogue.video(hdd, 'The Kite');
      await catalogue.video(hdd, 'Kite Walk');
      await catalogue.video(
        hdd,
        'Pilot',
        kind: LibraryKind.episode,
        show: 'A Kite Story',
        episode: 1,
      );
      await catalogue.video(
        hdd,
        'Pilot',
        kind: LibraryKind.episode,
        show: 'Kite Nine',
        episode: 1,
      );

      final found = _library(await catalogue.search('kite'));
      expect(
        found.sublist(0, 2),
        unorderedEquals(['Kite Walk', 'show Kite Nine']),
      );
      expect(
        found.sublist(2),
        unorderedEquals(['The Kite', 'show A Kite Story']),
      );
    });

    test('a hidden video is left out, and a show goes with its last '
        'episode', () async {
      final catalogue = await _Catalogue.open();
      final hdd = await catalogue.folder('Movies HDD');
      await catalogue.video(hdd, 'Kite Walk', hidden: true);
      final episode = await catalogue.video(
        hdd,
        'Pilot',
        kind: LibraryKind.episode,
        show: 'Kite Nine',
        episode: 1,
      );
      await catalogue.video(
        hdd,
        'Second',
        kind: LibraryKind.episode,
        show: 'Kite Nine',
        episode: 2,
        hidden: true,
      );

      final shown = await catalogue.search('kite');
      expect(_library(shown), ['show Kite Nine']);
      expect(
        (shown.library.hits.single as LibraryShowHit).show.episodes,
        1,
        reason: 'the hidden episode is not counted',
      );

      await catalogue.db.libraryDao.changeItem(
        episode,
        const LibraryItemsCompanion(isHidden: Value(true)),
      );
      final none = await catalogue.search('kite');
      expect(none.library.isEmpty, isTrue);
      expect(none.isEmpty, isTrue);
    });

    test('a download Movies or Series finds is left to them; one they '
        "don't find is here", () async {
      final catalogue = await _Catalogue.open();
      final downloads = await catalogue.folder('Downloads', downloads: true);
      // The provider lists it in a visible category: MOVIES has it.
      await catalogue.video(downloads, 'The Arena', from: ('a', 'm1', null));
      // In a category the user hid: only here.
      await catalogue.video(downloads, 'Arena Hidden', from: ('a', 'm3', null));
      // Hidden category, but a favorite: MOVIES has it.
      await catalogue.video(
        downloads,
        'Arena Starred',
        from: ('a', 'm4', null),
      );
      // The provider dropped it.
      await catalogue.video(
        downloads,
        'Arena Dropped',
        from: ('a', 'gone', null),
      );
      // Renamed in Edit details: MOVIES knows it only by the provider's
      // name.
      await catalogue.video(downloads, 'My Cut', from: ('a', 'm2', null));
      // Episodes of a series SERIES finds by its name, one with a title
      // of its own.
      await catalogue.video(
        downloads,
        'Episode 1',
        kind: LibraryKind.episode,
        show: 'Arena Chronicles',
        season: 1,
        episode: 1,
        from: ('a', 'e1-1', 's1'),
      );
      await catalogue.video(
        downloads,
        'The Kettle Job',
        kind: LibraryKind.episode,
        show: 'Arena Chronicles',
        season: 1,
        episode: 2,
        from: ('a', 'e1-2', 's1'),
      );

      final arena = await catalogue.search('arena');
      expect(
        _library(arena),
        unorderedEquals(['Arena Hidden', 'Arena Dropped']),
      );
      expect([
        for (final hit in arena.movies.hits) hit.movie.remoteKey,
      ], containsAll(['m1', 'm4']));
      expect(arena.series.hits.first.series.remoteKey, 's1');
      final dropped = arena.library.hits.whereType<LibraryItemHit>().firstWhere(
        (hit) => hit.item.title == 'Arena Dropped',
      );
      expect(dropped.item.isDownload, isTrue);
      expect(dropped.folderLabel, 'Downloads');

      expect(_library(await catalogue.search('cut')), ['My Cut']);
      expect(_library(await catalogue.search('kettle')), [
        'episode Arena Chronicles: The Kettle Job',
      ]);
      // The series' name and the episode's title together: SERIES can't
      // find that, the library does.
      expect(_library(await catalogue.search('arena kettle')), [
        'episode Arena Chronicles: The Kettle Job',
      ]);
    });

    test("a provider's series no longer listed: its downloads are a show "
        'here', () async {
      final catalogue = await _Catalogue.open();
      final downloads = await catalogue.folder('Downloads', downloads: true);
      for (final episode in [1, 2]) {
        await catalogue.video(
          downloads,
          'Episode $episode',
          kind: LibraryKind.episode,
          show: 'Glass Tide',
          season: 1,
          episode: episode,
          from: ('a', 'g$episode', 'gone'),
        );
      }

      final found = await catalogue.search('glass');
      final hit = found.library.hits.single as LibraryShowHit;
      expect(hit.show.key, 'p:a:gone');
      expect(hit.show.downloaded, isTrue);
      expect(hit.show.episodes, 2);
      expect(hit.show.providerSeriesKey, 'gone');
    });

    test('a show in several folders names none', () async {
      final catalogue = await _Catalogue.open();
      final hdd = await catalogue.folder('Movies HDD');
      final usb = await catalogue.folder('USB drive');
      for (final (folder, episode) in [(hdd, 1), (usb, 2)]) {
        await catalogue.video(
          folder,
          'Episode $episode',
          kind: LibraryKind.episode,
          show: 'Kite Nine',
          episode: episode,
        );
      }

      final hit =
          (await catalogue.search('kite')).library.hits.single
              as LibraryShowHit;
      expect(hit.show.episodes, 2);
      expect(hit.folderLabel, isNull);
    });

    test('five shown, and a sixth says there are more; accents and case '
        'fold', () async {
      final catalogue = await _Catalogue.open();
      final hdd = await catalogue.folder('Movies HDD');
      for (var i = 1; i <= 6; i++) {
        await catalogue.video(hdd, 'Été Kite $i');
      }

      final found = await catalogue.search('ETE k');
      expect(found.library.hits, hasLength(searchGroupSize));
      expect(found.library.hasMore, isTrue);
      expect(_library(found).first, 'Été Kite 1');
      expect((await catalogue.search('été kite 6')).library.hasMore, isFalse);
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
