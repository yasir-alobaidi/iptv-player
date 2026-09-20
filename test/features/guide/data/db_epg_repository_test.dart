// `isNull` exists in both drift and matcher; the matcher's is the one
// these tests mean.
import 'package:drift/drift.dart' hide isNull;
import 'package:flutter_test/flutter_test.dart';
import 'package:iptv_player/core/result.dart';
import 'package:iptv_player/data/db/app_database.dart';
import 'package:iptv_player/data/db/epg_tables.dart';
import 'package:iptv_player/data/db/tables.dart';
import 'package:iptv_player/features/guide/data/db_epg_repository.dart';
import 'package:iptv_player/features/guide/domain/epg.dart';

final _now = DateTime.utc(2026, 9, 20, 20);

void main() {
  late AppDatabase db;
  late DbEpgRepository repository;

  Future<void> addSource(String id) => db.sourcesDao.upsert(
    SourcesCompanion.insert(
      id: id,
      type: SourceType.xtream,
      name: 'Provider $id',
      url: 'http://$id.test:8080',
      createdAt: _now,
      updatedAt: _now,
    ),
  );

  Future<int> addChannel(String remoteKey, {String source = 's1'}) async {
    await db.channelsDao.upsertAll([
      ChannelsCompanion.insert(
        sourceId: source,
        remoteKey: remoteKey,
        name: 'Channel $remoteKey',
      ),
    ]);
    return (await db.channelsDao.byRemoteKey(source, remoteKey))!.id;
  }

  Future<void> match(int channelId, String xmltvId, {String source = 's1'}) =>
      db
          .into(db.epgMatches)
          .insertOnConflictUpdate(
            EpgMatchesCompanion.insert(
              channelId: Value(channelId),
              sourceId: source,
              xmltvId: xmltvId,
              rule: EpgMatchRule.exactId,
            ),
          );

  EpgProgramme programme(
    String channelId, {
    required DateTime start,
    Duration length = const Duration(hours: 1),
    String title = 'Programme',
    String? description,
  }) => EpgProgramme(
    id: 0,
    channelId: channelId,
    start: start,
    end: start.add(length),
    title: title,
    description: description,
  );

  setUp(() async {
    db = AppDatabase.memory();
    repository = DbEpgRepository(db, clock: () => _now);
    await addSource('s1');
  });
  tearDown(() => db.close());

  /// Imports [programmes] for [source] the way step 3's isolate will:
  /// start, stage, commit.
  Future<EpgImportCounts> import(
    List<EpgProgramme> programmes, {
    String source = 's1',
    List<GuideChannel>? channels,
    EpgImportCounts counts = const EpgImportCounts(),
  }) async {
    final run = (await repository.startImport(source)).valueOrNull!;
    final ids = {for (final p in programmes) p.channelId};
    await repository.stageChannels(run, [
      ...?channels,
      if (channels == null)
        for (final id in ids)
          GuideChannel(xmltvId: id, displayName: 'Guide $id'),
    ]);
    await repository.stagePrograms(run, programmes);
    final result = await repository.commitImport(
      sourceId: source,
      importRun: run,
      counts: counts,
    );
    return result.valueOrNull!;
  }

  group('now and next', () {
    test('reads them through what the matcher attached', () async {
      final channel = await addChannel('201');
      await match(channel, 'arena.sports');
      await import([
        programme(
          'arena.sports',
          start: _now.subtract(const Duration(minutes: 20)),
          title: 'Continental Cup',
        ),
        programme(
          'arena.sports',
          start: _now.add(const Duration(minutes: 40)),
          title: 'Post Match',
        ),
      ]);

      final found = (await repository.nowNextForChannels([
        channel,
      ], _now)).valueOrNull!;

      expect(found[channel]!.now!.title, 'Continental Cup');
      expect(found[channel]!.now!.channelId, 'arena.sports');
      expect(found[channel]!.next!.title, 'Post Match');
      expect(found[channel]!.now!.progressAt(_now), closeTo(1 / 3, 0.01));
    });

    test('a gap in the guide has a next but no now', () async {
      final channel = await addChannel('201');
      await match(channel, 'arena.sports');
      await import([
        programme(
          'arena.sports',
          start: _now.add(const Duration(hours: 2)),
          title: 'Late Kickoff',
        ),
      ]);

      final found = (await repository.nowNextForChannels([
        channel,
      ], _now)).valueOrNull!;

      expect(found[channel]!.now, isNull);
      expect(found[channel]!.next!.title, 'Late Kickoff');
    });

    test('an unmatched channel is absent, not empty', () async {
      final matched = await addChannel('201');
      final unmatched = await addChannel('214');
      await match(matched, 'arena.sports');
      await import([programme('arena.sports', start: _now)]);

      final found = (await repository.nowNextForChannels([
        matched,
        unmatched,
      ], _now)).valueOrNull!;

      expect(found.keys, [matched]);
    });

    test('a guide that has run out answers nothing', () async {
      final channel = await addChannel('201');
      await match(channel, 'arena.sports');
      await import([
        programme(
          'arena.sports',
          start: _now.subtract(const Duration(days: 3)),
        ),
      ]);

      final found = (await repository.nowNextForChannels([
        channel,
      ], _now)).valueOrNull!;

      expect(found, isEmpty);
    });

    test('no channels is no query', () async {
      expect(
        (await repository.nowNextForChannels([], _now)).valueOrNull,
        <int, EpgNowNext>{},
      );
    });
  });

  group('a window', () {
    test('returns what overlaps it, per channel, in start order', () async {
      final first = await addChannel('201');
      final second = await addChannel('214');
      await match(first, 'arena.sports');
      await match(second, 'velocity');
      await import([
        // Starts before the window and runs into it.
        programme(
          'arena.sports',
          start: _now.subtract(const Duration(minutes: 30)),
          length: const Duration(hours: 2),
          title: 'Long Feature',
        ),
        programme(
          'arena.sports',
          start: _now.add(const Duration(hours: 2)),
          title: 'Inside',
        ),
        // Starts after the window.
        programme(
          'arena.sports',
          start: _now.add(const Duration(hours: 9)),
          title: 'Outside',
        ),
        programme('velocity', start: _now, title: 'Motors'),
      ]);

      final found = (await repository.windowForChannels(
        [first, second],
        _now,
        _now.add(const Duration(hours: 4)),
      )).valueOrNull!;

      expect(found[first]!.map((p) => p.title), ['Long Feature', 'Inside']);
      expect(found[second]!.single.title, 'Motors');
    });
  });

  group('coverage', () {
    test('a source that never imported has no guide', () async {
      final coverage = (await repository.coverage('s1')).valueOrNull!;

      expect(coverage.hasGuide, isFalse);
      expect(coverage.lastImport, isNull);
      expect(coverage.isImporting, isFalse);
      expect(coverage.coversAt(_now), isFalse);
    });

    test('reports what the live import put there, and the matches', () async {
      final channel = await addChannel('201');
      await addChannel('214');
      await match(channel, 'arena.sports');
      await import([
        programme('arena.sports', start: _now),
        programme('arena.sports', start: _now.add(const Duration(hours: 1))),
      ], counts: const EpgImportCounts(skipped: {'bad_date': 4}));

      final coverage = (await repository.coverage('s1')).valueOrNull!;

      expect(coverage.hasGuide, isTrue);
      expect(coverage.guideChannels, 1);
      expect(coverage.programmes, 2);
      expect(coverage.firstStart, _now);
      expect(coverage.lastEnd, _now.add(const Duration(hours: 2)));
      expect(coverage.matchedChannels, 1);
      expect(coverage.totalChannels, 2);
      expect(coverage.unmatchedChannels, 1);
      expect(coverage.coversAt(_now), isTrue);
      expect(coverage.lastImport!.outcome, GuideImportOutcome.succeeded);
      expect(coverage.lastImport!.counts.skipped, {'bad_date': 4});
      expect(coverage.lastImport!.counts.skippedTotal, 4);
      expect(coverage.lastImport!.isLive, isTrue);
    });

    test('a failed refresh reports itself and keeps the old numbers', () async {
      await import([programme('arena.sports', start: _now)]);

      final run = (await repository.startImport('s1')).valueOrNull!;
      await repository.abandonImport(
        run,
        outcome: GuideImportOutcome.failed,
        failure: NetworkFailure('xmltv.php', 503),
      );

      final coverage = (await repository.coverage('s1')).valueOrNull!;
      expect(coverage.programmes, 1);
      expect(coverage.lastImport!.id, run);
      expect(coverage.lastImport!.outcome, GuideImportOutcome.failed);
      expect(coverage.lastImport!.failureCode, 'network');
      expect(coverage.lastImport!.failureStatus, 503);
      expect(coverage.lastImport!.isLive, isFalse);
    });

    test('says so while an import is running', () async {
      await repository.startImport('s1');

      expect(
        (await repository.coverage('s1')).valueOrNull!.isImporting,
        isTrue,
      );
    });

    test('is watched, and follows an import', () async {
      final coverage = repository.watchCoverage('s1');
      final seen = <GuideCoverage>[];
      final subscription = coverage.listen(seen.add);
      addTearDown(subscription.cancel);
      await pumpEventQueue();

      await import([programme('arena.sports', start: _now)]);
      await pumpEventQueue();

      expect(seen.first.hasGuide, isFalse);
      expect(seen.last.hasGuide, isTrue);
      expect(seen.last.programmes, 1);
    });
  });

  group('an interrupted import', () {
    test('is recovered and its staged rows are dropped', () async {
      await import([programme('arena.sports', start: _now)]);
      final killed = (await repository.startImport('s1')).valueOrNull!;
      await repository.stagePrograms(killed, [
        programme('arena.sports', start: _now, title: 'Never landed'),
      ]);

      expect((await repository.recoverInterrupted()).valueOrNull, 1);

      expect(await db.select(db.epgProgramsStaging).get(), isEmpty);
      final coverage = (await repository.coverage('s1')).valueOrNull!;
      expect(coverage.programmes, 1);
      expect(coverage.lastImport!.failureCode, interruptedImportCode);
      expect(coverage.isImporting, isFalse);
    });
  });

  group('the guide’s own channels', () {
    test('are searched by name and by id for the picker', () async {
      await import(
        [programme('arena.sports', start: _now)],
        channels: const [
          GuideChannel(xmltvId: 'arena.sports', displayName: 'Arena Sports 1'),
          GuideChannel(xmltvId: 'velocity.uk', displayName: 'Velocity Motors'),
          GuideChannel(xmltvId: 'summit.outdoor'),
        ],
      );

      final byName = (await repository.guideChannels(
        's1',
        query: 'motors',
      )).valueOrNull!;
      final byId = (await repository.guideChannels(
        's1',
        query: 'summit',
      )).valueOrNull!;
      final all = (await repository.guideChannels('s1')).valueOrNull!;

      expect(byName.single.xmltvId, 'velocity.uk');
      expect(byId.single.label, 'summit.outdoor');
      expect(all, hasLength(3));
    });
  });

  group('the user’s mapping', () {
    test('is written, replaced and removed through the repository', () async {
      await repository.setMapping(
        sourceId: 's1',
        channelRemoteKey: '201',
        xmltvId: 'arena.sports',
      );
      await repository.setMapping(
        sourceId: 's1',
        channelRemoteKey: '201',
        xmltvId: 'arena.one',
      );

      final mappings = (await repository.mappings('s1')).valueOrNull!;
      expect(mappings.single.xmltvId, 'arena.one');
      expect(mappings.single.updatedAt, _now);

      await repository.removeMapping(sourceId: 's1', channelRemoteKey: '201');
      expect((await repository.mappings('s1')).valueOrNull, isEmpty);
    });
  });

  test('clearing the guide leaves nothing to read', () async {
    final channel = await addChannel('201');
    await match(channel, 'arena.sports');
    await import([programme('arena.sports', start: _now)]);

    await repository.clearGuide('s1');

    expect((await repository.coverage('s1')).valueOrNull!.hasGuide, isFalse);
    expect(
      (await repository.nowNextForChannels([channel], _now)).valueOrNull,
      isEmpty,
    );
  });

  group('stored counts', () {
    test('read back as written', () {
      const counts = EpgImportCounts(
        channels: 3,
        programmes: 9,
        skipped: {'bad_date': 2, 'no_channel': 1},
        truncated: true,
      );

      final back = EpgImportCounts.fromJson(counts.toJson());

      expect(back.channels, 3);
      expect(back.programmes, 9);
      expect(back.skipped, {'bad_date': 2, 'no_channel': 1});
      expect(back.truncated, isTrue);
    });

    test('a damaged or foreign value reads as empty', () {
      expect(EpgImportCounts.fromJson(null).programmes, 0);
      expect(EpgImportCounts.fromJson('').programmes, 0);
      expect(EpgImportCounts.fromJson('not json').programmes, 0);
      expect(EpgImportCounts.fromJson('[1,2]').programmes, 0);
      expect(
        EpgImportCounts.fromJson('{"channels":"12","skipped":"none"}').channels,
        12,
      );
    });
  });
}
