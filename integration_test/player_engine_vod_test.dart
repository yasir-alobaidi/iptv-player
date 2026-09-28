// The real player on a file (Phase 5 step 6): an open that starts part-way
// in (a resume), the file's length, pause and play reported back, a seek,
// and the end of the file — against the fake panel's `/movie/` files,
// which answer Range as a panel does.
//
// Needs the VOD sample (tools/media_samples/generate.sh
// vod_h264_aac_10min; CI makes a 120 s one). IPTV_PLAYER_VIDEO=0 runs mpv
// with no video output.

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
    'a file starts where asked, knows its length, pauses, seeks and ends',
    (tester) async {
      HttpOverrides.global = null;
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

      Duration position() =>
          events.whereType<PlayerProgress>().lastOrNull?.position ??
          Duration.zero;

      // ── A resume: one open that starts 30 s in.
      const start = Duration(seconds: 30);
      final watch = Stopwatch()..start();
      await tester.runAsync(
        () => engine.open(
          PlayRequest(
            url: panel.movie(firstMovieId),
            live: false,
            start: start,
          ),
        ),
      );
      await _until(
        tester,
        () => events.any((e) => e is PlayerFirstFrame || e is PlayerFailed),
        'the first frame',
      );
      final firstFrame = watch.elapsed;
      expect(events.whereType<PlayerFailed>(), isEmpty, reason: '$events');
      await _until(
        tester,
        () => events.whereType<PlayerProgress>().length >= 2,
        'progress',
      );
      expect(position(), greaterThanOrEqualTo(start));
      expect(position(), lessThan(start + const Duration(seconds: 10)));
      final length = events.whereType<PlayerDuration>().last.duration;
      expect(length, greaterThan(const Duration(seconds: 60)));

      // ── Pause and play, reported back; the position holds while paused.
      events.clear();
      await tester.runAsync(() => engine.setPaused(paused: true));
      await _until(
        tester,
        () => events.whereType<PlayerPaused>().any((e) => e.paused),
        'the pause reported',
      );
      final held = position();
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(seconds: 1)),
      );
      expect(
        events.whereType<PlayerProgress>().where(
          (e) => e.position > held + const Duration(milliseconds: 500),
        ),
        isEmpty,
      );
      await tester.runAsync(() => engine.setPaused(paused: false));
      await _until(
        tester,
        () => events.whereType<PlayerPaused>().any((e) => !e.paused),
        'playing reported',
      );

      // ── A seek near the end, then the end of the file.
      events.clear();
      final target = length - const Duration(seconds: 4);
      await tester.runAsync(() => engine.seek(target));
      await _until(
        tester,
        () => position() >= target - const Duration(seconds: 1),
        'the position after the seek',
      );
      await _until(
        tester,
        () => events.any((e) => e is PlayerEnded),
        'the end of the file',
      );
      expect(events.whereType<PlayerFailed>(), isEmpty);

      // ── Stop lets go of the connection.
      await tester.runAsync(engine.stop);
      await _until(
        tester,
        () async => await panel.activeConnections() == 0,
        'the panel to see the connection closed',
      );

      // The measurement is this test's output.
      // ignore: avoid_print
      print(
        'vod: first frame at 30 s in ${firstFrame.inMilliseconds} ms, '
        'length $length, video ${video ? 'on' : 'off'}',
      );
    },
    skip: !vodAvailable,
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
