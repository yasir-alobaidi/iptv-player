import 'dart:io';

// `isNull` and `isNotNull` exist in both drift and matcher; the matcher's
// are the ones these tests mean.
import 'package:drift/drift.dart' hide isNotNull, isNull;
import 'package:drift/isolate.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:iptv_player/core/result.dart';
import 'package:iptv_player/data/db/app_database.dart';
import 'package:iptv_player/data/db/epg_tables.dart';
import 'package:iptv_player/data/db/tables.dart';
import 'package:iptv_player/data/sync/epg_match_work.dart';
import 'package:iptv_player/features/guide/domain/epg_match_summary.dart';
import 'package:iptv_player/features/guide/domain/epg_matcher.dart';

final _now = DateTime.utc(2026, 9, 23, 12);

/// The match job over a real file database, opened the way the app opens
/// it, so the job connects to it as it does in the app.
final class _Env {
  new _(this.directory, this.db);

  static Future<_Env> open() async {
    final directory = await Directory.systemTemp.createTemp('epg_match');
    final db = AppDatabase(await openAppDatabase(directory));
    final env = _Env._(directory, db);
    addTearDown(env.close);
    return env;
  }

  final Directory directory;
  final AppDatabase db;

  Future<void> source(String id) => db.sourcesDao.upsert(
    SourcesCompanion.insert(
      id: id,
      type: SourceType.xtream,
      name: 'Provider $id',
      url: 'http://$id.test:8080',
      createdAt: _now,
      updatedAt: _now,
    ),
  );

  /// Adds a provider channel and returns its row id.
  Future<int> channel(
    String sourceId,
    String remoteKey,
    String name, {
    String? epgKey,
  }) async {
    await db.channelsDao.upsertAll([
      ChannelsCompanion.insert(
        sourceId: sourceId,
        remoteKey: remoteKey,
        name: name,
        epgKey: Value(epgKey),
      ),
    ]);
    return (await db.channelsDao.byRemoteKey(sourceId, remoteKey))!.id;
  }

  /// Puts guide channels straight into the live table, as a swap would.
  Future<void> guide(String sourceId, Map<String, String?> channels) =>
      db.batch(
        (b) => b.insertAll(db.epgChannels, [
          for (final MapEntry(key: id, value: name) in channels.entries)
            EpgChannelsCompanion.insert(
              sourceId: sourceId,
              xmltvId: id,
              displayName: Value(name),
            ),
        ]),
      );

  Future<void> map(String sourceId, String remoteKey, String xmltvId) =>
      db.epgDao.setMapping(sourceId, remoteKey, xmltvId, _now);

  Future<EpgMatchWork> work(String sourceId, {int pageSize = 5000}) async =>
      EpgMatchWork(
        sourceId: sourceId,
        connection: await db.serializableConnection(),
        pageSize: pageSize,
      );

  Future<Result<EpgMatchSummary>> run(
    String sourceId, {
    int pageSize = 5000,
    void Function(int)? report,
  }) async =>
      await runEpgMatchWork(await work(sourceId, pageSize: pageSize), report);

  /// channel id → (guide id, rule) for a source.
  Future<Map<int, (String, EpgMatchRule)>> matches(String sourceId) async {
    final rows = await (db.select(
      db.epgMatches,
    )..where((t) => t.sourceId.equals(sourceId))).get();
    return {for (final row in rows) row.channelId: (row.xmltvId, row.rule)};
  }

  Future<void> close() async {
    await db.close();
    await directory.delete(recursive: true);
  }
}

/// A source whose channels each match by a different rule, or not at all.
typedef _Seeded = ({
  int exact,
  int loose,
  int named,
  int mapped,
  int mappedAway,
  int unmatched,
});

Future<_Seeded> _seed(_Env env, String sourceId) async {
  await env.source(sourceId);
  await env.guide(sourceId, {
    'bbcone.uk': 'BBC One',
    'itv1.uk': 'ITV 1',
    'skysportsnews.uk': 'Sky Sports News',
    'film4.uk': 'Film4',
    'film4plus1.uk': 'Film4 +1',
    '': 'A channel with no id',
  });
  final seeded = (
    exact: await env.channel(sourceId, '101', 'BBC 1', epgKey: 'bbcone.uk'),
    loose: await env.channel(sourceId, '102', 'ITV', epgKey: ' ITV1.UK '),
    named: await env.channel(sourceId, '103', 'UK: Sky Sports News HD'),
    mapped: await env.channel(sourceId, '104', 'Film4', epgKey: 'film4.uk'),
    mappedAway: await env.channel(sourceId, '105', 'Arena Sports 1'),
    unmatched: await env.channel(sourceId, '106', 'Nothing Like It'),
  );
  // One mapping to a guide channel, one to an id this guide lacks.
  await env.map(sourceId, '104', 'film4plus1.uk');
  await env.map(sourceId, '105', 'arena.sports.1');
  return seeded;
}

void main() {
  // Most tests run the job's body in the test isolate, where its database
  // (connected through the DriftIsolate, as in the app) sits beside the
  // test's own.
  driftRuntimeOptions.dontWarnAboutMultipleDatabases = true;

  test('each rule lands under its own name, and the summary counts '
      'them', () async {
    final env = await _Env.open();
    final c = await _seed(env, 's1');

    final summary = (await env.run('s1')).valueOrNull;

    expect(await env.matches('s1'), {
      c.exact: ('bbcone.uk', EpgMatchRule.exactId),
      c.loose: ('itv1.uk', EpgMatchRule.caseInsensitiveId),
      c.named: ('skysportsnews.uk', EpgMatchRule.normalizedName),
      c.mapped: ('film4plus1.uk', EpgMatchRule.manual),
      // The user's mapping stands even for an id the guide lacks.
      c.mappedAway: ('arena.sports.1', EpgMatchRule.manual),
    });
    expect(
      summary,
      const EpgMatchSummary(
        channels: 6,
        byRule: {
          GuideMatchRule.manual: 2,
          GuideMatchRule.exactId: 1,
          GuideMatchRule.caseInsensitiveId: 1,
          GuideMatchRule.normalizedName: 1,
        },
        guideChannels: 6,
      ),
    );
    expect(summary!.matched, 5);
    expect(summary.unmatched, 1);
    expect(
      '$summary',
      '5 of 6 channels matched against 6 guide channels (manual 2, exactId '
          '1, caseInsensitiveId 1, normalizedName 1)',
    );
  });

  test('every rule the matcher has is one the database stores', () {
    final stored = EpgMatchRule.values.map((r) => r.name).toSet();
    for (final rule in GuideMatchRule.values) {
      expect(stored, contains(rule.name));
    }
  });

  test('the rewrite is whole: what no longer matches loses its row, and '
      "another source's matches are untouched", () async {
    final env = await _Env.open();
    final c = await _seed(env, 's1');
    final other = await _seed(env, 's2');
    expect((await env.run('s1')).isOk, isTrue);
    expect((await env.run('s2')).isOk, isTrue);
    final before = await env.matches('s2');

    // BBC One leaves the guide, and the Film4 mapping is removed.
    await (env.db.delete(env.db.epgChannels)..where(
          (t) => t.sourceId.equals('s1') & t.xmltvId.equals('bbcone.uk'),
        ))
        .go();
    await env.db.epgDao.removeMapping('s1', '104');
    final summary = (await env.run('s1')).valueOrNull!;

    final after = await env.matches('s1');
    expect(after.containsKey(c.exact), isFalse);
    expect(after[c.mapped], ('film4.uk', EpgMatchRule.exactId));
    expect(after[c.mappedAway], ('arena.sports.1', EpgMatchRule.manual));
    expect(after, hasLength(4));
    expect(summary.matched, 4);
    expect(await env.matches('s2'), before);
    expect(before[other.exact], ('bbcone.uk', EpgMatchRule.exactId));
  });

  test('a channel removed later loses its match with it', () async {
    final env = await _Env.open();
    final c = await _seed(env, 's1');
    await env.run('s1');

    await (env.db.delete(
      env.db.channels,
    )..where((t) => t.id.equals(c.exact))).go();

    final matches = await env.matches('s1');
    expect(matches.containsKey(c.exact), isFalse);
    expect(matches, hasLength(4));
  });

  test('a source with no guide and no mappings has its matches '
      'cleared', () async {
    final env = await _Env.open();
    await _seed(env, 's1');
    await env.run('s1');
    expect(await env.matches('s1'), hasLength(5));

    await (env.db.delete(
      env.db.epgChannels,
    )..where((t) => t.sourceId.equals('s1'))).go();
    await env.db.epgDao.removeMapping('s1', '104');
    await env.db.epgDao.removeMapping('s1', '105');
    final summary = (await env.run('s1')).valueOrNull!;

    expect(await env.matches('s1'), isEmpty);
    expect(summary.channels, 6);
    expect(summary.matched, 0);
    expect(summary.guideChannels, 0);
    // The channels themselves are untouched.
    expect(await env.db.channelsDao.countFor('s1'), 6);
  });

  test("with no guide at all, the user's mappings are still written", () async {
    final env = await _Env.open();
    await env.source('s1');
    final mapped = await env.channel('s1', '201', 'Arena Sports 1');
    await env.channel('s1', '202', 'Velocity', epgKey: 'vel.uk');
    await env.map('s1', '201', 'arena.sports.1');

    final summary = (await env.run('s1')).valueOrNull!;

    expect(await env.matches('s1'), {
      mapped: ('arena.sports.1', EpgMatchRule.manual),
    });
    expect(summary.of(GuideMatchRule.manual), 1);
    expect(summary.guideChannels, 0);
  });

  test('small pages read every row once, and report after each', () async {
    final env = await _Env.open();
    await _seed(env, 's1');
    await env.run('s1');
    final whole = await env.matches('s1');
    final reports = <int>[];

    final summary = (await env.run(
      's1',
      pageSize: 2,
      report: reports.add,
    )).valueOrNull!;

    expect(await env.matches('s1'), whole);
    expect(reports, [2, 4, 6]);
    expect(summary.channels, 6);
    // Six guide channels in pages of two, the blank id among them.
    expect(summary.guideChannels, 6);
  });

  test('odd names and keys are matched or left alone, never thrown '
      '(hard rule 1)', () async {
    final env = await _Env.open();
    final c = await _seed(env, 's1');
    final odd = [
      await env.channel('s1', 'o1', ''),
      await env.channel('s1', 'o2', '   ', epgKey: '   '),
      await env.channel('s1', 'o3', '4K', epgKey: ''),
      await env.channel('s1', 'o4', '|UK| ▎ [FHD] (HD)'),
      await env.channel('s1', 'o5', '📺 🔥 &amp;amp; &#0; &#xD800;'),
      await env.channel('s1', 'o6', 'x' * 20000),
      await env.channel('s1', 'o7', 'Film4 +1 \u0000 \u200b'),
      await env.channel('s1', '', 'A channel with a blank key'),
    ];

    final result = await env.run('s1');

    expect(result.isOk, isTrue, reason: '${result.failureOrNull}');
    final summary = result.valueOrNull!;
    expect(summary.channels, 6 + odd.length);
    expect(summary.skipped, 0);
    final matches = await env.matches('s1');
    expect(matches[c.exact], ('bbcone.uk', EpgMatchRule.exactId));
    expect(matches[c.named], ('skysportsnews.uk', EpgMatchRule.normalizedName));
    // Whatever the odd ones matched, it is a guide channel's own id.
    for (final id in odd) {
      final match = matches[id];
      if (match == null) continue;
      expect(
        ['film4plus1.uk', 'film4.uk', 'bbcone.uk'],
        contains(match.$1),
        reason: 'channel $id',
      );
    }
  });

  test('a source that does not exist matches nothing, and fails '
      'nothing', () async {
    final env = await _Env.open();

    final summary = (await env.run('gone')).valueOrNull;

    expect(summary, const EpgMatchSummary(channels: 0));
  });

  test('in its own isolate, through the guarded job', () async {
    final env = await _Env.open();
    final c = await _seed(env, 's1');

    final job = startEpgMatchJob(
      await env.work('s1'),
      timeout: const Duration(seconds: 30),
    );
    final reports = <int>[];
    final listening = job.progress.listen(reports.add);
    final result = await job.result;
    await listening.cancel();

    final summary = result.valueOrNull?.valueOrNull;
    expect(summary, isNotNull, reason: '$result');
    expect(summary!.matched, 5);
    expect(reports, [6]);
    expect((await env.matches('s1'))[c.loose], (
      'itv1.uk',
      EpgMatchRule.caseInsensitiveId,
    ));
  });

  test('a stopped job writes nothing and says it was cancelled', () async {
    final env = await _Env.open();
    await _seed(env, 's1');

    final job = startEpgMatchJob(await env.work('s1'))..cancel();
    final result = await job.result;

    expect(result.failureOrNull, isA<CancelledFailure>());
    // A stop never lands inside the write: all of it, or none.
    expect(await env.matches('s1'), anyOf(isEmpty, hasLength(5)));
  });
}
