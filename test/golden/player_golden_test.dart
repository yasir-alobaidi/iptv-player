// Every test in this file is a golden; the tag is declared in
// dart_test.yaml so `flutter test --exclude-tags golden` can drop them
// on Windows.
@Tags(['golden'])
library;

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:iptv_player/app/destinations.dart';
import 'package:iptv_player/core/player/player_engine.dart';
import 'package:iptv_player/core/result.dart';
import 'package:iptv_player/features/live_tv/domain/now_next.dart';
import 'package:iptv_player/features/playback/domain/playback_state.dart';
import 'package:iptv_player/features/playback/presentation/player_screen.dart';

import '../app/app_harness.dart';
import '../features/live_tv/live_tv_fakes.dart';
import '../features/playback/support/vod_player_rig.dart';
import '../features/vod/vod_fakes.dart';
import 'golden_harness.dart';

/// The player has the focus as a whole and no Tab stops: its keys are its
/// own (docs/05's shortcut table), and the OSD coming up is how it shows
/// it is listening.
const _playerIsOneStop = {
  'no focus ring on "player"': 'the player is one stop; its keys are its own',
};

void main() {
  group('player', () {
    Future<LiveTvFakes> open(WidgetTester tester) async {
      hideDebugBanner();
      final live = LiveTvFakes();
      live.fakes.now = goldenNow();
      addTearDown(() => tester.runAsync(live.db.close));
      await tester.runAsync(live.seed);
      final now = live.fakes.now;
      live.guide.byKey['201'] = NowNext(
        now: Programme(
          title: 'Continental Cup · Semi-final',
          start: now.subtract(const Duration(minutes: 82)),
          end: now.add(const Duration(minutes: 38)),
        ),
        next: Programme(
          title: 'Match of the Week: Extended Highlights',
          start: now.add(const Duration(minutes: 38)),
          end: now.add(const Duration(minutes: 98)),
        ),
      );
      await pumpApp(
        tester,
        size: const Size(1280, 800),
        initialLocation: AppDestination.liveTv.path,
        overrides: live.overrides,
      );
      await _settle(tester);
      await tester.tap(find.text('Arena Sports 1').first);
      await _settle(tester);
      await tester.sendKeyEvent(LogicalKeyboardKey.enter);
      await _settle(tester);
      return live;
    }

    sceneTest('OSD', allow: _playerIsOneStop, (tester) async {
      final live = await open(tester);
      live.rig.engine
        ..firstFrame()
        ..emit(const PlayerVideoChanged(width: 1920, height: 1080));
      await _settle(tester);

      await golden(tester, 'images/player_osd.png');
      await tester.pump(const Duration(seconds: 4));
      await live.rig.coordinator.stop();
      await _settle(tester);
    });

    sceneTest('failure card', allow: _playerIsOneStop, (tester) async {
      final live = await open(tester);
      live.rig.prober.next = PlaybackProblem(
        PlaybackProblemKind.offline,
        failure: NotFoundFailure('stream: HTTP 404', 404),
      );
      live.rig.engine.fail();
      await _settle(tester);

      await golden(tester, 'images/player_failure.png');
      await tester.pump(const Duration(seconds: 4));
      await live.rig.coordinator.stop();
      await _settle(tester);
    });

    /// A movie or an episode in the player: its own face (ADR-017).
    Future<VodPlayerRig> play(
      WidgetTester tester,
      String location, {
      required Duration length,
      required Duration at,
      Size size = const Size(1280, 800),
    }) async {
      hideDebugBanner();
      final t = VodPlayerRig();
      t.vod.fakes.now = goldenNow();
      await t.open(tester, location, size: size);
      await tester.sendKeyEvent(LogicalKeyboardKey.enter);
      await settle(tester);
      await t.firstFrame(tester, length: length);
      t.rig.engine
        ..emit(const PlayerVideoChanged(width: 3840, height: 2160))
        ..emit(
          const PlayerTracks(
            audio: [
              MediaTrack(id: '1', language: 'eng', channels: '5.1'),
              MediaTrack(id: '2', language: 'fra', channels: 'stereo'),
            ],
            subtitles: [MediaTrack(id: '3', language: 'eng')],
            audioId: '1',
            subtitleId: '3',
          ),
        )
        ..progress(at, buffered: const Duration(minutes: 2));
      await settle(tester);
      return t;
    }

    sceneTest('a movie, paused', allow: _playerIsOneStop, (tester) async {
      final t = await play(
        tester,
        '/movies/src-1/501',
        length: vodPlayerHour,
        at: const Duration(minutes: 24, seconds: 10),
      );
      await tester.sendKeyEvent(LogicalKeyboardKey.space);
      await settle(tester);

      await golden(tester, 'images/player_movie_paused.png');
      await t.finish(tester);
    });

    sceneTest(
      'an episode in a large window, the keyboard on Subtitles',
      audit: false,
      (tester) async {
        final t = await play(
          tester,
          '/series/src-1/77',
          length: const Duration(minutes: 45),
          at: const Duration(minutes: 12, seconds: 40),
          size: const Size(1920, 1080),
        );
        // Play, back, forward, Start over, Next episode, the volume, Audio,
        // then Subtitles.
        for (var i = 0; i < 9; i++) {
          await tester.sendKeyEvent(LogicalKeyboardKey.tab);
          await tester.pump();
        }
        await settle(tester);
        await settle(tester);

        await golden(tester, 'images/player_episode_1920x1080.png');
        await t.finish(tester);
      },
    );

    sceneTest(
      "an episode's last minute: the card counting to the next episode, "
      'the OSD hidden (ADR-033)',
      // A look of its own: the hidden OSD's controls are still there to
      // focus (a TV focuses them before they fade in).
      audit: false,
      (tester) async {
        const length = Duration(minutes: 45);
        const at = Duration(minutes: 44, seconds: 10);
        final t = await play(
          tester,
          '/series/src-1/77',
          length: length,
          at: at,
        );
        // On the desktop the picture keeps the focus and the OSD hides on
        // its own; it plays on all the while (a still picture is a stall).
        for (var s = 1; s <= PlayerScreen.osdTimeout.inSeconds + 1; s++) {
          t.rig.engine.progress(
            at + Duration(seconds: s),
            buffered: const Duration(seconds: 30),
          );
          await tester.pump(const Duration(seconds: 1));
        }
        await settle(tester);

        await golden(tester, 'images/player_episode_next_offer.png');
        await t.finish(tester);
      },
    );
  }, skip: goldenSkipReason);
}

Future<void> _settle(WidgetTester tester) async {
  for (var i = 0; i < 5; i++) {
    await tester.runAsync(() => Future<void>.delayed(Duration.zero));
    await tester.pump(const Duration(milliseconds: 50));
  }
}
