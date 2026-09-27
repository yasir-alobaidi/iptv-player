// `isNull` exists in both drift and matcher; the matcher's is the one
// these tests mean.
import 'dart:async';
import 'dart:io';
import 'dart:isolate';

import 'package:drift/drift.dart' hide isNull;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:iptv_player/core/result.dart';
import 'package:iptv_player/data/db/app_database.dart';
import 'package:iptv_player/data/db/catalogue_tables.dart';
import 'package:iptv_player/data/db/epg_tables.dart';
import 'package:iptv_player/data/db/tables.dart';
import 'package:iptv_player/features/guide/data/db_epg_repository.dart';
import 'package:iptv_player/features/guide/data/guide_ranking_worker.dart';
import 'package:iptv_player/features/guide/domain/epg.dart';
import 'package:iptv_player/features/guide/domain/epg_matcher.dart';
import 'package:iptv_player/features/guide/domain/guide_channel_ranking.dart';
import 'package:iptv_player/features/guide/domain/guide_matching.dart';

final _now = DateTime.utc(2026, 9, 20, 20);

void main() {
  late AppDatabase db;
  late _Selects selects;
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
    selects = _Selects();
    db = AppDatabase(NativeDatabase.memory().interceptWith(selects));
    repository = DbEpgRepository(db, clock: () => _now);
    await addSource('s1');
  });
  tearDown(() async {
    await repository.dispose();
    await db.close();
  });

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

  group('channels with a guide', () {
    test('are the matched channels whose guide channel has programmes, '
        'whenever those are', () async {
      final matched = await addChannel('201');
      final later = await addChannel('202');
      final unmatched = await addChannel('203');
      final missing = await addChannel('204');
      await addSource('s2');
      final elsewhere = await addChannel('201', source: 's2');
      await match(matched, 'arena.sports');
      await match(later, 'velocity');
      // A mapping to an id this guide doesn't have.
      await match(missing, 'gone.uk');
      // Another source's guide has this id; this source's doesn't.
      await match(elsewhere, 'arena.sports', source: 's2');
      await import([
        programme('arena.sports', start: _now),
        programme('velocity', start: _now.add(const Duration(days: 5))),
      ]);

      final found = (await repository.channelsWithGuide([
        matched,
        later,
        unmatched,
        missing,
        elsewhere,
      ])).valueOrNull!;

      expect(found, {matched, later});
      expect(
        (await repository.channelsWithGuide(const [])).valueOrNull,
        isEmpty,
      );
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

    test('says when the guide in use came in, even after a refresh that '
        'failed', () async {
      var now = _now;
      final clocked = DbEpgRepository(db, clock: () => now);
      final first = (await clocked.startImport('s1')).valueOrNull!;
      await clocked.stageChannels(first, const [
        GuideChannel(xmltvId: 'arena.sports'),
      ]);
      await clocked.stagePrograms(first, [
        programme('arena.sports', start: _now),
      ]);
      now = _now.add(const Duration(minutes: 3));
      await clocked.commitImport(sourceId: 's1', importRun: first);
      expect(
        (await clocked.coverage('s1')).valueOrNull!.updatedAt,
        _now.add(const Duration(minutes: 3)),
      );

      now = _now.add(const Duration(hours: 6));
      final failed = (await clocked.startImport('s1')).valueOrNull!;
      now = _now.add(const Duration(hours: 6, minutes: 1));
      await clocked.abandonImport(
        failed,
        outcome: GuideImportOutcome.failed,
        failure: NetworkFailure('xmltv.php', 503),
      );

      final coverage = (await clocked.coverage('s1')).valueOrNull!;
      expect(coverage.lastImport!.id, failed);
      expect(coverage.lastImport!.outcome, GuideImportOutcome.failed);
      expect(coverage.updatedAt, _now.add(const Duration(minutes: 3)));
      expect(coverage.updatedAt!.isUtc, isTrue);
    });

    test('has no update time without a guide', () async {
      expect((await repository.coverage('s1')).valueOrNull!.updatedAt, isNull);
      await repository.startImport('s1');
      expect((await repository.coverage('s1')).valueOrNull!.updatedAt, isNull);
      await import([programme('arena.sports', start: _now)]);
      await repository.clearGuide('s1');
      expect((await repository.coverage('s1')).valueOrNull!.updatedAt, isNull);
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

  group('Settings → Guide’s channel list', () {
    late Map<String, int> ids;
    late int sports;

    Future<int> category(String key, {bool hidden = false}) => db
        .into(db.categories)
        .insert(
          CategoriesCompanion.insert(
            sourceId: 's1',
            kind: CatalogueKind.live,
            remoteKey: key,
            name: 'Category $key',
            isHidden: Value(hidden),
          ),
        );

    Future<void> attach(int channelId, String xmltvId, EpgMatchRule rule) => db
        .into(db.epgMatches)
        .insertOnConflictUpdate(
          EpgMatchesCompanion.insert(
            channelId: Value(channelId),
            sourceId: 's1',
            xmltvId: xmltvId,
            rule: rule,
          ),
        );

    /// Eight channels: six visible (four matched, two of them by hand),
    /// one hidden, one in a hidden category.
    setUp(() async {
      sports = await category('1');
      final adult = await category('2', hidden: true);
      ChannelsCompanion row(
        String key,
        String name, {
        int? number,
        int position = 0,
        int? categoryId,
      }) => ChannelsCompanion.insert(
        sourceId: 's1',
        remoteKey: key,
        name: name,
        number: Value(number),
        position: Value(position),
        categoryId: Value(categoryId),
        logoUrl: Value('http://logos.test/$key.png'),
        epgKey: Value('epg.$key'),
      );
      await db.channelsDao.upsertAll([
        // Inserted before 900, so its row id is lower: position decides.
        row('901', 'Quiet 50% Off_Channel', position: 1),
        row(
          '201',
          'Arena Sports 1',
          number: 201,
          position: 3,
          categoryId: sports,
        ),
        row(
          '202',
          'Arena Sports 2',
          number: 202,
          position: 2,
          categoryId: sports,
        ),
        row(
          '203',
          'ARENA SPORTS 3 FHD',
          number: 203,
          position: 4,
          categoryId: sports,
        ),
        row('7', 'Velocity Motors', number: 7, position: 5),
        row('900', 'Zebra TV'),
        row('301', 'Night Shift', number: 301, categoryId: adult),
        row('302', 'Backroom Feed', number: 302),
      ]);
      ids = {
        for (final channel in await db.select(db.channels).get())
          channel.remoteKey: channel.id,
      };
      await db.channelsDao.rename(ids['203']!, 'My Arena');
      await db.channelsDao.setHidden(ids['302']!, hidden: true);
      await import(
        [programme('arena.sports1', start: _now)],
        channels: const [
          GuideChannel(
            xmltvId: 'arena.sports1',
            displayName: 'Arena Sports 1 HD',
          ),
          GuideChannel(xmltvId: 'arena2'),
          GuideChannel(xmltvId: 'arena3', displayName: 'Arena Three'),
          GuideChannel(xmltvId: 'backroom', displayName: 'Backroom'),
        ],
      );
      await attach(ids['201']!, 'arena.sports1', EpgMatchRule.exactId);
      await attach(ids['202']!, 'arena2', EpgMatchRule.manual);
      await attach(ids['203']!, 'arena3', EpgMatchRule.normalizedName);
      // The user's mapping to an id this guide doesn't declare.
      await attach(ids['7']!, 'velocity.uk', EpgMatchRule.manual);
      await attach(ids['302']!, 'backroom', EpgMatchRule.exactId);
    });

    Future<List<ChannelGuideMatch>> list({
      ChannelMatchFilter filter = ChannelMatchFilter.unmatched,
      String query = '',
      int offset = 0,
      int limit = 100,
    }) async {
      final result = await repository.channelMatches(
        's1',
        filter: filter,
        query: query,
        offset: offset,
        limit: limit,
      );
      expect(result.isOk, isTrue, reason: '${result.failureOrNull}');
      return result.valueOrNull!;
    }

    Future<List<String>> keys({
      ChannelMatchFilter filter = ChannelMatchFilter.unmatched,
      String query = '',
      int offset = 0,
      int limit = 100,
    }) async => [
      for (final match in await list(
        filter: filter,
        query: query,
        offset: offset,
        limit: limit,
      ))
        match.remoteKey,
    ];

    Future<int> count({
      ChannelMatchFilter filter = ChannelMatchFilter.unmatched,
      String query = '',
    }) async => (await repository.countChannelMatches(
      's1',
      filter: filter,
      query: query,
    )).valueOrNull!;

    test('each filter, in channel-number order, numberless last by the '
        'provider’s order', () async {
      expect(await keys(), ['900', '901']);
      expect(await keys(filter: ChannelMatchFilter.manual), ['7', '202']);
      expect(await keys(filter: ChannelMatchFilter.all), [
        '7',
        '201',
        '202',
        '203',
        '900',
        '901',
      ]);
      expect(await count(), 2);
      expect(await count(filter: ChannelMatchFilter.manual), 2);
      expect(await count(filter: ChannelMatchFilter.all), 6);
    });

    test('text narrows every filter, on either name, and counts '
        'agree', () async {
      const all = ChannelMatchFilter.all;
      const manual = ChannelMatchFilter.manual;
      const unmatched = ChannelMatchFilter.unmatched;
      for (final (filter, query, expected) in [
        (all, 'arena', ['201', '202', '203']),
        (manual, 'arena', ['202']),
        (unmatched, 'arena', <String>[]),
        (unmatched, '  zebra ', ['900']),
        (all, 'motors', ['7']),
        (all, 'MOTORS', ['7']),
        // The provider's name, under the user's rename.
        (all, 'fhd', ['203']),
        // The user's rename.
        (all, 'my arena', ['203']),
        // Wildcards are only themselves.
        (all, '50%', ['901']),
        (all, '%', ['901']),
        (all, '_', ['901']),
        (all, r'\', <String>[]),
        (all, 'Sports _', <String>[]),
        // Hidden, or in a hidden category.
        (all, 'night', <String>[]),
        (all, 'backroom', <String>[]),
        (all, '   ', ['7', '201', '202', '203', '900', '901']),
      ]) {
        final reason = '${filter.name} "$query"';
        expect(
          await keys(filter: filter, query: query),
          expected,
          reason: reason,
        );
        expect(
          await count(filter: filter, query: query),
          expected.length,
          reason: reason,
        );
      }
    });

    test('digits find the channel with that number, and names with '
        'them', () async {
      const all = ChannelMatchFilter.all;
      for (final (filter, query, expected) in [
        (all, '7', ['7']),
        (all, '201', ['201']),
        // No channel 2; "Arena Sports 2" has the digit.
        (all, '2', ['202']),
        (ChannelMatchFilter.unmatched, '7', <String>[]),
        (ChannelMatchFilter.manual, '202', ['202']),
        // Hidden channels have numbers too.
        (all, '302', <String>[]),
        // More digits than any number holds.
        (all, '9' * 40, <String>[]),
      ]) {
        final reason = '${filter.name} "$query"';
        expect(
          await keys(filter: filter, query: query),
          expected,
          reason: reason,
        );
        expect(
          await count(filter: filter, query: query),
          expected.length,
          reason: reason,
        );
      }
    });

    test('pages', () async {
      const all = ChannelMatchFilter.all;
      expect(await keys(filter: all, offset: 2, limit: 2), ['202', '203']);
      expect(await keys(filter: all, offset: 5, limit: 10), ['901']);
      expect(await keys(filter: all, offset: 6), isEmpty);
      expect(await keys(filter: all, limit: 0), isEmpty);
      expect(await keys(filter: all, offset: -3, limit: 1), ['7']);
    });

    test('what a row says', () async {
      final rows = {
        for (final row in await list(filter: ChannelMatchFilter.all))
          row.remoteKey: row,
      };

      expect(
        rows['201'],
        ChannelGuideMatch(
          channelId: ids['201']!,
          sourceId: 's1',
          remoteKey: '201',
          name: 'Arena Sports 1',
          providerName: 'Arena Sports 1',
          number: 201,
          logoUrl: 'http://logos.test/201.png',
          epgKey: 'epg.201',
          xmltvId: 'arena.sports1',
          rule: GuideMatchRule.exactId,
          guideLabel: 'Arena Sports 1 HD',
          inGuide: true,
        ),
      );
      expect(rows['201']!.isMatched, isTrue);
      expect(rows['201']!.isManual, isFalse);
      // The user's name shows; the provider's is what the picker ranks by.
      expect(rows['203']!.name, 'My Arena');
      expect(rows['203']!.providerName, 'ARENA SPORTS 3 FHD');
      expect(rows['203']!.rule, GuideMatchRule.normalizedName);
      expect(rows['203']!.guideLabel, 'Arena Three');
      expect(
        rows['900'],
        ChannelGuideMatch(
          channelId: ids['900']!,
          sourceId: 's1',
          remoteKey: '900',
          name: 'Zebra TV',
          providerName: 'Zebra TV',
          logoUrl: 'http://logos.test/900.png',
          epgKey: 'epg.900',
        ),
      );
      expect(rows['900']!.isMatched, isFalse);
    });

    test('a guide channel with no name is labelled by its id', () async {
      final row = (await list(filter: ChannelMatchFilter.manual))
          .singleWhere((row) => row.remoteKey == '202');

      expect(row.inGuide, isTrue);
      expect(row.guideLabel, 'arena2');
      expect(row.isManual, isTrue);
    });

    test('a mapping to an id the guide lacks: matched, not in the '
        'guide', () async {
      final row = (await list(filter: ChannelMatchFilter.manual)).first;

      expect(row.remoteKey, '7');
      expect(row.xmltvId, 'velocity.uk');
      expect(row.isMatched, isTrue);
      expect(row.isManual, isTrue);
      expect(row.inGuide, isFalse);
      expect(row.guideLabel, isNull);
    });

    test('with the guide cleared, every match is out of it', () async {
      await repository.clearGuide('s1');

      final rows = await list(filter: ChannelMatchFilter.all);

      expect(rows.where((row) => row.isMatched), hasLength(4));
      expect(rows.where((row) => row.inGuide), isEmpty);
      expect(rows.map((row) => row.guideLabel).nonNulls, isEmpty);
    });

    test('a rule this build doesn’t know is a match all the same', () async {
      await db.customStatement(
        "UPDATE epg_matches SET rule = 'fromTheFuture' WHERE channel_id = ?",
        [ids['201']],
      );

      final row = (await repository.channelMatch(ids['201']!)).valueOrNull!;

      expect(row.xmltvId, 'arena.sports1');
      expect(row.rule, isNull);
      expect(row.isMatched, isTrue);
      expect(row.isManual, isFalse);
      expect(await keys(), isNot(contains('201')));
      expect(await keys(filter: ChannelMatchFilter.all), contains('201'));
    });

    test('one channel is found hidden or not; a gone one is null', () async {
      final hidden = (await repository.channelMatch(ids['302']!)).valueOrNull!;
      final inHiddenCategory = (await repository.channelMatch(ids['301']!))
          .valueOrNull!;
      final visible = (await repository.channelMatch(ids['201']!)).valueOrNull;

      expect(hidden.remoteKey, '302');
      expect(hidden.xmltvId, 'backroom');
      expect(hidden.guideLabel, 'Backroom');
      expect(inHiddenCategory.remoteKey, '301');
      expect(inHiddenCategory.isMatched, isFalse);
      expect(visible, (await list(filter: ChannelMatchFilter.all))[1]);
      final gone = await repository.channelMatch(999999);
      expect(gone.isOk, isTrue);
      expect(gone.valueOrNull, isNull);
    });

    test('another source’s channels stay out', () async {
      await addSource('s2');
      await addChannel('500', source: 's2');

      expect(await keys(filter: ChannelMatchFilter.all), hasLength(6));
      expect(
        (await repository.channelMatches(
          's2',
          filter: ChannelMatchFilter.all,
        )).valueOrNull!.map((row) => row.remoteKey),
        ['500'],
      );
    });

    test('the counts are watched: a mapping and its rematch, a hidden '
        'category', () async {
      final seen = <ChannelMatchCounts>[];
      final subscription = repository
          .watchChannelMatchCounts('s1')
          .listen(seen.add);
      addTearDown(subscription.cancel);
      await pumpEventQueue();
      expect(seen, [
        const ChannelMatchCounts(channels: 6, matched: 4, manual: 2),
      ]);

      // What the picker does: map, then the rematch rewrites the source's
      // matches in one transaction.
      await repository.setMapping(
        sourceId: 's1',
        channelRemoteKey: '900',
        xmltvId: 'arena3',
      );
      final current = await (db.select(
        db.epgMatches,
      )..where((t) => t.sourceId.equals('s1'))).get();
      await db.epgDao.replaceMatches('s1', [
        for (final match in current) match.toCompanion(false),
        EpgMatchesCompanion.insert(
          channelId: Value(ids['900']!),
          sourceId: 's1',
          xmltvId: 'arena3',
          rule: EpgMatchRule.manual,
        ),
      ]);
      await pumpEventQueue();
      expect(
        seen.last,
        const ChannelMatchCounts(channels: 6, matched: 5, manual: 3),
      );

      await db.categoriesDao.setHidden(sports, hidden: true);
      await pumpEventQueue();
      // 7 and 900 (both by hand) and 901 are left.
      expect(
        seen.last,
        const ChannelMatchCounts(channels: 3, matched: 2, manual: 2),
      );

      // A write that changes no count is no new value.
      final before = seen.length;
      await db.channelsDao.rename(ids['900']!, 'Zebra');
      await pumpEventQueue();
      expect(seen, hasLength(before));
      expect(seen.last.unmatched, 1);
    });

    test('a count that can’t be read is a storage failure on the '
        'stream', () async {
      await db.customStatement('DROP TABLE epg_matches');

      expect(
        repository.watchChannelMatchCounts('s1'),
        emitsError(isA<StorageFailure>()),
      );
      expect(
        (await repository.channelMatches('s1')).failureOrNull,
        isA<AppFailure>(),
      );
    });
  });

  group('the Match… picker’s candidates', () {
    const guide = [
      GuideChannel(xmltvId: 'velocity.uk', displayName: 'Velocity Motors'),
      GuideChannel(xmltvId: 'arena.sports1', displayName: 'Arena Sports 1 HD'),
      GuideChannel(xmltvId: 'arena.sports2', displayName: 'Arena Sports 2'),
      GuideChannel(xmltvId: 'arena.sports10'),
    ];

    Future<void> importGuide(
      List<GuideChannel> channels, {
      String source = 's1',
    }) => import(
      [programme(channels.first.xmltvId, start: _now)],
      source: source,
      channels: channels,
    );

    Future<List<GuideChannelCandidate>> candidates(
      String channelName, {
      String source = 's1',
      String query = '',
      int limit = 50,
      DbEpgRepository? from,
    }) async {
      final result = await (from ?? repository).matchCandidates(
        source,
        channelName: channelName,
        query: query,
        limit: limit,
      );
      expect(result.isOk, isTrue, reason: '${result.failureOrNull}');
      return result.valueOrNull!;
    }

    List<String> ids(List<GuideChannelCandidate> candidates) => [
      for (final candidate in candidates) candidate.channel.xmltvId,
    ];

    test('none without a guide, or once it is cleared', () async {
      expect(await candidates('Arena Sports 1'), isEmpty);

      await importGuide(guide);
      expect(await candidates('Arena Sports 1'), hasLength(4));

      await repository.clearGuide('s1');
      expect(await candidates('Arena Sports 1'), isEmpty);
    });

    test('are the guide ranked for the channel, as the ranking '
        'ranks it', () async {
      await importGuide(guide);

      final ranked = await candidates('Arena Sports 1');

      expect(
        ranked,
        rankGuideChannels(
          prepareGuideChannels(guide),
          channelName: 'Arena Sports 1',
        ),
      );
      expect(ranked.first.channel, guide[1]);
      expect(ranked.first.score, 1.0);
      expect(ids(await candidates('Arena Sports 1', query: 'velo')), [
        'velocity.uk',
      ]);
      expect(await candidates('Arena Sports 1', limit: 2), hasLength(2));
      expect(await candidates('Arena Sports 1', limit: 0), isEmpty);
    });

    test('the guide is read once per live import', () async {
      await importGuide(guide);
      selects.guideChannels = 0;

      await Future.wait([
        candidates('Arena Sports 1'),
        candidates('Arena Sports 2'),
      ]);
      await candidates('Arena Sports 1', query: 'arena');
      await candidates('Velocity Motors');

      expect(selects.guideChannels, 1);
    });

    test('a new import is read again, and only its channels are '
        'offered', () async {
      await importGuide(guide);
      await candidates('Arena Sports 1');
      selects.guideChannels = 0;

      await importGuide(const [
        GuideChannel(xmltvId: 'summit.outdoor', displayName: 'Summit'),
      ]);
      final after = await candidates('Arena Sports 1');
      await candidates('Summit');

      expect(ids(after), ['summit.outdoor']);
      expect(selects.guideChannels, 1);
    });

    test('each source keeps its own', () async {
      await addSource('s2');
      await importGuide(guide);
      await importGuide(const [
        GuideChannel(xmltvId: 'summit.outdoor', displayName: 'Summit'),
      ], source: 's2');
      selects.guideChannels = 0;

      for (var i = 0; i < 3; i++) {
        expect(await candidates('Arena Sports 1'), hasLength(4));
        expect(ids(await candidates('Summit', source: 's2')), [
          'summit.outdoor',
        ]);
      }

      expect(selects.guideChannels, 2);
    });

    group('from a large guide', () {
      late DbEpgRepository large;

      DbEpgRepository open({
        Duration idle = const Duration(seconds: 60),
        Duration timeout = const Duration(seconds: 10),
        GuideRankingWorkerMain worker = runGuideRankingWorker,
      }) {
        final opened = DbEpgRepository(
          db,
          clock: () => _now,
          rankingIdle: idle,
          rankingTimeout: timeout,
          rankingWorker: worker,
        );
        large = opened;
        return opened;
      }

      setUp(open);
      tearDown(() => large.dispose());

      List<GuideChannel> channels(int count, {String name = 'Channel'}) => [
        for (var i = 0; i < count; i++)
          GuideChannel(
            xmltvId: '${name.toLowerCase()}$i.uk',
            displayName: '$name $i',
          ),
      ];

      const overLimit = DbEpgRepository.rankInBackgroundAbove + 1;

      /// Completes when [isolate] has exited. Listens before anything can
      /// kill it.
      Future<void> exitOf(Isolate isolate) {
        final exited = ReceivePort();
        isolate.addOnExitListener(exited.sendPort);
        return exited.first
            .timeout(const Duration(seconds: 10))
            .whenComplete(exited.close);
      }

      test('over 2,000 channels, are ranked by a worker as the ranking '
          'ranks them, and only the query crosses to it', () async {
        final guide = channels(overLimit);
        await importGuide(guide);
        final prepared = prepareGuideChannels(guide);

        final first = await candidates('Channel 1500', limit: 5, from: large);
        final narrowed = await candidates(
          'Channel 1500',
          query: 'channel 2000',
          from: large,
        );
        final all = await candidates('Arena', from: large);

        expect(
          first,
          rankGuideChannels(prepared, channelName: 'Channel 1500', limit: 5),
        );
        expect(first.first.channel.xmltvId, 'channel1500.uk');
        expect(
          narrowed,
          rankGuideChannels(
            prepared,
            channelName: 'Channel 1500',
            query: 'channel 2000',
          ),
        );
        expect(ids(narrowed), ['channel2000.uk']);
        expect(all, rankGuideChannels(prepared, channelName: 'Arena'));
        expect(all, hasLength(50));
        expect(large.rankingWorkerStarts, 1);
        expect(large.rankingQueries, 3);
        // The worker read the guide itself: the app's side never did.
        expect(selects.guideChannels, 0);
      });

      test('calls that come together share one worker', () async {
        await importGuide(channels(overLimit));

        final answers = await Future.wait([
          for (var i = 0; i < 4; i++)
            candidates('Channel $i', limit: 1, from: large),
        ]);

        expect(
          [for (final answer in answers) ...ids(answer)],
          ['channel0.uk', 'channel1.uk', 'channel2.uk', 'channel3.uk'],
        );
        expect(large.rankingWorkerStarts, 1);
        expect(large.rankingQueries, 4);
        expect(large.rankingWorkerIsolates, hasLength(1));
      });

      test('a new import replaces the worker, and a cleared guide stops '
          'it', () async {
        await importGuide(channels(overLimit));
        await candidates('Channel 1', from: large);
        final first = large.rankingWorkerIsolates.single;
        final firstExited = exitOf(first);

        await importGuide(channels(overLimit, name: 'Station'));
        final after = await candidates('Station 7', limit: 1, from: large);

        await firstExited;
        expect(ids(after), ['station7.uk']);
        expect(large.rankingWorkerStarts, 2);
        final second = large.rankingWorkerIsolates.single;
        expect(second, isNot(first));
        final secondExited = exitOf(second);

        await repository.clearGuide('s1');
        expect(await candidates('Station 7', from: large), isEmpty);
        await secondExited;
        expect(large.rankingWorkerIsolates, isEmpty);
      });

      test('a worker unused for a while is stopped, and the next call '
          'starts another', () async {
        open(idle: const Duration(milliseconds: 200));
        await importGuide(channels(overLimit));
        await candidates('Channel 1', from: large);
        final exited = exitOf(large.rankingWorkerIsolates.single);

        await exited;

        expect(large.rankingWorkerIsolates, isEmpty);
        expect(ids(await candidates('Channel 9', limit: 1, from: large)), [
          'channel9.uk',
        ]);
        expect(large.rankingWorkerStarts, 2);
      });

      test('dispose stops the worker, and later calls are '
          'cancelled', () async {
        await importGuide(channels(overLimit));
        await candidates('Channel 1', from: large);
        final exited = exitOf(large.rankingWorkerIsolates.single);

        await large.dispose();

        await exited;
        final after = await large.matchCandidates(
          's1',
          channelName: 'Channel 1',
        );
        expect(after.failureOrNull, isA<CancelledFailure>());
        expect(large.rankingWorkerStarts, 1);
      });

      test('a worker that dies mid-query fails that query, and the next '
          'call starts over', () async {
        open(worker: _flakyWorker);
        await importGuide(channels(overLimit));
        await candidates('Channel 1', from: large);

        final died = await large.matchCandidates(
          's1',
          channelName: _dieOnQuery,
        );

        expect(died.failureOrNull, isA<UnexpectedFailure>());
        expect(ids(await candidates('Channel 2', limit: 1, from: large)), [
          'channel2.uk',
        ]);
        expect(large.rankingWorkerStarts, 2);
      });

      test('a query not answered in time fails, and the worker is '
          'replaced', () async {
        open(worker: _flakyWorker, timeout: const Duration(milliseconds: 300));
        await importGuide(channels(overLimit));
        await candidates('Channel 1', from: large);

        final slow = await large.matchCandidates(
          's1',
          channelName: _hangOnQuery,
        );

        expect(slow.failureOrNull, isA<TimeoutFailure>());
        expect(ids(await candidates('Channel 2', limit: 1, from: large)), [
          'channel2.uk',
        ]);
        expect(large.rankingWorkerStarts, 2);
      });

      test('of 2,000 channels, are ranked here', () async {
        await importGuide(channels(DbEpgRepository.rankInBackgroundAbove));

        final ranked = await candidates('Channel 1500', limit: 5, from: large);

        expect(large.rankingWorkerStarts, 0);
        expect(ranked.first.channel.xmltvId, 'channel1500.uk');
      });
    });
  });
}

final class _Selects extends QueryInterceptor {
  /// Reads of a source's whole guide channel list (drift's own
  /// statement, quoted, unlike the swap's and the list's joins).
  int guideChannels = 0;

  @override
  Future<List<Map<String, Object?>>> runSelect(
    QueryExecutor executor,
    String statement,
    List<Object?> args,
  ) {
    if (statement.contains('FROM "epg_channels"')) guideChannels++;
    return super.runSelect(executor, statement, args);
  }
}

const _dieOnQuery = 'die';
const _hangOnQuery = 'hang';

/// A ranking worker that exits when asked to rank [_dieOnQuery], and
/// stalls on [_hangOnQuery]. Top level, as a worker's entry point must be.
void _flakyWorker(Object start) {
  unawaited(
    runGuideRankingWorker(
      start,
      beforeRanking: (channelName) {
        if (channelName == _dieOnQuery) Isolate.exit();
        if (channelName == _hangOnQuery) sleep(const Duration(seconds: 2));
      },
    ),
  );
}
