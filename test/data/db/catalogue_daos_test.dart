// `isNull` and `isNotNull` exist in both drift and matcher; the matcher's
// are the ones these tests mean.
import 'package:drift/drift.dart' hide isNotNull, isNull;
import 'package:flutter_test/flutter_test.dart';
import 'package:iptv_player/data/db/app_database.dart';
import 'package:iptv_player/data/db/catalogue_tables.dart';
import 'package:iptv_player/data/db/daos/sync_runs_dao.dart';
import 'package:iptv_player/data/db/tables.dart';

final _now = DateTime.utc(2026, 9, 18, 9);

Future<void> _addSource(AppDatabase db, String id) => db.sourcesDao.upsert(
  SourcesCompanion.insert(
    id: id,
    type: SourceType.xtream,
    name: 'Provider $id',
    url: 'http://$id.test:8080',
    createdAt: _now,
    updatedAt: _now,
  ),
);

CategoriesCompanion _category(
  String remoteKey, {
  String source = 's1',
  CatalogueKind kind = CatalogueKind.live,
  String? name,
  int position = 0,
  int? run,
}) => CategoriesCompanion.insert(
  sourceId: source,
  kind: kind,
  remoteKey: remoteKey,
  name: name ?? 'Category $remoteKey',
  position: Value(position),
  seenRun: Value(run),
);

ChannelsCompanion _channel(
  String remoteKey, {
  String source = 's1',
  String? name,
  int? categoryId,
  int? run,
}) => ChannelsCompanion.insert(
  sourceId: source,
  remoteKey: remoteKey,
  name: name ?? 'Channel $remoteKey',
  categoryId: Value(categoryId),
  seenRun: Value(run),
);

/// FTS5's own check that an external-content index matches its table.
/// Throws `SqliteException` (SQLITE_CORRUPT_VTAB) when it does not.
Future<void> _checkFts(AppDatabase db, String table) => db.customStatement(
  "INSERT INTO $table($table, rank) VALUES ('integrity-check', 1)",
);

Future<List<int>> _search(AppDatabase db, String table, String query) async {
  final rows = await db
      .customSelect(
        'SELECT rowid FROM $table WHERE $table MATCH ? ORDER BY rowid',
        variables: [Variable.withString(query)],
      )
      .get();
  return [for (final row in rows) row.read<int>('rowid')];
}

void main() {
  late AppDatabase db;

  setUp(() async {
    db = AppDatabase.memory();
    await _addSource(db, 's1');
    await _addSource(db, 's2');
  });
  tearDown(() => db.close());

  group('categories', () {
    test('a re-sync refreshes the provider columns and keeps the '
        "user's", () async {
      await db.categoriesDao.upsertAll([_category('7', name: 'Sports')]);
      final id = (await db.categoriesDao.idsByRemoteKey(
        's1',
        CatalogueKind.live,
      ))['7']!;
      await db.categoriesDao.rename(id, 'My sport');
      await db.categoriesDao.setHidden(id, hidden: true);
      await db.categoriesDao.reorder([id]);

      await db.categoriesDao.upsertAll([
        _category('7', name: 'UK | Sports', position: 4, run: 2),
      ]);

      final row = await (db.select(
        db.categories,
      )..where((t) => t.id.equals(id))).getSingle();
      expect(row.name, 'UK | Sports');
      expect(row.position, 4);
      expect(row.seenRun, 2);
      expect(row.displayName, 'My sport');
      expect(row.isHidden, isTrue);
      expect(row.sortOrder, 0);
    });

    test('the same remote key is a different category per kind', () async {
      await db.categoriesDao.upsertAll([
        _category('1'),
        _category('1', kind: CatalogueKind.movie),
        _category('1', kind: CatalogueKind.series),
      ]);

      expect(await db.select(db.categories).get(), hasLength(3));
    });

    test('sweep deletes only what the run did not see, in that source '
        'only', () async {
      await db.categoriesDao.upsertAll([
        _category('old', run: 1),
        _category('kept', run: 2),
        _category('never-marked'),
        _category('other', source: 's2', run: 1),
      ]);

      final swept = await db.categoriesDao.sweep('s1', 2);

      expect(swept, 2);
      final left = await db.select(db.categories).get();
      expect(left.map((c) => c.remoteKey), unorderedEquals(['kept', 'other']));
    });

    test("display order is the user's order, then the provider's", () async {
      await db.categoriesDao.upsertAll([
        _category('a'),
        _category('b', position: 1),
        _category('c', position: 2),
        _category('d', position: 3),
      ]);
      final ids = await db.categoriesDao.idsByRemoteKey(
        's1',
        CatalogueKind.live,
      );
      await db.categoriesDao.reorder([ids['c']!, ids['a']!]);

      final rows = await db.categoriesDao
          .watchForSource('s1', CatalogueKind.live)
          .first;

      expect(rows.map((c) => c.remoteKey), ['c', 'a', 'b', 'd']);
    });

    test('hidden categories can be left out', () async {
      await db.categoriesDao.upsertAll([_category('a'), _category('b')]);
      final ids = await db.categoriesDao.idsByRemoteKey(
        's1',
        CatalogueKind.live,
      );
      await db.categoriesDao.setHidden(ids['a']!, hidden: true);

      final visible = await db.categoriesDao
          .watchForSource('s1', CatalogueKind.live, includeHidden: false)
          .first;

      expect(visible.map((c) => c.remoteKey), ['b']);
    });

    test('select all and none apply to one source and kind', () async {
      await db.categoriesDao.upsertAll([
        _category('a'),
        _category('b'),
        _category('m', kind: CatalogueKind.movie),
        _category('x', source: 's2'),
      ]);

      await db.categoriesDao.setAllHidden(
        's1',
        CatalogueKind.live,
        hidden: true,
      );

      final hidden = await (db.select(
        db.categories,
      )..where((t) => t.isHidden)).get();
      expect(hidden.map((c) => c.remoteKey), unorderedEquals(['a', 'b']));
    });

    test('a blank rename restores the provider name', () async {
      await db.categoriesDao.upsertAll([_category('a')]);
      final id = (await db.categoriesDao.idsByRemoteKey(
        's1',
        CatalogueKind.live,
      ))['a']!;

      await db.categoriesDao.rename(id, '  Mine  ');
      var row = await (db.select(
        db.categories,
      )..where((t) => t.id.equals(id))).getSingle();
      expect(row.displayName, 'Mine');

      await db.categoriesDao.rename(id, '   ');
      row = await (db.select(
        db.categories,
      )..where((t) => t.id.equals(id))).getSingle();
      expect(row.displayName, isNull);
    });

    test('a sweep limited to some kinds leaves the others', () async {
      await db.categoriesDao.upsertAll([
        _category('1', run: 1),
        _category('1', kind: CatalogueKind.movie, run: 1),
        _category('1', kind: CatalogueKind.series, run: 1),
      ]);

      final removed = await db.categoriesDao.sweep(
        's1',
        2,
        kinds: {CatalogueKind.live, CatalogueKind.series},
      );

      expect(removed, 2);
      final left = await db.select(db.categories).get();
      expect(left.map((c) => c.kind), [CatalogueKind.movie]);
    });

    test('item counts per category, uncategorized under null', () async {
      await db.categoriesDao.upsertAll([_category('a'), _category('b')]);
      final ids = await db.categoriesDao.idsByRemoteKey(
        's1',
        CatalogueKind.live,
      );
      await db.channelsDao.upsertAll([
        _channel('1', categoryId: ids['a']),
        _channel('2', categoryId: ids['a']),
        _channel('3', categoryId: ids['b']),
        _channel('4'),
        _channel('5', source: 's2'),
      ]);

      final counts = await db.categoriesDao.itemCounts(
        's1',
        CatalogueKind.live,
      );

      expect(counts, {ids['a']: 2, ids['b']: 1, null: 1});
    });
  });

  group('channels', () {
    test('a re-sync keeps the row id, the rename and the hidden '
        'flag', () async {
      await db.channelsDao.upsertAll([_channel('101', name: 'BBC One')]);
      final before = await db.channelsDao.byRemoteKey('s1', '101');
      await db.channelsDao.rename(before!.id, 'BBC 1');
      await db.channelsDao.setHidden(before.id, hidden: true);

      await db.channelsDao.upsertAll([
        _channel('101', name: 'BBC One HD', run: 3),
      ]);

      final after = await db.channelsDao.byRemoteKey('s1', '101');
      expect(after!.id, before.id);
      expect(after.name, 'BBC One HD');
      expect(after.seenRun, 3);
      expect(after.displayName, 'BBC 1');
      expect(after.isHidden, isTrue);
    });

    test('the same remote key in two sources is two channels', () async {
      await db.channelsDao.upsertAll([
        _channel('1'),
        _channel('1', source: 's2'),
      ]);

      expect(await db.channelsDao.countFor('s1'), 1);
      expect(await db.channelsDao.countFor('s2'), 1);
    });

    test('a swept category leaves its channels uncategorized, not '
        'deleted', () async {
      await db.categoriesDao.upsertAll([_category('a', run: 1)]);
      final id = (await db.categoriesDao.idsByRemoteKey(
        's1',
        CatalogueKind.live,
      ))['a']!;
      await db.channelsDao.upsertAll([_channel('1', categoryId: id, run: 2)]);

      await db.categoriesDao.sweep('s1', 2);

      final row = await db.channelsDao.byRemoteKey('s1', '1');
      expect(row, isNotNull);
      expect(row!.categoryId, isNull);
    });

    test('sweep deletes what the run did not see', () async {
      await db.channelsDao.upsertAll([
        _channel('gone', run: 1),
        _channel('here', run: 2),
      ]);

      expect(await db.channelsDao.sweep('s1', 2), 1);
      expect(await db.channelsDao.byRemoteKey('s1', 'gone'), isNull);
      expect(await db.channelsDao.byRemoteKey('s1', 'here'), isNotNull);
    });
  });

  group('search index', () {
    test('follows inserts, renames, re-syncs and deletes', () async {
      await db.channelsDao.upsertAll([
        _channel('1', name: 'Sky Sports Main Event'),
        _channel('2', name: 'BBC One'),
      ]);
      final sky = (await db.channelsDao.byRemoteKey('s1', '1'))!.id;
      final bbc = (await db.channelsDao.byRemoteKey('s1', '2'))!.id;
      expect(await _search(db, 'channels_fts', 'spo*'), [sky]);

      // A user rename is searchable, and so is the provider's name.
      await db.channelsDao.rename(bbc, 'Beeb');
      expect(await _search(db, 'channels_fts', 'beeb'), [bbc]);
      expect(await _search(db, 'channels_fts', 'bbc'), [bbc]);

      // A re-sync that renames the channel replaces the old words.
      await db.channelsDao.upsertAll([_channel('1', name: 'Sky Cinema')]);
      expect(await _search(db, 'channels_fts', 'spo*'), isEmpty);
      expect(await _search(db, 'channels_fts', 'cinema'), [sky]);

      // Case and accents fold.
      await db.channelsDao.upsertAll([_channel('3', name: 'CANAL+ Série')]);
      final canal = (await db.channelsDao.byRemoteKey('s1', '3'))!.id;
      expect(await _search(db, 'channels_fts', 'serie'), [canal]);

      await db.channelsDao.sweep('s1', 99);
      expect(await _search(db, 'channels_fts', 'cinema'), isEmpty);

      await _checkFts(db, 'channels_fts');
    });

    test('movies and series are indexed too, and stay consistent', () async {
      await db.moviesDao.upsertAll([
        MoviesCompanion.insert(sourceId: 's1', remoteKey: '1', name: 'Heat'),
      ]);
      await db.seriesDao.upsertAll([
        SeriesCompanion.insert(sourceId: 's1', remoteKey: '1', name: 'Dark'),
      ]);
      await db.moviesDao.upsertAll([
        MoviesCompanion.insert(
          sourceId: 's1',
          remoteKey: '1',
          name: 'Heat (1995)',
        ),
      ]);

      expect(await _search(db, 'movies_fts', 'heat'), hasLength(1));
      expect(await _search(db, 'series_fts', 'dark'), hasLength(1));

      await db.moviesDao.sweep('s1', 99);
      await db.seriesDao.sweep('s1', 99);

      expect(await _search(db, 'movies_fts', 'heat'), isEmpty);
      expect(await _search(db, 'series_fts', 'dark'), isEmpty);
      await _checkFts(db, 'movies_fts');
      await _checkFts(db, 'series_fts');
    });
  });

  group('movies', () {
    test('details survive a re-sync and go with the movie', () async {
      await db.moviesDao.upsertAll([
        MoviesCompanion.insert(sourceId: 's1', remoteKey: '9', name: 'Heat'),
      ]);
      final id = (await db.moviesDao.byRemoteKey('s1', '9'))!.id;
      await db.moviesDao.saveDetails(
        MovieDetailsCompanion.insert(
          movieId: Value(id),
          plot: const Value('A crew of thieves.'),
          fetchedAt: _now,
        ),
      );

      await db.moviesDao.upsertAll([
        MoviesCompanion.insert(
          sourceId: 's1',
          remoteKey: '9',
          name: 'Heat',
          rating: const Value(8.3),
          seenRun: const Value(2),
        ),
      ]);
      expect((await db.moviesDao.detailsFor(id))?.plot, 'A crew of thieves.');
      expect((await db.moviesDao.byRemoteKey('s1', '9'))?.rating, 8.3);

      await db.moviesDao.sweep('s1', 3);
      expect(await db.moviesDao.detailsFor(id), isNull);
    });
  });

  group('series', () {
    SeriesCompanion show({int? run}) => SeriesCompanion.insert(
      sourceId: 's1',
      remoteKey: '5',
      name: 'Dark',
      seenRun: Value(run),
    );

    EpisodesCompanion episode(int seriesId, int season, int number) =>
        EpisodesCompanion.insert(
          seriesId: seriesId,
          remoteKey: 'e$season-$number',
          season: season,
          episode: number,
          title: 'Episode $number',
        );

    test('episodes are replaced as a set, in season order', () async {
      await db.seriesDao.upsertAll([show()]);
      final id = (await db.seriesDao.byRemoteKey('s1', '5'))!.id;

      await db.seriesDao.replaceEpisodes(id, [
        episode(id, 1, 1),
        episode(id, 1, 2),
      ], fetchedAt: _now);
      await db.seriesDao.replaceEpisodes(id, [
        episode(id, 2, 1),
        episode(id, 1, 2),
        episode(id, 1, 1),
      ], fetchedAt: _now.add(const Duration(days: 1)));

      final episodes = await db.seriesDao.episodesOf(id);
      expect(episodes.map((e) => e.remoteKey), ['e1-1', 'e1-2', 'e2-1']);
    });

    test('a re-sync keeps the episodes and when they were fetched', () async {
      await db.seriesDao.upsertAll([show()]);
      final id = (await db.seriesDao.byRemoteKey('s1', '5'))!.id;
      await db.seriesDao.replaceEpisodes(id, [
        episode(id, 1, 1),
      ], fetchedAt: _now);

      await db.seriesDao.upsertAll([show(run: 2)]);

      final row = await db.seriesDao.byRemoteKey('s1', '5');
      expect(row!.id, id);
      expect(row.episodesFetchedAt, _now);
      expect(await db.seriesDao.episodesOf(id), hasLength(1));
    });

    test('ids by remote key: only those asked for, in this source', () async {
      await db.seriesDao.upsertAll([
        show(),
        SeriesCompanion.insert(sourceId: 's1', remoteKey: '6', name: 'Lost'),
        SeriesCompanion.insert(sourceId: 's2', remoteKey: '5', name: 'Dark'),
      ]);

      final ids = await db.seriesDao.idsByRemoteKey('s1', ['5', '7']);

      expect(ids.keys, ['5']);
      expect(ids['5'], (await db.seriesDao.byRemoteKey('s1', '5'))!.id);
    });

    test('M3U episodes: upserted in place, then swept by run', () async {
      await db.seriesDao.upsertAll([show(run: 1)]);
      await db.seriesDao.upsertAll([
        SeriesCompanion.insert(sourceId: 's2', remoteKey: '5', name: 'Dark'),
      ]);
      final id = (await db.seriesDao.byRemoteKey('s1', '5'))!.id;
      final other = (await db.seriesDao.byRemoteKey('s2', '5'))!.id;
      EpisodesCompanion seen(int series, String key, int run, String title) =>
          EpisodesCompanion.insert(
            seriesId: series,
            remoteKey: key,
            season: 1,
            episode: 1,
            title: title,
            seenRun: Value(run),
          );
      await db.seriesDao.upsertEpisodes([
        seen(id, 'a', 1, 'A'),
        seen(id, 'b', 1, 'B'),
        seen(other, 'a', 1, 'Other source'),
      ]);
      final before = (await db.seriesDao.episodesOf(id)).first.id;

      await db.seriesDao.upsertEpisodes([seen(id, 'a', 2, 'A renamed')]);
      final removed = await db.seriesDao.sweepEpisodes('s1', 2);

      expect(removed, 1);
      final episodes = await db.seriesDao.episodesOf(id);
      expect(episodes.map((e) => (e.id, e.title)), [(before, 'A renamed')]);
      expect(await db.seriesDao.episodesOf(other), hasLength(1));
      expect(await db.seriesDao.episodeCountFor('s1'), 1);
    });

    test('a swept series takes its episodes with it', () async {
      await db.seriesDao.upsertAll([show(run: 1)]);
      final id = (await db.seriesDao.byRemoteKey('s1', '5'))!.id;
      await db.seriesDao.replaceEpisodes(id, [
        episode(id, 1, 1),
      ], fetchedAt: _now);

      await db.seriesDao.sweep('s1', 2);

      expect(await db.select(db.episodes).get(), isEmpty);
    });
  });

  group('sync runs', () {
    test('each run gets a new, increasing id', () async {
      final first = await db.syncRunsDao.start('s1', _now);
      final second = await db.syncRunsDao.start('s1', _now);

      expect(second, greaterThan(first));
    });

    test('finish records the outcome; latest is the newest run', () async {
      final first = await db.syncRunsDao.start('s1', _now);
      await db.syncRunsDao.finish(
        first,
        outcome: SyncOutcome.succeeded,
        at: _now,
        countsJson: '{"live":3}',
      );
      final second = await db.syncRunsDao.start('s1', _now);
      await db.syncRunsDao.finish(
        second,
        outcome: SyncOutcome.failed,
        at: _now,
        failure: 'timeout',
      );

      final latest = await db.syncRunsDao.latest('s1');
      expect(latest!.id, second);
      expect(latest.outcome, SyncOutcome.failed);
      expect(latest.failure, 'timeout');
      expect(await db.syncRunsDao.latest('s2'), isNull);
    });

    test('runs left running by a dead process are failed on '
        'launch', () async {
      final orphan = await db.syncRunsDao.start('s1', _now);
      final done = await db.syncRunsDao.start('s2', _now);
      await db.syncRunsDao.finish(
        done,
        outcome: SyncOutcome.succeeded,
        at: _now,
      );

      expect(await db.syncRunsDao.failInterrupted(_now), 1);

      final row = await db.syncRunsDao.latest('s1');
      expect(row!.id, orphan);
      expect(row.outcome, SyncOutcome.failed);
      expect(row.failure, syncInterruptedFailure);
      expect(
        (await db.syncRunsDao.latest('s2'))!.outcome,
        SyncOutcome.succeeded,
      );
    });
  });

  test('removing a source removes its whole catalogue and nothing '
      'else', () async {
    for (final source in ['s1', 's2']) {
      await db.syncRunsDao.start(source, _now);
      await db.categoriesDao.upsertAll([_category('a', source: source)]);
      await db.channelsDao.upsertAll([_channel('1', source: source)]);
      await db.moviesDao.upsertAll([
        MoviesCompanion.insert(sourceId: source, remoteKey: '1', name: 'M'),
      ]);
      await db.seriesDao.upsertAll([
        SeriesCompanion.insert(sourceId: source, remoteKey: '1', name: 'S'),
      ]);
    }

    await db.sourcesDao.remove('s1');

    for (final table in <TableInfo<Table, Object?>>[
      db.syncRuns,
      db.categories,
      db.channels,
      db.movies,
      db.series,
    ]) {
      final rows = await db
          .customSelect('SELECT source_id FROM ${table.actualTableName}')
          .get();
      expect(rows.map((r) => r.read<String>('source_id')), [
        's2',
      ], reason: table.actualTableName);
    }
    await _checkFts(db, 'channels_fts');
  });
}
