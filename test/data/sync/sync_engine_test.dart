import 'dart:async';
import 'dart:convert';
import 'dart:io';

// `isNull` and `isNotNull` exist in both drift and matcher; the matcher's
// are the ones these tests mean.
import 'package:drift/drift.dart' hide isNotNull, isNull;
import 'package:fake_provider/profile.dart';
import 'package:fake_provider/server.dart';
import 'package:fake_provider/server_state.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:iptv_player/core/logging/app_log.dart';
import 'package:iptv_player/core/logging/secret_registry.dart';
import 'package:iptv_player/core/result.dart';
import 'package:iptv_player/core/secure/credential_store.dart';
import 'package:iptv_player/data/db/app_database.dart';
import 'package:iptv_player/data/db/catalogue_tables.dart';
import 'package:iptv_player/data/db/daos/sync_runs_dao.dart';
import 'package:iptv_player/data/sync/sync_engine.dart';
import 'package:iptv_player/features/sources/data/db_source_repository.dart';
import 'package:iptv_player/features/sources/domain/source.dart';
import 'package:iptv_player/features/sources/domain/sync.dart';
import 'package:logger/logger.dart';

/// The sync engine end to end: a real file database opened the way the
/// app opens it, the sync isolate, and a real server — the fake provider
/// in-process, or a playlist on disk.
final class _Env {
  new _(this.directory, this.db, {DateTime Function()? clock})
    : store = InMemoryCredentialStore(),
      memory = MemoryOutput() {
    final secrets = SecretRegistry();
    log = AppLog(output: memory, secrets: secrets);
    repository = DbSourceRepository(
      database: db,
      store: store,
      secrets: secrets,
      log: log,
    );
    engine = SyncEngine(
      database: db,
      sources: repository,
      log: log,
      clock: clock,
      // Small batches, so a few hundred rows still take several.
      batchSize: 50,
    );
  }

  static Future<_Env> open({DateTime Function()? clock}) async {
    final directory = await Directory.systemTemp.createTemp('sync_engine');
    final db = AppDatabase(await openAppDatabase(directory));
    final env = _Env._(directory, db, clock: clock);
    addTearDown(env.close);
    return env;
  }

  final Directory directory;
  final AppDatabase db;
  final InMemoryCredentialStore store;
  final MemoryOutput memory;
  late final AppLog log;
  late final DbSourceRepository repository;
  late final SyncEngine engine;

  List<String> get logLines => [for (final e in memory.buffer) ...e.lines];

  Future<String> add(SourceDraft draft) async =>
      (await repository.add(draft)).valueOrNull!.id;

  /// A playlist file in this environment's directory.
  String playlist(String name, String text) {
    final file = File('${directory.path}/$name')..writeAsStringSync(text);
    return file.path;
  }

  Future<SyncRunRow> latestRun(String sourceId) async =>
      (await db.syncRunsDao.latest(sourceId))!;

  Future<void> close() async {
    await engine.dispose();
    await log.close();
    await db.close();
    await directory.delete(recursive: true);
  }
}

Future<FakeProviderServer> _fakeProvider(FakeProfile profile) async {
  final runDir = await Directory.systemTemp.createTemp('fake_provider');
  addTearDown(() => runDir.delete(recursive: true));
  final server = await FakeProviderServer.start(
    state: FakeServerState(
      profile: profile,
      samplesDir: runDir.path,
      ffmpegPath: 'ffmpeg',
      runDir: runDir.path,
    ),
    port: 0,
  );
  addTearDown(server.close);
  return server;
}

/// Forwards every request to [upstream], except the `player_api.php`
/// actions in [answers]: an `int` answers with that status, a `String`
/// with that body.
Future<Uri> _panelProxy(Uri upstream, Map<String, Object> answers) async {
  final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
  final client = HttpClient();
  addTearDown(() async {
    client.close(force: true);
    await server.close(force: true);
  });
  server.listen((request) async {
    final response = request.response;
    switch (answers[request.uri.queryParameters['action']]) {
      case final int status:
        response.statusCode = status;
      case final String body:
        response
          ..headers.contentType = ContentType.json
          ..write(body);
      default:
        final forwarded = await client.getUrl(
          upstream.replace(path: request.uri.path, query: request.uri.query),
        );
        final answer = await forwarded.close();
        response.statusCode = answer.statusCode;
        await response.addStream(answer);
    }
    await response.close();
  });
  return Uri.parse('http://${server.address.host}:${server.port}');
}

SourceDraft _xtream(Uri server, {String password = 'test'}) => SourceDraft(
  type: SourceType.xtream,
  name: 'Fake panel',
  url: server.toString(),
  username: 'test',
  password: password,
);

SourceDraft _file(String path) =>
    SourceDraft(type: SourceType.m3uFile, name: 'Playlist', url: path);

Future<int> _count(AppDatabase db, String table, [String where = '1']) async {
  final row = await db
      .customSelect('SELECT COUNT(*) AS n FROM $table WHERE $where')
      .getSingle();
  return row.read<int>('n');
}

/// The row the provider lists first.
Future<R> _first<T extends Table, R>(
  AppDatabase db,
  TableInfo<T, R> table,
) async {
  final position = table.columnsByName['position']! as GeneratedColumn<int>;
  return await (db.select(table)
        ..orderBy([(_) => OrderingTerm.asc(position)])
        ..limit(1))
      .getSingle();
}

/// FTS5's own consistency check; throws on a stale index.
Future<void> _checkSearchIndexes(AppDatabase db) async {
  for (final table in ['channels_fts', 'movies_fts', 'series_fts']) {
    await db.customStatement(
      "INSERT INTO $table($table, rank) VALUES ('integrity-check', 1)",
    );
  }
}

const _playlistV1 = '''
#EXTM3U url-tvg="http://epg.test/guide.xml"
#EXTINF:-1 tvg-id="bbc1" tvg-chno="1" tvg-logo="http://logo.test/bbc1.png" group-title="UK",BBC One
#EXTVLCOPT:http-user-agent=Special/1.0
http://tv.test/live/1.ts
#EXTINF:-1 tvg-id="itv" group-title="UK",ITV
http://tv.test/live/2.ts
#EXTINF:-1 group-title="News",Newsroom
http://tv.test/live/3.ts
#EXTINF:-1,No group channel
http://tv.test/live/4.ts
#EXTINF:-1 group-title="Films",Heat (1995)
http://tv.test/movie/10.mkv
#EXTINF:-1 group-title="Films",Arrival
http://tv.test/vod/arrival.mp4
#EXTINF:-1 tvg-logo="http://logo.test/dark.jpg" group-title="Series",Dark S01 E01
http://tv.test/series/100.mkv
#EXTINF:-1 group-title="Series",Dark S01 E02
http://tv.test/series/101.mkv
#EXTINF:-1 group-title="Series",Dark S02 E01
http://tv.test/series/102.mkv
#EXTINF:-1 group-title="Cartoons",Pilot
http://tv.test/series/200.mp4
#EXTINF:-1 group-title="Cartoons",The second one
http://tv.test/series/201.mp4
#EXTINF:-1,Lonely episode
http://tv.test/series/300.mp4
''';

void main() {
  // The Flutter test binding fakes HttpClient with 400s; these need
  // sockets.
  setUpAll(() => HttpOverrides.global = null);

  group('Xtream', () {
    test('a first sync stores the catalogue, the account and the run, '
        'reporting each stage', () async {
      final env = await _Env.open();
      final server = await _fakeProvider(fakeProfiles['default']!);
      final id = await env.add(_xtream(server.url));
      final statuses = <SyncStatus>[];
      final watching = env.engine.watch(id).listen(statuses.add);

      final report = (await env.engine.sync(id)).valueOrNull!;
      // The last status is delivered just after the future completes.
      await pumpEventQueue();
      await watching.cancel();

      expect(report.channels, 240);
      expect(report.movies, 120);
      expect(report.series, 24);
      expect(report.skipped, 0);
      expect(report.removed, 0);
      expect(await env.db.channelsDao.countFor(id), 240);
      expect(await env.db.moviesDao.countFor(id), 120);
      expect(await env.db.seriesDao.countFor(id), 24);
      expect(await _count(env.db, 'categories'), report.categories);
      // Every item is filed: the default profile has no dangling ids.
      expect(await _count(env.db, 'channels', 'category_id IS NULL'), 0);

      final source = (await env.db.sourcesDao.byId(id))!;
      expect(source.lastSyncedAt, isNotNull);
      expect(source.expiresAt, isNotNull);
      final account = jsonDecode(source.accountJson!) as Map<String, Object?>;
      expect(account['status'], 'Active');
      expect(account.keys, isNot(contains('password')));

      final run = await env.latestRun(id);
      expect(run.outcome, SyncOutcome.succeeded);
      expect(jsonDecode(run.countsJson!), containsPair('channels', 240));

      expect(statuses.first, isA<SyncIdle>());
      expect(statuses.last, isA<SyncSucceeded>());
      final progress = [
        for (final status in statuses)
          if (status is SyncRunning) status.progress,
      ];
      final stages = [
        for (final (i, p) in progress.indexed)
          if (i == 0 || progress[i - 1].stage != p.stage) p.stage,
      ];
      expect(stages, [
        SyncStage.account,
        SyncStage.categories,
        SyncStage.live,
        SyncStage.movies,
        SyncStage.series,
        SyncStage.finishing,
      ]);
      final account2 = progress
          .firstWhere((p) => p.stage == SyncStage.categories)
          .account;
      expect(account2?.status, 'Active');
      expect(account2?.expiresAt, source.expiresAt);
      // "Channels 150 of 240": a total once the list is in, and counts that
      // climb batch by batch.
      final live = progress.where((p) => p.stage == SyncStage.live).toList();
      expect(live.map((p) => p.stageTotal), contains(240));
      expect(live.map((p) => p.channels), containsAll([50, 100, 240]));
      await _checkSearchIndexes(env.db);
    });

    test('the quirky profile syncs whole, and dangling categories become '
        'uncategorized', () async {
      final env = await _Env.open();
      final profile = fakeProfiles['quirky']!;
      final server = await _fakeProvider(profile);
      final id = await env.add(_xtream(server.url));

      final report = (await env.engine.sync(id)).valueOrNull!;

      expect(report.channels, profile.liveCount);
      expect(report.movies, profile.movieCount);
      expect(report.series, profile.seriesCount);
      expect(
        await _count(env.db, 'channels', 'category_id IS NULL'),
        greaterThan(0),
      );
      await _checkSearchIndexes(env.db);
    });

    test('a re-sync keeps everything the user set, and removes only what '
        'the provider dropped', () async {
      final env = await _Env.open();
      final profile = fakeProfiles['default']!;
      final first = await _fakeProvider(profile);
      final draft = _xtream(first.url);
      final id = await env.add(draft);
      await env.engine.sync(id);

      final db = env.db;
      final live = await db.categoriesDao
          .watchForSource(id, CatalogueKind.live)
          .first;
      await db.categoriesDao.setHidden(live[0].id, hidden: true);
      await db.categoriesDao.rename(live[1].id, 'My sport');
      await db.categoriesDao.reorder([live[2].id, live[1].id]);
      // The first of each kind: the provider keeps those.
      final channel = await _first(db, db.channels);
      await db.channelsDao.setHidden(channel.id, hidden: true);
      await db.channelsDao.rename(channel.id, 'Mine');
      final movie = await _first(db, db.movies);
      final fetched = DateTime.utc(2026, 9, 18, 12);
      await db.moviesDao.saveDetails(
        MovieDetailsCompanion.insert(
          movieId: Value(movie.id),
          plot: const Value('A plot'),
          fetchedAt: fetched,
        ),
      );
      final show = await _first(db, db.series);
      await db.seriesDao.replaceEpisodes(show.id, [
        EpisodesCompanion.insert(
          seriesId: show.id,
          remoteKey: 'e1',
          season: 1,
          episode: 1,
          title: 'Pilot',
        ),
      ], fetchedAt: fetched);

      // The provider drops its last 40 channels and 20 movies.
      final second = await _fakeProvider(
        profile.copyWith(
          liveCount: profile.liveCount - 40,
          movieCount: profile.movieCount - 20,
        ),
      );
      await env.repository.update(id, draft.copyWith(url: '${second.url}'));
      final report = (await env.engine.sync(id)).valueOrNull!;

      expect(report.removed, 60);
      expect(await db.channelsDao.countFor(id), profile.liveCount - 40);
      expect(await db.moviesDao.countFor(id), profile.movieCount - 20);

      final categories = {
        for (final c
            in await db.categoriesDao
                .watchForSource(id, CatalogueKind.live)
                .first)
          c.id: c,
      };
      expect(categories[live[0].id]!.isHidden, isTrue);
      expect(categories[live[1].id]!.displayName, 'My sport');
      expect(categories[live[1].id]!.sortOrder, 1);
      expect(categories[live[2].id]!.sortOrder, 0);

      final kept = (await db.channelsDao.byRemoteKey(id, channel.remoteKey))!;
      expect(kept.id, channel.id);
      expect(kept.isHidden, isTrue);
      expect(kept.displayName, 'Mine');
      expect((await db.moviesDao.detailsFor(movie.id))!.plot, 'A plot');
      expect(await db.seriesDao.episodesOf(show.id), hasLength(1));
      expect(
        (await db.seriesDao.byRemoteKey(id, show.remoteKey))!.episodesFetchedAt,
        fetched,
      );
      await _checkSearchIndexes(db);
    });

    test('a panel that fails part-way keeps the last catalogue whole, and '
        'the run says why', () async {
      final env = await _Env.open();
      final upstream = await _fakeProvider(fakeProfiles['default']!);
      final draft = _xtream(upstream.url);
      final id = await env.add(draft);
      await env.engine.sync(id);

      // Series fail with a 404, which is not retried.
      final proxy = await _panelProxy(upstream.url, {'get_series': 404});
      await env.repository.update(id, draft.copyWith(url: '$proxy'));
      final result = await env.engine.sync(id);

      expect(result.failureOrNull, isA<NotFoundFailure>());
      expect(env.engine.statusOf(id), isA<SyncFailed>());
      final run = await env.latestRun(id);
      expect(run.outcome, SyncOutcome.failed);
      expect(run.failure, 'not_found');
      expect(await env.db.channelsDao.countFor(id), 240);
      expect(await env.db.seriesDao.countFor(id), 24);
    });

    test('a list that comes back empty keeps the last one', () async {
      final env = await _Env.open();
      final upstream = await _fakeProvider(fakeProfiles['default']!);
      final draft = _xtream(upstream.url);
      final id = await env.add(draft);
      await env.engine.sync(id);
      final hiddenMovies =
          (await env.db.categoriesDao
                  .watchForSource(id, CatalogueKind.movie)
                  .first)
              .first;
      await env.db.categoriesDao.setHidden(hiddenMovies.id, hidden: true);

      final proxy = await _panelProxy(upstream.url, {
        'get_vod_streams': '[]',
        'get_vod_categories': '[]',
      });
      await env.repository.update(id, draft.copyWith(url: '$proxy'));
      final report = (await env.engine.sync(id)).valueOrNull!;

      expect(report.movies, 0);
      expect(report.removed, 0);
      expect(await env.db.moviesDao.countFor(id), 120);
      final categories = await env.db.categoriesDao
          .watchForSource(id, CatalogueKind.movie)
          .first;
      expect(
        categories.singleWhere((c) => c.id == hiddenMovies.id).isHidden,
        isTrue,
      );
      expect(
        env.logLines,
        contains(contains('the movie list came back empty; kept the last')),
      );
    });

    test('a wrong password fails as auth and changes nothing', () async {
      final env = await _Env.open();
      final server = await _fakeProvider(fakeProfiles['default']!);
      final id = await env.add(_xtream(server.url, password: 'wrong'));

      final result = await env.engine.sync(id);

      expect(result.failureOrNull, isA<AuthFailure>());
      expect((await env.latestRun(id)).failure, 'auth');
      expect(await env.db.channelsDao.countFor(id), 0);
      expect((await env.db.sourcesDao.byId(id))!.lastSyncedAt, isNull);
    });
  });

  group('M3U', () {
    test('categories come from groups, series from episode names', () async {
      final env = await _Env.open();
      final id = await env.add(_file(env.playlist('v1.m3u', _playlistV1)));

      final report = (await env.engine.sync(id)).valueOrNull!;

      expect(report.channels, 4);
      // Two films, and the episode with no numbering and no group.
      expect(report.movies, 3);
      expect(report.series, 2);
      expect(report.episodes, 5);
      final db = env.db;
      Future<List<String>> names(CatalogueKind kind) async => [
        for (final c in await db.categoriesDao.watchForSource(id, kind).first)
          c.name,
      ];
      expect(await names(CatalogueKind.live), ['UK', 'News']);
      expect(await names(CatalogueKind.movie), ['Films']);
      expect(await names(CatalogueKind.series), ['Series', 'Cartoons']);

      final bbc = await (db.select(
        db.channels,
      )..where((t) => t.name.equals('BBC One'))).getSingle();
      expect(bbc.number, 1);
      expect(bbc.epgKey, 'bbc1');
      expect(bbc.streamUrl, 'http://tv.test/live/1.ts');
      expect(jsonDecode(bbc.extrasJson!), {'user_agent': 'Special/1.0'});
      final lone = await (db.select(
        db.channels,
      )..where((t) => t.name.equals('No group channel'))).getSingle();
      expect(lone.categoryId, isNull);

      final heat = await (db.select(
        db.movies,
      )..where((t) => t.name.equals('Heat (1995)'))).getSingle();
      expect(heat.ext, 'mkv');

      final series = await (db.select(
        db.series,
      )..orderBy([(t) => OrderingTerm.asc(t.position)])).get();
      expect(series.map((s) => s.name), ['Dark', 'Cartoons']);
      expect(series.first.posterUrl, 'http://logo.test/dark.jpg');
      final dark = await db.seriesDao.episodesOf(series.first.id);
      expect(
        [for (final e in dark) (e.season, e.episode)],
        [(1, 1), (1, 2), (2, 1)],
      );
      final cartoons = await db.seriesDao.episodesOf(series.last.id);
      expect(
        [for (final e in cartoons) (e.episode, e.title)],
        [(1, 'Pilot'), (2, 'The second one')],
      );
      await _checkSearchIndexes(db);
    });

    test('a changed playlist: what left is swept, the user keeps the '
        'rest', () async {
      final env = await _Env.open();
      final path = env.playlist('list.m3u', _playlistV1);
      final id = await env.add(_file(path));
      await env.engine.sync(id);
      final db = env.db;
      final itv = await (db.select(
        db.channels,
      )..where((t) => t.name.equals('ITV'))).getSingle();
      await db.channelsDao.setHidden(itv.id, hidden: true);

      File(path).writeAsStringSync(
        _playlistV1
            .replaceFirst(
              '#EXTINF:-1 group-title="News",Newsroom\n'
                  'http://tv.test/live/3.ts\n',
              '',
            )
            .replaceFirst(
              '#EXTINF:-1 group-title="Series",Dark S02 E01\n'
                  'http://tv.test/series/102.mkv\n',
              '',
            ),
      );
      final report = (await env.engine.sync(id)).valueOrNull!;

      // The channel, its now-empty category, and the episode.
      expect(report.removed, 3);
      expect(await db.channelsDao.countFor(id), 3);
      expect(await db.seriesDao.episodeCountFor(id), 4);
      final kept = (await db.channelsDao.byRemoteKey(id, itv.remoteKey))!;
      expect(kept.id, itv.id);
      expect(kept.isHidden, isTrue);
      await _checkSearchIndexes(db);
    });

    test('a missing file fails and keeps the last catalogue', () async {
      final env = await _Env.open();
      final path = env.playlist('list.m3u', _playlistV1);
      final id = await env.add(_file(path));
      await env.engine.sync(id);
      File(path).deleteSync();

      final result = await env.engine.sync(id);

      expect(result.failureOrNull, isA<NotFoundFailure>());
      expect((await env.latestRun(id)).outcome, SyncOutcome.failed);
      expect(await env.db.channelsDao.countFor(id), 4);
    });

    test('an empty playlist is a failure, not an empty catalogue', () async {
      final env = await _Env.open();
      final path = env.playlist('list.m3u', _playlistV1);
      final id = await env.add(_file(path));
      await env.engine.sync(id);
      File(path).writeAsStringSync('#EXTM3U\n');

      final result = await env.engine.sync(id);

      expect(result.failureOrNull, isA<ParseFailure>());
      expect(await env.db.channelsDao.countFor(id), 4);
    });

    test("the playlist's EPG URLs go to the secure store", () async {
      final env = await _Env.open();
      final id = await env.add(_file(env.playlist('list.m3u', _playlistV1)));

      await env.engine.sync(id);

      final credentials = (await env.repository.credentialsFor(id))
          .valueOrNull!;
      expect(credentials.advertisedEpgUrls, ['http://epg.test/guide.xml']);
      expect((await env.db.sourcesDao.byId(id))!.credentialRef, 'source.$id');
    });
  });

  test('cancel stops the run and leaves a consistent catalogue', () async {
    final env = await _Env.open();
    final lines = StringBuffer('#EXTM3U\n');
    for (var i = 0; i < 20000; i++) {
      lines
        ..writeln('#EXTINF:-1 group-title="G${i % 40}",Channel $i')
        ..writeln('http://tv.test/live/$i.ts');
    }
    final id = await env.add(_file(env.playlist('big.m3u', '$lines')));
    final writing = Completer<void>();
    final watching = env.engine.watch(id).listen((status) {
      if (status case SyncRunning(:final progress)
          when progress.channels > 0 && !writing.isCompleted) {
        writing.complete();
      }
    });

    final result = env.engine.sync(id);
    await writing.future;
    await env.engine.cancel(id);
    await watching.cancel();

    expect((await result).failureOrNull, isA<CancelledFailure>());
    expect(env.engine.statusOf(id), isA<SyncCancelled>());
    final run = await env.latestRun(id);
    expect(run.outcome, SyncOutcome.cancelled);
    final written = await env.db.channelsDao.countFor(id);
    expect(written, lessThan(20000));
    // Whole batches only.
    expect(written % 50, 0);
    await _checkSearchIndexes(env.db);

    // And the next sync picks up cleanly.
    expect((await env.engine.sync(id)).valueOrNull!.channels, 20000);
    expect(await env.db.channelsDao.countFor(id), 20000);
  });

  test('one sync per source: asking again joins the run', () async {
    final env = await _Env.open();
    final id = await env.add(_file(env.playlist('list.m3u', _playlistV1)));

    final first = env.engine.sync(id);
    final second = env.engine.sync(id);

    expect(identical(first, second), isTrue);
    await first;
    expect(await _count(env.db, 'sync_runs'), 1);
  });

  test('startUp fails interrupted runs, then syncs only stale '
      'sources', () async {
    final now = DateTime.utc(2026, 9, 18, 12);
    final env = await _Env.open(clock: () => now);
    final stale = await env.add(_file(env.playlist('a.m3u', _playlistV1)));
    final fresh = await env.add(_file(env.playlist('b.m3u', _playlistV1)));
    final old = await env.add(_file(env.playlist('c.m3u', _playlistV1)));
    await env.db.sourcesDao.markSynced(
      fresh,
      now.subtract(const Duration(hours: 1)),
    );
    await env.db.sourcesDao.markSynced(
      old,
      now.subtract(const Duration(hours: 13)),
    );
    // A run the last session never finished.
    final interrupted = await env.db.syncRunsDao.start(
      fresh,
      now.subtract(const Duration(hours: 2)),
    );

    await env.engine.startUp();

    final dead = await (env.db.select(
      env.db.syncRuns,
    )..where((t) => t.id.equals(interrupted))).getSingle();
    expect(dead.outcome, SyncOutcome.failed);
    expect(dead.failure, syncInterruptedFailure);
    expect((await env.db.sourcesDao.byId(stale))!.lastSyncedAt, now);
    expect((await env.db.sourcesDao.byId(old))!.lastSyncedAt, now);
    expect(
      (await env.db.sourcesDao.byId(fresh))!.lastSyncedAt,
      now.subtract(const Duration(hours: 1)),
    );
    expect(await env.db.channelsDao.countFor(fresh), 0);
  });

  test('an unknown source is not found, and records no run', () async {
    final env = await _Env.open();

    final result = await env.engine.sync('nope');

    expect(result.failureOrNull, isA<NotFoundFailure>());
    expect(await _count(env.db, 'sync_runs'), 0);
  });
}
