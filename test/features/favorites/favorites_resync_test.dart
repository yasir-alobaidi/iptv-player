import 'dart:io';

import 'package:fake_provider/profile.dart';
import 'package:fake_provider/server.dart';
import 'package:fake_provider/server_state.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:iptv_player/core/logging/app_log.dart';
import 'package:iptv_player/core/logging/secret_registry.dart';
import 'package:iptv_player/core/secure/credential_store.dart';
import 'package:iptv_player/data/db/app_database.dart';
import 'package:iptv_player/data/sync/sync_engine.dart';
import 'package:iptv_player/features/favorites/data/db_favorites_repository.dart';
import 'package:iptv_player/features/live_tv/data/db_channel_repository.dart';
import 'package:iptv_player/features/live_tv/domain/channels.dart';
import 'package:iptv_player/features/sources/data/db_source_repository.dart';
import 'package:iptv_player/features/sources/domain/source.dart';
import 'package:logger/logger.dart';

/// Phase 6 exit criterion 2: the favorites' order and groups survive the
/// app closing and opening again, and a re-sync from the panel that gives
/// every channel a new row id — they are keyed by the provider's key.
void main() {
  setUpAll(() => HttpOverrides.global = null);

  test('order and groups survive a restart and a re-sync that renumbers '
      'every channel', () async {
    final runDir = await Directory.systemTemp.createTemp('fav_panel');
    addTearDown(() => runDir.delete(recursive: true));
    final server = await FakeProviderServer.start(
      state: FakeServerState(
        profile: fakeProfiles['default']!,
        samplesDir: runDir.path,
        ffmpegPath: 'ffmpeg',
        runDir: runDir.path,
      ),
      port: 0,
    );
    addTearDown(server.close);
    final directory = await Directory.systemTemp.createTemp('fav_db');
    addTearDown(() => directory.delete(recursive: true));
    final store = InMemoryCredentialStore();
    final log = AppLog(output: MemoryOutput(), secrets: SecretRegistry());
    addTearDown(log.close);

    Future<(AppDatabase, SyncEngine, DbSourceRepository)> open() async {
      final db = AppDatabase(await openAppDatabase(directory));
      final sources = DbSourceRepository(
        database: db,
        store: store,
        secrets: SecretRegistry(),
        log: log,
      );
      return (
        db,
        SyncEngine(database: db, sources: sources, log: log),
        sources,
      );
    }

    var (db, sync, sources) = await open();
    final id = (await sources.add(
      SourceDraft(
        type: SourceType.xtream,
        name: 'Panel',
        url: '${server.url}',
        username: 'test',
        password: 'test',
      ),
    )).valueOrNull!.id;
    expect((await sync.sync(id)).isOk, isTrue);

    var channels = DbChannelRepository(db);
    var favorites = DbFavoritesRepository(db);
    final first = (await channels.range(
      ChannelQuery(sourceId: id),
      0,
      6,
    )).valueOrNull!;
    for (final channel in first.take(5)) {
      await channels.setFavorite(channel, on: true);
    }
    final sports = (await favorites.createGroup(id, 'Sports')).valueOrNull!;
    final news = (await favorites.createGroup(id, 'News')).valueOrNull!;
    await favorites.moveChannel(first[3], groupId: sports, index: 0);
    await favorites.moveChannel(first[1], groupId: sports, index: 0);
    await favorites.moveChannel(first[4], groupId: news, index: 0);
    await favorites.moveGroup(news, 0);
    await favorites.moveChannel(first[2], groupId: null, index: 0);

    Future<List<String>> order(ChannelFilter filter) async => [
      for (final c in (await channels.range(
        ChannelQuery(sourceId: id, filter: filter),
        0,
        50,
      )).valueOrNull!)
        c.remoteKey,
    ];
    Future<List<String>> groupNames() async => [
      for (final g in await favorites.watchGroups(id).first) g.name,
    ];
    final expected = [
      first[4].remoteKey,
      first[1].remoteKey,
      first[3].remoteKey,
      first[2].remoteKey,
      first[0].remoteKey,
    ];
    expect(await order(const FavoriteChannels()), expected);
    expect(await groupNames(), ['News', 'Sports']);

    // The app closes and opens again on the same file.
    await sync.dispose();
    await db.close();
    (db, sync, sources) = await open();
    channels = DbChannelRepository(db);
    favorites = DbFavoritesRepository(db);
    expect(await order(const FavoriteChannels()), expected);
    expect(await order(FavoriteGroupChannels(sports)), [
      first[1].remoteKey,
      first[3].remoteKey,
    ]);

    // A re-sync that renumbers every row: the channels go, and come back
    // with new ids.
    await db.customStatement('DELETE FROM channels WHERE source_id = ?', [id]);
    expect((await sync.sync(id)).isOk, isTrue);
    final again = (await channels.range(
      ChannelQuery(sourceId: id),
      0,
      6,
    )).valueOrNull!;
    expect(again.first.remoteKey, first.first.remoteKey);
    expect(again.first.id, isNot(first.first.id), reason: 'renumbered');
    expect(await order(const FavoriteChannels()), expected);
    expect(await order(FavoriteGroupChannels(news)), [first[4].remoteKey]);
    expect(await groupNames(), ['News', 'Sports']);

    await sync.dispose();
    await db.close();
  });
}
