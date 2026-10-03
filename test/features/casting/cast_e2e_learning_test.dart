import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:fake_receiver/fake_receiver.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:iptv_player/core/cast/cast_plan.dart';
import 'package:iptv_player/features/casting/domain/casting_state.dart';

import '../../data/cast/relay/relay_rig.dart';
import 'support/cast_e2e_rig.dart';

/// Phase 7 step 6: what the TV refuses teaches the app, and what ends is
/// loaded again — through the app's coordinators, the relay with FFmpeg,
/// the fake panel and a fake TV with a device's limits.
void main() {
  setUpAll(() => HttpOverrides.global = null);

  late CastE2E rig;

  tearDown(() => rig.close());

  Future<void> cast(String sample) async {
    await rig.coordinator.connect(rig.device);
    await rig.phase(CastPhase.idle);
    unawaited(rig.playback.playLive(panelChannel(channelOf[sample]!)));
  }

  test(
    'HEVC to an H.264-only device: refused, learned, re-encoded, playing',
    () async {
      rig = await CastE2E.start(device: FakeDevice.chromecastHd);
      final notices = <CastNotice>[];
      rig.coordinator.notices.listen(notices.add);
      await cast('hevc_1080p50_aac');
      await rig.tvPlaying(within: const Duration(seconds: 60));
      expect(rig.devices.devices['fake-tv']!.learned.refusedCodecs, {'hevc'});
      final changed = notices.whereType<CastPlanChanged>().single;
      expect(changed.before.video, isA<CastVideoCopy>());
      expect(changed.after.video, isA<CastVideoTranscode>());
      expect(rig.state.plan, changed.after);
      expect(rig.tv.checks.last.videoCodec, 'h264');
    },
    skip: relaySkip(['hevc_1080p50_aac']),
    timeout: const Timeout(Duration(minutes: 3)),
  );

  test(
    '4K to a TV on a 1080p HDMI link: 1080p learned, re-encoded, playing',
    () async {
      rig = await CastE2E.start(device: FakeDevice.tvOnHdLink);
      await cast('h264_2160p25_aac');
      await rig.tvPlaying(within: const Duration(seconds: 60));
      expect(rig.devices.devices['fake-tv']!.learned.maxHeight, 1080);
      final video = rig.state.plan!.video as CastVideoTranscode;
      expect(video.height, 1080);
      expect(video.reasons.first, TranscodeReason.aboveLearnedHeight);
      expect(rig.tv.checks.last.height, 1080);
    },
    skip: relaySkip(['h264_2160p25_aac']),
    timeout: const Timeout(Duration(minutes: 3)),
  );

  test(
    'a continuous stream whose FFmpeg dies: the TV finishes, the cast '
    'loads a new one (ADR-004)',
    () async {
      rig = await CastE2E.start();
      await cast('hevc_1080p50_aac');
      // A continuous stream is checked once, from its start.
      await rig.tvPlaying(checks: 1);
      expect(rig.state.plan!.delivery, CastDelivery.relayContinuous);
      final first = rig.tv.loaded!['contentId'];
      final pids = [
        for (final file in rig.running)
          (jsonDecode(file.readAsStringSync()) as Map)['pid'] as int,
      ];
      expect(pids, hasLength(1));
      Process.killPid(pids.single, ProcessSignal.sigkill);
      await until(
        // Between FINISHED and the new LOAD the TV holds no media.
        () => (rig.tv.loaded?['contentId'] ?? first) != first,
        within: const Duration(seconds: 30),
        what: 'a new LOAD',
      );
      final checked = rig.tv.checks.length;
      await rig.tvPlaying(after: checked, checks: 1);
      expect(rig.state.phase, CastPhase.playing);
      expect(
        rig.logLines.where((l) => l.contains('loading it again')),
        hasLength(1),
      );
    },
    skip: relaySkip(['hevc_1080p50_aac']),
    timeout: const Timeout(Duration(minutes: 2)),
  );

  test(
    'a codec switch mid-stream: probed again, planned again, loaded again',
    () async {
      rig = await CastE2E.start();
      final channel = '${channelOf['h264_1080p50_aac']!}';
      rig.resolver.query = 'codec_switch_after_s=8';
      await cast('h264_1080p50_aac');
      await rig.tvPlaying();
      expect(rig.state.plan!.delivery, CastDelivery.relayHls);
      // From now on the channel is HEVC for good.
      rig.resolver
        ..query = ''
        ..remap[channel] = channelOf['hevc_1080p50_aac']!;
      await until(
        () => rig.state.plan?.delivery == CastDelivery.relayContinuous,
        within: const Duration(seconds: 30),
        what: 'the HEVC plan',
      );
      expect(
        rig.logLines.where((l) => l.contains('The stream changed')),
        hasLength(1),
      );
      final checked = rig.tv.checks.length;
      await rig.tvPlaying(after: checked, checks: 1);
      expect(rig.tv.checks.last.videoCodec, 'hevc');
    },
    skip: relaySkip(['h264_1080p50_aac', 'hevc_1080p50_aac']),
    timeout: const Timeout(Duration(minutes: 2)),
  );
}
