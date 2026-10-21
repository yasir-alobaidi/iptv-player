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

String? _focused() => FocusManager.instance.primaryFocus?.debugLabel;

/// The control with the focus, by the name it gives assistive technology.
String? _control() => FocusManager.instance.primaryFocus?.context
    ?.findAncestorWidgetOfExactType<FocusableSurface>()
    ?.semanticLabel;

/// The focus is on one of the next-episode card's buttons.
bool _focusOnCard() =>
    FocusManager.instance.primaryFocus?.context
        ?.findAncestorWidgetOfExactType<NextEpisodeCard>() !=
    null;

/// [text] on the card: a button's label starts with it ("Next episode ·
/// 33").
Finder _onCard(String text) => find.descendant(
  of: find.byType(NextEpisodeCard),
  matching: find.byWidgetPredicate(
    (widget) => widget is Text && (widget.data?.startsWith(text) ?? false),
  ),
);

List<String> _seeks(_Vod t) => [
  for (final c in t.rig.engine.calls)
    if (c.startsWith('seek:')) c,
];

/// How far a file's OSD has faded in: 1 shown, 0 hidden.
double _osd(WidgetTester tester) => tester
    .widget<AnimatedOpacity>(
      find.ancestor(
        of: find.byType(VodOsdBottom),
        matching: find.byType(AnimatedOpacity),
      ),
    )
    .opacity;

/// Tab until [control] has the focus (on the next-episode card when
/// [onCard]; a label that starts with [control]).
Future<void> _tabTo(
  WidgetTester tester,
  String control, {
  bool onCard = false,
}) async {
  bool there() =>
      (_control()?.startsWith(control) ?? false) && (!onCard || _focusOnCard());
  for (var i = 0; i < 40 && !there(); i++) {
    await tester.sendKeyEvent(LogicalKeyboardKey.tab);
    await tester.pump();
  }
  await settle(tester);
  expect(there(), isTrue, reason: 'Tab reaches $control');
}

/// Plays a film on from [from] for [seconds], a second at a time (a
/// picture that stands still for 8 s is a stall).
Future<void> _playOn(
  _Vod t,
  WidgetTester tester, {
  required Duration from,
  required int seconds,
}) async {
  for (var s = 1; s <= seconds; s++) {
    t.rig.engine.progress(from + Duration(seconds: s));
    await tester.pump(const Duration(seconds: 1));
  }
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

    _vodTest('until the picture comes the OSD stays up over the opening '
        'screen, which alone says how it goes', (tester, t) async {
      // A resume: "Resumed from" waits for the picture at its place.
      await t.open(
        tester,
        '/movies/src-1/501',
        before: () => t.progress.save(
          const MovieRef('src-1', '501'),
          position: const Duration(minutes: 24, seconds: 10),
          duration: _hour,
        ),
      );
      await _key(tester, LogicalKeyboardKey.enter);

      expect(find.text('Preparing…'), findsOneWidget);
      expect(
        find.descendant(
          of: find.byType(VodOsdBottom),
          matching: find.text('Preparing…'),
        ),
        findsNothing,
      );
      expect(find.textContaining('Resumed from'), findsNothing);
      await tester.pump(const Duration(seconds: 5));
      expect(find.text('Still connecting…'), findsOneWidget);
      expect(find.text('Preparing…'), findsNothing);
      final osd = tester.widget<AnimatedOpacity>(
        find.ancestor(
          of: find.byType(VodOsdTop),
          matching: find.byType(AnimatedOpacity),
        ),
      );
      expect(osd.opacity, 1);

      await t.firstFrame(tester);
      expect(find.text('Still connecting…'), findsNothing);
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

    _vodTest('←/→ and Shift seek as each key is let go (ADR-048); Space '
        "pauses; the live player's zapping keys do nothing", (tester, t) async {
      await t.open(tester, '/movies/src-1/501');
      await _key(tester, LogicalKeyboardKey.enter);
      await t.firstFrame(tester);
      t.rig.engine.progress(const Duration(minutes: 5));
      await settle(tester);
      List<String> seeks() => [
        for (final c in t.rig.engine.calls)
          if (c.startsWith('seek:')) c,
      ];

      // Down: the bar moves; up: the seek runs, no rest waited for.
      await tester.sendKeyDownEvent(LogicalKeyboardKey.arrowRight);
      await tester.pump();
      expect(find.text('5:10'), findsWidgets);
      expect(seeks(), isEmpty);
      await tester.sendKeyUpEvent(LogicalKeyboardKey.arrowRight);
      expect(seeks(), ['seek:310000']);
      await tester.sendKeyEvent(LogicalKeyboardKey.arrowRight);
      await tester.sendKeyDownEvent(LogicalKeyboardKey.shiftLeft);
      await tester.sendKeyEvent(LogicalKeyboardKey.arrowLeft);
      await tester.sendKeyUpEvent(LogicalKeyboardKey.shiftLeft);
      await tester.pump();
      // The bar is there; the bubble still says where.
      expect(find.text('4:20'), findsWidgets);
      expect(seeks(), ['seek:310000', 'seek:320000', 'seek:260000']);
      await tester.pump(const Duration(milliseconds: 350));
      expect(seeks(), hasLength(3), reason: 'nothing left for the rest');

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
      expect(seeks(), ['seek:1810000'], reason: 'run as the key is let go');
      expect(focused(), 'seek bar', reason: "the bar's arrows are its own");

      // Held: 20 repeats at 10 s, then 30 s steps; one seek, let go.
      await tester.sendKeyDownEvent(LogicalKeyboardKey.arrowLeft);
      for (var i = 0; i < 25; i++) {
        await tester.sendKeyRepeatEvent(LogicalKeyboardKey.arrowLeft);
      }
      expect(seeks(), hasLength(1), reason: 'nothing while it is held');
      await tester.sendKeyUpEvent(LogicalKeyboardKey.arrowLeft);
      await tester.pump();
      // 1810 − 10 − 19 × 10 − 6 × 30 = 1430 s.
      expect(find.text('23:50'), findsNWidgets(2));
      expect(seeks(), ['seek:1810000', 'seek:1430000']);
      await tester.pump(const Duration(milliseconds: 350));
      expect(seeks(), hasLength(2));

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

    _vodTest("an open menu holds the OSD up (its keys aren't the player's); "
        'after a choice the focus is back on its button, and the OSD hides '
        'as usual', (tester, t) async {
      await play(tester, t);
      const from = Duration(minutes: 5);
      final wait = PlayerScreen.osdFocusTimeout.inSeconds + 1;

      await _tabTo(tester, 'Picture size: Fit');
      await _key(tester, LogicalKeyboardKey.enter);
      expect(find.text('Fill (crop)'), findsOneWidget);
      await _playOn(t, tester, from: from, seconds: wait);
      expect(_osd(tester), 1);
      expect(find.text('Fill (crop)'), findsOneWidget);

      await _key(tester, LogicalKeyboardKey.arrowDown);
      await _key(tester, LogicalKeyboardKey.enter);
      expect(t.rig.engine.calls, contains('aspect:fill'));
      expect(find.text('Fill (crop)'), findsNothing);
      expect(_osd(tester), 1);
      expect(_control(), 'Picture size: Fill (crop)');

      await _playOn(
        t,
        tester,
        from: from + Duration(seconds: wait),
        seconds: wait,
      );
      expect(_osd(tester), 0);
      expect(_focused(), 'player');
    });

    _vodTest('on a TV an open menu holds the OSD up too; after a choice the '
        'focus is back on its button, then the OSD hides as usual and the '
        'picture has the focus', (tester, t) async {
      await t.open(
        tester,
        '/movies/src-1/501',
        extra: [formFactorProvider.overrideWithValue(FormFactor.tv)],
      );
      await _key(tester, LogicalKeyboardKey.enter);
      await t.firstFrame(tester);
      const from = Duration(minutes: 5);
      t.rig.engine.progress(from);
      await settle(tester);
      final wait = PlayerScreen.osdFocusTimeout.inSeconds + 1;

      await _key(tester, LogicalKeyboardKey.arrowDown);
      expect(_focused(), 'player controls');
      for (var i = 0; i < 12 && _control() != 'Picture size: Fit'; i++) {
        await _key(tester, LogicalKeyboardKey.arrowRight);
      }
      expect(_control(), 'Picture size: Fit');
      await _key(tester, LogicalKeyboardKey.select);
      expect(find.text('Fill (crop)'), findsOneWidget);
      await _playOn(t, tester, from: from, seconds: wait);
      expect(_osd(tester), 1);
      expect(find.text('Fill (crop)'), findsOneWidget);

      await _key(tester, LogicalKeyboardKey.arrowDown);
      await _key(tester, LogicalKeyboardKey.select);
      expect(t.rig.engine.calls, contains('aspect:fill'));
      expect(_osd(tester), 1);
      expect(_control(), 'Picture size: Fill (crop)');

      await _playOn(
        t,
        tester,
        from: from + Duration(seconds: wait),
        seconds: wait,
      );
      expect(_osd(tester), 0);
      expect(_focused(), 'player');
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

  group('a film never has the next-episode card, its count or Next episode '
      '(ADR-033)', () {
    for (final formFactor in FormFactor.values) {
      _vodTest('${formFactor.name}: a minute and 20 s from its end', (
        tester,
        t,
      ) async {
        await t.open(
          tester,
          '/movies/src-1/501',
          extra: [formFactorProvider.overrideWithValue(formFactor)],
        );
        await _key(tester, LogicalKeyboardKey.enter);
        await t.firstFrame(tester);
        void nothing() {
          expect(find.byType(NextEpisodeCard), findsNothing);
          expect(find.text('NEXT EPISODE'), findsNothing);
          expect(find.textContaining('Next episode ·'), findsNothing);
          expect(find.text('Next episode'), findsNothing);
          expect(findByLabel('Next episode'), findsNothing);
        }

        for (final left in [61, 60, 45, 21]) {
          t.rig.engine.progress(_hour - Duration(seconds: left));
          await settle(tester);
          nothing();
        }
        // Playing on through where a count would have run.
        for (var left = 20; left >= 5; left--) {
          t.rig.engine.progress(_hour - Duration(seconds: left));
          await tester.pump(const Duration(seconds: 1));
          nothing();
        }
        expect(t.rig.engine.opened, hasLength(1));
        expect(t.app.location, playerRoutePath);
      });
    }
  });

  group('an episode', () {
    /// Series 77's page, then its primary action (Play S1 · E1): Enter on
    /// the desktop, where it has the focus; on a [tv] (whose page opens
    /// on Back) a press.
    Future<void> playFirst(
      WidgetTester tester,
      _Vod t, {
      bool tv = false,
    }) async {
      await t.open(
        tester,
        '/series/src-1/77',
        extra: [if (tv) formFactorProvider.overrideWithValue(FormFactor.tv)],
      );
      expect(find.text('Play S1 · E1'), findsOneWidget);
      if (tv) {
        await tester.tap(find.text('Play S1 · E1'));
        await settle(tester);
      } else {
        await _key(tester, LogicalKeyboardKey.enter);
      }
      await t.firstFrame(tester, length: const Duration(minutes: 45));
    }

    /// The last [seconds] of the episode start playing.
    Future<void> credits(_Vod t, WidgetTester tester, int seconds) async {
      t.rig.engine.progress(
        const Duration(minutes: 45) - Duration(seconds: seconds),
      );
      await settle(tester);
    }

    /// Plays on from [from] seconds left for [seconds], a second at a time
    /// (a picture that stands still for 8 s is a stall).
    Future<void> playOn(
      _Vod t,
      WidgetTester tester, {
      required int from,
      required int seconds,
    }) async {
      for (var s = 1; s <= seconds; s++) {
        t.rig.engine.progress(
          const Duration(minutes: 45) - Duration(seconds: from - s),
        );
        await tester.pump(const Duration(seconds: 1));
      }
    }

    _vodTest('the top says the series and S · E', (tester, t) async {
      await playFirst(tester, t);
      expect(find.text('Glass Tide'), findsOneWidget);
      expect(find.text('S1 · E1 · Low Water'), findsOneWidget);
    });

    _vodTest('at 20 s left the card says 10, a second later 9; Tab reaches '
        'Next episode, and Enter plays the next now', (tester, t) async {
      await playFirst(tester, t);
      await credits(t, tester, 20);

      expect(find.text('NEXT EPISODE'), findsOneWidget);
      expect(find.text('Ledger'), findsOneWidget);
      expect(find.text('Next episode · 10'), findsOneWidget);
      await playOn(t, tester, from: 20, seconds: 1);
      expect(find.text('Next episode · 9'), findsOneWidget);
      expect(_focused(), 'player', reason: 'the desktop card never takes it');

      await _tabTo(tester, 'Next episode', onCard: true);
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
      await playOn(t, tester, from: 19, seconds: 9);
      await settle(tester);
      expect(t.rig.engine.opened.last.url, contains('/7102.'));
    });

    _vodTest('when the count plays the next episode the player has the '
        'keyboard: Space pauses it', (tester, t) async {
      await playFirst(tester, t);
      await credits(t, tester, 20);
      await playOn(t, tester, from: 20, seconds: 10);
      expect(t.rig.engine.opened.last.url, contains('/7102.'));
      await t.firstFrame(tester, length: const Duration(minutes: 48));
      for (var i = 0; i < 4; i++) {
        await settle(tester);
      }
      expect(_focused(), 'player');
      await _key(tester, LogicalKeyboardKey.space);
      expect(t.rig.engine.calls.last, 'paused:true');
    });

    _vodTest('a page under the player that takes the focus gives it back '
        'while the player is on top', (tester, t) async {
      await playFirst(tester, t);
      expect(_focused(), 'player');
      // The series page's Play, under the player, asks for it (its
      // autofocus does, when what it would play changes).
      final under = find.byWidgetPredicate(
        (w) => w is Focus && w.focusNode?.debugLabel == 'series primary',
        skipOffstage: false,
      );
      tester.widget<Focus>(under.first).focusNode!.requestFocus();
      await settle(tester);
      expect(_focused(), 'player');
      await _key(tester, LogicalKeyboardKey.space);
      expect(t.rig.engine.calls.last, 'paused:true');
    });

    _vodTest('Esc hides it; at the end the card is back without the count, '
        'and Back to series goes to its page', (tester, t) async {
      await playFirst(tester, t);
      await credits(t, tester, 15);
      expect(find.text('Next episode · 5'), findsOneWidget);

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

    _vodTest('from a minute left the card counts: "Next episode · 50", its '
        'bar out of 50 (the user: "it should show the count down"); on the '
        'desktop the picture keeps the focus, so → seeks and Space pauses; '
        'Tab reaches Next episode, which plays it at once', (tester, t) async {
      await playFirst(tester, t);
      await credits(t, tester, 61);
      expect(find.byType(NextEpisodeCard), findsNothing);

      await credits(t, tester, 60);
      expect(find.text('NEXT EPISODE'), findsOneWidget);
      expect(find.text('Ledger'), findsOneWidget);
      expect(_onCard('Next episode'), findsOneWidget);
      expect(_onCard('Hide'), findsOneWidget);
      expect(find.text('Next episode · 50'), findsOneWidget);
      expect(_focused(), 'player');
      // The count follows the episode, and plays nothing before its end.
      await playOn(t, tester, from: 60, seconds: 15);
      expect(find.text('Next episode · 35'), findsOneWidget);
      expect(t.rig.engine.opened, hasLength(1));
      expect(_focused(), 'player');

      // The player's keys, with the card up.
      await _key(tester, LogicalKeyboardKey.arrowRight);
      await tester.pump(const Duration(milliseconds: 350));
      expect(_seeks(t), ['seek:${(45 * 60 - 35) * 1000}']);
      t.rig.engine.progress(const Duration(minutes: 45, seconds: -35));
      await settle(tester);
      await _key(tester, LogicalKeyboardKey.space);
      expect(t.rig.engine.calls.last, 'paused:true');
      expect(t.rig.engine.opened, hasLength(1));
      await _key(tester, LogicalKeyboardKey.space);
      expect(t.rig.engine.calls.last, 'paused:false');

      await _tabTo(tester, 'Next episode', onCard: true);
      await _key(tester, LogicalKeyboardKey.enter);
      expect(t.rig.engine.opened.last.url, contains('/7102.'));
    });

    _vodTest('the card stands on its own: counting, the OSD '
        'hides and shows around it, and it stays where it is', (
      tester,
      t,
    ) async {
      await playFirst(tester, t);
      await credits(t, tester, 50);
      double osd() => _osd(tester);
      Rect card() => tester.getRect(find.byType(NextEpisodeCard));
      final at = card();
      expect(osd(), 1);
      expect(
        find.ancestor(
          of: find.byType(NextEpisodeCard),
          matching: find.byType(AnimatedOpacity),
        ),
        findsNothing,
        reason: 'the card does not fade with the OSD',
      );

      await playOn(
        t,
        tester,
        from: 50,
        seconds: PlayerScreen.osdTimeout.inSeconds + 1,
      );
      expect(osd(), 0);
      expect(card(), at);
      expect(_focused(), 'player');

      // The count doesn't hold the OSD up either, and runs while it hides.
      await credits(t, tester, 20);
      expect(find.text('Next episode · 10'), findsOneWidget);
      expect(osd(), 0);
      await playOn(t, tester, from: 20, seconds: 1);
      expect(find.text('Next episode · 9'), findsOneWidget);
      expect(card(), at);

      final mouse = await tester.createGesture(kind: PointerDeviceKind.mouse);
      await mouse.addPointer(
        location: tester.getCenter(find.byType(PlayerScreen)),
      );
      await mouse.moveBy(const Offset(4, 4));
      await settle(tester);
      expect(osd(), 1);
      expect(card(), at);
      await mouse.removePointer();
    });

    _vodTest('Hide skips it: Tab reaches it and Space presses it (on the '
        "desktop the card's ←/→ still seek); the picture has the focus; no "
        'card again for this episode, nothing plays by itself, and the end '
        'card offers the next', (tester, t) async {
      await playFirst(tester, t);
      await credits(t, tester, 45);
      expect(_focused(), 'player');

      await _tabTo(tester, 'Next episode', onCard: true);
      await _key(tester, LogicalKeyboardKey.arrowRight);
      await tester.pump(const Duration(milliseconds: 350));
      expect(_seeks(t), ['seek:${(45 * 60 - 35) * 1000}']);
      expect(
        _control(),
        startsWith('Next episode'),
        reason: 'the arrow seeked',
      );
      t.rig.engine.progress(const Duration(minutes: 45, seconds: -35));
      await settle(tester);

      await _tabTo(tester, 'Hide', onCard: true);
      await _key(tester, LogicalKeyboardKey.space);
      expect(find.byType(NextEpisodeCard), findsNothing);
      expect(_focused(), 'player');
      expect(t.rig.engine.calls, isNot(contains('paused:true')));

      // Out of the last minute and back, then through the count's time.
      await credits(t, tester, 120);
      await credits(t, tester, 40);
      expect(find.byType(NextEpisodeCard), findsNothing);
      await credits(t, tester, 21);
      await playOn(t, tester, from: 21, seconds: 18);
      expect(find.byType(NextEpisodeCard), findsNothing);
      expect(t.rig.engine.opened, hasLength(1));

      await credits(t, tester, 2);
      t.rig.engine.end();
      await settle(tester);
      expect(_onCard('Play next episode'), findsOneWidget);
      expect(_onCard('Back to series'), findsOneWidget);
      expect(_control(), 'Play next episode');
      await _key(tester, LogicalKeyboardKey.enter);
      expect(t.rig.engine.opened.last.url, contains('/7102.'));
    });

    _vodTest('seeking back out of the last minute takes the card away; '
        'the last minute brings it back; Esc hides it', (tester, t) async {
      await playFirst(tester, t);
      await credits(t, tester, 50);
      expect(find.byType(NextEpisodeCard), findsOneWidget);

      await credits(t, tester, 90);
      expect(find.byType(NextEpisodeCard), findsNothing);
      expect(_focused(), 'player');

      await credits(t, tester, 40);
      expect(_onCard('Next episode'), findsOneWidget);
      expect(_focused(), 'player');

      await _key(tester, LogicalKeyboardKey.escape);
      expect(find.byType(NextEpisodeCard), findsNothing);
      expect(t.app.location, playerRoutePath, reason: 'Esc only hid it');
      expect(_focused(), 'player');
    });

    _vodTest('on a TV the card takes the focus: ←/→ move between its two '
        "buttons and don't seek; OK plays the next", (tester, t) async {
      await playFirst(tester, t, tv: true);
      await credits(t, tester, 50);
      expect(_focusOnCard(), isTrue);
      expect(_control(), startsWith('Next episode'));

      await _key(tester, LogicalKeyboardKey.arrowRight);
      expect(_control(), 'Hide');
      await _key(tester, LogicalKeyboardKey.arrowRight);
      expect(_control(), 'Hide');
      await _key(tester, LogicalKeyboardKey.arrowLeft);
      expect(_control(), startsWith('Next episode'));
      await tester.pump(const Duration(milliseconds: 350));
      expect(_seeks(t), isEmpty);

      await _key(tester, LogicalKeyboardKey.select);
      expect(t.rig.engine.opened.last.url, contains('/7102.'));
    });

    _vodTest('on a TV, scrubbing on the seek bar into the last minute: → '
        "keeps seeking, the card doesn't take the focus; when the OSD hides, "
        "the card's first button has it", (tester, t) async {
      await playFirst(tester, t, tv: true);
      await credits(t, tester, 80);
      await _key(tester, LogicalKeyboardKey.arrowDown);
      expect(_focused(), 'player controls');
      await _key(tester, LogicalKeyboardKey.arrowUp);
      expect(_focused(), 'seek bar');

      Future<void> scrub(int toLeft) async {
        await _key(tester, LogicalKeyboardKey.arrowRight);
        await tester.pump(const Duration(milliseconds: 350));
        expect(_seeks(t).last, 'seek:${(45 * 60 - toLeft) * 1000}');
        t.rig.engine.progress(Duration(seconds: 45 * 60 - toLeft));
        await settle(tester);
      }

      await scrub(70);
      expect(find.byType(NextEpisodeCard), findsNothing);
      await scrub(60);
      expect(_onCard('Next episode'), findsOneWidget);
      expect(_focused(), 'seek bar');
      await scrub(50);
      expect(_focused(), 'seek bar');

      // The OSD hides on its own (the longer wait, a control having the
      // focus): the card, still in sight, takes it.
      await playOn(
        t,
        tester,
        from: 50,
        seconds: PlayerScreen.osdFocusTimeout.inSeconds + 1,
      );
      expect(_osd(tester), 0);
      expect(_focusOnCard(), isTrue);
      expect(_control(), startsWith('Next episode'));
    });

    _vodTest('on a TV the end card takes the focus, even from one of the '
        "OSD's controls (nothing plays any more, and the OSD stays up)", (
      tester,
      t,
    ) async {
      await playFirst(tester, t, tv: true);
      await credits(t, tester, 50);
      await tester.binding.handlePopRoute();
      await settle(tester);
      expect(find.byType(NextEpisodeCard), findsNothing);
      await _key(tester, LogicalKeyboardKey.arrowDown);
      expect(_focused(), 'player controls');

      await credits(t, tester, 3);
      t.rig.engine.end();
      await settle(tester);
      expect(_focusOnCard(), isTrue);
      expect(_control(), 'Play next episode');
    });

    _vodTest('on a TV Back hides the card and gives the picture the focus; '
        'nothing plays by itself, and the end card offers the next', (
      tester,
      t,
    ) async {
      await playFirst(tester, t, tv: true);
      await credits(t, tester, 50);
      expect(_focusOnCard(), isTrue);

      await tester.binding.handlePopRoute();
      await settle(tester);
      expect(find.byType(NextEpisodeCard), findsNothing);
      expect(_focused(), 'player');
      expect(t.app.location, playerRoutePath);

      await credits(t, tester, 21);
      await playOn(t, tester, from: 21, seconds: 18);
      expect(find.byType(NextEpisodeCard), findsNothing);
      expect(t.rig.engine.opened, hasLength(1));
      t.rig.engine.end();
      await settle(tester);
      expect(_control(), 'Play next episode');
      await _key(tester, LogicalKeyboardKey.select);
      expect(t.rig.engine.opened.last.url, contains('/7102.'));
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
