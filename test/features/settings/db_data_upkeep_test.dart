import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:iptv_player/data/db/app_database.dart';
import 'package:iptv_player/data/db/user_tables.dart';
import 'package:iptv_player/features/settings/data/db_data_upkeep.dart';
import 'package:iptv_player/features/settings/domain/data_upkeep.dart';
import 'package:iptv_player/features/vod/data/db_watch_progress.dart';
import 'package:iptv_player/features/vod/domain/next_up.dart';
import 'package:iptv_player/features/vod/domain/watch_progress.dart';

import '../vod/vod_test_support.dart';

const int _mb = 1024 * 1024;

void main() {
  group('on a database in memory', () {
    late AppDatabase db;
    late DbDataUpkeep upkeep;
    late DbWatchProgress progress;
    late DateTime clock;

    const harbor = MovieRef('src', 'm1');
    EpisodeRef episode(int season, int number) =>
        EpisodeRef('src', 'e$season-$number', seriesKey: '77');
    const length = Duration(minutes: 50);
    const episodes = ['e1-1', 'e1-2', 'e2-1', 'e2-2'];

    setUp(() async {
      db = AppDatabase.memory();
      addTearDown(db.close);
      upkeep = DbDataUpkeep(db);
      clock = t0;
      progress = DbWatchProgress(db, clock: () => clock);
      await addSource(db, 'src');
      await addMovie(db, 'm1', 'The Quiet Harbor');
      final series = await addSeries(db, '77', 'Glass Tide');
      await addEpisodes(db, series, [(1, 1), (1, 2), (2, 1), (2, 2)]);
    });

    Future<void> watched(VodRef ref, Duration position, {DateTime? at}) {
      clock = at ?? clock.add(const Duration(minutes: 1));
      return progress.save(ref, position: position, duration: length);
    }

    String describe(ContinueItem item) => switch (item) {
      ContinueMovie(:final movie) => movie.name,
      ContinueEpisode(:final episode, :final upNext) =>
        '${episode.remoteKey}${upNext ? ' next' : ''}',
      ContinueLibraryFile(:final item) => 'file ${item.title}',
    };

    Future<List<String>> cards() async =>
        (await progress.continueWatching().first).map(describe).toList();

    Future<String?> seriesNextUp() async {
      final marks = await progress.watchSeries('src', '77').first;
      return nextUpAmong(episodes, (key) => marks[key])?.episode;
    }

    test('a tidy-up months later leaves Continue watching and the '
        "series' next episode as they were, and forgets the rest", () async {
      // Season 1 and the first of season 2 finished half a year ago, and
      // a film left half way then.
      await watched(episode(1, 1), length, at: t0);
      await watched(episode(1, 2), length);
      await watched(episode(2, 1), length);
      await watched(harbor, const Duration(minutes: 25));
      expect(await cards(), ['The Quiet Harbor', 'e2-2 next']);
      expect(await seriesNextUp(), 'e2-2');

      final pruned = await upkeep.prune(t0.add(const Duration(days: 180)));

      expect(pruned.valueOrNull?.titles, 2, reason: 'e1-1 and e1-2');
      expect(await cards(), ['The Quiet Harbor', 'e2-2 next']);
      expect(await seriesNextUp(), 'e2-2');
      expect((await progress.watchSeries('src', '77').first).keys, ['e2-1']);
    });

    test('Clear: each choice forgets its own kind, and Continue watching '
        'follows at once', () async {
      await watched(harbor, const Duration(minutes: 25));
      await db.watchHistoryDao.touch(UserItemType.live, 'src', '101', clock);
      final shown = <List<ContinueItem>>[];
      final watching = progress.continueWatching().listen(shown.add);
      addTearDown(watching.cancel);
      await pumpEventQueue();
      expect(shown.last, hasLength(1));

      expect(
        (await upkeep.clearHistory(HistoryChoice.channels)).valueOrNull,
        1,
      );
      expect(
        await db.watchHistoryDao.find(UserItemType.movie, 'src', 'm1'),
        isNotNull,
      );

      expect((await upkeep.clearHistory(HistoryChoice.titles)).valueOrNull, 1);
      await pumpEventQueue();
      expect(shown.last, isEmpty);

      await watched(harbor, const Duration(minutes: 25));
      await db.watchHistoryDao.touch(UserItemType.live, 'src', '101', clock);
      expect(
        (await upkeep.clearHistory(HistoryChoice.everything)).valueOrNull,
        2,
      );
      expect(await upkeep.watchHistoryCounts().first, (channels: 0, titles: 0));
    });

    test('measured, it says whether a guide is in place', () async {
      expect((await upkeep.measure()).valueOrNull?.hasGuide, isFalse);

      await db
          .into(db.epgPrograms)
          .insert(
            EpgProgramsCompanion.insert(
              sourceId: 'src',
              epgChannelId: 'bbc1.uk',
              startUtc: 0,
              endUtc: 1,
              title: 'News',
            ),
          );

      expect((await upkeep.measure()).valueOrNull?.hasGuide, isTrue);
    });
  });

  test(
    'a file database: measured with its log, compacted to its live '
    'pages, the log emptied; on its own isolate, as the app opens it',
    () async {
      final directory = await Directory.systemTemp.createTemp('upkeep');
      addTearDown(() => directory.delete(recursive: true));
      final db = AppDatabase(await openAppDatabase(directory));
      addTearDown(db.close);
      final upkeep = DbDataUpkeep(db);
      await db.customStatement('CREATE TABLE filler (blob BLOB)');
      for (var i = 0; i < 24; i++) {
        await db.customStatement('INSERT INTO filler VALUES (zeroblob(?))', [
          _mb,
        ]);
      }
      await db.customStatement('DELETE FROM filler');

      final room = (await upkeep.measure()).valueOrNull!;
      expect(room.freeBytes, greaterThan(20 * _mb));
      expect(room.worthCompacting, isTrue);
      final file = File('${directory.path}/$appDatabaseFileName');
      expect(
        room.bytes,
        file.lengthSync() + File('${file.path}-wal').lengthSync(),
      );

      final compacted = (await upkeep.compact()).valueOrNull!;

      expect(compacted.before, room.bytes);
      expect(compacted.after, lessThan(_mb));
      expect(File('${file.path}-wal').lengthSync(), 0);
      final after = (await upkeep.measure()).valueOrNull!;
      expect(after.freeBytes, 0);
      expect(after.bytes, compacted.after);
      expect(after.worthCompacting, isFalse);
    },
  );

  group('worth compacting', () {
    DatabaseRoom room(int pagesMb, int freeMb, {bool guide = false}) =>
        DatabaseRoom(
          bytes: pagesMb * _mb,
          pagesBytes: pagesMb * _mb,
          freeBytes: freeMb * _mb,
          hasGuide: guide,
        );

    test('a quarter of the file and 8 MB free, both', () {
      expect(room(40, 10).worthCompacting, isTrue);
      expect(room(40, 9).worthCompacting, isFalse, reason: 'under a quarter');
      expect(room(20, 7).worthCompacting, isFalse, reason: 'under 8 MB');
      expect(room(77, 52).worthCompacting, isTrue, reason: 'a guide gone');
    });

    test('with a guide in place, half the file: the room a daily import '
        'leaves is taken again by the next one, never worth a rewrite', () {
      // A 30 MB guide, staged beside the old one and swapped in: 30 MB
      // free of 77.
      expect(room(77, 30, guide: true).worthCompacting, isFalse);
      expect(room(77, 30).worthCompacting, isTrue, reason: 'no guide');
      expect(room(80, 40, guide: true).worthCompacting, isTrue);
      expect(room(12, 7, guide: true).worthCompacting, isFalse);
    });

    test('a long log is worth emptying alone', () {
      expect(
        const DatabaseRoom(
          bytes: 100 * _mb,
          pagesBytes: 36 * _mb,
          freeBytes: 0,
          logBytes: 64 * _mb,
        ).worthTrimmingLog,
        isTrue,
      );
      expect(room(40, 0).worthTrimmingLog, isFalse);
    });
  });
}
