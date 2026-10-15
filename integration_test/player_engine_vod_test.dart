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

  // The Bedroom TV (ADR-027): a film resumed from a panel slow to let the
  // resume's range in was "playing" at its first decoded frame, before the
  // place; the 8-second stall check then reconnected it, twice, while
  // the picture left from the channel before stayed up.
  for (final (name, id, extension) in [
    ('an MP4', firstMovieId, 'mp4'),
    ('an MKV', firstMovieId + 1, 'mkv'),
  ]) {
    testWidgets(
      '$name resumed on a panel slow to seek: no first frame before the '
      'place, and a slow seek is buffering',
      (tester) async {
        HttpOverrides.global = null;
        binding.framePolicy =
            LiveTestWidgetsFlutterBindingFramePolicy.fullyLive;
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
        final events = <(Duration, PlayerEvent)>[];
        final watch = Stopwatch();
        final subscription = engine.events.listen(
          (event) => events.add((watch.elapsed, event)),
        );
        addTearDown(subscription.cancel);
        await tester.pumpWidget(
          MaterialApp(
            home: engine.videoView(background: const Color(0xFF000000)),
          ),
        );
        Iterable<T> seen<T>() => events.map((e) => e.$2).whereType<T>();
        Duration position() =>
            seen<PlayerProgress>().lastOrNull?.position ?? Duration.zero;

        const delay = Duration(seconds: 4);
        const start = Duration(seconds: 90);
        final url =
            '${panel.movie(id, extension: extension)}'
            '?seek_delay_ms=${delay.inMilliseconds}';
        watch.start();
        await tester.runAsync(
          () => engine.open(PlayRequest(url: url, live: false, start: start)),
        );
        await _until(
          tester,
          () =>
              seen<PlayerFirstFrame>().isNotEmpty ||
              seen<PlayerFailed>().isNotEmpty,
          'the first frame',
          seconds: 40,
        );
        expect(seen<PlayerFailed>(), isEmpty, reason: '$events');
        final firstFrame = events.firstWhere((e) => e.$2 is PlayerFirstFrame);
        expect(firstFrame.$1, greaterThanOrEqualTo(delay), reason: '$events');
        // From the first frame on, the place: no position reported before it.
        final after = events.where((e) => e.$1 >= firstFrame.$1);
        await _until(
          tester,
          () => after.map((e) => e.$2).whereType<PlayerProgress>().length >= 4,
          'progress',
        );
        for (final progress
            in after.map((e) => e.$2).whereType<PlayerProgress>()) {
          expect(
            progress.position,
            greaterThanOrEqualTo(start - const Duration(seconds: 1)),
          );
        }
        final playing = position();
        await _until(
          tester,
          () => position() > playing + const Duration(seconds: 1),
          'the film to play on',
        );

        // ── A seek the panel holds back: buffering while it waits, then
        // playing from there.
        events.clear();
        final target = start + const Duration(seconds: 120);
        final sought = watch.elapsed;
        await tester.runAsync(() => engine.seek(target));
        await _until(
          tester,
          () => seen<PlayerBuffering>().any((e) => e.buffering),
          'buffering while the seek waits',
        );
        await _until(
          tester,
          () =>
              seen<PlayerBuffering>().lastOrNull?.buffering == false &&
              position() >= target,
          'the seek to land',
          seconds: 30,
        );
        final buffering = events.firstWhere(
          (e) => e.$2 is PlayerBuffering && (e.$2 as PlayerBuffering).buffering,
        );
        final landed = events.lastWhere(
          (e) =>
              e.$2 is PlayerBuffering && !(e.$2 as PlayerBuffering).buffering,
        );
        expect(landed.$1 - sought, greaterThanOrEqualTo(delay));

        // The measurement is this test's output.
        // ignore: avoid_print
        print(
          'slow panel, $name: first frame at 1:30 after '
          '${firstFrame.$1.inMilliseconds} ms (the range held '
          '${delay.inMilliseconds} ms); a seek buffering after '
          '${(buffering.$1 - sought).inMilliseconds} ms, playing after '
          '${(landed.$1 - sought).inMilliseconds} ms',
        );
      },
      skip: !vodAvailable,
      timeout: const Timeout(Duration(minutes: 2)),
    );
  }
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
