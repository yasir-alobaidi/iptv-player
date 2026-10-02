import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:iptv_player/core/cast/cast_plan.dart';
import 'package:iptv_player/core/cast/cast_relay.dart';
import 'package:iptv_player/core/cast/stream_facts.dart';
import 'package:iptv_player/core/core_providers.dart';
import 'package:iptv_player/core/logging/app_log.dart';
import 'package:iptv_player/core/logging/secret_registry.dart';
import 'package:iptv_player/core/result.dart';
import 'package:iptv_player/data/cast/ffmpeg_binaries.dart';
import 'package:iptv_player/data/cast/relay/isolate_cast_relay.dart';
import 'package:iptv_player/features/casting/data/casting_providers.dart';
import 'package:logger/logger.dart';

/// What the relay's app side refuses before starting anything; casting
/// it for real is `relay_cast_test.dart`.
void main() {
  final log = AppLog(output: MemoryOutput(), secrets: SecretRegistry());
  late IsolateCastRelay relay;

  setUp(() {
    relay = IsolateCastRelay(
      binaries: const FfmpegBinaries(ffmpeg: '/nope', ffprobe: '/nope'),
      processFolder: Directory.systemTemp,
      relayFolder: Directory.systemTemp,
      log: log,
    );
  });

  CastRelayRequest request(CastDelivery delivery, CastVideo video) =>
      CastRelayRequest(
        plan: CastPlan(
          delivery: delivery,
          video: video,
          audio: const CastAudioCopy(0),
          live: true,
          output: const CastOutput(),
        ),
        facts: const StreamFacts(origin: StreamFactsOrigin.probe),
        source: CastUpstreamSource(
          sourceId: 's',
          live: true,
          resolve: () async => Err(NotFoundFailure('source s')),
        ),
        localAddress: '127.0.0.1',
      );

  test('a direct plan has nothing to relay', () async {
    final start = await relay.start(
      request(CastDelivery.directHls, const CastVideoCopy()),
    );
    expect(
      (start as CastRelayNotStarted).failure.kind,
      CastRelayFailureKind.couldNotStart,
    );
  });

  test('a re-encode with nothing to re-encode with', () async {
    final start = await relay.start(
      request(
        CastDelivery.relayHls,
        const CastVideoTranscode(
          height: 1080,
          bitRate: 6000000,
          reasons: [TranscodeReason.codecUnsupported],
        ),
      ),
    );
    final failure = (start as CastRelayNotStarted).failure;
    expect(failure.kind, CastRelayFailureKind.encoderFailed);
    expect(failure.detail, contains('re-encode'));
  });

  test('nothing after it closed', () async {
    await relay.close();
    final start = await relay.start(
      request(CastDelivery.relayHls, const CastVideoCopy()),
    );
    expect(start, isA<CastRelayNotStarted>());
    expect(
      await relay.openInput(
        CastUpstreamSource(
          sourceId: 's',
          live: true,
          resolve: () async => Err(NotFoundFailure('s')),
        ),
      ),
      isNull,
    );
  });

  test('a build without FFmpeg relays nothing', () async {
    final container = ProviderContainer(
      overrides: [
        ffmpegBinariesProvider.overrideWithValue(null),
        appLogProvider.overrideWithValue(log),
      ],
    );
    addTearDown(container.dispose);
    final none = container.read(castRelayProvider);
    expect(none, isA<UnavailableCastRelay>());
    final start = await none.start(
      request(CastDelivery.relayHls, const CastVideoCopy()),
    );
    expect(
      (start as CastRelayNotStarted).failure.detail,
      'This build has no FFmpeg.',
    );
    expect(
      await none.openInput(
        CastUpstreamSource(
          sourceId: 's',
          live: true,
          resolve: () async => Err(NotFoundFailure('s')),
        ),
      ),
      isNull,
    );
    expect(await none.connections.isEmpty, isTrue);
  });
}
