// The real player (media_kit + our patched media_kit_video, ADR-003)
// against the fake provider's live streams: the first frame, a zap, the
// connection let go on stop, and a channel that isn't there.
//
// Needs the media samples (tools/media_samples/generate.sh), which CI
// doesn't have: skipped without them. IPTV_PLAYER_VIDEO=0 runs mpv with no
// video output (`vo=null`), for a machine with no GPU (ADR-010, step 1).

import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:iptv_player/core/logging/app_log.dart';
import 'package:iptv_player/core/logging/secret_registry.dart';
import 'package:iptv_player/core/player/player_engine.dart';
import 'package:iptv_player/data/player_mediakit/media_kit_player_engine.dart';

import 'support/fake_panel.dart';
import 'support/keyboard.dart';

void main() {
  final binding = IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  final video = Platform.environment['IPTV_PLAYER_VIDEO'] != '0';

  testWidgets(
    'plays, zaps, lets go of the connection, and fails a missing channel',
    (tester) async {
      HttpOverrides.global = null;
      // Frames on the engine's own schedule, as in the app: the video
      // controller only gets its texture once frames are drawn.
      binding.framePolicy = LiveTestWidgetsFlutterBindingFramePolicy.fullyLive;
      final panel = (await tester.runAsync(
        () => FakePanel.start(streams: true),
      ))!;
      addTearDown(() => tester.runAsync(panel.stop));
      final engine = (await tester.runAsync(
        () => MediaKitPlayerEngine.create(
          log: AppLog(output: SilentOutput(), secrets: SecretRegistry()),
          secrets: SecretRegistry(),
          video: video,
        ),
      ))!;
      addTearDown(() => tester.runAsync(engine.dispose));
      final events = <PlayerEvent>[];
      final subscription = engine.events.listen(events.add);
      addTearDown(subscription.cancel);

      await tester.pumpWidget(
        MaterialApp(
          home: engine.videoView(background: const Color(0xFF000000)),
        ),
      );

      Future<Duration> play(String url) async {
        events.clear();
        final watch = Stopwatch()..start();
        await tester.runAsync(() => engine.open(PlayRequest(url: url)));
        await _until(
          tester,
          () => events.any((e) => e is PlayerFirstFrame || e is PlayerFailed),
          'the first frame of $url',
        );
        expect(events.whereType<PlayerFailed>(), isEmpty, reason: '$events');
        return watch.elapsed;
      }

      // ── The first channel (H.264 1080p50), then a zap (1080p25).
      final first = await play(panel.live(1));
      await _until(
        tester,
        () => events.whereType<PlayerProgress>().length >= 3,
        'progress while playing',
      );
      final info = (await tester.runAsync(engine.streamInfo))!;
      if (video) {
        expect(info.width, 1920);
        expect(info.height, 1080);
      }
      expect(info.videoCodec, isNotNull);
      final zap = await play(panel.live(2));
      // The previous stream's connection is gone: one open at a time.
      expect(await tester.runAsync(panel.activeConnections), 1);

      // ── Stop lets go of the connection.
      await tester.runAsync(engine.stop);
      await _until(
        tester,
        () async => await panel.activeConnections() == 0,
        'the panel to see the connection closed',
      );

      // ── A channel that isn't there fails, with the reason behind it.
      events.clear();
      await tester.runAsync(
        () => engine.open(PlayRequest(url: panel.live(99999))),
      );
      await _until(
        tester,
        () => events.any((e) => e is PlayerFailed),
        'the failure of a missing channel',
      );
      expect(events.whereType<PlayerFirstFrame>(), isEmpty);

      // The measurement is this test's output.
      // ignore: avoid_print
      print(
        'player: first frame ${first.inMilliseconds} ms, zap '
        '${zap.inMilliseconds} ms, video ${video ? 'on' : 'off'}, '
        'decoder ${info.hardwareDecoder ?? 'software'}',
      );
    },
    skip: !streamsAvailable,
    timeout: const Timeout(Duration(minutes: 2)),
  );
}

Future<void> _until(
  WidgetTester tester,
  FutureOr<bool> Function() done,
  String what, {
  int seconds = 20,
}) async {
  final deadline = DateTime.now().add(Duration(seconds: seconds));
  while (DateTime.now().isBefore(deadline)) {
    if ((await tester.runAsync(() async => await done())) ?? false) return;
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 50)),
    );
    await tester.pump();
  }
  fail('Timed out waiting for $what');
}
