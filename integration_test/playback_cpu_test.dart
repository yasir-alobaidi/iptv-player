// Phase 9 step 8's measurement of the player's processor use (docs/06:
// H.264 1080p50 with hardware decoding, ≤ 15 % of the whole CPU): the
// whole app on the fake panel, its first channel (H.264 1080p50 + AAC)
// full screen in the app's own player, the controls gone, for a minute
// after ten seconds to settle. The process's CPU time comes from
// /proc/self/stat, as a share of one core and of all of them; with it,
// the decoder mpv chose and the frames it dropped. Meaningful in profile
// mode on the real display only:
//
//     flutter drive --profile -d linux \
//       --driver=test_driver/integration_test.dart \
//       --target=integration_test/playback_cpu_test.dart
//
// (under xvfb the picture is drawn by the processor, which is the very
// thing measured). PLAYBACK_CPU_SECONDS changes the minute, and
// IPTV_PICTURE_QUALITY=high measures Settings → Playback → Picture
// quality's High (mpv drawing at the screen's size, with its sharper
// filters) instead of Standard.

import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:iptv_player/app/app.dart';
import 'package:iptv_player/app/router.dart';
import 'package:iptv_player/core/player/player_engine.dart';
import 'package:iptv_player/features/live_tv/data/live_tv_providers.dart';
import 'package:iptv_player/features/live_tv/presentation/live_tv_screen.dart';
import 'package:iptv_player/features/playback/data/playback_providers.dart';
import 'package:iptv_player/features/playback/domain/playback_state.dart';

import 'support/fake_panel.dart';
import 'support/frames.dart';
import 'support/keyboard.dart';
import 'support/panel_app.dart';

void main() {
  final binding = IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  final seconds =
      int.tryParse(Platform.environment['PLAYBACK_CPU_SECONDS'] ?? '') ?? 60;
  final quality = Platform.environment['IPTV_PICTURE_QUALITY'] == 'high'
      ? PictureQuality.high
      : PictureQuality.standard;

  testWidgets(
    "the player's processor use on H.264 1080p50",
    (tester) async {
      HttpOverrides.global = null;
      // The window as it is: with the test window's size overridden (the
      // walks' way to a fixed layout) Flutter never asks the player for
      // its picture, mpv drops every frame, and what is measured is a
      // player that draws nothing (found by this test's first run:
      // 6.5 % of a core, 2,996 of 3,000 frames dropped).
      binding.framePolicy = LiveTestWidgetsFlutterBindingFramePolicy.fullyLive;

      final panel = (await tester.runAsync(
        () => FakePanel.start(streams: true),
      ))!;
      addTearDown(() => tester.runAsync(panel.stop));
      final app = (await tester.runAsync(
        () => PanelApp.open(panel, video: true, maxConnections: 1),
      ))!;
      addTearDown(() => tester.runAsync(app.close));
      final container = app.container;
      // The fake panel's first channel: H.264 1080p50 + AAC.
      final channel = (await tester.runAsync(
        () => container
            .read(channelRepositoryProvider)
            .byRemoteKey(app.sourceId, '1'),
      ))!.valueOrNull!;

      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: const IptvPlayerApp(),
        ),
      );
      SystemChannels.lifecycle.setMessageHandler((message) async => null);
      tester.binding.platformDispatcher.onViewFocusChange = (_) {};
      Keys(tester).resume();
      await tester.pump();
      await waitReal(tester, 1500);

      final settings = container.read(
        playbackSettingsControllerProvider.notifier,
      );
      await tester.runAsync(
        () => settings.update(
          container
              .read(playbackSettingsControllerProvider)
              .copyWith(pictureQuality: quality),
        ),
      );
      final coordinator = container.read(playbackCoordinatorProvider);
      await tester.runAsync(() => coordinator.playLive(channel));
      unawaited(container.read(routerProvider).push<void>(playerRoutePath));
      final by = DateTime.now().add(const Duration(seconds: 30));
      while (coordinator.state is! PlaybackPlaying &&
          DateTime.now().isBefore(by)) {
        await waitReal(tester, 100);
        await tester.pump();
      }
      expect(coordinator.state, isA<PlaybackPlaying>());

      // Ten seconds to settle: the decoder chosen, the controls gone.
      await waitReal(tester, 10000);
      await tester.pump();
      // The picture is on the screen at the stream's size: a player that
      // draws nothing uses no processor either, and would pass.
      expect(app.location, playerRoutePath);
      final picture = find.byType(Texture);
      expect(picture, findsOneWidget, reason: "the player's picture");
      final drawnAt = tester.getSize(picture);
      expect(
        drawnAt.width,
        greaterThan(1),
        reason: 'the picture is drawn, not only counted as playing',
      );
      final frames = <FrameTiming>[];
      void collect(List<FrameTiming> timings) => frames.addAll(timings);
      SchedulerBinding.instance.addTimingsCallback(collect);
      final before = await tester.runAsync(coordinator.engine.streamInfo);
      final ticks = _cpuTicks();
      final watch = Stopwatch()..start();
      // Dropped frames, ten seconds at a time.
      final drops = <int>[];
      var counted = before?.droppedFrames ?? 0;
      for (var left = seconds; left > 0; left -= 10) {
        await waitReal(tester, (left < 10 ? left : 10) * 1000);
        final now =
            (await tester.runAsync(coordinator.engine.streamInfo))
                ?.droppedFrames ??
            counted;
        drops.add(now - counted);
        counted = now;
      }
      watch.stop();
      final used = (_cpuTicks() - ticks) / 100;
      final after = await tester.runAsync(coordinator.engine.streamInfo);
      await waitReal(tester, 200);
      SchedulerBinding.instance.removeTimingsCallback(collect);
      expect(coordinator.state, isA<PlaybackPlaying>());

      final oneCore = used / (watch.elapsedMilliseconds / 1000) * 100;
      final cores = Platform.numberOfProcessors;
      final dropped =
          (after?.droppedFrames ?? 0) - (before?.droppedFrames ?? 0);
      final report = {
        'picture_quality': quality.name,
        'seconds': seconds,
        'cpu_pct_of_one_core': double.parse(oneCore.toStringAsFixed(1)),
        'cpu_pct_of_all_cores': double.parse(
          (oneCore / cores).toStringAsFixed(2),
        ),
        'cores': cores,
        'decoder': after?.hardwareDecoder ?? 'software',
        'picture': '${after?.width}×${after?.height} at ${after?.fps} fps',
        'video_codec': after?.videoCodec,
        'dropped_frames': dropped,
        'dropped_per_10_s': drops,
        // The texture mpv draws into: the video's own size for Standard,
        // the screen's for High.
        'drawn_at': '${drawnAt.width.round()}×${drawnAt.height.round()}',
        'screen':
            '${tester.view.physicalSize.width.round()}×'
            '${tester.view.physicalSize.height.round()}',
        'frames_the_app_built': frames.length,
      };
      binding.reportData = {'playback_cpu': report};
      // The measurement is this test's output, read by whoever runs it.
      // ignore: avoid_print
      print(
        'playback cpu (${kProfileMode ? 'profile' : 'debug'} mode): $report',
      );
      expect(tester.takeException(), isNull);
    },
    // Nothing to measure with no picture (CI: no GPU, `vo=null`), or
    // with no stream to play.
    skip: !streamsAvailable || Platform.environment['IPTV_PLAYER_VIDEO'] == '0',
    timeout: Timeout(Duration(seconds: seconds + 240)),
    // As the app runs without a screen reader: flutter_test builds the
    // semantics tree on every frame unless told not to.
    semanticsEnabled: false,
  );
}

/// This process's CPU time so far, in clock ticks (100 a second on
/// Linux): user + system from /proc/self/stat.
int _cpuTicks() {
  final stat = File('/proc/self/stat').readAsStringSync();
  // Fields after the command name, which is in parentheses.
  final fields = stat.substring(stat.lastIndexOf(')') + 2).split(' ');
  return int.parse(fields[11]) + int.parse(fields[12]);
}
