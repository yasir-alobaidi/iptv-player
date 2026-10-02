import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:iptv_player/core/cast/cast_plan.dart';
import 'package:iptv_player/core/cast/cast_planner.dart';
import 'package:iptv_player/core/cast/cast_relay.dart';
import 'package:iptv_player/core/cast/stream_facts.dart';

import 'relay_rig.dart';

/// The fake panel's live faults that the relay rides through (docs/04's
/// matrix, Phase 7 step 5): each relayed to the fake receiver, which must
/// keep getting segments it can play. The refusals are in
/// `relay_refusals_test.dart`.
void main() {
  setUpAll(() => HttpOverrides.global = null);

  final skip = relaySkip(['h264_1080p50_aac']);
  const channel = 1;
  RelayRig? rig;
  late StreamFacts facts;

  tearDown(() async {
    await rig?.close();
    rig = null;
  });

  /// Channel 1 (H.264 1080p50 + AAC) cast with the panel's [faults], once
  /// the TV plays it.
  Future<(RelayRig, Relayed)> cast(
    String faults, {
    bool continuous = false,
  }) async {
    final started = rig = await RelayRig.start();
    facts = await started.probe(channel);
    final plan = started.plan(
      facts,
      settings: CastSettings(lowLatency: continuous),
    );
    expect(
      plan.delivery,
      continuous ? CastDelivery.relayContinuous : CastDelivery.relayHls,
    );
    final relayed = await started.relayed(
      plan,
      facts,
      started.source(channel, query: faults),
    );
    await started.load(relayed);
    await started.playing(checks: continuous ? 1 : 2);
    return (started, relayed);
  }

  /// The TV keeps getting pictures with sound past [seconds] of stream.
  Future<void> playsOn(RelayRig rig, int seconds) async {
    await rig.playing(
      checks: seconds ~/ 2,
      within: Duration(seconds: seconds + 20),
    );
    for (final check in rig.tv.checks) {
      expect(check.hasVideo, isTrue, reason: '$check');
      expect(check.hasAudio, isTrue, reason: '$check');
    }
  }

  void noFailure(Relayed relayed) {
    expect(relayed.events.whereType<CastRelayFailed>(), isEmpty);
  }

  test(
    'a drop: FFmpeg reconnects through the proxy, nothing restarts',
    () async {
      final (rig, relayed) = await cast('drop_after_s=4');
      await playsOn(rig, 16);
      expect(
        rig.logLines.where((l) => l.contains('FFmpeg reconnects')),
        isNotEmpty,
      );
      expect(relayed.events.whereType<CastRelayRestarted>(), isEmpty);
      expect(rig.tv.checks.every((c) => !c.discontinuity), isTrue);
      noFailure(relayed);
    },
    skip: skip,
    timeout: const Timeout(Duration(minutes: 2)),
  );

  test(
    'a cut mid-body: the same',
    () async {
      final (rig, relayed) = await cast('cut_after_s=4');
      await playsOn(rig, 16);
      expect(rig.logLines.where((l) => l.contains('stream broke')), isNotEmpty);
      expect(relayed.events.whereType<CastRelayRestarted>(), isEmpty);
      noFailure(relayed);
    },
    skip: skip,
    timeout: const Timeout(Duration(minutes: 2)),
  );

  test(
    'a stall: FFmpeg restarted behind the same URL, the playlist '
    'continued after a discontinuity',
    () async {
      final (rig, relayed) = await cast('stall_after_s=4');
      final restarted = await relayed.next<CastRelayRestarted>();
      expect(restarted.count, 1);
      await until(
        () => rig.tv.checks.any((c) => c.discontinuity),
        within: const Duration(seconds: 30),
        what: 'a segment after the restart',
      );
      final after = rig.tv.checks.indexWhere((c) => c.discontinuity);
      expect(rig.tv.checks[after].hasVideo, isTrue);
      expect(rig.tv.playerState, anyOf('PLAYING', 'BUFFERING'));
      noFailure(relayed);
    },
    skip: skip,
    timeout: const Timeout(Duration(minutes: 2)),
  );

  test(
    'an 8 s slow start: ready late, then it plays',
    () async {
      final clock = Stopwatch()..start();
      final (rig, relayed) = await cast('slow_start_ms=8000');
      expect(clock.elapsed, greaterThan(const Duration(seconds: 8)));
      await playsOn(rig, 6);
      expect(relayed.events.whereType<CastRelayRestarted>(), isEmpty);
      noFailure(relayed);
    },
    skip: skip,
    timeout: const Timeout(Duration(minutes: 2)),
  );

  test(
    'an expiring redirect: every reconnect follows it afresh',
    () async {
      // The token lasts 10 s; the cut at 12 s needs a new one.
      final (rig, relayed) = await cast(
        'redirect_with_expiring_token=1&cut_after_s=12',
      );
      await playsOn(rig, 20);
      expect(rig.logLines.where((l) => l.contains('stream broke')), isNotEmpty);
      expect(rig.logLines.where((l) => l.contains('HTTP 403')), isEmpty);
      noFailure(relayed);
    },
    skip: skip,
    timeout: const Timeout(Duration(minutes: 2)),
  );

  test(
    'a drop on the continuous stream: FFmpeg reconnects, the TV reads on',
    () async {
      final (rig, relayed) = await cast('drop_after_s=4', continuous: true);
      final before = rig.tv.fetches.length;
      await Future<void>.delayed(const Duration(seconds: 10));
      expect(relayed.events.whereType<CastRelayEnded>(), isEmpty);
      expect(rig.tv.playerState, 'PLAYING');
      expect(rig.tv.fetches.length, before, reason: 'one request, still on');
      noFailure(relayed);
    },
    skip: skip,
    timeout: const Timeout(Duration(minutes: 2)),
  );
}
