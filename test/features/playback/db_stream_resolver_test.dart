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
}
