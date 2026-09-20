// `isNull` and `isNotNull` exist in both drift and matcher; the matcher's
// are the ones these tests mean.
import 'package:drift/drift.dart' hide isNotNull, isNull;
import 'package:flutter_test/flutter_test.dart';
import 'package:iptv_player/data/db/app_database.dart';
import 'package:iptv_player/data/db/catalogue_tables.dart';
import 'package:iptv_player/data/db/daos/epg_dao.dart';
import 'package:iptv_player/data/db/epg_tables.dart';
import 'package:iptv_player/data/db/tables.dart';

final _now = DateTime.utc(2026, 9, 20, 18);

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

EpgChannelsStagingCompanion _channel(int run, String xmltvId, {String? name}) =>
    EpgChannelsStagingCompanion.insert(
      importRun: run,
      xmltvId: xmltvId,
      displayName: Value(name ?? 'Guide $xmltvId'),
    );

EpgProgramsStagingCompanion _programme(
  int run,
  String xmltvId, {
  required DateTime start,
  Duration length = const Duration(hours: 1),
  String title = 'Programme',
  String? description,
}) => EpgProgramsStagingCompanion.insert(
  importRun: run,
  epgChannelId: xmltvId,
  startUtc: start.millisecondsSinceEpoch,
  endUtc: start.add(length).millisecondsSinceEpoch,
  title: title,
  description: Value(description),
);

/// FTS5's own check that an external-content index matches its table.
Future<void> _checkFts(AppDatabase db) => db.customStatement(
  "INSERT INTO programs_fts(programs_fts, rank) VALUES ('integrity-check', 1)",
);

Future<List<int>> _search(AppDatabase db, String query) async {
  final rows = await db
      .customSelect(
        'SELECT rowid FROM programs_fts WHERE programs_fts MATCH ? '
        'ORDER BY rowid',
        variables: [Variable.withString(query)],
      )
      .get();
  return [for (final row in rows) row.read<int>('rowid')];
}

String _counts(EpgTotals totals) =>
    '{"channels":${totals.channels},"programmes":${totals.programs},'
    '"first":${totals.firstStartMs},"last":${totals.lastEndMs}}';

void main() {
  late AppDatabase db;
  late EpgDao dao;

  setUp(() async {
    db = AppDatabase.memory();
    dao = db.epgDao;
    await _addSource(db, 's1');
    await _addSource(db, 's2');
  });
  tearDown(() => db.close());

  Future<int> import(
    String source, {
    int channels = 2,
    int programmes = 3,
  }) async {
    final run = await dao.startImport(source, _now);
    await dao.stageChannels([
      for (var i = 0; i < channels; i++) _channel(run, '$source.chan$i'),
    ]);
    await dao.stagePrograms([
      for (var i = 0; i < channels; i++)
        for (var j = 0; j < programmes; j++)
          _programme(
            run,
            '$source.chan$i',
            start: _now.add(Duration(hours: j)),
            title: 'Programme $i-$j',
          ),
    ]);
    return run;
  }

  group('the swap', () {
    test('puts the staged rows in place and empties staging', () async {
      final run = await import('s1');

      final totals = await dao.swapIn(
        sourceId: 's1',
        importRun: run,
        at: _now,
        countsJson: _counts,
      );

      expect(totals.channels, 2);
      expect(totals.programs, 6);
      expect(totals.firstStartMs, _now.millisecondsSinceEpoch);
      expect(
        totals.lastEndMs,
        _now.add(const Duration(hours: 3)).millisecondsSinceEpoch,
      );
      expect(await db.select(db.epgChannels).get(), hasLength(2));
      expect(await db.select(db.epgPrograms).get(), hasLength(6));
      expect(await db.select(db.epgChannelsStaging).get(), isEmpty);
      expect(await db.select(db.epgProgramsStaging).get(), isEmpty);

      final row = (await dao.latestImport('s1'))!;
      expect(row.outcome, SyncOutcome.succeeded);
      expect(row.isLive, isTrue);
      expect(row.finishedAt, _now);
      expect(row.countsJson, contains('"programmes":6'));
    });

    test('replaces the last guide, and only for its own source', () async {
      final first = await import('s1');
      await dao.swapIn(
        sourceId: 's1',
        importRun: first,
        at: _now,
        countsJson: _counts,
      );
      final other = await import('s2');
      await dao.swapIn(
        sourceId: 's2',
        importRun: other,
        at: _now,
        countsJson: _counts,
      );

      final second = await import('s1', channels: 1, programmes: 1);
      await dao.swapIn(
        sourceId: 's1',
        importRun: second,
        at: _now,
        countsJson: _counts,
      );

      final programmes = await db.select(db.epgPrograms).get();
      expect(programmes.where((p) => p.sourceId == 's1'), hasLength(1));
      expect(programmes.where((p) => p.sourceId == 's2'), hasLength(6));
      expect((await dao.liveImport('s1'))!.id, second);
      final replaced = await (db.select(
        db.epgImports,
      )..where((t) => t.id.equals(first))).getSingle();
      expect(replaced.isLive, isFalse);
    });

    test('a file that declares a channel twice stages it once', () async {
      final run = await dao.startImport('s1', _now);

      await dao.stageChannels([
        _channel(run, 'arena.sports', name: 'Arena Sports 1'),
        _channel(run, 'arena.sports', name: 'Arena Sports One'),
      ]);

      final staged = await db.select(db.epgChannelsStaging).get();
      expect(staged, hasLength(1));
      expect(staged.single.displayName, 'Arena Sports 1');
    });
  });

  group('an import that never finishes', () {
    test('leaves the live guide alone and its rows in staging', () async {
      final first = await import('s1');
      await dao.swapIn(
        sourceId: 's1',
        importRun: first,
        at: _now,
        countsJson: _counts,
      );

      // The isolate is killed here: staged, never swapped.
      final killed = await import('s1', channels: 4, programmes: 4);

      expect(await db.select(db.epgPrograms).get(), hasLength(6));
      expect((await dao.liveImport('s1'))!.id, first);
      expect(await db.select(db.epgProgramsStaging).get(), hasLength(16));
      expect((await dao.latestImport('s1'))!.id, killed);
    });

    test('is recorded and swept on the next launch', () async {
      final first = await import('s1');
      await dao.swapIn(
        sourceId: 's1',
        importRun: first,
        at: _now,
        countsJson: _counts,
      );
      final killed = await import('s1', channels: 4, programmes: 4);
      final later = _now.add(const Duration(minutes: 5));

      expect(await dao.failInterruptedImports(later), 1);
      expect(await dao.sweepStaging(), 16);

      final row = await (db.select(
        db.epgImports,
      )..where((t) => t.id.equals(killed))).getSingle();
      expect(row.outcome, SyncOutcome.failed);
      expect(row.failure, epgInterruptedFailure);
      expect(row.finishedAt, later);
      expect(await db.select(db.epgProgramsStaging).get(), isEmpty);
      expect(await db.select(db.epgChannelsStaging).get(), isEmpty);
      // The guide the user can see never moved.
      expect(await db.select(db.epgPrograms).get(), hasLength(6));
      expect((await dao.liveImport('s1'))!.id, first);
    });

    test('the sweep leaves a running import alone', () async {
      final running = await import('s1');

      expect(await dao.sweepStaging(), 0);
      expect(await db.select(db.epgProgramsStaging).get(), hasLength(6));
      expect((await dao.latestImport('s1'))!.id, running);
    });
  });

  group('the user’s mapping', () {
    test('survives an import that replaces the whole guide', () async {
      await dao.setMapping('s1', '201', 'arena.sports', _now);
      final run = await import('s1');

      await dao.swapIn(
        sourceId: 's1',
        importRun: run,
        at: _now,
        countsJson: _counts,
      );

      final mappings = await dao.mappingsFor('s1');
      expect(mappings.single.channelRemoteKey, '201');
      expect(mappings.single.xmltvId, 'arena.sports');
    });

    test('a second mapping for the same channel replaces it', () async {
      await dao.setMapping('s1', '201', 'arena.sports', _now);
      await dao.setMapping('s1', '201', 'arena.one', _now);

      expect((await dao.mappingsFor('s1')).single.xmltvId, 'arena.one');
      expect(await dao.removeMapping('s1', '201'), 1);
      expect(await dao.mappingsFor('s1'), isEmpty);
    });
  });

  group('what the matcher resolved', () {
    Future<int> addChannel(String remoteKey) async {
      await db.channelsDao.upsertAll([
        ChannelsCompanion.insert(
          sourceId: 's1',
          remoteKey: remoteKey,
          name: 'Channel $remoteKey',
        ),
      ]);
      return (await db.channelsDao.byRemoteKey('s1', remoteKey))!.id;
    }

    test('is replaced whole, and goes with its channel', () async {
      final first = await addChannel('201');
      final second = await addChannel('214');
      await dao.replaceMatches('s1', [
        EpgMatchesCompanion.insert(
          channelId: Value(first),
          sourceId: 's1',
          xmltvId: 'arena.sports',
          rule: EpgMatchRule.exactId,
        ),
        EpgMatchesCompanion.insert(
          channelId: Value(second),
          sourceId: 's1',
          xmltvId: 'velocity',
          rule: EpgMatchRule.normalizedName,
        ),
      ]);

      await dao.replaceMatches('s1', [
        EpgMatchesCompanion.insert(
          channelId: Value(first),
          sourceId: 's1',
          xmltvId: 'arena.one',
          rule: EpgMatchRule.manual,
        ),
      ]);

      final matches = await db.select(db.epgMatches).get();
      expect(matches, hasLength(1));
      expect(matches.single.xmltvId, 'arena.one');
      expect(matches.single.rule, EpgMatchRule.manual);

      await (db.delete(db.channels)..where((t) => t.id.equals(first))).go();
      expect(await db.select(db.epgMatches).get(), isEmpty);
    });
  });

  test('removing a source takes its guide with it', () async {
    final run = await import('s1');
    await dao.swapIn(
      sourceId: 's1',
      importRun: run,
      at: _now,
      countsJson: _counts,
    );
    await dao.setMapping('s1', '201', 's1.chan0', _now);
    await import('s2');

    await (db.delete(db.sources)..where((t) => t.id.equals('s1'))).go();

    expect(await db.select(db.epgChannels).get(), isEmpty);
    expect(await db.select(db.epgPrograms).get(), isEmpty);
    expect(await db.select(db.epgMappings).get(), isEmpty);
    // The other source's import, and the rows it staged, are untouched.
    expect(await db.select(db.epgImports).get(), hasLength(1));
    expect(await db.select(db.epgProgramsStaging).get(), hasLength(6));
  });

  test('clearing a source’s guide leaves its imports on record', () async {
    final run = await import('s1');
    await dao.swapIn(
      sourceId: 's1',
      importRun: run,
      at: _now,
      countsJson: _counts,
    );

    await dao.clearLiveGuide('s1');

    expect(await db.select(db.epgPrograms).get(), isEmpty);
    expect(await db.select(db.epgChannels).get(), isEmpty);
    expect(await dao.liveImport('s1'), isNull);
    expect((await dao.latestImport('s1'))!.outcome, SyncOutcome.succeeded);
  });

  group('the programmes index', () {
    test('follows every insert, update and delete', () async {
      final run = await dao.startImport('s1', _now);
      await dao.stagePrograms([
        _programme(
          run,
          's1.chan0',
          start: _now,
          title: 'Continental Cup',
          description: 'A place in the final',
        ),
        _programme(
          run,
          's1.chan0',
          start: _now.add(const Duration(hours: 1)),
          title: 'Late Kickoff',
        ),
      ]);
      await dao.swapIn(
        sourceId: 's1',
        importRun: run,
        at: _now,
        countsJson: _counts,
      );

      final cup = (await (db.select(
        db.epgPrograms,
      )..where((t) => t.title.equals('Continental Cup'))).getSingle()).id;
      expect(await _search(db, 'cup'), [cup]);
      expect(await _search(db, 'final'), [cup]);

      await (db.update(db.epgPrograms)..where((t) => t.id.equals(cup))).write(
        const EpgProgramsCompanion(title: Value('Continental Final')),
      );
      expect(await _search(db, 'cup'), isEmpty);
      expect(await _search(db, 'continental'), [cup]);
      await _checkFts(db);

      await (db.delete(db.epgPrograms)..where((t) => t.id.equals(cup))).go();
      expect(await _search(db, 'continental'), isEmpty);
      expect(await _search(db, 'kickoff'), hasLength(1));
      await _checkFts(db);
    });

    test('a swap that replaces a guide leaves it consistent', () async {
      final first = await import('s1');
      await dao.swapIn(
        sourceId: 's1',
        importRun: first,
        at: _now,
        countsJson: _counts,
      );
      final second = await import('s1', channels: 1, programmes: 2);

      await dao.swapIn(
        sourceId: 's1',
        importRun: second,
        at: _now,
        countsJson: _counts,
      );

      await _checkFts(db);
      expect(await _search(db, 'programme'), hasLength(2));
    });
  });
}
