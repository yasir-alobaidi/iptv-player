import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:iptv_player/core/result.dart';
import 'package:iptv_player/data/db/app_database.dart';
import 'package:iptv_player/data/providers/xtream/xtream_models.dart';
import 'package:iptv_player/features/sources/domain/categories.dart';
import 'package:iptv_player/features/vod/data/db_movie_repository.dart';
import 'package:iptv_player/features/vod/data/db_watch_progress.dart';
import 'package:iptv_player/features/vod/domain/catalogue.dart';
import 'package:iptv_player/features/vod/domain/titles.dart';

import 'vod_test_support.dart';

void main() {
  late AppDatabase db;
  late ScriptedDetails provider;
  late DbMovieRepository repo;
  late DateTime now;
  late int drama;
  late int hiddenKids;

  setUp(() async {
    db = AppDatabase.memory();
    addTearDown(db.close);
    now = t0;
    provider = ScriptedDetails();
    repo = DbMovieRepository(db, provider, clock: () => now);
    await addSource(db, 'src');
    await addSource(db, 'other');
    drama = await addCategory(db, 'src', CatalogueKind.movie, '10', 'Drama');
    hiddenKids = await addCategory(
      db,
      'src',
      CatalogueKind.movie,
      '11',
      'Kids',
      hidden: true,
    );
    await addMovie(
      db,
      '501',
      'The Quiet Harbor',
      category: drama,
      rating: 7.8,
      added: t0.subtract(const Duration(days: 2)),
    );
    await addMovie(
      db,
      '502',
      'copper hollow',
      category: drama,
      rating: 7.1,
      added: t0.subtract(const Duration(days: 30)),
    );
    await addMovie(db, '503', 'Kestrel Point', category: hiddenKids);
    await addMovie(db, '504', 'Ember Road', rating: 6.7);
    await addMovie(db, '505', 'Elsewhere', source: 'other');
  });

  Future<List<String>> names(TitleQuery query) async => [
    for (final m in (await repo.range(query, 0, 50)).valueOrNull!) m.name,
  ];

  group('the grid', () {
    const all = TitleQuery(sourceId: 'src');

    test('all: every movie but those in a hidden category, newest first; '
        'undated ones by when they were first seen', () async {
      expect(await names(all), [
        'The Quiet Harbor',
        'copper hollow',
        // No date: the order the app first saw them, newest first.
        'Ember Road',
      ]);
      expect(await repo.watchCount(all).first, 3);
    });

    test('by name, ignoring case; by rating, unrated last', () async {
      expect(await names(all.copyWith(sort: TitleSort.name)), [
        'copper hollow',
        'Ember Road',
        'The Quiet Harbor',
      ]);
      expect(await names(all.copyWith(sort: TitleSort.rating)), [
        'The Quiet Harbor',
        'copper hollow',
        'Ember Road',
      ]);
    });

    test('a category, uncategorized, a filter', () async {
      expect(await names(all.copyWith(filter: CategoryTitles(drama))), [
        'The Quiet Harbor',
        'copper hollow',
      ]);
      expect(await names(all.copyWith(filter: CategoryTitles(hiddenKids))), [
        'Kestrel Point',
      ]);
      expect(await names(all.copyWith(filter: const UncategorizedTitles())), [
        'Ember Road',
      ]);
      expect(await names(all.copyWith(text: 'HOLL')), ['copper hollow']);
      expect(await names(all.copyWith(text: '50%_')), isEmpty);
    });

    test('a window is the rows at that offset', () async {
      final window = (await repo.range(all, 1, 1)).valueOrNull!;
      expect(window.single.name, 'copper hollow');
    });

    test('favorites: flagged on the item, their own filter, and the count '
        'follows', () async {
      final counts = repo
          .watchCount(all.copyWith(filter: const FavoriteTitles()))
          .take(2)
          .toList();
      final harbor = (await repo.byRemoteKey('src', '501')).valueOrNull!;
      expect(harbor.isFavorite, isFalse);

      await repo.setFavorite(harbor, on: true);

      expect(await counts, [0, 1]);
      expect(
        (await repo.byRemoteKey('src', '501')).valueOrNull!.isFavorite,
        isTrue,
      );
      await repo.setFavorite(harbor, on: false);
      expect(
        await names(all.copyWith(filter: const FavoriteTitles())),
        isEmpty,
      );
    });

    test('where it was left comes with the movie', () async {
      final progress = DbWatchProgress(db, clock: () => now);
      final harbor = (await repo.byRemoteKey('src', '501')).valueOrNull!;
      await progress.save(
        harbor.ref,
        position: const Duration(minutes: 72),
        duration: const Duration(minutes: 118),
      );

      final again = (await repo.byRemoteKey('src', '501')).valueOrNull!;
      expect(again.watch!.position, const Duration(minutes: 72));
      expect(again.watch!.remaining, const Duration(minutes: 46));
      expect(again.watch!.resumable, isTrue);
    });

    test('NEW for a week after it was added', () async {
      final [harbor, copper, ...] = (await repo.range(all, 0, 10)).valueOrNull!;
      expect(harbor.isNewAt(now), isTrue);
      expect(copper.isNewAt(now), isFalse);
    });
  });

  group('details (decision 2)', () {
    Future<MovieItem> harbor() async =>
        (await repo.byRemoteKey('src', '501')).valueOrNull!;

    test(
      'the first open fetches and stores; the second makes no request',
      () async {
        final first = await repo.details(await harbor()).toList();
        expect(first.first, isA<DetailsLoading<MovieDetails>>());
        final ready = first.last as DetailsReady<MovieDetails>;
        expect(ready.value.plot, 'A storm strands a ferry.');
        expect(ready.value.runtime, const Duration(minutes: 118));
        expect(ready.value.fetchedAt, t0);
        expect(provider.movieCalls, 1);

        now = t0.add(const Duration(days: 6));
        final second = await repo.details(await harbor()).toList();
        expect(second, hasLength(1));
        expect((second.single as DetailsReady<MovieDetails>).refreshing, false);
        expect(
          (second.single as DetailsReady<MovieDetails>).value.plot,
          'A storm strands a ferry.',
        );
        expect(provider.movieCalls, 1);
      },
    );

    test('a week later the cache shows at once and is fetched again behind '
        'it', () async {
      await repo.details(await harbor()).drain<void>();
      now = t0.add(const Duration(days: 8));
      provider.movieAnswer = const Ok(XtreamMovieInfo(plot: 'Recut.'));

      final states = await repo.details(await harbor()).toList();

      expect(states, hasLength(2));
      final stale = states.first as DetailsReady<MovieDetails>;
      expect(stale.refreshing, isTrue);
      expect(stale.value.plot, 'A storm strands a ferry.');
      expect((states.last as DetailsReady<MovieDetails>).value.plot, 'Recut.');
      expect(provider.movieCalls, 2);
    });

    test('a failed refresh keeps the cache and says nothing', () async {
      await repo.details(await harbor()).drain<void>();
      now = t0.add(const Duration(days: 8));
      provider.movieAnswer = Err(NetworkFailure('offline'));

      final states = await repo.details(await harbor()).toList();

      final last = states.last as DetailsReady<MovieDetails>;
      expect(last.refreshing, isFalse);
      expect(last.value.plot, 'A storm strands a ferry.');
    });

    test('a failed first fetch is a failure with its reason', () async {
      provider.movieAnswer = Err(NetworkFailure('HTTP 503', 503));

      final states = await repo.details(await harbor()).toList();

      expect(states.first, isA<DetailsLoading<MovieDetails>>());
      final failed = states.last as DetailsFailed<MovieDetails>;
      expect(failed.failure, isA<NetworkFailure>());
      expect(await db.moviesDao.detailsFor((await harbor()).id), isNull);
    });

    test('an empty answer ({} or info: []) is details with nothing in them, '
        'kept like any other', () async {
      provider.movieAnswer = const Ok(XtreamMovieInfo());

      final states = await repo.details(await harbor()).toList();

      final ready = states.last as DetailsReady<MovieDetails>;
      expect(ready.value.plot, isNull);
      await repo.details(await harbor()).drain<void>();
      expect(provider.movieCalls, 1);
    });

    test('two pages opening at once share one request', () async {
      provider.gate = Completer<void>();
      final movie = await harbor();
      final a = repo.details(movie).toList();
      final b = repo.details(movie).toList();
      await pumpEventQueue();
      provider.gate!.complete();

      await Future.wait([a, b]);
      expect(provider.movieCalls, 1);
      expect(
        ((await b).last as DetailsReady<MovieDetails>).value.plot,
        isNotNull,
      );
    });

    test('an M3U source fetches nothing', () async {
      provider.xtream = false;

      final states = await repo.details(await harbor()).toList();

      expect(states.single, isA<DetailsReady<MovieDetails>>());
      expect(provider.movieCalls, 0);
    });

    test('the probe and the backdrop are kept', () async {
      provider.movieAnswer = const Ok(
        XtreamMovieInfo(
          backdropUrl: 'http://img.test/bg.jpg',
          videoHeight: 2160,
          audioChannels: 6,
        ),
      );
      await repo.details(await harbor()).drain<void>();

      final row = (await db.moviesDao.detailsFor((await harbor()).id))!;
      expect(row.videoHeight, 2160);
      expect(row.audioChannels, 6);
      expect(row.backdropUrl, 'http://img.test/bg.jpg');
    });
  });
}
