import 'dart:async';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:iptv_player/core/cast/cast_plan.dart';
import 'package:iptv_player/features/casting/domain/casting_state.dart';
import 'package:iptv_player/features/playback/domain/playable.dart';
import 'package:iptv_player/features/vod/domain/titles.dart';

import '../../data/cast/relay/relay_rig.dart';
import 'support/cast_e2e_rig.dart';

/// The fake panel's movie [id] (100000 is the MP4 sample, 100001 the
/// H.264 + AC-3 Matroska one), as the screens hold it.
MovieItem panelMovie(int id, String ext) => MovieItem(
  id: id,
  sourceId: 'panel',
  remoteKey: '$id',
  name: 'Movie $id',
  ext: ext,
  runtime: const Duration(minutes: 10),
);

/// Phase 7 step 6, decision 1: movies cast through the app — a file the
/// TV can't play as it is goes through the relay, a seek starts it again
/// there, and its place is saved like local playback.
void main() {
  setUpAll(() => HttpOverrides.global = null);

  late CastE2E rig;

  tearDown(() => rig.close());

  test(
    'a Matroska movie from its place, a seek, Stop casting: its place kept',
    () async {
      rig = await CastE2E.start();
      await rig.coordinator.connect(rig.device);
      await rig.phase(CastPhase.idle);
      unawaited(
        rig.playback.playVod(
          PlayableMovie(panelMovie(100001, 'mkv')),
          from: const Duration(minutes: 1),
        ),
      );
      await rig.tvPlaying(checks: 1);
      await rig.phase(CastPhase.playing);
      final plan = rig.state.plan!;
      expect(plan.delivery, CastDelivery.relayContinuous);
      expect(plan.audio, isA<CastAudioToAac>());
      expect(rig.tv.checks.last.audioCodec, 'aac');
      expect(
        rig.coordinator.timeline.position,
        greaterThanOrEqualTo(const Duration(minutes: 1)),
      );
      expect(rig.coordinator.timeline.duration, isNotNull);

      final first = rig.tv.loaded!['contentId'];
      await rig.playback.seek(const Duration(minutes: 5));
      await until(
        // Between FINISHED and the new LOAD the TV holds no media.
        () => (rig.tv.loaded?['contentId'] ?? first) != first,
        what: 'the LOAD after the seek',
      );
      final checked = rig.tv.checks.length;
      await rig.tvPlaying(after: checked, checks: 1);
      await rig.phase(CastPhase.playing);
      expect(
        rig.coordinator.timeline.position,
        greaterThanOrEqualTo(const Duration(minutes: 5)),
      );

      await rig.coordinator.disconnect();
      expect(
        rig.progress.lastPosition,
        greaterThanOrEqualTo(const Duration(minutes: 5)),
      );
      await until(() => rig.running.isEmpty, what: 'no FFmpeg left');
    },
    skip:
        relaySkip(const []) ??
        (File('${samples.path}/vod_h264_ac3_10min.mkv').existsSync()
            ? null
            : 'no vod_h264_ac3_10min.mkv sample'),
    timeout: const Timeout(Duration(minutes: 2)),
  );

  test(
    "a relayed movie paused for longer than the relay's quiet rule: the "
    "TV's buffer holds it back, and it plays on (backpressure, not a "
    'stall)',
    () async {
      rig = await CastE2E.start();
      await rig.coordinator.connect(rig.device);
      await rig.phase(CastPhase.idle);
      unawaited(rig.playback.playVod(PlayableMovie(panelMovie(100001, 'mkv'))));
      await rig.tvPlaying(checks: 1);
      await rig.phase(CastPhase.playing);
      expect(rig.state.plan!.delivery, CastDelivery.relayContinuous);
      final loads = rig.tv.requests('LOAD').length;

      // FFmpeg copies the file far faster than it plays: the TV's buffer
      // fills, then the paused TV reads nothing at all.
      await rig.playback.setPaused(paused: true);
      await until(() => rig.tv.playerState == 'PAUSED', what: 'paused');
      await Future<void>.delayed(const Duration(seconds: 14));
      // FFmpeg waits on the TV, blocked: not stopped as a quiet one,
      // which would leave the TV the end of what it holds.
      expect(rig.running, hasLength(1));
      expect(rig.logLines.where((l) => l.contains('Broken pipe')), isEmpty);
      await rig.playback.setPaused(paused: false);
      await until(() => rig.tv.playerState == 'PLAYING', what: 'playing');
      await Future<void>.delayed(const Duration(seconds: 2));

      expect(rig.state.phase, CastPhase.playing);
      expect(rig.state.problem, isNull);
      expect(rig.tv.requests('LOAD'), hasLength(loads), reason: 'no new LOAD');
      expect(rig.running, hasLength(1));
      expect(
        rig.logLines.where((l) => l.contains('the stream to the TV ended')),
        isEmpty,
      );

      // Stop casting while the TV's buffer is full: at once all the same.
      final stopping = Stopwatch()..start();
      await rig.coordinator.disconnect();
      expect(stopping.elapsed, lessThan(const Duration(seconds: 2)));
      await until(() => rig.running.isEmpty, what: 'no FFmpeg left');
    },
    skip:
        relaySkip(const []) ??
        (File('${samples.path}/vod_h264_ac3_10min.mkv').existsSync()
            ? null
            : 'no vod_h264_ac3_10min.mkv sample'),
    timeout: const Timeout(Duration(minutes: 2)),
  );

  test(
    "an MP4 straight to the TV, which can't read it: the relay from then "
    'on',
    () async {
      rig = await CastE2E.start();
      final plans = rig.plans;
      await rig.coordinator.connect(rig.device);
      await rig.phase(CastPhase.idle);
      unawaited(rig.playback.playVod(PlayableMovie(panelMovie(100000, 'mp4'))));
      // The panel sends no CORS headers: the TV drops its answer.
      await rig.tvPlaying(checks: 1);
      expect(
        [for (final plan in plans) plan.delivery],
        [CastDelivery.directFile, CastDelivery.relayContinuous],
      );
      expect(rig.devices.devices['fake-tv']!.learned.directRefusedSources, {
        'panel',
      });
      // The TV was handed the provider's URL, credentials and all: never
      // in the log (hard rule 3).
      expect(rig.logLines.where((l) => l.contains('/test/test/')), isEmpty);
    },
    skip:
        relaySkip(const []) ??
        (File('${samples.path}/vod_h264_aac_10min.mp4').existsSync()
            ? null
            : 'no vod_h264_aac_10min.mp4 sample'),
    timeout: const Timeout(Duration(minutes: 2)),
  );
}
