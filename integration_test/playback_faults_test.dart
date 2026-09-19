// The fault suite (Phase 3 step 8): the real player (media_kit, our
// patched media_kit_video) and the real coordinator, resolver and prober,
// against the fake provider's stream faults (docs/06). Each fault either
// recovers (the picture comes back) or ends in the right failure, with
// the server's answer where there was one.
//
// Needs the media samples (h264_1080p50_aac and hevc_1080p50_aac; CI
// generates them). IPTV_PLAYER_VIDEO=0 runs mpv with no video output.

import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:iptv_player/core/logging/app_log.dart';
import 'package:iptv_player/core/logging/secret_registry.dart';
import 'package:iptv_player/core/player/player_engine.dart';
import 'package:iptv_player/core/secure/credential_store.dart';
import 'package:iptv_player/data/db/app_database.dart';
import 'package:iptv_player/data/player_mediakit/media_kit_player_engine.dart';
import 'package:iptv_player/features/live_tv/data/db_channel_repository.dart';
import 'package:iptv_player/features/playback/data/db_playback_history.dart';
import 'package:iptv_player/features/playback/data/db_stream_resolver.dart';
import 'package:iptv_player/features/playback/data/http_stream_prober.dart';
import 'package:iptv_player/features/playback/domain/playback.dart';
import 'package:iptv_player/features/playback/domain/playback_coordinator.dart';
import 'package:iptv_player/features/playback/domain/playback_state.dart';
import 'package:iptv_player/features/sources/data/db_source_repository.dart';
import 'package:iptv_player/features/sources/domain/source.dart';

import 'support/fake_panel.dart';
import 'support/keyboard.dart';

void main() {
  final binding = IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  final video = Platform.environment['IPTV_PLAYER_VIDEO'] != '0';

  testWidgets(
    'every stream fault recovers or explains itself',
    (tester) async {
      HttpOverrides.global = null;
      binding.framePolicy = LiveTestWidgetsFlutterBindingFramePolicy.fullyLive;
      final rig = (await tester.runAsync(() => _Rig.open(video: video)))!;
      addTearDown(() => tester.runAsync(rig.close));
      await tester.pumpWidget(
        MaterialApp(
          home: rig.engine.videoView(background: const Color(0xFF000000)),
        ),
      );
      final report = <String>[];

      Future<void> fault(
        String name,
        Map<String, Object?> faults,
        Future<void> Function() check,
      ) async {
        await tester.runAsync(() async {
          await rig.coordinator.stop();
          await rig.panel.setFaults(faults);
        });
        final watch = Stopwatch()..start();
        await check();
        report.add('$name: ${watch.elapsed.inMilliseconds} ms');
      }

      Future<void> until(
        bool Function(PlaybackState s) done,
        String what, {
        int seconds = 45,
      }) => _until(
        tester,
        () => done(rig.coordinator.state),
        '$what (state ${rig.coordinator.state})',
        seconds: seconds,
      );

      bool playing(PlaybackState s) => s is PlaybackPlaying;

      // ── A clean start, for reference.
      await fault('clean', const {}, () async {
        await tester.runAsync(() => rig.play(1));
        await until(playing, 'a picture');
      });

      // ── Drop: the body ends after 3 s; the watchdog reconnects and the
      // picture comes back (it will drop again: the fault stays on).
      await fault('drop', const {'drop_after_s': 3}, () async {
        await tester.runAsync(() => rig.play(1));
        await until(playing, 'a picture');
        await until(
          (s) => s is PlaybackReconnecting,
          'the drop to be noticed',
          seconds: 20,
        );
        await until(playing, 'the picture back after the drop');
      });

      // ── Stall: the media stops but the connection stays open; the
      // stall watchdog (or mpv's own timeout) reconnects.
      await fault('stall', const {'stall_after_s': 3}, () async {
        await tester.runAsync(() => rig.play(1));
        await until(playing, 'a picture');
        await until(
          (s) => s is PlaybackReconnecting,
          'the stall to be noticed',
          seconds: 40,
        );
        await tester.runAsync(() => rig.panel.setFaults(const {}));
        await until(playing, 'the picture back after the stall');
      });

      // ── Slow start: 4 s before the server answers; no failure.
      await fault('slow start', const {'slow_start_ms': 4000}, () async {
        await tester.runAsync(() => rig.play(1));
        await until(playing, 'a picture after a slow start');
        expect(
          rig.states.whereType<PlaybackReconnecting>(),
          isEmpty,
          reason: 'a slow start is not a failure',
        );
      });

      // ── 401: the account is refused; no retries.
      await fault('401', const {'http_status': 401}, () async {
        await tester.runAsync(() => rig.play(1));
        await until((s) => s is PlaybackFailed, 'the refusal');
        final failed = rig.coordinator.state as PlaybackFailed;
        expect(failed.problem.kind, PlaybackProblemKind.auth);
        expect(failed.attempts, 0);
        expect(failed.problem.failure?.statusCode, 401);
      });

      // ── 404: the channel is off the air; no retries.
      await fault('404', const {'http_status': 404}, () async {
        await tester.runAsync(() => rig.play(1));
        await until((s) => s is PlaybackFailed, 'the 404');
        final failed = rig.coordinator.state as PlaybackFailed;
        expect(failed.problem.kind, PlaybackProblemKind.offline);
        expect(failed.problem.failure?.statusCode, 404);
      });

      // ── Connection limit: a full account, tried 3 times, explained.
      await fault('connection limit', const {'max_connections': 0}, () async {
        await tester.runAsync(() => rig.play(1));
        await until(
          (s) => s is PlaybackFailed,
          'the limit to be explained',
          seconds: 60,
        );
        final failed = rig.coordinator.state as PlaybackFailed;
        expect(failed.problem.kind, PlaybackProblemKind.connectionLimit);
        expect(failed.attempts, 3);
      });

      // ── 500: retried; once the server recovers, so does the picture.
      await fault('500 then recovery', const {'http_status': 500}, () async {
        await tester.runAsync(() => rig.play(1));
        await until((s) => s is PlaybackReconnecting, 'a retry');
        final retrying = rig.coordinator.state as PlaybackReconnecting;
        expect(retrying.problem.kind, PlaybackProblemKind.server);
        await tester.runAsync(() => rig.panel.setFaults(const {}));
        await until(playing, 'the picture once the server recovers');
      });

      // ── An expiring redirect: the token dies after 10 s and the stream
      // drops at 12 s; the reconnect builds the URL from the source again
      // (a fresh redirect), never from the dead token.
      await fault(
        'expiring redirect',
        const {'redirect_with_expiring_token': true, 'drop_after_s': 12},
        () async {
          await tester.runAsync(() => rig.play(1));
          await until(playing, 'a picture through the redirect');
          await until(
            (s) => s is PlaybackReconnecting,
            'the drop after the token expired',
            seconds: 30,
          );
          await until(playing, 'the picture back with a fresh token');
        },
      );

      // ── Codec switch: H.264 turns into HEVC mid-stream; the picture
      // carries on.
      await fault('codec switch', const {'codec_switch_after_s': 3}, () async {
        await tester.runAsync(() => rig.play(1));
        await until(playing, 'a picture');
        await tester.runAsync(
          () => Future<void>.delayed(const Duration(seconds: 10)),
        );
        await tester.pump();
        expect(
          rig.coordinator.state,
          isA<PlaybackPlaying>(),
          reason: 'still playing after the switch',
        );
      });

      await tester.runAsync(rig.coordinator.stop);
      // The report is this test's output.
      // ignore: avoid_print
      print('faults (video ${video ? 'on' : 'off'}): ${report.join(' · ')}');
    },
    skip: !streamsAvailable,
    timeout: const Timeout(Duration(minutes: 10)),
  );
}

/// The real playback stack on a throwaway database, pointed at the fake
/// panel as an Xtream source.
final class _Rig {
  new _(
    this.panel,
    this.db,
    this.engine,
    this.coordinator,
    this.channels,
    this.sourceId,
  );

  static Future<_Rig> open({required bool video}) async {
    final panel = await FakePanel.start(streams: true);
    final db = AppDatabase.memory();
    final secrets = SecretRegistry();
    final log = AppLog(output: SilentOutput(), secrets: secrets);
    final sources = DbSourceRepository(
      database: db,
      store: InMemoryCredentialStore(),
      secrets: secrets,
      log: log,
    );
    final source = (await sources.add(
      SourceDraft(
        type: SourceType.xtream,
        name: 'Fake',
        url: panel.url,
        username: 'test',
        password: 'test',
        maxConnectionsOverride: 2,
      ),
    )).valueOrNull!;
    await db.channelsDao.upsertAll([
      ChannelsCompanion.insert(
        sourceId: source.id,
        remoteKey: '1',
        name: 'Channel 1',
      ),
    ]);
    final engine = await MediaKitPlayerEngine.create(
      log: log,
      secrets: secrets,
      video: video,
    );
    final channels = DbChannelRepository(db);
    final coordinator = PlaybackCoordinator(
      engine: engine,
      resolver: DbStreamResolver(db, sources),
      prober: HttpStreamProber(sources),
      history: DbPlaybackHistory(db),
      channels: channels,
      log: log,
      // Quick to start, so a stall shows within seconds.
      settings: () => const PlaybackSettings(preset: BufferPreset.lowLatency),
    );
    return _Rig._(panel, db, engine, coordinator, channels, source.id);
  }

  final FakePanel panel;
  final AppDatabase db;
  final MediaKitPlayerEngine engine;
  final PlaybackCoordinator coordinator;
  final DbChannelRepository channels;
  final String sourceId;
  final List<PlaybackState> states = [];
  StreamSubscription<PlaybackState>? _watch;

  Future<void> play(int id) async {
    states.clear();
    await _watch?.cancel();
    _watch = coordinator.states.listen(states.add);
    final channel = (await channels.byRemoteKey(sourceId, '$id')).valueOrNull!;
    await coordinator.playLive(channel);
  }

  Future<void> close() async {
    await _watch?.cancel();
    await coordinator.dispose();
    await engine.dispose();
    await db.close();
    await panel.stop();
  }
}

Future<void> _until(
  WidgetTester tester,
  bool Function() done,
  String what, {
  int seconds = 45,
}) async {
  final deadline = DateTime.now().add(Duration(seconds: seconds));
  while (DateTime.now().isBefore(deadline)) {
    if (done()) return;
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 100)),
    );
    await tester.pump();
  }
  fail('Timed out waiting for $what');
}
