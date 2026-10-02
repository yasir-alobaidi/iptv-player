import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:iptv_player/core/cast/cast_relay.dart';
import 'package:iptv_player/features/playback/data/http_stream_prober.dart';
import 'package:iptv_player/features/playback/domain/playback_state.dart';

import 'relay_rig.dart';

/// The fake panel's faults the relay can't ride through: each fails the
/// session with what docs/03 needs to say why, as local playback does
/// (`classifyStreamFailure`); and the codec switch, told so the plan is
/// made again (step 6).
void main() {
  setUpAll(() => HttpOverrides.global = null);

  final skip = relaySkip(['h264_1080p50_aac']);
  const channel = 1;
  RelayRig? rig;

  tearDown(() async {
    await rig?.close();
    rig = null;
  });

  /// Starts relaying channel 1 with [faults]; the session, not waited for.
  Future<CastRelaySession> start(
    RelayRig rig,
    String faults, {
    int maxConnections = 2,
  }) async {
    final facts = await rig.probe(channel);
    final started = await rig.relay.start(
      CastRelayRequest(
        plan: rig.plan(facts),
        facts: facts,
        source: rig.source(
          channel,
          query: faults,
          maxConnections: maxConnections,
        ),
        localAddress: '127.0.0.1',
      ),
    );
    return (started as CastRelayStarted).session;
  }

  for (final (status, kind) in [
    (401, PlaybackProblemKind.auth),
    (404, PlaybackProblemKind.offline),
    (500, PlaybackProblemKind.server),
  ]) {
    test(
      'HTTP $status: failed, in the words local playback uses',
      () async {
        final started = rig = await RelayRig.start();
        final session = await start(started, 'http_status=$status');
        final failure = await session.ready.timeout(
          const Duration(seconds: 30),
        );
        expect(failure, isNotNull);
        expect(failure!.kind, CastRelayFailureKind.providerRefused);
        expect(failure.status, status);
        expect(
          classifyStreamFailure(status: status, body: failure.body).kind,
          kind,
        );
        await until(() => started.running.isEmpty, what: 'no FFmpeg');
      },
      skip: skip,
      timeout: const Timeout(Duration(minutes: 2)),
    );
  }

  test(
    'a full account: tried again, then failed as the connection limit',
    () async {
      final started = rig = await RelayRig.start(
        maxConnections: 1,
        proxyTimings: quickRetries,
      );
      final facts = await started.probe(channel);
      // Another device of the user's holds the one connection.
      final other = HttpClient();
      addTearDown(() => other.close(force: true));
      final holding = (await (await other.getUrl(
        Uri.parse('${started.panel.url}/live/test/test/2.ts'),
      )).close()).listen((_) {});
      addTearDown(holding.cancel);
      await until(() => started.panel.state.activeStreams == 1);

      final relay = await started.relay.start(
        CastRelayRequest(
          plan: started.plan(facts),
          facts: facts,
          source: started.source(channel),
          localAddress: '127.0.0.1',
        ),
      );
      final failure = await (relay as CastRelayStarted).session.ready.timeout(
        const Duration(seconds: 30),
      );
      expect(failure!.kind, CastRelayFailureKind.providerRefused);
      expect(failure.status, 403);
      expect(failure.body, contains('MAX_CONNECTIONS'));
      expect(
        classifyStreamFailure(status: 403, body: failure.body).kind,
        PlaybackProblemKind.connectionLimit,
      );
      expect(
        started.logLines.where((l) => l.contains('(full?); trying again')),
        isNotEmpty,
      );
    },
    skip: skip,
    timeout: const Timeout(Duration(minutes: 2)),
  );

  test(
    'a codec switch mid-stream is told, so the plan is made again',
    () async {
      final started = rig = await RelayRig.start();
      final facts = await started.probe(channel);
      final relayed = await started.relayed(
        started.plan(facts),
        facts,
        started.source(channel, query: 'codec_switch_after_s=4'),
      );
      await started.load(relayed);
      await relayed.next<CastRelayStreamsChanged>();
      expect(
        started.logLines.where((l) => l.contains('0x1b 0xf → 0x24 0xf')),
        isNotEmpty,
      );
    },
    skip: skip,
    timeout: const Timeout(Duration(minutes: 2)),
  );
}
