import 'package:drift/drift.dart' show Value;
import 'package:flutter_test/flutter_test.dart';
import 'package:iptv_player/core/result.dart';
import 'package:iptv_player/data/db/app_database.dart';
import 'package:iptv_player/data/providers/xtream/xtream_models.dart';
import 'package:iptv_player/features/sources/domain/categories.dart';
import 'package:iptv_player/features/vod/data/db_series_repository.dart';
import 'package:iptv_player/features/vod/data/db_watch_progress.dart';
import 'package:iptv_player/features/vod/domain/catalogue.dart';
import 'package:iptv_player/features/vod/domain/titles.dart';

import 'vod_test_support.dart';

const _episodes = XtreamSeriesInfo(
  plot: 'A harbor inspector follows the tide logs.',
  cast: 'Iris Vance',
  director: 'Ada Keller',
  genre: 'Thriller',
  backdropUrl: 'http://img.test/glass_tide_bg.jpg',
  episodes: [
    XtreamEpisode(id: '7101', season: 1, episode: 1, title: 'Low Water'),
    XtreamEpisode(id: '7102', season: 1, episode: 2, title: 'Ledger'),
    XtreamEpisode(
      id: '7201',
      season: 2,
      episode: 1,
      title: 'Undertow',
      durationSeconds: 3120,
    ),
  ],
);

void main() {
  late AppDatabase db;
  late ScriptedDetails provider;
  late DbSeriesRepository repo;
  late DateTime now;

  setUp(() async {
    db = AppDatabase.memory();
    addTearDown(db.close);
    now = t0;
    provider = ScriptedDetails()..seriesAnswer = const Ok(_episodes);
    repo = DbSeriesRepository(db, provider, clock: () => now);
    await addSource(db, 'src');
    final thrillers = await addCategory(
      db,
      'src',
      CatalogueKind.series,
      '30',
      'Thriller',
    );
    await addSeries(
      db,
      '77',
      'Glass Tide',
      category: thrillers,
      rating: 8.4,
      updated: t0.subtract(const Duration(days: 3)),
    );
    await addSeries(
      db,
      '78',
      'Kettle Bay',
      rating: 7.2,
      updated: t0.subtract(const Duration(days: 1)),
    );
  });

  Future<SeriesItem> glassTide() async =>
      (await repo.byRemoteKey('src', '77')).valueOrNull!;

  test('the grid: recently updated first, by name, by rating', () async {
    Future<List<String>> names(TitleSort sort) async => [
      for (final s in (await repo.range(
        TitleQuery(sourceId: 'src', sort: sort),
        0,
        10,
      )).valueOrNull!)
        s.name,
    ];
    expect(await names(TitleSort.recentlyAdded), ['Kettle Bay', 'Glass Tide']);
    expect(await names(TitleSort.name), ['Glass Tide', 'Kettle Bay']);
    expect(await names(TitleSort.rating), ['Glass Tide', 'Kettle Bay']);
    expect(await repo.watchCount(const TitleQuery(sourceId: 'src')).first, 2);
  });

  group('details (decision 2)', () {
    test("the first open fetches the seasons and the series' own info; the "
        'second makes no request', () async {
      final first = await repo.details(await glassTide()).toList();

      expect(first.first, isA<DetailsLoading<SeriesDetails>>());
      final details = (first.last as DetailsReady<SeriesDetails>).value;
      expect(details.seasons.map((s) => s.number), [1, 2]);
      expect(details.seasons.first.episodes.map((e) => e.title), [
        'Low Water',
        'Ledger',
      ]);
      expect(
        details.seasons.last.episodes.single.duration,
        const Duration(minutes: 52),
      );
      expect(details.backdropUrl, 'http://img.test/glass_tide_bg.jpg');
      expect(details.cast, 'Iris Vance');
      expect(details.episodeCount, 3);
      expect(provider.seriesCalls, 1);

      now = t0.add(const Duration(hours: 23));
      final second = await repo.details(await glassTide()).toList();
      expect(second.single, isA<DetailsReady<SeriesDetails>>());
      expect(provider.seriesCalls, 1);
    });

    test('a day later, or once last_modified moved, it is fetched again '
        'behind the cache', () async {
      await repo.details(await glassTide()).drain<void>();

      now = t0.add(const Duration(hours: 25));
      final dayLater = await repo.details(await glassTide()).toList();
      expect((dayLater.first as DetailsReady<SeriesDetails>).refreshing, true);
      expect(provider.seriesCalls, 2);

      // The next sync says the series changed after that fetch.
      await db.seriesDao.upsertAll([
        SeriesCompanion.insert(
          sourceId: 'src',
          remoteKey: '77',
          name: 'Glass Tide',
          updatedAt: Value(now.add(const Duration(minutes: 5))),
        ),
      ]);
      now = now.add(const Duration(minutes: 10));
      await repo.details(await glassTide()).drain<void>();
      expect(provider.seriesCalls, 3);
    });

    test('a failed refresh keeps the episodes and says nothing; a failed '
        'first fetch says why', () async {
      await repo.details(await glassTide()).drain<void>();
      now = t0.add(const Duration(days: 2));
      provider.seriesAnswer = Err(NetworkFailure('offline'));

      final refresh = await repo.details(await glassTide()).toList();
      final kept = refresh.last as DetailsReady<SeriesDetails>;
      expect(kept.refreshing, isFalse);
      expect(kept.value.episodeCount, 3);

      final kettle = (await repo.byRemoteKey('src', '78')).valueOrNull!;
      final first = await repo.details(kettle).toList();
      expect(first.last, isA<DetailsFailed<SeriesDetails>>());
    });

    test('an M3U series shows the episodes its sync brought, and fetches '
        'nothing', () async {
      provider.xtream = false;
      await addEpisodes(db, (await glassTide()).id, [(1, 1), (1, 2)]);

      final states = await repo.details(await glassTide()).toList();

      expect(
        (states.single as DetailsReady<SeriesDetails>).value.episodeCount,
        2,
      );
      expect(provider.seriesCalls, 0);
    });

    test('a re-fetch keeps where each episode was left', () async {
      await repo.details(await glassTide()).drain<void>();
      final progress = DbWatchProgress(db, clock: () => now);
      final details = await repo.details(await glassTide()).last;
      final lowWater = (details as DetailsReady<SeriesDetails>)
          .value
          .seasons
          .first
          .episodes
          .first;
      await progress.setWatched(lowWater.ref, watched: true);

      now = t0.add(const Duration(days: 2));
      await repo.details(await glassTide()).drain<void>();

      final marks = await progress.watchSeries('src', '77').first;
      expect(marks['7101']!.completed, isTrue);
    });
  });

  test('the episode after: the next in its season, then the next season, '
      'then none', () async {
    await repo.details(await glassTide()).drain<void>();
    final seasons =
        ((await repo.details(await glassTide()).last)
                as DetailsReady<SeriesDetails>)
            .value
            .seasons;
    final [e11, e12] = seasons.first.episodes;
    final e21 = seasons.last.episodes.single;

    expect((await repo.episodeAfter(e11)).valueOrNull, e12);
    expect((await repo.episodeAfter(e12)).valueOrNull, e21);
    expect((await repo.episodeAfter(e21)).valueOrNull, isNull);
  });
}
