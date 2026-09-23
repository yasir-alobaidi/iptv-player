// `isNull` exists in both drift and matcher; the matcher's is the one
// these tests mean.
import 'package:drift/drift.dart' hide isNull;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:iptv_player/data/db/app_database.dart';
import 'package:iptv_player/data/db/epg_tables.dart';
import 'package:iptv_player/data/db/tables.dart';
import 'package:iptv_player/features/guide/data/db_epg_repository.dart';
import 'package:iptv_player/features/guide/data/db_guide.dart';
import 'package:iptv_player/features/live_tv/domain/channels.dart';
import 'package:iptv_player/features/live_tv/domain/now_next.dart';

final _start = DateTime.utc(2026, 9, 20, 20);

void main() {
  late AppDatabase db;
  late _Selects selects;
  late DbGuide guide;
  late DateTime now;

  Future<ChannelItem> addChannel(String remoteKey) async {
    await db.channelsDao.upsertAll([
      ChannelsCompanion.insert(
        sourceId: 's1',
        remoteKey: remoteKey,
        name: 'Channel $remoteKey',
      ),
    ]);
    final row = (await db.channelsDao.byRemoteKey('s1', remoteKey))!;
    return ChannelItem(
      id: row.id,
      sourceId: 's1',
      remoteKey: remoteKey,
      name: row.name,
    );
  }

  Future<void> match(ChannelItem channel, String xmltvId) => db
      .into(db.epgMatches)
      .insertOnConflictUpdate(
        EpgMatchesCompanion.insert(
          channelId: Value(channel.id),
          sourceId: 's1',
          xmltvId: xmltvId,
          rule: EpgMatchRule.exactId,
        ),
      );

  /// A programme on [xmltvId] from [from] minutes after the start, for
  /// [minutes].
  Future<void> programme(
    String xmltvId,
    String title, {
    required int from,
    int minutes = 60,
    String? description,
  }) {
    final start = _start.add(Duration(minutes: from));
    return db
        .into(db.epgPrograms)
        .insert(
          EpgProgramsCompanion.insert(
            sourceId: 's1',
            epgChannelId: xmltvId,
            startUtc: start.millisecondsSinceEpoch,
            endUtc: start
                .add(Duration(minutes: minutes))
                .millisecondsSinceEpoch,
            title: title,
            description: Value(description),
          ),
        );
  }

  setUp(() async {
    selects = _Selects();
    db = AppDatabase(NativeDatabase.memory().interceptWith(selects));
    now = _start;
    guide = DbGuide(DbEpgRepository(db), clock: () => now);
    await db.sourcesDao.upsert(
      SourcesCompanion.insert(
        id: 's1',
        type: SourceType.xtream,
        name: 'Northwind TV',
        url: 'http://northwind.test',
        createdAt: _start,
        updatedAt: _start,
      ),
    );
  });
  tearDown(() async {
    await guide.dispose();
    await db.close();
  });

  group('a page', () {
    late ChannelItem arena;
    late ChannelItem gap;
    late ChannelItem unmatched;

    setUp(() async {
      arena = await addChannel('201');
      gap = await addChannel('202');
      unmatched = await addChannel('203');
      await match(arena, 'arena.sports');
      await match(gap, 'gap.tv');
      await programme(
        'arena.sports',
        'Continental Cup',
        from: -20,
        description: 'The semi-final.',
      );
      await programme('arena.sports', 'Post Match', from: 40);
      await programme('gap.tv', 'Late News', from: 15, minutes: 30);
    });

    test('is nothing until it is looked up', () {
      expect(guide.cached(arena), isNull);
    });

    test('warms in one query: now and next, a gap, and none', () async {
      selects.guide = 0;

      await guide.warm([arena, gap, unmatched]);

      expect(selects.guide, 1);
      final found = guide.cached(arena)!;
      expect(found.now!.title, 'Continental Cup');
      expect(found.now!.description, 'The semi-final.');
      expect(found.now!.start, _start.subtract(const Duration(minutes: 20)));
      expect(found.next!.title, 'Post Match');
      expect(guide.cached(gap)!.now, isNull, reason: 'a gap until 20:15');
      expect(guide.cached(gap)!.next!.title, 'Late News');
      expect(guide.cached(unmatched), NowNext.none, reason: 'looked up');
    });

    test('asks nothing again for a channel it has warmed', () async {
      await guide.warm([arena, gap, unmatched]);
      selects.guide = 0;

      final found = (await guide.nowNext(arena)).valueOrNull!;

      expect(found.now!.title, 'Continental Cup');
      expect((await guide.nowNext(unmatched)).valueOrNull, NowNext.none);
      expect(selects.guide, 0);
    });

    test('looks one channel up on its own when asked', () async {
      final found = (await guide.nowNext(gap)).valueOrNull!;

      expect(found.now, isNull);
      expect(found.next!.title, 'Late News');
      expect(selects.guide, 1);
      expect(guide.cached(gap), found);
      expect(guide.cached(arena), isNull);
    });
  });

  test('a page of many channels is a query per 500', () async {
    final channels = [
      for (var i = 0; i < 1200; i++)
        ChannelItem(id: i + 1, sourceId: 's1', remoteKey: '$i', name: '$i'),
    ];
    selects.guide = 0;

    await guide.warm(channels);

    expect(selects.guide, 3);
    expect(guide.cached(channels.last), NowNext.none);
  });

  group('never shows a programme that has ended', () {
    late ChannelItem arena;

    setUp(() async {
      arena = await addChannel('201');
      await match(arena, 'arena.sports');
      await programme('arena.sports', 'Continental Cup', from: -20);
      await programme('arena.sports', 'Post Match', from: 40, minutes: 20);
      await programme('arena.sports', 'Late News', from: 60);
      await guide.warm([arena]);
    });

    test('next becomes now once it starts', () {
      now = _start.add(const Duration(minutes: 45));

      final found = guide.cached(arena)!;

      expect(found.now!.title, 'Post Match');
      expect(found.next, isNull, reason: 'not looked up yet');
    });

    test('unknown once both have ended', () {
      now = _start.add(const Duration(minutes: 61));

      expect(guide.cached(arena), isNull);
    });

    test('asks again once the answer changes shape', () async {
      now = _start.add(const Duration(minutes: 45));
      selects.guide = 0;

      final found = (await guide.nowNext(arena)).valueOrNull!;

      expect(selects.guide, 1);
      expect(found.now!.title, 'Post Match');
      expect(found.next!.title, 'Late News');
    });

    test('a gap between them is a gap', () async {
      final gap = await addChannel('202');
      await match(gap, 'gap.tv');
      await programme('gap.tv', 'Early', from: -30, minutes: 40);
      await programme('gap.tv', 'Later', from: 30);
      await guide.warm([gap]);
      now = _start.add(const Duration(minutes: 20));

      final found = guide.cached(gap)!;

      expect(found.now, isNull);
      expect(found.next!.title, 'Later');
    });
  });

  group('when the guide changes', () {
    late ChannelItem arena;
    late ChannelItem velocity;

    setUp(() async {
      arena = await addChannel('201');
      velocity = await addChannel('203');
      await match(arena, 'arena.sports');
      await programme('arena.sports', 'Continental Cup', from: -20);
      await programme('velocity', 'Grand Prix', from: -10);
      await guide.warm([arena, velocity]);
    });

    test('a new match says so, and the next lookup asks again', () async {
      final fired = guide.changes.first;

      await match(velocity, 'velocity');
      await fired.timeout(const Duration(seconds: 2));

      // Until it is asked again, the list keeps what it showed.
      expect(guide.cached(velocity), NowNext.none);
      selects.guide = 0;
      final found = (await guide.nowNext(velocity)).valueOrNull!;
      expect(selects.guide, 1);
      expect(found.now!.title, 'Grand Prix');
      expect(guide.cached(velocity)!.now!.title, 'Grand Prix');

      // Every answer went stale, not only the one that changed.
      await guide.nowNext(arena);
      expect(selects.guide, 2);
    });

    test('an import says so', () async {
      final fired = guide.changes.first;

      await db.epgDao.startImport('s1', _start);

      await fired.timeout(const Duration(seconds: 2));
      selects.guide = 0;
      await guide.warm([arena]);
      expect(selects.guide, 1);
    });

    test('programme rows alone do not', () async {
      var changes = 0;
      final subscription = guide.changes.listen((_) => changes++);
      addTearDown(subscription.cancel);

      await programme('arena.sports', 'Post Match', from: 40);
      await Future<void>.delayed(const Duration(milliseconds: 50));

      expect(changes, 0);
    });
  });
}

/// Counts the statements that read the guide through the matcher.
final class _Selects extends QueryInterceptor {
  int guide = 0;

  @override
  Future<List<Map<String, Object?>>> runSelect(
    QueryExecutor executor,
    String statement,
    List<Object?> args,
  ) {
    if (statement.contains('epg_matches m JOIN epg_programs')) guide++;
    return super.runSelect(executor, statement, args);
  }
}
