import 'dart:async';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:iptv_player/core/cast/cast_plan.dart';
import 'package:iptv_player/core/player/player_engine.dart';
import 'package:iptv_player/features/casting/domain/casting_state.dart';

import '../../data/cast/relay/relay_rig.dart';
import 'support/cast_e2e_rig.dart';

/// Phase 7 step 6: live channels cast through the app — the coordinators,
/// the relay with FFmpeg, the fake panel, and a fake TV that fetches and
/// checks what it plays.
void main() {
  setUpAll(() => HttpOverrides.global = null);

  late CastE2E rig;

  tearDown(() => rig.close());

  /// The most streams the panel had open at once, from now on.
  int Function() mostOpen(CastE2E rig) {
    var most = rig.panel.state.activeStreams;
    final watch = Timer.periodic(const Duration(milliseconds: 20), (_) {
      final now = rig.panel.state.activeStreams;
      if (now > most) most = now;
    });
    addTearDown(watch.cancel);
    return () => most;
  }

  test(
    'a channel, a zap, Stop casting: on one connection, with the picture, '
    'nothing left behind',
    () async {
      rig = await CastE2E.start();
      final most = mostOpen(rig);
      await rig.coordinator.connect(rig.device);
      await rig.phase(CastPhase.idle);
      final logo = '${rig.panel.url}/art/live/1.png';
      unawaited(
        rig.playback.playLive(
          panelChannel(channelOf['h264_1080p50_aac']!, logoUrl: logo),
        ),
      );
      await rig.tvPlaying();
      await rig.phase(CastPhase.playing);
      expect(rig.state.plan!.delivery, CastDelivery.relayHls);
      expect(rig.tv.checks.last.videoCodec, 'h264');
      expect(rig.tv.checks.last.audioCodec, 'aac');
      // The picture: the app's cached copy, from the relay.
      final metadata = rig.tv.loaded!['metadata']! as Map;
      final images = metadata['images']! as List;
      final picture = (images.single as Map)['url']! as String;
      expect(picture, startsWith('http://127.0.0.1:384'));
      final answer = await (await HttpClient().getUrl(Uri.parse(picture)))
          .close();
      expect(answer.statusCode, 200);
      expect(answer.headers.contentType?.primaryType, 'image');
      await answer.drain<void>();

      unawaited(
        rig.playback.playLive(panelChannel(channelOf['h264_1080p25_ac3']!)),
      );
      await until(
        () => rig.state.plan?.audio is CastAudioToAac,
        what: "the second channel's plan",
      );
      final checked = rig.tv.checks.length;
      await rig.tvPlaying(after: checked);
      await rig.phase(CastPhase.playing);
      expect(rig.tv.checks.last.audioCodec, 'aac', reason: 'AC-3 converted');
      expect(most(), 1, reason: 'a one-connection panel');

      await rig.coordinator.disconnect();
      expect(rig.tv.app, isNull, reason: 'the TV went home');
      await until(() => rig.running.isEmpty, what: 'no FFmpeg left');
      expect(rig.sessionFolders, isEmpty);
      await until(() => rig.panel.state.activeStreams == 0);
    },
    skip: relaySkip(['h264_1080p50_aac', 'h264_1080p25_ac3']),
    timeout: const Timeout(Duration(minutes: 2)),
  );

  test(
    "Cast while watching: the laptop's facts, no probe",
    () async {
      rig = await CastE2E.start();
      final channel = panelChannel(channelOf['h264_1080p50_aac']!);
      await rig.playback.playLive(channel);
      rig.engine
        ..info = const StreamInfo(
          videoCodec: 'h264',
          width: 1920,
          height: 1080,
          fps: 50,
          audioCodec: 'aac',
          audioChannels: 2,
        )
        ..firstFrame();
      await rig.coordinator.connect(rig.device);
      await rig.tvPlaying();
      expect(rig.engine.calls, contains('stop'));
      expect(
        rig.logLines.where((l) => l.contains('Facts from the player')),
        hasLength(1),
      );
      expect(rig.logLines.where((l) => l.contains('ffprobe')), isEmpty);
    },
    skip: relaySkip(['h264_1080p50_aac']),
    timeout: const Timeout(Duration(minutes: 2)),
  );

  test(
    "the provider's own HLS straight to the TV, which can't read it: the "
    'relay from then on',
    () async {
      rig = await CastE2E.start();
      rig.resolver.hls = true;
      final plans = rig.plans;
      await rig.coordinator.connect(rig.device);
      await rig.phase(CastPhase.idle);
      unawaited(
        rig.playback.playLive(panelChannel(channelOf['h264_1080p50_aac']!)),
      );
      // The panel sends no CORS headers, so the TV drops its answers and
      // gives up: an error soon after the LOAD.
      await rig.tvPlaying();
      expect(
        [for (final plan in plans) plan.delivery],
        [CastDelivery.directHls, CastDelivery.relayHls],
      );
      expect(rig.devices.devices['fake-tv']!.learned.directRefusedSources, {
        'panel',
      });
      // The TV was handed the provider's URL, credentials and all: never
      // in the log (hard rule 3).
      expect(rig.logLines.where((l) => l.contains('/test/test/')), isEmpty);
    },
    skip: relaySkip(['h264_1080p50_aac']),
    timeout: const Timeout(Duration(minutes: 2)),
  );
}
