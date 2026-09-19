import 'dart:io';

import 'package:fake_provider/profile.dart';
import 'package:fake_provider/server.dart';
import 'package:fake_provider/server_state.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:iptv_player/core/logging/app_log.dart';
import 'package:iptv_player/core/logging/secret_registry.dart';
import 'package:iptv_player/core/secure/credential_store.dart';
import 'package:iptv_player/data/db/app_database.dart';
import 'package:iptv_player/features/live_tv/domain/channels.dart';
import 'package:iptv_player/features/playback/data/http_stream_prober.dart';
import 'package:iptv_player/features/playback/domain/playback.dart';
import 'package:iptv_player/features/playback/domain/playback_state.dart';
import 'package:iptv_player/features/sources/data/db_source_repository.dart';
import 'package:iptv_player/features/sources/domain/source.dart';
import 'package:logger/logger.dart';

/// The prober against the fake panel's stream faults, over real HTTP:
/// each answer read into docs/03's error classes. No ffmpeg needed: every
/// case here is answered before a stream starts.
void main() {
  setUpAll(() => HttpOverrides.global = null);

  late FakeProviderServer server;
  late AppDatabase db;
  late DbSourceRepository sources;
  late HttpStreamProber prober;
  late String sourceId;

  setUp(() async {
    final runDir = await Directory.systemTemp.createTemp('prober');
    addTearDown(() => runDir.delete(recursive: true));
    server = await FakeProviderServer.start(
      state: FakeServerState(
        profile: fakeProfiles['default']!,
        samplesDir: runDir.path,
        ffmpegPath: 'ffmpeg',
        runDir: runDir.path,
      ),
      port: 0,
    );
    addTearDown(server.close);
    db = AppDatabase.memory();
    addTearDown(db.close);
    final secrets = SecretRegistry();
    sources = DbSourceRepository(
      database: db,
      store: InMemoryCredentialStore(),
      secrets: secrets,
      log: AppLog(output: MemoryOutput(), secrets: secrets),
    );
    sourceId = (await sources.add(
      SourceDraft(
        type: SourceType.xtream,
        name: 'Fake',
        url: '${server.url}',
        username: 'test',
        password: 'test',
      ),
    )).valueOrNull!.id;
    prober = HttpStreamProber(sources);
  });

  Future<PlaybackProblem> probe(String query, {String password = 'test'}) =>
      prober.diagnose(
        ChannelItem(id: 1, sourceId: sourceId, remoteKey: '1', name: 'c'),
        ResolvedStream(
          url: '${server.url}/live/test/$password/1.ts$query',
          maxConnections: 2,
        ),
        detail: 'Failed to open',
      );

  test('404 → offline, with the status for the UI', () async {
    final problem = await probe('?http_status=404');
    expect(problem.kind, PlaybackProblemKind.offline);
    expect(problem.failure?.statusCode, 404);
    expect(problem.detail, 'Failed to open');
  });

  test('429 and a full panel → the connection limit', () async {
    expect(
      (await probe('?http_status=429')).kind,
      PlaybackProblemKind.connectionLimit,
    );
    expect(
      (await probe('?max_connections=0')).kind,
      PlaybackProblemKind.connectionLimit,
    );
  });

  test('5xx → server (retried)', () async {
    final problem = await probe('?http_status=503');
    expect(problem.kind, PlaybackProblemKind.server);
    expect(problem.retryable, isTrue);
  });

  test(
    'a refused stream with a sign-in the panel refuses too → auth',
    () async {
      await sources.update(
        sourceId,
        SourceDraft(
          type: SourceType.xtream,
          name: 'Fake',
          url: '${server.url}',
          username: 'test',
          password: 'wrong',
        ),
      );
      final problem = await probe('', password: 'wrong');
      expect(problem.kind, PlaybackProblemKind.auth);
      expect(problem.failure?.statusCode, 401);
    },
  );

  test('nothing listening → network (retried)', () async {
    final problem = await prober.diagnose(
      ChannelItem(id: 1, sourceId: sourceId, remoteKey: '1', name: 'c'),
      const ResolvedStream(
        url: 'http://127.0.0.1:9/live/a/b/1.ts',
        maxConnections: 1,
      ),
    );
    expect(problem.kind, PlaybackProblemKind.network);
  });
}
