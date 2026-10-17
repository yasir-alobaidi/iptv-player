import 'dart:async';

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:iptv_player/core/core_providers.dart';
import 'package:iptv_player/core/library/library_item.dart';
import 'package:iptv_player/core/platform/form_factor.dart';
import 'package:iptv_player/core/result.dart';
import 'package:iptv_player/design/components.dart';
import 'package:iptv_player/features/live_tv/presentation/live_tv_screen.dart';
import 'package:iptv_player/features/playback/domain/playable.dart';
import 'package:iptv_player/features/playback/domain/playback_state.dart';
import 'package:iptv_player/features/playback/presentation/player_overlays.dart';
import 'package:iptv_player/features/playback/presentation/player_screen.dart';
import 'package:iptv_player/features/playback/presentation/vod_launch.dart';
import 'package:iptv_player/features/playback/presentation/vod_osd.dart';
import 'package:iptv_player/features/vod/domain/watch_progress.dart';

import '../../app/app_harness.dart';
import '../vod/vod_fakes.dart';
import 'support/vod_player_rig.dart';

typedef _Vod = VodPlayerRig;

const Duration _hour = vodPlayerHour;

/// A test with a [_Vod] that is always stopped at the end, pass or fail:
/// a failed expectation otherwise leaves the watchdog's timers running,
/// and the test hangs instead of failing.
void _vodTest(
  String description,
  Future<void> Function(WidgetTester tester, _Vod t) body,
) => testWidgets(description, (tester) async {
  final t = _Vod();
  try {
    await body(tester, t);
  } finally {
    await t.finish(tester);
  }
});

Future<void> _key(
  WidgetTester tester,
  LogicalKeyboardKey key, {
  bool shift = false,
}) async {
  if (shift) await tester.sendKeyDownEvent(LogicalKeyboardKey.shiftLeft);
  await tester.sendKeyEvent(key);
  if (shift) await tester.sendKeyUpEvent(LogicalKeyboardKey.shiftLeft);
  await settle(tester);
}

void main() {
  group('a movie', () {
    _vodTest('Play opens the player on it, full screen, with its own face', (
      tester,
      t,
    ) async {
      await t.open(tester, '/movies/src-1/501');

      await _key(tester, LogicalKeyboardKey.enter);
      await t.firstFrame(tester);

      expect(t.app.location, playerRoutePath);
      expect(t.window.changes, [true]);
      final request = t.rig.engine.opened.single;
      expect(request.live, isFalse);
      expect(request.start, isNull);
      expect(find.byType(VodOsdTop), findsOneWidget);
      expect(find.byType(OsdTop), findsNothing);
      expect(find.text('The Quiet Harbor'), findsOneWidget);
      expect(find.text('LIVE'), findsNothing);
      // The seek bar, and the volume's beside its button.
      expect(
        tester
            .widgetList<AppSlider>(find.byType(AppSlider))
            .map((slider) => slider.semanticLabel),
        ['Position', 'Volume'],
      );
      expect(find.text('−1:00:00'), findsOneWidget);
      expect(findByLabel('Pause'), findsOneWidget);
    });

    _vodTest('until the picture comes the OSD stays up and says Preparing', (
      tester,
      t,
    ) async {
      await t.open(tester, '/movies/src-1/501');
      await _key(tester, LogicalKeyboardKey.enter);
      await tester.pump(const Duration(seconds: 5));

      expect(find.text('Preparing…'), findsOneWidget);
      final osd = tester.widget<AnimatedOpacity>(
        find.ancestor(
          of: find.byType(VodOsdTop),
          matching: find.byType(AnimatedOpacity),
        ),
      );
      expect(osd.opacity, 1);

      await t.firstFrame(tester);
      expect(find.text('Preparing…'), findsNothing);
    });

    _vodTest('Esc saves where it was, stops, and its page offers Resume', (
      tester,
      t,
    ) async {
      await t.open(tester, '/movies/src-1/501');
      await _key(tester, LogicalKeyboardKey.enter);
      await t.firstFrame(tester);
      t.rig.engine.progress(const Duration(minutes: 25, seconds: 3));
      await settle(tester);

      await _key(tester, LogicalKeyboardKey.escape);

      expect(t.app.location, '/movies/src-1/501');
      expect(t.window.changes, [true, false]);
      expect(t.rig.state, isA<PlaybackIdle>());
      expect(t.rig.engine.calls, contains('stop'));
      final mark = await tester.runAsync(
        () => t.progress.watch(const MovieRef('src-1', '501')).first,
      );
      expect(mark?.position, const Duration(minutes: 25, seconds: 3));
      expect(mark?.duration, _hour);
      expect(find.text('Resume from 25:03'), findsOneWidget);
    });

    _vodTest('Resume opens where it was left and says so for 5 s; Home '
        'starts over', (tester, t) async {
      await t.open(
        tester,
        '/movies/src-1/501',
        before: () => t.progress.save(
          const MovieRef('src-1', '501'),
          position: const Duration(minutes: 24, seconds: 10),
          duration: _hour,
        ),
      );
      expect(find.text('Resume from 24:10'), findsOneWidget);

      await _key(tester, LogicalKeyboardKey.enter);
      await t.firstFrame(tester);

      expect(
        t.rig.engine.opened.single.start,
        const Duration(minutes: 24, seconds: 10),
      );
      expect(
        find.text('Resumed from 24:10 · Home starts over'),
        findsOneWidget,
      );
      await tester.pump(const Duration(seconds: 5));
      expect(find.textContaining('Resumed from'), findsNothing);

      await _key(tester, LogicalKeyboardKey.home);
      expect(t.rig.engine.calls, contains('seek:0'));
    });

    _vodTest('Start over opens at the start', (tester, t) async {
      await t.open(
        tester,
        '/movies/src-1/501',
        before: () => t.progress.save(
          const MovieRef('src-1', '501'),
          position: const Duration(minutes: 24),
          duration: _hour,
        ),
      );
      await tester.tap(find.text('Start over'));
      await settle(tester);
      await t.firstFrame(tester);

      expect(t.rig.engine.opened.single.start, isNull);
      expect(find.textContaining('Resumed from'), findsNothing);
    });

    _vodTest('←/→ and Shift seek once the keys rest; Space pauses; the '
        "live player's zapping keys do nothing", (tester, t) async {
      await t.open(tester, '/movies/src-1/501');
      await _key(tester, LogicalKeyboardKey.enter);
      await t.firstFrame(tester);
      t.rig.engine.progress(const Duration(minutes: 5));
      await settle(tester);
      List<String> seeks() => [
        for (final c in t.rig.engine.calls)
          if (c.startsWith('seek:')) c,
      ];

      await tester.sendKeyEvent(LogicalKeyboardKey.arrowRight);
      await tester.sendKeyEvent(LogicalKeyboardKey.arrowRight);
      await tester.sendKeyDownEvent(LogicalKeyboardKey.shiftLeft);
      await tester.sendKeyEvent(LogicalKeyboardKey.arrowLeft);
      await tester.sendKeyUpEvent(LogicalKeyboardKey.shiftLeft);
      await tester.pump();
      // The bar is already there; the bubble says where.
      expect(find.text('4:20'), findsWidgets);
      expect(seeks(), isEmpty);
      await tester.pump(const Duration(milliseconds: 350));
      expect(seeks(), ['seek:260000']);

      await _key(tester, LogicalKeyboardKey.space);
      expect(t.rig.engine.calls, contains('paused:true'));
      expect(findByLabel('Play'), findsOneWidget);
      await _key(tester, LogicalKeyboardKey.space);
      expect(t.rig.engine.calls.last, 'paused:false');

      await _key(tester, LogicalKeyboardKey.arrowDown);
      await _key(tester, LogicalKeyboardKey.digit4);
      await tester.pump(const Duration(seconds: 2));
      expect(t.rig.engine.opened, hasLength(1));
      expect(t.app.location, playerRoutePath);
    });

    _vodTest('on a TV a movie has no Download (ADR-025: no downloads '
        'there); the desktop has it', (tester, t) async {
      await t.open(
        tester,
        '/movies/src-1/501',
        extra: [formFactorProvider.overrideWithValue(FormFactor.tv)],
      );
      expect(find.text('Download'), findsNothing);
      expect(findByLabel('Play'), findsWidgets);
    });

    _vodTest('on a TV: OK pauses and plays on; ←/→ seek; ↑/↓ reach the '
        "controls on Play, whose arrows don't seek; Back gives the picture "
        'the focus again', (tester, t) async {
      String? focused() => FocusManager.instance.primaryFocus?.debugLabel;
      await t.open(
        tester,
        '/movies/src-1/501',
        extra: [formFactorProvider.overrideWithValue(FormFactor.tv)],
      );
      await _key(tester, LogicalKeyboardKey.enter);
      await t.firstFrame(tester);
      t.rig.engine.progress(const Duration(minutes: 5));
      await settle(tester);
      List<String> seeks() => [
        for (final c in t.rig.engine.calls)
          if (c.startsWith('seek:')) c,
      ];
      expect(focused(), 'player');
      // No volume on a TV: the remote's works the TV.
      expect(
        tester
            .widgetList<AppSlider>(find.byType(AppSlider))
            .map((slider) => slider.semanticLabel),
        ['Position'],
      );

      await _key(tester, LogicalKeyboardKey.select);
      expect(t.rig.engine.calls, contains('paused:true'));
      expect(findByLabel('Play'), findsOneWidget);
      await _key(tester, LogicalKeyboardKey.select);
      expect(t.rig.engine.calls.last, 'paused:false');

      await _key(tester, LogicalKeyboardKey.arrowRight);
      await tester.pump(const Duration(milliseconds: 350));
      expect(seeks(), ['seek:310000']);

      await _key(tester, LogicalKeyboardKey.arrowDown);
      expect(focused(), 'player controls');
      expect(t.rig.engine.calls, isNot(contains(startsWith('volume'))));
      await _key(tester, LogicalKeyboardKey.arrowRight);
      await tester.pump(const Duration(milliseconds: 350));
      expect(focused(), isNot('player controls'));
      expect(seeks(), hasLength(1), reason: 'the arrows move the focus');
      // OK on Back 10 seconds.
      await _key(tester, LogicalKeyboardKey.select);
      await tester.pump(const Duration(milliseconds: 350));
      expect(seeks(), hasLength(2));

      await tester.binding.handlePopRoute();
      await settle(tester);
      expect(focused(), 'player');
      expect(t.app.location, playerRoutePath);
    });

    _vodTest('on a TV the seek bar is a stop above Play: ←/→ there seek, a '
        'hold in growing steps; OK after seeking goes there and plays; Down '
        'goes back to Play', (tester, t) async {
      String? focused() => FocusManager.instance.primaryFocus?.debugLabel;
      AppSlider bar() => tester.widget<AppSlider>(
        find.byWidgetPredicate(
          (w) => w is AppSlider && w.semanticLabel == 'Position',
        ),
      );
      await t.open(
        tester,
        '/movies/src-1/501',
        extra: [formFactorProvider.overrideWithValue(FormFactor.tv)],
      );
      await _key(tester, LogicalKeyboardKey.enter);
      await t.firstFrame(tester);
      t.rig.engine.progress(const Duration(minutes: 30));
      await settle(tester);
      List<String> seeks() => [
        for (final c in t.rig.engine.calls)
          if (c.startsWith('seek:')) c,
      ];

      await _key(tester, LogicalKeyboardKey.arrowDown);
      expect(focused(), 'player controls');
      expect(bar().focused, isFalse);
      await _key(tester, LogicalKeyboardKey.arrowUp);
      expect(focused(), 'seek bar');
      // It grows, and says where it is.
      expect(bar().focused, isTrue);
      expect(find.text('30:00'), findsNWidgets(2));

      await tester.sendKeyEvent(LogicalKeyboardKey.arrowRight);
      await tester.pump();
      expect(find.text('30:10'), findsNWidgets(2));
      expect(seeks(), isEmpty);
      await tester.pump(const Duration(milliseconds: 350));
      expect(seeks(), ['seek:1810000']);
      expect(focused(), 'seek bar', reason: "the bar's arrows are its own");

      // Held: 20 repeats at 10 s, then 30 s steps; one seek, let go.
      await tester.sendKeyDownEvent(LogicalKeyboardKey.arrowLeft);
      for (var i = 0; i < 25; i++) {
        await tester.sendKeyRepeatEvent(LogicalKeyboardKey.arrowLeft);
      }
      await tester.sendKeyUpEvent(LogicalKeyboardKey.arrowLeft);
      await tester.pump();
      // 1810 − 10 − 19 × 10 − 6 × 30 = 1430 s.
      expect(find.text('23:50'), findsNWidgets(2));
      expect(seeks(), hasLength(1));
      await tester.pump(const Duration(milliseconds: 350));
      expect(seeks().last, 'seek:1430000');

      // OK with nothing waiting pauses; after a step it goes there now
      // and plays on.
      await _key(tester, LogicalKeyboardKey.select);
      expect(t.rig.engine.calls.last, 'paused:true');
      expect(focused(), 'seek bar');
      await tester.sendKeyEvent(LogicalKeyboardKey.arrowRight);
      await tester.pump();
      await tester.sendKeyEvent(LogicalKeyboardKey.select);
      await tester.pump();
      expect(seeks().last, 'seek:1440000');
      expect(t.rig.engine.calls.last, 'paused:false');

      await _key(tester, LogicalKeyboardKey.arrowDown);
      expect(focused(), 'player controls');
      expect(bar().focused, isFalse);

      // A press on the picture is still 10 s; a hold there grows too.
      await tester.binding.handlePopRoute();
      await settle(tester);
      expect(focused(), 'player');
      await tester.sendKeyDownEvent(LogicalKeyboardKey.arrowRight);
      for (var i = 0; i < 20; i++) {
        await tester.sendKeyRepeatEvent(LogicalKeyboardKey.arrowRight);
      }
      await tester.sendKeyUpEvent(LogicalKeyboardKey.arrowRight);
      await tester.pump(const Duration(milliseconds: 350));
      // 1440 + 10 + 19 × 10 + 30 = 1670 s.
      expect(seeks().last, 'seek:1670000');
    });

    _vodTest("on a TV ↑ from any of the row's controls is the seek bar, "
        'however wide the time beside it; ↓ goes back to that control', (
      tester,
      t,
    ) async {
      String? focused() => FocusManager.instance.primaryFocus?.debugLabel;
      String? control() => FocusManager.instance.primaryFocus?.context
          ?.findAncestorWidgetOfExactType<FocusableSurface>()
          ?.semanticLabel;
      await t.open(
        tester,
        '/movies/src-1/501',
        extra: [formFactorProvider.overrideWithValue(FormFactor.tv)],
      );
      await _key(tester, LogicalKeyboardKey.enter);
      // Past an hour, "1:05:00" pushes the bar's start past Play's right
      // edge: Back, at the top, was the only control straight above
      // (the user, on the Bedroom TV).
      await t.firstFrame(tester, length: const Duration(hours: 2));
      t.rig.engine.progress(const Duration(hours: 1, minutes: 5));
      await settle(tester);

      await _key(tester, LogicalKeyboardKey.arrowDown);
      expect(focused(), 'player controls');
      await _key(tester, LogicalKeyboardKey.arrowUp);
      expect(focused(), 'seek bar');
      await _key(tester, LogicalKeyboardKey.arrowDown);
      expect(focused(), 'player controls');

      await _key(tester, LogicalKeyboardKey.arrowRight);
      await _key(tester, LogicalKeyboardKey.arrowRight);
      expect(control(), 'Forward 10 seconds');
      await _key(tester, LogicalKeyboardKey.arrowUp);
      expect(focused(), 'seek bar');
      await _key(tester, LogicalKeyboardKey.arrowDown);
      expect(control(), 'Forward 10 seconds');

      // The row's far end too.
      await _key(tester, LogicalKeyboardKey.arrowUp);
      await _key(tester, LogicalKeyboardKey.arrowDown);
      for (var i = 0; i < 12; i++) {
        await _key(tester, LogicalKeyboardKey.arrowRight);
      }
      expect(control(), 'Stream info');
      await _key(tester, LogicalKeyboardKey.arrowUp);
      expect(focused(), 'seek bar');
      await _key(tester, LogicalKeyboardKey.arrowDown);
      expect(control(), 'Stream info');
    });

    _vodTest('a movie that ends goes back to its page, watched', (
      tester,
      t,
    ) async {
      await t.open(tester, '/movies/src-1/501');
      await _key(tester, LogicalKeyboardKey.enter);
      await t.firstFrame(tester);
      t.rig.engine.progress(_hour - const Duration(seconds: 2));
      t.rig.engine.end();
      await settle(tester);

      expect(t.app.location, '/movies/src-1/501');
      final mark = await tester.runAsync(
        () => t.progress.watch(const MovieRef('src-1', '501')).first,
      );
      expect(mark?.completed, isTrue);
    });

    _vodTest('leaving the player any other way stops the movie too', (
      tester,
      t,
    ) async {
      await t.open(tester, '/movies/src-1/501');
      await _key(tester, LogicalKeyboardKey.enter);
      await t.firstFrame(tester);
      t.rig.engine.progress(const Duration(minutes: 7));
      await settle(tester);

      await tester.sendKeyDownEvent(LogicalKeyboardKey.controlLeft);
      await tester.sendKeyEvent(LogicalKeyboardKey.digit2);
      await tester.sendKeyUpEvent(LogicalKeyboardKey.controlLeft);
      await settle(tester);

      expect(t.app.location, '/live');
      expect(t.rig.state, isA<PlaybackIdle>());
      final mark = await tester.runAsync(
        () => t.progress.watch(const MovieRef('src-1', '501')).first,
      );
      expect(mark?.position, const Duration(minutes: 7));
    });

    _vodTest("a movie the provider doesn't have any more says so", (
      tester,
      t,
    ) async {
      t.rig.prober.next = PlaybackProblem(
        PlaybackProblemKind.offline,
        failure: NotFoundFailure('stream: HTTP 404', 404),
      );
      await t.open(tester, '/movies/src-1/501');
      await _key(tester, LogicalKeyboardKey.enter);
      t.rig.engine.fail('404 Not Found');
      await settle(tester);

      expect(find.text('No longer available'), findsOneWidget);
      expect(
        find.textContaining(
          'This movie is no longer available from your provider.',
        ),
        findsOneWidget,
      );
      expect(find.text('Retry'), findsOneWidget);
      expect(find.text('Next episode'), findsNothing);
    });
  });

  group("a file's controls on the OSD (ADR-017)", () {
    Future<void> play(WidgetTester tester, _Vod t) async {
      await t.open(tester, '/movies/src-1/501');
      await _key(tester, LogicalKeyboardKey.enter);
      await t.firstFrame(tester);
      t.rig.engine.progress(const Duration(minutes: 5));
      await settle(tester);
    }

    _vodTest('a click on the picture pauses, and Play shows in the middle '
        'of it', (tester, t) async {
      await play(tester, t);
      expect(find.byType(OsdCenterPlay), findsNothing);

      await tester.tapAt(tester.getCenter(find.byType(PlayerScreen)));
      // A click waits to see whether it is the first of two.
      await tester.pump(const Duration(milliseconds: 350));
      await settle(tester);
      expect(t.rig.engine.calls, contains('paused:true'));
      expect(find.byType(OsdCenterPlay), findsOneWidget);

      await tester.tap(find.byType(OsdCenterPlay));
      await settle(tester);
      expect(t.rig.engine.calls.last, 'paused:false');
      expect(find.byType(OsdCenterPlay), findsNothing);
    });

    _vodTest('a hidden OSD is not rebuilt as the film plays (its time '
        'moved 4 times a second); it is up to date the moment it shows', (
      tester,
      t,
    ) async {
      await play(tester, t);
      Duration shown() => tester
          .widget<VodOsdBottom>(find.byType(VodOsdBottom))
          .timeline
          .position;
      t.rig.engine.progress(const Duration(minutes: 6));
      await settle(tester);
      expect(shown(), const Duration(minutes: 6));

      // It hides on its own, then fades out.
      await tester.pump(PlayerScreen.osdTimeout);
      await tester.pump(const Duration(seconds: 1));
      t.rig.engine.progress(const Duration(minutes: 7));
      await settle(tester);
      expect(shown(), const Duration(minutes: 6));

      // A mouse move brings it back, at the film's place.
      final mouse = await tester.createGesture(kind: PointerDeviceKind.mouse);
      await mouse.addPointer(
        location: tester.getCenter(find.byType(PlayerScreen)),
      );
      await mouse.moveBy(const Offset(4, 4));
      await tester.pump();
      expect(shown(), const Duration(minutes: 7));
      await mouse.removePointer();
    });

    _vodTest('a double click is full screen, not a pause', (tester, t) async {
      await play(tester, t);
      final picture = tester.getCenter(find.byType(PlayerScreen));

      await tester.tapAt(picture);
      await tester.pump(const Duration(milliseconds: 60));
      await tester.tapAt(picture);
      await tester.pump(const Duration(milliseconds: 350));
      await settle(tester);

      expect(t.window.changes, [true, false]);
      expect(t.rig.engine.calls, isNot(contains('paused:true')));
      expect(find.byType(PlayerScreen), findsOneWidget);
    });

    _vodTest('↑ and ↓ turn the volume', (tester, t) async {
      await play(tester, t);

      await _key(tester, LogicalKeyboardKey.arrowDown);
      await _key(tester, LogicalKeyboardKey.arrowDown);
      expect(t.rig.engine.calls.last, 'volume:90.0');
      await _key(tester, LogicalKeyboardKey.arrowUp);
      expect(t.rig.engine.calls.last, 'volume:95.0');
      expect(findByLabel('Mute, volume 95%'), findsOneWidget);
      // No channel to zap to.
      expect(t.rig.engine.opened, hasLength(1));
    });

    _vodTest('Back 10 seconds and Forward 10 seconds seek', (tester, t) async {
      await play(tester, t);
      List<String> seeks() => [
        for (final c in t.rig.engine.calls)
          if (c.startsWith('seek:')) c,
      ];

      await tester.tap(findByLabel('Forward 10 seconds'));
      await tester.pump(const Duration(milliseconds: 350));
      expect(seeks(), ['seek:310000']);

      t.rig.engine.progress(const Duration(minutes: 5, seconds: 10));
      await settle(tester);
      await tester.tap(findByLabel('Back 10 seconds'));
      await tester.tap(findByLabel('Back 10 seconds'));
      await tester.pump(const Duration(milliseconds: 350));
      expect(seeks().last, 'seek:290000');
    });

    _vodTest('Speed plays the file faster and says so; leaving the player '
        'puts it back', (tester, t) async {
      await play(tester, t);
      expect(find.text('1×'), findsOneWidget);

      await tester.tap(findByLabel('Speed'));
      await settle(tester);
      expect(find.text('1× · Normal'), findsOneWidget);
      await tester.tap(find.text('1.5×'));
      await settle(tester);

      expect(t.rig.engine.calls, contains('speed:1.5'));
      expect(find.text('1.5×'), findsOneWidget);

      await _key(tester, LogicalKeyboardKey.escape);
      expect(t.rig.engine.calls, contains('speed:1.0'));
    });

    _vodTest('Picture size sets the shape and ticks it; leaving the player '
        'puts Fit back', (tester, t) async {
      await play(tester, t);

      await tester.tap(findByLabel('Picture size: Fit'));
      await settle(tester);
      await tester.tap(find.text('Fill (crop)'));
      await settle(tester);

      expect(t.rig.engine.calls, contains('aspect:fill'));
      expect(findByLabel('Picture size: Fill (crop)'), findsOneWidget);

      await _key(tester, LogicalKeyboardKey.escape);
      expect(t.rig.engine.calls, contains('aspect:fit'));
    });

    _vodTest('a movie has no Next episode; Back leaves, saving its place', (
      tester,
      t,
    ) async {
      await play(tester, t);
      expect(findByLabel('Next episode'), findsNothing);

      await tester.tap(findByLabel('Back'));
      await settle(tester);

      expect(t.app.location, '/movies/src-1/501');
      expect(find.text('Resume from 5:00'), findsOneWidget);
    });

    _vodTest('an episode with one after it has Next episode', (
      tester,
      t,
    ) async {
      await t.open(tester, '/series/src-1/77');
      await _key(tester, LogicalKeyboardKey.enter);
      await t.firstFrame(tester, length: const Duration(minutes: 45));

      await tester.tap(findByLabel('Next episode'));
      await settle(tester);

      expect(t.rig.engine.opened.last.url, contains('/7102.'));
      await t.firstFrame(tester, length: const Duration(minutes: 48));
      expect(find.text('S1 · E2 · Ledger'), findsOneWidget);
      // The last one of the season: nothing after it.
      expect(findByLabel('Next episode'), findsNothing);
    });
  });

  group('an episode', () {
    /// Series 77's page, then its primary action (Play S1 · E1).
    Future<void> playFirst(WidgetTester tester, _Vod t) async {
      await t.open(tester, '/series/src-1/77');
      expect(find.text('Play S1 · E1'), findsOneWidget);
      await _key(tester, LogicalKeyboardKey.enter);
      await t.firstFrame(tester, length: const Duration(minutes: 45));
    }

    /// The last [seconds] of the episode start playing.
    Future<void> credits(_Vod t, WidgetTester tester, int seconds) async {
      t.rig.engine.progress(
        const Duration(minutes: 45) - Duration(seconds: seconds),
      );
      await settle(tester);
    }

    _vodTest('the top says the series and S · E', (tester, t) async {
      await playFirst(tester, t);
      expect(find.text('Glass Tide'), findsOneWidget);
      expect(find.text('S1 · E1 · Low Water'), findsOneWidget);
    });

    _vodTest('at 20 s left the card counts down, and Enter plays the next '
        'now', (tester, t) async {
      await playFirst(tester, t);
      await credits(t, tester, 19);

      expect(find.text('NEXT EPISODE'), findsOneWidget);
      expect(find.text('Ledger'), findsOneWidget);
      expect(find.text('Play now · 10'), findsOneWidget);
      await tester.pump(const Duration(seconds: 1));
      expect(find.text('Play now · 9'), findsOneWidget);

      await _key(tester, LogicalKeyboardKey.enter);
      expect(t.rig.engine.opened.last.url, contains('/7102.'));
      expect(t.rig.state.item, isA<PlayableEpisode>());
      await t.firstFrame(tester, length: const Duration(minutes: 48));
      expect(find.text('S1 · E2 · Ledger'), findsOneWidget);
      expect(find.text('NEXT EPISODE'), findsNothing);
    });

    _vodTest('at the end of the count the next plays on its own', (
      tester,
      t,
    ) async {
      await playFirst(tester, t);
      await credits(t, tester, 19);
      await tester.pump(const Duration(seconds: 10));
      await settle(tester);
      expect(t.rig.engine.opened.last.url, contains('/7102.'));
    });

    _vodTest('Esc cancels; at the end the card is back without the count, '
        'and Back to series goes to its page', (tester, t) async {
      await playFirst(tester, t);
      await credits(t, tester, 15);
      expect(find.text('Play now · 10'), findsOneWidget);

      await _key(tester, LogicalKeyboardKey.escape);
      expect(find.text('NEXT EPISODE'), findsNothing);
      expect(t.app.location, playerRoutePath, reason: 'Esc only cancelled');
      // Past where the count would have ended, playing all the while.
      for (var s = 1; s <= 12; s++) {
        t.rig.engine.progress(
          const Duration(minutes: 45) - Duration(seconds: 15 - s),
        );
        await tester.pump(const Duration(seconds: 1));
      }
      expect(t.rig.engine.opened, hasLength(1));

      t.rig.engine.end();
      await settle(tester);
      expect(find.text('Play next episode'), findsOneWidget);
      expect(find.text('Back to series'), findsOneWidget);

      await tester.tap(find.text('Back to series'));
      await settle(tester);
      expect(t.app.location, '/series/src-1/77');
      final mark = await tester.runAsync(
        () => t.progress
            .watch(const EpisodeRef('src-1', '7101', seriesKey: '77'))
            .first,
      );
      expect(mark?.completed, isTrue);
    });

    _vodTest('a failed episode offers the next one', (tester, t) async {
      await playFirst(tester, t);
      t.rig.prober.next = const PlaybackProblem(PlaybackProblemKind.offline);
      t.rig.engine.fail();
      await settle(tester);

      expect(find.text('No longer available'), findsOneWidget);
      await tester.tap(find.text('Next episode'));
      await settle(tester);
      expect(t.rig.engine.opened.last.url, contains('/7102.'));
    });
  });

  group("a file on this computer that can't be read (Phase 8 decision 8)", () {
    _vodTest('a library file offers Show in folder, which leaves full '
        'screen first, and Remove from library, which leaves the player', (
      tester,
      t,
    ) async {
      late final LibraryItem file;
      await t.open(
        tester,
        '/',
        before: () async => file = await t.addLibraryItem(),
      );
      t.rig.resolver.missingFiles.add(file.id);
      unawaited(
        PlayerVodLauncher(
          t.rig.coordinator,
          () => t.app.router,
        ).playLibraryItem(file),
      );
      await settle(tester);

      expect(t.app.location, playerRoutePath);
      expect(find.text('This file is missing or damaged'), findsOneWidget);
      expect(find.text('Retry'), findsOneWidget);

      await tester.tap(find.text('Show in folder'));
      await settle(tester);
      expect(t.reveal.shown, [file.path]);
      expect(t.window.changes.last, isFalse);

      await tester.tap(find.text('Remove from library'));
      await settle(tester);
      expect(
        await tester.runAsync(() => t.vod.db.libraryDao.itemById(file.id)),
        isNull,
      );
      expect(t.app.location, isNot(playerRoutePath));
      expect(
        find.text('Removed from the library. The file stays where it is.'),
        findsOneWidget,
      );
    });

    _vodTest("a downloaded movie's damaged file offers them too; Remove "
        'goes back to its page', (tester, t) async {
      late final LibraryItem file;
      await t.open(
        tester,
        '/movies/src-1/501',
        before: () async => file = await t.addLibraryItem(download: true),
      );
      t.rig.resolver.downloads['501'] = file.path!;
      await _key(tester, LogicalKeyboardKey.enter);
      t.rig.engine.fail('Failed to recognize file format.');
      await settle(tester);

      expect(find.text('This file is missing or damaged'), findsOneWidget);
      expect(find.text('Show in folder'), findsOneWidget);
      await tester.tap(find.text('Remove from library'));
      await settle(tester);

      expect(t.app.location, '/movies/src-1/501');
      expect(
        find.text('Removed from the library. Play uses your provider again.'),
        findsOneWidget,
      );
    });

    _vodTest("a provider's movie that fails offers neither", (tester, t) async {
      t.rig.prober.next = const PlaybackProblem(PlaybackProblemKind.offline);
      await t.open(
        tester,
        '/movies/src-1/501',
        before: () => t.addLibraryItem(download: true),
      );
      await _key(tester, LogicalKeyboardKey.enter);
      t.rig.engine.fail();
      await settle(tester);

      expect(find.text('No longer available'), findsOneWidget);
      expect(find.text('Show in folder'), findsNothing);
      expect(find.text('Remove from library'), findsNothing);
    });
  });
}
