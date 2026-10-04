import 'package:flutter_test/flutter_test.dart';
import 'package:iptv_player/data/db/app_database.dart';
import 'package:iptv_player/features/vod/data/db_watch_progress.dart';
import 'package:iptv_player/features/vod/domain/watch_progress.dart';

import 'vod_test_support.dart';

void main() {
  late AppDatabase db;
  late DbWatchProgress progress;
  late DateTime now;
  late int glassTide;

  const harbor = MovieRef('src', 'm1');
  const ember = MovieRef('src', 'm2');
  const elsewhere = MovieRef('other', 'm9');
  EpisodeRef episode(int season, int number) =>
      EpisodeRef('src', 'e$season-$number', seriesKey: '77');

  const hour = Duration(hours: 1);
  const length = Duration(minutes: 100);

  setUp(() async {
    db = AppDatabase.memory();
    addTearDown(db.close);
    now = t0;
    progress = DbWatchProgress(db, clock: () => now);
    await addSource(db, 'src');
    await addSource(db, 'other');
    await addMovie(db, 'm1', 'The Quiet Harbor');
    await addMovie(db, 'm2', 'Ember Road');
    await addMovie(db, 'm9', 'Elsewhere', source: 'other');
    glassTide = await addSeries(db, '77', 'Glass Tide');
    await addEpisodes(db, glassTide, [(1, 1), (1, 2), (2, 1)]);
  });

  Future<void> save(VodRef ref, Duration position, {Duration? duration}) async {
    now = now.add(const Duration(minutes: 1));
    await progress.save(ref, position: position, duration: duration ?? length);
  }

  Future<List<ContinueItem>> cards() => progress.continueWatching().first;

  String describe(ContinueItem item) => switch (item) {
    ContinueMovie(:final movie) => movie.name,
    ContinueEpisode(:final episode, :final upNext) =>
      '${episode.remoteKey}${upNext ? ' next' : ''}',
    ContinueLibraryFile(:final item) => 'file ${item.title}',
  };

  group('saving', () {
    test('watched at 95 %, not before; resumable between a minute and '
        'that', () async {
      await save(harbor, const Duration(seconds: 50));
      var mark = (await progress.watch(harbor).first)!;
      expect(mark.resumable, isFalse, reason: 'under a minute');

      await save(harbor, const Duration(minutes: 72));
      mark = (await progress.watch(harbor).first)!;
      expect(mark.resumable, isTrue);
      expect(mark.completed, isFalse);
      expect(mark.remaining, const Duration(minutes: 28));

      await save(harbor, const Duration(minutes: 95));
      mark = (await progress.watch(harbor).first)!;
      expect(mark.completed, isTrue);
      expect(mark.resumable, isFalse);
    });

    test(
      'a length the player never learned: never watched by position',
      () async {
        await progress.save(harbor, position: const Duration(hours: 3));
        final mark = (await progress.watch(harbor).first)!;
        expect(mark.completed, isFalse);
        expect(mark.duration, isNull);
      },
    );

    test('mark as watched, and forget it again', () async {
      await progress.setWatched(episode(1, 1), watched: true);
      expect(
        (await progress.watchSeries('src', '77').first)['e1-1']!.completed,
        isTrue,
      );
      await progress.setWatched(episode(1, 1), watched: false);
      expect(await progress.watchSeries('src', '77').first, isEmpty);
    });
  });

  group('Continue watching (decision 5)', () {
    test(
      'movies between a minute and 95 %, newest first, every source',
      () async {
        await save(harbor, const Duration(minutes: 30));
        await save(ember, const Duration(seconds: 20));
        await save(elsewhere, const Duration(minutes: 10));

        expect((await cards()).map(describe), [
          'Elsewhere',
          'The Quiet Harbor',
        ]);

        await save(ember, const Duration(minutes: 5));
        await save(harbor, const Duration(minutes: 99));
        expect((await cards()).map(describe), ['Ember Road', 'Elsewhere']);
      },
    );

    test('a series: the episode in progress, else the one after the last '
        'finished, and nothing after the last one', () async {
      await save(episode(1, 1), length);
      expect((await cards()).map(describe), ['e1-2 next']);

      await save(episode(1, 2), const Duration(minutes: 5));
      final [card] = await cards();
      expect(describe(card), 'e1-2');
      expect(
        (card as ContinueEpisode).mark!.position,
        const Duration(minutes: 5),
      );
      expect(card.series.name, 'Glass Tide');

      // Finishing season 1 moves on to season 2.
      await save(episode(1, 2), length);
      expect((await cards()).map(describe), ['e2-1 next']);

      await save(episode(2, 1), length);
      expect(await cards(), isEmpty);
    });

    test(
      'a few seconds of the next episode still show it from the start',
      () async {
        await save(episode(1, 1), length);
        await save(episode(1, 2), const Duration(seconds: 12));

        final [card] = await cards();
        expect(describe(card), 'e1-2 next');
      },
    );

    test(
      'dismissed: gone, series whole; watching again brings it back',
      () async {
        await save(harbor, const Duration(minutes: 30));
        await save(episode(1, 1), length);
        await save(episode(1, 2), const Duration(minutes: 5));
        final all = await cards();
        expect(all, hasLength(2));

        for (final card in all) {
          await progress.dismiss(card);
        }
        expect(await cards(), isEmpty);

        await save(episode(1, 2), const Duration(minutes: 6));
        expect((await cards()).map(describe), ['e1-2']);
      },
    );

    test('follows the history as it changes', () async {
      final seen = progress.continueWatching().take(2).toList();
      await pumpEventQueue();
      await save(harbor, const Duration(minutes: 30));

      final [before, after] = await seen;
      expect(before, isEmpty);
      expect(after.map(describe), ['The Quiet Harbor']);
    });

    test('at most the limit', () async {
      await save(harbor, hour);
      await save(ember, hour);
      await save(elsewhere, hour);
      expect(await progress.continueWatching(limit: 2).first, hasLength(2));
    });
  });
}
