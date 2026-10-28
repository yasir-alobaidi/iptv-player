import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/misc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:iptv_player/app/destinations.dart';
import 'package:iptv_player/core/core_providers.dart';
import 'package:iptv_player/core/platform/form_factor.dart';
import 'package:iptv_player/design/components.dart';
import 'package:iptv_player/features/live_tv/presentation/live_tv_screen.dart';
import 'package:iptv_player/features/playback/presentation/player_overlays.dart';
import 'package:iptv_player/features/playback/presentation/player_screen.dart';
import 'package:iptv_player/features/playback/presentation/player_system_ui.dart';
import 'package:iptv_player/features/playback/presentation/vod_osd.dart';

import '../../app/app_harness.dart';
import '../live_tv/live_tv_fakes.dart';
import '../vod/vod_fakes.dart';
import 'support/system_ui_fakes.dart';
import 'support/vod_player_rig.dart';

/// The full-screen player on a phone or a tablet (ADR-068): a finger's
/// gestures, the screen it asks for, and Back. The desktop's and the TV's
/// own are their tests' (player_screen_test, vod_player_screen_test); a
/// test here holds each of them unchanged where a finger's differ.
void main() {
  late RecordedPlayerSystemUi screen;

  setUp(() => screen = RecordedPlayerSystemUi());

  /// What a test started, stopped at its end, pass or fail, while it still
  /// pumps: a stream left playing leaves the watchdog's timers running.
  final finishers = <Future<void> Function()>[];

  void touchTest(
    String description,
    Future<void> Function(WidgetTester tester) body,
  ) => testWidgets(description, (tester) async {
    try {
      await body(tester);
    } finally {
      for (final finish in finishers.reversed) {
        await finish();
      }
      finishers.clear();
    }
  });

  List<Override> on(FormFactor formFactor) => [
    formFactorProvider.overrideWithValue(formFactor),
    playerSystemUiProvider.overrideWithValue(screen),
  ];

  List<String> seeks(VodPlayerRig t) => [
    for (final c in t.rig.engine.calls)
      if (c.startsWith('seek:')) c,
  ];

  /// How far the film's OSD has faded in: 1 shown, 0 hidden.
  double osd(WidgetTester tester) => tester
      .widget<AnimatedOpacity>(
        find.ancestor(
          of: find.byType(VodOsdBottom),
          matching: find.byType(AnimatedOpacity),
        ),
      )
      .opacity;

  /// The picture's point [across] it (0 its left edge, 1 its right).
  Offset picture(WidgetTester tester, double across) {
    final box = tester.getRect(find.byType(PlayerScreen));
    return Offset(box.left + box.width * across, box.center.dy);
  }

  Future<void> tapAt(WidgetTester tester, Offset at) async {
    await tester.tapAt(at);
    // A tap waits to see whether it is the first of two.
    await tester.pump(const Duration(milliseconds: 350));
    await settle(tester);
  }

  Future<void> doubleTapAt(WidgetTester tester, Offset at) async {
    await tester.tapAt(at);
    await tester.pump(const Duration(milliseconds: 60));
    await tester.tapAt(at);
    await tester.pump();
  }

  /// A film playing 5 minutes in, on [formFactor] (a tablet's window: the
  /// gestures are the device's, not the window's).
  Future<VodPlayerRig> playFilm(
    WidgetTester tester, {
    FormFactor formFactor = FormFactor.mobile,
  }) async {
    final t = VodPlayerRig();
    finishers.add(() => t.finish(tester));
    await t.open(
      tester,
      '/movies/src-1/501',
      size: const Size(1280, 800),
      extra: on(formFactor),
    );
    await tester.sendKeyEvent(LogicalKeyboardKey.enter);
    await settle(tester);
    await t.firstFrame(tester);
    t.rig.engine.progress(const Duration(minutes: 5));
    await settle(tester);
    return t;
  }

  group('a film on a phone or a tablet', () {
    touchTest('a tap shows the controls and the next hides them; it never '
        'pauses', (tester) async {
      final t = await playFilm(tester);
      expect(osd(tester), 1, reason: 'up as the player opens');

      await tapAt(tester, picture(tester, 0.5));
      expect(osd(tester), 0);
      await tapAt(tester, picture(tester, 0.5));
      expect(osd(tester), 1);

      expect(t.rig.engine.calls, isNot(contains('paused:true')));
      expect(find.byType(OsdCenterPlay), findsNothing);
      // Shown by a tap, they go by themselves as ever.
      t.rig.engine.progress(const Duration(minutes: 5, seconds: 2));
      await tester.pump(PlayerScreen.osdTimeout);
      await settle(tester);
      expect(osd(tester), 0);
    });

    touchTest('a double tap on the right third goes on 10 s and says so '
        'there; another adds 10 more; the left third goes back', (
      tester,
    ) async {
      final t = await playFilm(tester);
      // The controls hidden first: a seek by a finger brings none up.
      await tapAt(tester, picture(tester, 0.5));
      expect(osd(tester), 0);

      await doubleTapAt(tester, picture(tester, 0.85));
      await settle(tester);
      expect(seeks(t), ['seek:310000']);
      expect(find.text('+10 s'), findsOneWidget);
      expect(osd(tester), 0, reason: 'the note says it, quietly');

      await doubleTapAt(tester, picture(tester, 0.85));
      await settle(tester);
      expect(seeks(t).last, 'seek:320000', reason: 'twice is 20 s');
      expect(find.text('+20 s'), findsOneWidget);
      expect(t.rig.engine.calls, isNot(contains('paused:true')));

      // The note goes a moment after the last double tap, and with it
      // nothing else comes up.
      await tester.pump(PlayerScreen.skipNoteTime);
      await settle(tester);
      expect(find.text('+20 s'), findsNothing);
      expect(osd(tester), 0);

      await doubleTapAt(tester, picture(tester, 0.1));
      await settle(tester);
      expect(seeks(t).last, 'seek:310000');
      expect(find.text('−10 s'), findsOneWidget);
      await tester.pump(PlayerScreen.skipNoteTime);
      await settle(tester);
    });

    touchTest('a double tap in the middle third is a tap, never a seek', (
      tester,
    ) async {
      final t = await playFilm(tester);
      await doubleTapAt(tester, picture(tester, 0.5));
      await settle(tester);
      expect(seeks(t), isEmpty);
      expect(osd(tester), 0, reason: 'the controls were up: they go');
      expect(t.window.changes, [true], reason: 'no full screen to toggle');
    });

    touchTest('spreading two fingers fills the screen with the picture; '
        'pinching fits it again, each said on the picture', (tester) async {
      final t = await playFilm(tester);
      final middle = picture(tester, 0.5);

      Future<void> pinch(double from, double to) async {
        final a = await tester.startGesture(middle - Offset(from, 0));
        final b = await tester.startGesture(middle + Offset(from, 0));
        await tester.pump();
        for (var i = 1; i <= 4; i++) {
          final step = (to - from) / 4;
          await a.moveBy(Offset(-step, 0));
          await b.moveBy(Offset(step, 0));
          await tester.pump(const Duration(milliseconds: 16));
        }
        await a.up();
        await b.up();
        await settle(tester);
      }

      await pinch(60, 160);
      expect(t.rig.engine.calls, contains('aspect:fill'));
      expect(find.text('Picture size: Fill (crop)'), findsOneWidget);
      expect(findByLabel('Picture size: Fill (crop)'), findsOneWidget);

      await pinch(160, 60);
      expect(t.rig.engine.calls.last, 'aspect:fit');
      expect(find.text('Picture size: Fit'), findsOneWidget);
      await tester.pump(PlayerScreen.pinchNoteTime);
      await settle(tester);
      expect(find.text('Picture size: Fit'), findsNothing);
    });

    touchTest('the seek bar follows a finger dragged along it', (tester) async {
      final t = await playFilm(tester);
      final bar = find.byWidgetPredicate(
        (widget) => widget is AppSlider && widget.semanticLabel == 'Position',
      );
      final track = tester.getRect(find.byType(Slider).first);
      expect(
        find.descendant(of: bar, matching: find.byType(Slider)),
        findsOneWidget,
      );
      final from = tester.getCenter(
        find.descendant(of: bar, matching: find.byType(Slider)),
      );
      // To three quarters of the way along: 45 minutes of the hour.
      final gesture = await tester.startGesture(from);
      await gesture.moveTo(
        Offset(track.left + track.width * 0.75, from.dy),
        timeStamp: const Duration(milliseconds: 100),
      );
      await tester.pump();
      await gesture.up();
      await settle(tester);
      final seek = int.parse(seeks(t).last.split(':').last);
      expect(
        seek,
        inInclusiveRange(40 * 60 * 1000, 46 * 60 * 1000),
        reason: 'about three quarters of an hour (the thumb has a margin)',
      );
    });
  });

  group("a phone's or a tablet's screen", () {
    Future<void> openBare(WidgetTester tester, Size size) async {
      final live = LiveTvFakes();
      addTearDown(() => tester.runAsync(live.db.close));
      await tester.runAsync(live.seed);
      await pumpApp(
        tester,
        size: size,
        initialLocation: playerRoutePath,
        overrides: [...live.overrides, ...on(FormFactor.mobile)],
      );
      await settle(tester);
    }

    touchTest('a phone turns the player on its side with the system bars '
        'hidden, and leaving gives both back', (tester) async {
      await openBare(tester, const Size(360, 780));
      expect(screen.calls, ['enter landscape']);

      // Turned: the player is the same, and asks nothing again.
      tester.view.physicalSize = const Size(780, 360);
      await settle(tester);
      expect(screen.calls, ['enter landscape']);

      await tester.pumpWidget(const SizedBox.shrink());
      expect(screen.calls, ['enter landscape', 'leave']);
    });

    touchTest('a tablet stays as it is held, the system bars hidden', (
      tester,
    ) async {
      await openBare(tester, const Size(800, 1280));
      expect(screen.calls, ['enter']);
      await tester.pumpWidget(const SizedBox.shrink());
      expect(screen.calls, ['enter', 'leave']);
    });

    touchTest('leaving with Back gives the screen back too', (tester) async {
      final t = await playFilm(tester);
      expect(screen.calls, ['enter']);
      await tester.binding.handlePopRoute();
      await settle(tester);
      expect(t.app.location, isNot(playerRoutePath));
      expect(screen.calls, ['enter', 'leave']);
    });
  });

  group('a channel on a phone or a tablet', () {
    late LiveTvFakes live;
    late AppUnderTest app;

    Future<void> openChannel(WidgetTester tester) async {
      live = LiveTvFakes();
      addTearDown(() => tester.runAsync(live.db.close));
      await tester.runAsync(live.seed);
      app = await pumpApp(
        tester,
        initialLocation: AppDestination.liveTv.path,
        size: const Size(1280, 800),
        overrides: [...live.overrides, ...on(FormFactor.mobile)],
      );
      await settle(tester);
      await tester.tap(find.text('Arena Sports 1').first);
      await settle(tester);
      await tester.sendKeyEvent(LogicalKeyboardKey.enter);
      await settle(tester);
      live.rig.engine.firstFrame();
      await settle(tester);
      finishers.add(() async {
        await tester.pump(const Duration(seconds: 4));
        await live.rig.coordinator.stop();
        await settle(tester);
      });
    }

    double channelOsd(WidgetTester tester) => tester
        .widget<AnimatedOpacity>(
          find
              .ancestor(
                of: find.byType(OsdBottom),
                matching: find.byType(AnimatedOpacity),
              )
              .first,
        )
        .opacity;

    touchTest('a tap shows and hides the controls at once (no double tap '
        'to wait for)', (tester) async {
      await openChannel(tester);
      expect(channelOsd(tester), 1);
      await tester.tapAt(tester.getCenter(find.byType(PlayerScreen)));
      await tester.pump();
      await settle(tester);
      expect(channelOsd(tester), 0);
      await tester.tapAt(tester.getCenter(find.byType(PlayerScreen)));
      await tester.pump();
      await settle(tester);
      expect(channelOsd(tester), 1);
    });

    touchTest("the system's Back closes an open menu first, then the "
        'channel panel, then leaves the player', (tester) async {
      await openChannel(tester);

      await tester.tap(findByLabel('Audio'));
      await settle(tester);
      expect(find.byType(AppMenu), findsOneWidget);
      await tester.binding.handlePopRoute();
      await settle(tester);
      expect(find.byType(AppMenu), findsNothing);
      expect(app.location, playerRoutePath);

      await tester.tap(findByLabel('Channels'));
      await settle(tester);
      expect(find.byType(ChannelPanel), findsOneWidget);
      await tester.binding.handlePopRoute();
      await settle(tester);
      expect(find.byType(ChannelPanel), findsNothing);
      expect(app.location, playerRoutePath);

      await tester.binding.handlePopRoute();
      await settle(tester);
      expect(app.location, AppDestination.liveTv.path);
    });

    touchTest('a tap on the picture beside the channel panel closes it', (
      tester,
    ) async {
      await openChannel(tester);
      await tester.tap(findByLabel('Channels'));
      await settle(tester);
      expect(find.byType(ChannelPanel), findsOneWidget);

      await tester.tapAt(picture(tester, 0.8));
      await tester.pump();
      await settle(tester);
      expect(find.byType(ChannelPanel), findsNothing);
      expect(app.location, playerRoutePath);
    });
  });

  group('the desktop and the TV are as they were', () {
    touchTest('on the desktop a click on a film pauses it, and the phone '
        "screen's seam is never asked", (tester) async {
      final t = await playFilm(tester, formFactor: FormFactor.desktop);
      await tapAt(tester, picture(tester, 0.85));
      expect(t.rig.engine.calls, contains('paused:true'));
      expect(seeks(t), isEmpty);
      expect(screen.calls, isEmpty);
    });

    touchTest('on the desktop a double click is full screen, not a seek', (
      tester,
    ) async {
      final t = await playFilm(tester, formFactor: FormFactor.desktop);
      await doubleTapAt(tester, picture(tester, 0.85));
      await tester.pump(const Duration(milliseconds: 350));
      await settle(tester);
      expect(t.window.changes, [true, false]);
      expect(seeks(t), isEmpty);
      expect(find.text('+10 s'), findsNothing);
    });

    touchTest("on a TV OK still pauses a film, and the phone screen's "
        'seam is never asked', (tester) async {
      final t = await playFilm(tester, formFactor: FormFactor.tv);
      await tester.pump(const Duration(seconds: 4));
      await tester.sendKeyEvent(LogicalKeyboardKey.select);
      await settle(tester);
      expect(t.rig.engine.calls, contains('paused:true'));
      expect(screen.calls, isEmpty);
    });
  });
}
