import 'dart:convert';

import 'package:drift/drift.dart' hide isNull;
import 'package:flutter_test/flutter_test.dart';
import 'package:iptv_player/core/logging/app_log.dart';
import 'package:iptv_player/core/logging/secret_registry.dart';
import 'package:iptv_player/core/secure/credential_store.dart';
import 'package:iptv_player/data/db/app_database.dart';
import 'package:iptv_player/features/live_tv/domain/channels.dart';
import 'package:iptv_player/features/playback/data/db_stream_resolver.dart';
import 'package:iptv_player/features/sources/data/db_source_repository.dart';
import 'package:iptv_player/features/sources/domain/source.dart';
import 'package:iptv_player/features/vod/domain/titles.dart';
import 'package:logger/logger.dart';

void main() {
  late AppDatabase db;
  late DbSourceRepository sources;
  late DbStreamResolver resolver;

  setUp(() {
    db = AppDatabase.memory();
    final secrets = SecretRegistry();
    sources = DbSourceRepository(
      database: db,
      store: InMemoryCredentialStore(),
      secrets: secrets,
      log: AppLog(output: MemoryOutput(), secrets: secrets),
    );
    resolver = DbStreamResolver(db, sources);
  });
  tearDown(() => db.close());

  Future<Source> add(SourceDraft draft) async =>
      (await sources.add(draft)).valueOrNull!;

  Future<void> channel(
    String sourceId,
    String key, {
    String? streamUrl,
    String? extras,
  }) => db.channelsDao.upsertAll([
    ChannelsCompanion.insert(
      sourceId: sourceId,
      remoteKey: key,
      name: 'Channel $key',
      streamUrl: Value(streamUrl),
      extrasJson: Value(extras),
    ),
  ]);

  ChannelItem item(String sourceId, String key) =>
      ChannelItem(id: 1, sourceId: sourceId, remoteKey: key, name: 'c');

  test('Xtream: the URL from the stored credentials, TS or HLS', () async {
    final source = await add(
      const SourceDraft(
        type: SourceType.xtream,
        name: 'N',
        url: 'http://line.test:8080',
        username: 'viewer',
        password: 'secret',
      ),
    );
    await channel(source.id, '201');

    final ts = (await resolver.live(item(source.id, '201'))).valueOrNull!;
    expect(ts.url, 'http://line.test:8080/live/viewer/secret/201.ts');
    expect(ts.hls, isFalse);
    expect(ts.userAgent, 'VLC/3.0.20 LibVLC/3.0.20');
    // No account stored yet: assume the strictest limit.
    expect(ts.maxConnections, 1);
    expect('$ts', isNot(contains('secret')));

    await sources.update(
      source.id,
      const SourceDraft(
        type: SourceType.xtream,
        name: 'N',
        url: 'http://line.test:8080',
        username: 'viewer',
        liveFormat: LiveFormat.hls,
      ),
    );
    final hls = (await resolver.live(item(source.id, '201'))).valueOrNull!;
    expect(hls.url, endsWith('/201.m3u8'));
    expect(hls.hls, isTrue);
  });

  test('the connection limit: the override, else the account', () async {
    final source = await add(
      const SourceDraft(
        type: SourceType.xtream,
        name: 'N',
        url: 'http://line.test',
        username: 'u',
        password: 'pw',
      ),
    );
    await channel(source.id, '1');
    await db.sourcesDao.saveAccount(
      source.id,
      accountJson: jsonEncode({'max_connections': 3}),
      expiresAt: null,
    );
    expect(
      (await resolver.live(item(source.id, '1'))).valueOrNull!.maxConnections,
      3,
    );

    await sources.update(
      source.id,
      const SourceDraft(
        type: SourceType.xtream,
        name: 'N',
        url: 'http://line.test',
        username: 'u',
        maxConnectionsOverride: 2,
      ),
    );
    expect(
      (await resolver.live(item(source.id, '1'))).valueOrNull!.maxConnections,
      2,
    );
  });

  test('M3U: the line template filled from the playlist URL, with the '
      "line's own User-Agent", () async {
    final source = await add(
      const SourceDraft(
        type: SourceType.m3uUrl,
        name: 'P',
        url: 'http://p.test/get.php?username=ann&password=hunter22',
      ),
    );
    await channel(
      source.id,
      'abc',
      streamUrl: 'http://p.test/live/{username}/{password}/5.m3u8',
      extras: jsonEncode({'user_agent': 'Box/2'}),
    );

    final stream = (await resolver.live(item(source.id, 'abc'))).valueOrNull!;

    expect(stream.url, 'http://p.test/live/ann/hunter22/5.m3u8');
    expect(stream.hls, isTrue);
    expect(stream.userAgent, 'Box/2');
  });

  test('a channel with no stream URL and a missing source are failures, '
      'not throws', () async {
    final source = await add(
      const SourceDraft(type: SourceType.m3uFile, name: 'F', url: '/x.m3u'),
    );
    await channel(source.id, 'k');

    expect((await resolver.live(item(source.id, 'k'))).isOk, isFalse);
    expect((await resolver.live(item('gone', 'k'))).isOk, isFalse);
  });

  group('movies and episodes', () {
    MovieItem movie(String sourceId, String key, {String? ext}) => MovieItem(
      id: 1,
      sourceId: sourceId,
      remoteKey: key,
      name: 'm',
      ext: ext,
    );

    EpisodeItem episode(String sourceId, String key, {String? ext}) =>
        EpisodeItem(
          id: 1,
          sourceId: sourceId,
          seriesKey: 's9',
          remoteKey: key,
          season: 1,
          episode: 1,
          title: 'e',
          ext: ext,
        );

    Future<void> seriesWithEpisode(
      String sourceId,
      String key, {
      String? streamUrl,
    }) async {
      await db.seriesDao.upsertAll([
        SeriesCompanion.insert(sourceId: sourceId, remoteKey: 's9', name: 'S'),
      ]);
      final row = (await db.seriesDao.byRemoteKey(sourceId, 's9'))!;
      await db.seriesDao.upsertEpisodes([
        EpisodesCompanion.insert(
          seriesId: row.id,
          remoteKey: key,
          season: 1,
          episode: 1,
          title: 'e',
          streamUrl: Value(streamUrl),
        ),
      ]);
    }

    test(
      "Xtream: /movie/ and /series/ with the item's own extension",
      () async {
        final source = await add(
          const SourceDraft(
            type: SourceType.xtream,
            name: 'N',
            url: 'http://line.test:8080/base',
            username: 'viewer',
            password: 'secret',
          ),
        );

        final film = (await resolver.movie(movie(source.id, '501', ext: 'MKV')))
            .valueOrNull!;
        expect(
          film.url,
          'http://line.test:8080/base/movie/viewer/secret/501.mkv',
        );
        expect(film.hls, isFalse);
        expect(film.userAgent, 'VLC/3.0.20 LibVLC/3.0.20');
        expect(film.maxConnections, 1);

        final show = (await resolver.episode(
          episode(source.id, '7201', ext: 'mp4'),
        )).valueOrNull!;
        expect(
          show.url,
          'http://line.test:8080/base/series/viewer/secret/7201.mp4',
        );

        // No extension from the panel: MP4, the likeliest.
        final bare = (await resolver.movie(movie(source.id, '502')))
            .valueOrNull!;
        expect(bare.url, endsWith('/502.mp4'));
      },
    );

    test("M3U: the line's template, filled in", () async {
      final source = await add(
        const SourceDraft(
          type: SourceType.m3uUrl,
          name: 'P',
          url: 'http://p.test/get.php?username=ann&password=hunter22',
        ),
      );
      await db.moviesDao.upsertAll([
        MoviesCompanion.insert(
          sourceId: source.id,
          remoteKey: 'film',
          name: 'Film',
          streamUrl: const Value(
            'http://p.test/movie/{username}/{password}/9.mkv',
          ),
        ),
      ]);
      await seriesWithEpisode(
        source.id,
        'ep',
        streamUrl: 'http://p.test/series/{username}/{password}/10.mp4',
      );

      expect(
        (await resolver.movie(movie(source.id, 'film'))).valueOrNull!.url,
        'http://p.test/movie/ann/hunter22/9.mkv',
      );
      expect(
        (await resolver.episode(episode(source.id, 'ep'))).valueOrNull!.url,
        'http://p.test/series/ann/hunter22/10.mp4',
      );
      // Gone from the playlist: a failure, not a throw.
      expect((await resolver.episode(episode(source.id, 'x'))).isOk, isFalse);
      expect((await resolver.movie(movie('gone', 'film'))).isOk, isFalse);
    });
  });
}
