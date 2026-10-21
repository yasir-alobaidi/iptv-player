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

  // The Bedroom TV (2026-10-18): the Subtitles menu ticked Off while mpv
  // showed the file's own pick, and still Off after a pick in it; then Off
  // left the last line on screen for good (mpv says nothing more once its
  // subtitles are off).
  testWidgets(
    'the subtitles ticked are the ones mpv shows, and Off clears the line',
    (tester) async {
      binding.framePolicy = LiveTestWidgetsFlutterBindingFramePolicy.fullyLive;
      final dir = Directory.systemTemp.createTempSync('engine_subtitles');
      addTearDown(() => dir.deleteSync(recursive: true));
      // One line each, for the whole file.
      File srt(String name, String line) =>
          File('${dir.path}/$name')
            ..writeAsStringSync('1\n00:00:00,000 --> 01:00:00,000\n$line\n');
      final english = srt('vod_h264_aac_10min.en.srt', 'An English line');
      final german = srt('vod_h264_aac_10min.de.srt', 'Eine deutsche Zeile');
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
      PlayerTracks? tracks() => events.whereType<PlayerTracks>().lastOrNull;
      Future<String> sid() async =>
          (await tester.runAsync(() => engine.mpvProperty('sid')))!;

      final film = File('${samplesDirectory.path}/vod_h264_aac_10min.mp4')
          .absolute
          .path;
      await tester.runAsync(
        () => engine.open(
          PlayRequest(
            url: film,
            live: false,
            subtitleFiles: [english.path, german.path],
            subtitleLanguages: const ['en'],
          ),
        ),
      );
      await _until(
        tester,
        () => events.any((e) => e is PlayerFirstFrame || e is PlayerFailed),
        'the first frame',
      );
      expect(events.whereType<PlayerFailed>(), isEmpty, reason: '$events');
      await _until(
        tester,
        () => (tracks()?.subtitles.length ?? 0) == 2,
        'both subtitle files as tracks',
      );

      // ── mpv's own picks are the ones ticked: its sound, and the English
      // file Preferred subtitles asked for (ADR-041: mpv 0.34 knows no
      // language for a file beside the video; the engine reads its name).
      final audio = (await tester.runAsync(() => engine.mpvProperty('aid')))!;
      expect(audio, isNot('no'));
      await _until(
        tester,
        () => tracks()?.audioId == audio,
        "mpv's sound ticked (${tracks()?.audioId} for $audio)",
      );
      String? englishId() => tracks()?.subtitles
          .where((t) => t.title?.contains('.en.') ?? false)
          .firstOrNull
          ?.id;
      await _until(
        tester,
        () => englishId() != null && tracks()?.subtitleId == englishId(),
        'English ticked (${tracks()?.subtitleId} of ${tracks()?.subtitles})',
      );
      final picked = await sid();
      expect(picked, englishId());
      if (video) {
        await _until(
          tester,
          () => find.text('An English line').evaluate().isNotEmpty,
          'the English line on screen',
        );
      }

      // ── The other one, picked: ticked, and its line replaces the first.
      final other = tracks()!.subtitles.firstWhere((t) => t.id != picked).id;
      await tester.runAsync(() => engine.selectSubtitle(other));
      await _until(
        tester,
        () => tracks()?.subtitleId == other,
        'the pick ticked (${tracks()?.subtitleId} for $other)',
      );
      expect(await sid(), other);
      if (video) {
        await _until(
          tester,
          () =>
              find.text('Eine deutsche Zeile').evaluate().isNotEmpty &&
              find.text('An English line').evaluate().isEmpty,
          'the German line in place of the English one',
        );
      }

      // ── Off: nothing ticked, and no line left on screen.
      await tester.runAsync(() => engine.selectSubtitle(null));
      await _until(
        tester,
        () => tracks()?.subtitleId == null,
        'Off ticked (${tracks()?.subtitleId})',
      );
      expect(await sid(), 'no');
      if (video) {
        await _until(
          tester,
          () => find.text('Eine deutsche Zeile').evaluate().isEmpty,
          'the line gone',
        );
      }

      // ── The next file starts from Settings, not from the last pick: mpv
      // kept the German track's number for it.
      Future<void> reopen(List<String> languages) async {
        events.clear();
        await tester.runAsync(
          () => engine.open(
            PlayRequest(
              url: film,
              live: false,
              subtitleFiles: [english.path, german.path],
              subtitleLanguages: languages,
            ),
          ),
        );
        await _until(
          tester,
          () => events.any((e) => e is PlayerFirstFrame || e is PlayerFailed),
          'the first frame again',
        );
        expect(events.whereType<PlayerFailed>(), isEmpty, reason: '$events');
        await _until(
          tester,
          () => (tracks()?.subtitles.length ?? 0) == 2,
          'both subtitle files again',
        );
      }

      await tester.runAsync(() => engine.selectSubtitle(other));
      await _until(
        tester,
        () => tracks()?.subtitleId == other,
        'German ticked',
      );
      await reopen(const ['en']);
      await _until(
        tester,
        () => tracks()?.subtitleId == englishId(),
        'English again (${tracks()?.subtitleId})',
      );

      // ── None asked for: off, with files beside the video (ADR-041; mpv
      // showed the first of them).
      await reopen(const []);
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(seconds: 1)),
      );
      await tester.pump();
      expect(await sid(), 'no');
      expect(tracks()?.subtitleId, isNull);
      if (video) expect(find.text('An English line'), findsNothing);
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

        // Both places fit CI's 120 s sample.
        const delay = Duration(seconds: 4);
        const start = Duration(seconds: 30);
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
        // playing from there. Back to before the place it resumed at,
        // which was never read: a file reads as far ahead as its bytes
        // allow (ADR-048), so a seek ahead lands in what is buffered.
        events.clear();
        final target = start - const Duration(seconds: 15);
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
              position() >= target &&
              position() < start,
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
          'slow panel, $name: first frame at ${start.inSeconds} s after '
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
