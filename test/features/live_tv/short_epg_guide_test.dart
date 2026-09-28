import 'dart:io';

import 'package:fake_provider/profile.dart';
import 'package:fake_provider/server.dart';
import 'package:fake_provider/server_state.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:iptv_player/core/logging/app_log.dart';
import 'package:iptv_player/core/logging/secret_registry.dart';
import 'package:iptv_player/core/secure/credential_store.dart';
import 'package:iptv_player/data/db/app_database.dart';
import 'package:iptv_player/features/live_tv/data/short_epg_guide.dart';
import 'package:iptv_player/features/live_tv/domain/channels.dart';
import 'package:iptv_player/features/sources/data/db_source_repository.dart';
import 'package:iptv_player/features/sources/domain/source.dart';
import 'package:logger/logger.dart';

void main() {
  setUpAll(() => HttpOverrides.global = null);

  late FakeProviderServer panel;
  late DbSourceRepository sources;
  late String sourceId;

  setUp(() async {
    final runDir = await Directory.systemTemp.createTemp('short_epg');
    addTearDown(() => runDir.delete(recursive: true));
    panel = await FakeProviderServer.start(
      state: FakeServerState(
        profile: fakeProfiles['default']!,
        samplesDir: runDir.path,
        ffmpegPath: 'ffmpeg',
        runDir: runDir.path,
      ),
      port: 0,
    );
    addTearDown(panel.close);
    final db = AppDatabase.memory();
    addTearDown(db.close);
    final secrets = SecretRegistry();
    final log = AppLog(output: MemoryOutput(), secrets: secrets);
    addTearDown(log.close);
    sources = DbSourceRepository(
      database: db,
      store: InMemoryCredentialStore(),
      secrets: secrets,
      log: log,
    );
    final added = await sources.add(
      SourceDraft(
        type: SourceType.xtream,
        name: 'Fake panel',
        url: '${panel.url}',
        username: 'test',
        password: 'test',
      ),
    );
    sourceId = added.valueOrNull!.id;
  });

  ChannelItem channel(String remoteKey) =>
      ChannelItem(id: 1, sourceId: sourceId, remoteKey: remoteKey, name: 'x');

  test(
    'the first answer arrives, and two asks at once share one request',
    () async {
      final guide = ShortEpgGuide(sources);

      // Before the fix the first answer never completed: the in-flight
      // future waited for itself.
      final [a, b] = await Future.wait([
        guide.nowNext(channel('1')),
        guide.nowNext(channel('1')),
      ]).timeout(const Duration(seconds: 10));

      expect(a.valueOrNull!.now, isNotNull);
      expect(b.valueOrNull, a.valueOrNull);
      expect(panel.state.apiCalls['get_short_epg'], 1);
      expect(guide.cached(channel('1')), a.valueOrNull);
    },
  );
}
