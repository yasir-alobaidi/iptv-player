import 'dart:io';

import 'package:fake_receiver/fake_receiver.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:iptv_player/core/cast/cast_device.dart';
import 'package:iptv_player/core/cast/cast_device_profile.dart';
import 'package:iptv_player/core/cast/cast_plan.dart';
import 'package:iptv_player/core/cast/cast_relay.dart';

import 'relay_rig.dart';

/// Casts through the relay, end to end and real but for the TV: the fake
/// panel's samples probed through the relay's proxy, planned by the
/// planner, relayed by FFmpeg in the relay's isolate, loaded with the
/// app's own Cast client, and fetched and checked by the fake receiver as
/// the TV would (Phase 7 decision 8). docs/04's matrix, without the TV.
void main() {
  setUpAll(() => HttpOverrides.global = null);

  RelayRig? rig;
  tearDown(() async {
    await rig?.close();
    rig = null;
  });

  Future<RelayRig> start({FakeDevice device = FakeDevice.tv4k}) async =>
      rig = await RelayRig.start(device: device);

  /// Casts [sample] to the rig's TV as planned for [device]: the plan, the
  /// session and what the TV checked.
  Future<(CastPlan, Relayed)> cast(
    RelayRig rig,
    String sample, {
    CastDeviceProfile device = const CastDeviceProfile(),
  }) async {
    final channel = channelOf[sample]!;
    final facts = await rig.probe(channel);
    final plan = rig.plan(facts, device: device);
    final session = await rig.relayed(plan, facts, rig.source(channel));
    await rig.load(session);
    await rig.playing(
      checks: plan.delivery == CastDelivery.relayContinuous ? 1 : 2,
    );
    return (plan, session);
  }

  test(
    'H.264 1080p50 + AAC: HLS, both copied; FFmpeg says what it opened; '
    'stopped, nothing is left',
    () async {
      final rig = await start();
      final channel = channelOf['h264_1080p50_aac']!;
      final facts = await rig.probe(channel);
      expect(facts.video!.codec, 'h264');
      expect(facts.video!.height, 1080);
      final plan = rig.plan(facts);
      expect(plan.delivery, CastDelivery.relayHls);
      expect(plan.video, isA<CastVideoCopy>());
      expect(plan.audio, isA<CastAudioCopy>());
      final relayed = await rig.relayed(plan, facts, rig.source(channel));
      final session = relayed.session;
      expect(session.url, startsWith('http://127.0.0.1:'));
      expect(session.url, endsWith('/index.m3u8'));
      expect(session.contentType, 'application/x-mpegurl');
      await rig.load(relayed);
      await rig.playing();
      await relayed.next<CastRelayFetched>();
      final seen = (await relayed.next<CastRelayOpened>()).facts;
      expect(seen.video!.codec, 'h264');
      expect(seen.video!.height, 1080);
      expect(seen.audio.single.codec, 'aac');
      for (final check in rig.tv.checks) {
        expect(check.videoCodec, 'h264');
        expect(check.height, 1080);
        expect(check.audioCodec, 'aac');
      }
      expect(rig.tv.fetches.every((f) => f.cors), isTrue);
      expect(rig.running, hasLength(1), reason: "the relay's FFmpeg");
      expect(rig.sessions.listSync(), hasLength(1));

      await session.stop();
      await until(() => rig.running.isEmpty, what: 'no FFmpeg');
      expect(rig.sessions.listSync(), isEmpty);
      // Nothing the relay logged carries the panel's credentials.
      expect(rig.logLines.join('\n'), isNot(contains('/test/test/')));
    },
    skip: relaySkip(['h264_1080p50_aac']),
    timeout: const Timeout(Duration(minutes: 2)),
  );

  test(
    'H.264 + AC-3 5.1: the sound to AAC stereo',
    () async {
      final rig = await start();
      final (plan, _) = await cast(rig, 'h264_1080p25_ac3');
      expect(plan.audio, isA<CastAudioToAac>());
      for (final check in rig.tv.checks) {
        expect(check.videoCodec, 'h264');
        expect(check.audioCodec, 'aac');
        expect(check.audioChannels, 2);
      }
    },
    skip: relaySkip(['h264_1080p25_ac3']),
    timeout: const Timeout(Duration(minutes: 2)),
  );

  test(
    'HEVC 1080p: one continuous MP4, copied; the TV leaving stops it',
    () async {
      final rig = await start();
      final (plan, relayed) = await cast(rig, 'hevc_1080p50_aac');
      expect(plan.delivery, CastDelivery.relayContinuous);
      expect(relayed.session.contentType, 'video/mp4');
      expect(relayed.session.url, endsWith('/stream.mp4'));
      final check = rig.tv.checks.single;
      expect(check.videoCodec, 'hevc');
      expect(check.height, 1080);
      expect(check.audioCodec, 'aac');
      expect(check.hasVideo && check.hasAudio, isTrue);
      expect(rig.running, hasLength(1));

      // The TV's own Back: it stops fetching.
      rig.tv.remoteBack();
      expect((await relayed.next<CastRelayEnded>()).tvLeft, isTrue);
      await until(() => rig.running.isEmpty, what: 'no FFmpeg');
    },
    skip: relaySkip(['hevc_1080p50_aac']),
    timeout: const Timeout(Duration(minutes: 2)),
  );

  test(
    'HEVC to a TV set to "HEVC: No": re-encoded to H.264 on the processor',
    () async {
      final rig = await start(device: FakeDevice.chromecastHd);
      final (plan, _) = await cast(
        rig,
        'hevc_1080p50_aac',
        device: const CastDeviceProfile(hevc: HevcSupport.no),
      );
      expect(plan.video, isA<CastVideoTranscode>());
      expect(plan.delivery, CastDelivery.relayHls);
      for (final check in rig.tv.checks) {
        expect(check.videoCodec, 'h264');
        expect(check.height, 1080);
      }
    },
    skip: relaySkip(['hevc_1080p50_aac']),
    timeout: const Timeout(Duration(minutes: 2)),
  );

  test(
    'MPEG-2 576i: re-encoded and deinterlaced',
    () async {
      final rig = await start();
      final (plan, _) = await cast(rig, 'mpeg2_576i25_mp2');
      final video = plan.video as CastVideoTranscode;
      expect(video.deinterlace, isTrue);
      for (final check in rig.tv.checks) {
        expect(check.videoCodec, 'h264');
        expect(check.height, 576);
        expect(check.audioCodec, 'aac');
      }
    },
    skip: relaySkip(['mpeg2_576i25_mp2']),
    timeout: const Timeout(Duration(minutes: 2)),
  );

  test(
    'H.264 1080i + MP2: the picture copied interlaced, the sound to AAC',
    () async {
      final rig = await start();
      final (plan, _) = await cast(rig, 'h264_1080i50_mp2');
      expect(plan.video, isA<CastVideoCopy>());
      expect(plan.output.interlaced, isTrue);
      for (final check in rig.tv.checks) {
        expect(check.videoCodec, 'h264');
        expect(check.audioCodec, 'aac');
      }
    },
    skip: relaySkip(['h264_1080i50_mp2']),
    timeout: const Timeout(Duration(minutes: 2)),
  );

  test(
    'HEVC 4K + E-AC-3 to the 4K TV: continuous, copied',
    () async {
      final rig = await start();
      final (plan, _) = await cast(rig, 'hevc_2160p25_eac3');
      expect(plan.video, isA<CastVideoCopy>());
      final check = rig.tv.checks.single;
      expect(check.videoCodec, 'hevc');
      expect(check.height, 2160);
      expect(check.audioCodec, 'aac');
    },
    skip: relaySkip(['hevc_2160p25_eac3']),
    timeout: const Timeout(Duration(minutes: 2)),
  );

  test(
    '4K to a TV on a 1080p link: refused, as the TV does (step 6 learns)',
    () async {
      final rig = await start(device: FakeDevice.tvOnHdLink);
      final channel = channelOf['h264_2160p25_aac']!;
      final facts = await rig.probe(channel);
      final plan = rig.plan(facts);
      expect(plan.video, isA<CastVideoCopy>(), reason: 'not learned yet');
      final session = await rig.relayed(plan, facts, rig.source(channel));
      await rig.load(session);
      await until(
        () => rig.tv.requests('LOAD').isNotEmpty && rig.tv.playerState == null,
        what: 'the LOAD refused',
      );
      expect(rig.tv.checks.first.height, 2160);
    },
    skip: relaySkip(['h264_2160p25_aac']),
    timeout: const Timeout(Duration(minutes: 2)),
  );

  test(
    'a one-connection source: the probe lets go before the relay connects',
    () async {
      final rig = await RelayRig.start(maxConnections: 1);
      addTearDown(rig.close);
      final opened = <int>[];
      final counting = rig.relay.connections
          .where((c) => c.sourceId == 'panel')
          .listen((c) => opened.add(c.open));
      addTearDown(counting.cancel);
      final channel = channelOf['h264_1080p50_aac']!;
      final facts = await rig.probe(channel, maxConnections: 1);
      final plan = rig.plan(facts);
      final session = await rig.relayed(
        plan,
        facts,
        rig.source(channel, maxConnections: 1),
      );
      await rig.load(session);
      await rig.playing();
      expect(opened.every((n) => n <= 1), isTrue, reason: '$opened');
      expect(opened, containsAllInOrder([1, 0, 1]));
      expect(rig.panel.state.activeStreams, 1);
    },
    skip: relaySkip(['h264_1080p50_aac']),
    timeout: const Timeout(Duration(minutes: 2)),
  );

  test(
    'a continuous stream that ended: renewed, loaded again, it plays',
    () async {
      final rig = await start();
      final (_, relayed) = await cast(rig, 'hevc_1080p50_aac');
      final first = relayed.session.url;
      rig.tv.remoteBack();
      await relayed.next<CastRelayEnded>();
      expect(await relayed.session.renew(), isNull);
      expect(relayed.session.url, isNot(first));
      expect(await relayed.session.ready, isNull);
      // The TV's Back closed its receiver: the next LOAD joins anew.
      rig.joinAgain();
      await rig.load(relayed);
      await rig.playing();
      expect(rig.tv.checks.last.videoCodec, 'hevc');
    },
    skip: relaySkip(['hevc_1080p50_aac']),
    timeout: const Timeout(Duration(minutes: 2)),
  );

  test(
    'the relay closed with a session on: its FFmpeg and folders gone',
    () async {
      final rig = await start();
      await cast(rig, 'h264_1080p50_aac');
      expect(rig.running, isNotEmpty);
      await rig.relay.close();
      expect(rig.running, isEmpty);
      expect(rig.sessions.existsSync(), isFalse);
    },
    skip: relaySkip(['h264_1080p50_aac']),
    timeout: const Timeout(Duration(minutes: 2)),
  );

  test(
    "the provider's own HLS, through the proxy",
    () async {
      final rig = await start();
      final channel = channelOf['h264_1080p50_aac']!;
      final facts = await rig.probe(channel);
      final plan = rig.plan(facts);
      final session = await rig.relayed(
        plan,
        facts,
        rig.source(channel, hls: true),
      );
      await rig.load(session);
      await rig.playing();
      expect(rig.tv.checks.last.videoCodec, 'h264');
    },
    skip: relaySkip(['h264_1080p50_aac']),
    timeout: const Timeout(Duration(minutes: 2)),
  );
}
