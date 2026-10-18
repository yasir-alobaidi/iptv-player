// The real player (media_kit + our patched media_kit_video, ADR-003)
// against the fake provider's live streams: the first frame, a zap, the
// connection let go on stop, the desktop's picture (Picture size and
// Picture quality), and a channel that isn't there.
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
import 'package:iptv_player/data/player_mediakit/desktop_picture.dart';
import 'package:iptv_player/data/player_mediakit/media_kit_player_engine.dart';
import 'package:media_kit_video/media_kit_video.dart';

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

      Future<Duration> play(
        String url, {
        PictureQuality quality = PictureQuality.standard,
      }) async {
        events.clear();
        final watch = Stopwatch()..start();
        await tester.runAsync(
          () => engine.open(PlayRequest(url: url, pictureQuality: quality)),
        );
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

      // ── HLS (the live format a source can choose).
      final hls = await play(panel.live(1, extension: 'm3u8'));
      await tester.runAsync(engine.stop);

      // ── Settings → Playback → Hardware decoding: Off decodes the next
      // file on the processor, and Automatic hands it back (Phase 9
      // decision 4). With no picture Automatic leaves mpv's own setting.
      events.clear();
      await tester.runAsync(
        () => engine.open(
          PlayRequest(url: panel.live(1), hardwareDecoding: false),
        ),
      );
      await _until(
        tester,
        () => events.any((e) => e is PlayerFirstFrame || e is PlayerFailed),
        'the first frame with hardware decoding off',
      );
      expect(events.whereType<PlayerFailed>(), isEmpty, reason: '$events');
      expect(await tester.runAsync(() => engine.mpvProperty('hwdec')), 'no');
      final software = (await tester.runAsync(engine.streamInfo))!;
      expect(software.hardwareDecoder, isNull);
      await play(panel.live(2));
      if (video) {
        expect(
          await tester.runAsync(() => engine.mpvProperty('hwdec')),
          hwdecAutomatic,
        );
      }
      await tester.runAsync(engine.stop);

      // ── The desktop's picture (ADR-035), on the 4:3 channel (MPEG-2
      // 576i, shown 768 × 576) in a 16:9 window.
      if (video) {
        Video picture() => tester.widget<Video>(find.byType(Video));
        // The texture mpv draws into, as the picture widget lays it out.
        Size texture() => tester.getSize(find.byType(Texture));
        Future<String> mpv(String name) async =>
            (await tester.runAsync(() => engine.mpvProperty(name)))!;
        const sd = Size(768, 576);

        // Standard: the texture has the video's own shape, so mpv's
        // panscan and keepaspect have nothing to act on; Fill and Stretch
        // are the picture widget's fit.
        await play(panel.live(5));
        await _until(
          tester,
          () => texture() == sd,
          "the texture at the video's own size",
        );
        final standardScale = await mpv('scale');
        final standardDeband = await mpv('deband');
        for (final (mode, fit) in [
          (AspectMode.fill, BoxFit.cover),
          (AspectMode.stretch, BoxFit.fill),
          (AspectMode.fit, BoxFit.contain),
        ]) {
          await tester.runAsync(() => engine.setAspect(mode));
          await tester.pump();
          expect(picture().fit, fit, reason: mode.name);
          expect(texture(), sd, reason: mode.name);
        }

        // High: mpv's sharper filters, and the texture at the size the
        // picture takes on screen; Fill's is the whole window (mpv crops
        // into it).
        await play(panel.live(5), quality: PictureQuality.high);
        expect(await mpv('scale'), 'spline36');
        expect(await mpv('deband'), 'yes');
        Size drawn(BoxFit fit) {
          final (width, height) = highQualityPictureSize(
            video: sd,
            box: tester.getSize(find.byType(Video)),
            devicePixelRatio: tester.view.devicePixelRatio,
            fit: fit,
          )!;
          return Size(width.toDouble(), height.toDouble());
        }

        await _until(
          tester,
          () => texture() == drawn(BoxFit.contain),
          "High's texture at the picture's size (${drawn(BoxFit.contain)})",
        );
        await tester.runAsync(() => engine.setAspect(AspectMode.fill));
        await _until(
          tester,
          () => texture() == drawn(BoxFit.cover),
          "Fill's texture, the whole window (${drawn(BoxFit.cover)})",
        );
        expect(double.parse(await mpv('panscan')), 1);
        await tester.runAsync(() => engine.setAspect(AspectMode.fit));
        await _until(
          tester,
          () => texture() == drawn(BoxFit.contain),
          "Fit's texture again (${drawn(BoxFit.contain)})",
        );

        // Standard again: the running mpv's own filters, and the video's
        // own size.
        await play(panel.live(5));
        expect(await mpv('scale'), standardScale);
        expect(await mpv('deband'), standardDeband);
        await _until(
          tester,
          () => texture() == sd,
          "the video's own size again",
        );
        // What was measured is part of this test's output.
        // ignore: avoid_print
        print(
          'picture: window ${tester.getSize(find.byType(Video))}, High '
          '${drawn(BoxFit.contain)}, scale $standardScale → spline36',
        );
        await tester.runAsync(engine.stop);
      }

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
        '${zap.inMilliseconds} ms, HLS ${hls.inMilliseconds} ms, '
        'video ${video ? 'on' : 'off'}, '
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
