import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:iptv_player/app/destinations.dart';
import 'package:iptv_player/core/core_providers.dart';
import 'package:iptv_player/core/platform/form_factor.dart';
import 'package:iptv_player/core/player/player_engine.dart';
import 'package:iptv_player/design/components.dart';
import 'package:iptv_player/features/live_tv/data/db_channel_repository.dart';
import 'package:iptv_player/features/live_tv/domain/now_next.dart';
import 'package:iptv_player/features/live_tv/presentation/live_tv_screen.dart';
import 'package:iptv_player/features/playback/presentation/player_overlays.dart';
import 'package:iptv_player/features/playback/presentation/player_screen.dart';
import 'package:iptv_player/features/playback/presentation/time_corner.dart';

import '../../app/app_harness.dart';
import '../live_tv/live_tv_fakes.dart';

void main() {
  late LiveTvFakes live;
  late AppUnderTest app;

  /// Live TV with Arena Sports 1 (201) opened full screen with Enter;
  /// [guide] what is on it now and next, [picture] false still opening.
  Future<void> open(
    WidgetTester tester, {
    FormFactor formFactor = FormFactor.desktop,
    Size size = const Size(1440, 900),
    NowNext Function(DateTime now)? guide,
    bool picture = true,
  }) async {
    live = LiveTvFakes();
    if (guide != null) live.guide.byKey['201'] = guide(live.fakes.now);
    addTearDown(() => tester.runAsync(live.db.close));
    await tester.runAsync(live.seed);
    app = await pumpApp(
      tester,
      initialLocation: AppDestination.liveTv.path,
      size: size,
      overrides: [
        ...live.overrides,
        formFactorProvider.overrideWithValue(formFactor),
      ],
    );
    await _settle(tester);
    await tester.tap(find.text('Arena Sports 1').first);
    await _settle(tester);
    await tester.sendKeyEvent(LogicalKeyboardKey.enter);
    await _settle(tester);
    if (!picture) return;
    live.rig.engine.firstFrame();
    await _settle(tester);
  }

  Future<void> finish(WidgetTester tester) async {
    await tester.pump(const Duration(seconds: 4));
    await live.rig.coordinator.stop();
    await _settle(tester);
  }

  testWidgets("the system's back (a TV remote's Back) closes stream info "
      'first, then leaves: one step a press', (tester) async {
    await open(tester);
    await tester.sendKeyEvent(LogicalKeyboardKey.keyI);
    await _settle(tester);
    expect(find.byType(StreamInfoOverlay), findsOneWidget);

    await tester.binding.handlePopRoute();
    await _settle(tester);
    expect(find.byType(StreamInfoOverlay), findsNothing);
    expect(app.location, playerRoutePath);

    await tester.binding.handlePopRoute();
    await _settle(tester);
    expect(app.location, AppDestination.liveTv.path);
    await finish(tester);
  });

  group('on a TV (docs/07)', () {
    String? focused() => FocusManager.instance.primaryFocus?.debugLabel;

    testWidgets('OK shows the controls on Channels; the arrows move between '
        'them, not through the channels, and OK presses one', (tester) async {
      await open(tester, formFactor: FormFactor.tv);
      await tester.pump(const Duration(seconds: 4));
      expect(focused(), 'player');

      await tester.sendKeyEvent(LogicalKeyboardKey.select);
      await _settle(tester);
      expect(focused(), 'player controls');

      await tester.sendKeyEvent(LogicalKeyboardKey.arrowRight);
      await _settle(tester);
      expect(focused(), isNot('player controls'));
      await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
      await _settle(tester);
      await tester.sendKeyEvent(LogicalKeyboardKey.arrowLeft);
      await _settle(tester);
      expect(focused(), 'player controls');
      await tester.pump(const Duration(milliseconds: 400));
      expect(live.rig.engine.opened, hasLength(1), reason: 'no zap');
      expect(find.byType(ChannelPanel), findsNothing);

      await tester.sendKeyEvent(LogicalKeyboardKey.select);
      await _settle(tester);
      expect(find.byType(ChannelPanel), findsOneWidget);
      await finish(tester);
    });

    for (final size in [const Size(1440, 900), const Size(960, 540)]) {
      testWidgets('→ walks every control to the last, never to the picture '
          '(the user: "I cant do anything with the remote"), at $size', (
        tester,
      ) async {
        await open(tester, formFactor: FormFactor.tv, size: size);
        await tester.sendKeyEvent(LogicalKeyboardKey.select);
        await _settle(tester);
        final walk = <String?>[];
        for (var i = 0; i < 12; i++) {
          walk.add(
            FocusManager.instance.primaryFocus?.context
                ?.findAncestorWidgetOfExactType<OsdButton>()
                ?.tooltip,
          );
          await tester.sendKeyEvent(LogicalKeyboardKey.arrowRight);
          await _settle(tester);
        }
        expect(walk.toSet().toList(), [
          'Channels',
          'Previous channel',
          'Next channel',
          'Last channel',
          'Add to favorites',
          'Audio',
          'Subtitles',
          'Picture size: Fit',
          'Stream info',
        ]);
        expect(walk.last, 'Stream info');
        await finish(tester);
      });
    }

    testWidgets('Back from a control gives the picture the focus and hides '
        'the OSD; the next Back leaves', (tester) async {
      await open(tester, formFactor: FormFactor.tv);
      await tester.sendKeyEvent(LogicalKeyboardKey.select);
      await _settle(tester);
      expect(focused(), 'player controls');

      await tester.binding.handlePopRoute();
      await _settle(tester);
      expect(focused(), 'player');
      expect(app.location, playerRoutePath);
      final osd = tester.widget<AnimatedOpacity>(
        find.ancestor(
          of: find.byType(OsdTop),
          matching: find.byType(AnimatedOpacity),
        ),
      );
      expect(osd.opacity, 0);

      // With the picture focused, ↓ zaps again.
      await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
      await tester.pump(const Duration(milliseconds: 400));
      await _settle(tester);
      expect(live.rig.engine.opened, hasLength(2));

      await tester.binding.handlePopRoute();
      await _settle(tester);
      expect(app.location, AppDestination.liveTv.path);
      await finish(tester);
    });

    testWidgets('a typed number goes with OK', (tester) async {
      await open(tester, formFactor: FormFactor.tv);
      await tester.sendKeyEvent(LogicalKeyboardKey.digit2);
      await tester.sendKeyEvent(LogicalKeyboardKey.digit0);
      await tester.sendKeyEvent(LogicalKeyboardKey.digit3);
      await _settle(tester);

      await tester.sendKeyEvent(LogicalKeyboardKey.select);
      await _settle(tester);
      expect(live.rig.engine.opened.last.url, contains('203'));
      expect(focused(), 'player');
      await finish(tester);
    });
  });

  testWidgets('Enter plays full screen; Esc goes back to Live TV', (
    tester,
  ) async {
    await open(tester);

    expect(app.location, playerRoutePath);
    expect(find.byType(PlayerScreen), findsOneWidget);
    expect(live.window.changes, [true]);
    expect(live.rig.engine.opened.single.url, contains('201'));

    await tester.sendKeyEvent(LogicalKeyboardKey.escape);
    await _settle(tester);

    expect(app.location, AppDestination.liveTv.path);
    expect(live.window.changes, [true, false]);
    // Still playing: the preview carries on.
    expect(live.rig.engine.playing, isTrue);
    await finish(tester);
  });

  testWidgets('the OSD hides after 3 s and any key brings it back', (
    tester,
  ) async {
    await open(tester);
    Finder osd() => find.byType(OsdTop);
    double opacity() => tester
        .widget<AnimatedOpacity>(
          find.ancestor(of: osd(), matching: find.byType(AnimatedOpacity)),
        )
        .opacity;

    expect(opacity(), 1);
    await tester.pump(const Duration(seconds: 3, milliseconds: 100));
    expect(opacity(), 0);

    await tester.sendKeyEvent(LogicalKeyboardKey.keyM);
    await _settle(tester);
    expect(opacity(), 1);
    expect(live.rig.engine.calls, contains('muted:true'));
    await finish(tester);
  });

  testWidgets('↓ opens the next channel at once; ↓↓ in a row shows the '
      'banner at once and opens only the last after a moment, not each '
      'between (ADR-052)', (tester) async {
    await open(tester);

    await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
    await tester.pump();
    await tester.pump();
    expect(live.rig.engine.opened, hasLength(2), reason: 'no wait');
    expect(live.rig.engine.opened.last.url, contains('202'));
    await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
    await tester.pump();
    await tester.pump();
    expect(find.byType(ChannelBanner), findsOneWidget);
    expect(find.text('203  Velocity Motors'), findsOneWidget);
    expect(live.rig.engine.opened, hasLength(2), reason: 'the keys move on');

    await tester.pump(const Duration(milliseconds: 400));
    await _settle(tester);
    expect(live.rig.engine.opened, hasLength(3));
    expect(live.rig.engine.opened.last.url, contains('203'));

    // At rest again: the next ↓ opens at once.
    await tester.pump(const Duration(milliseconds: 400));
    await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
    await tester.pump();
    await tester.pump();
    expect(live.rig.engine.opened, hasLength(4));
    await finish(tester);
  });

  testWidgets('digits reach a channel by number; Backspace goes back', (
    tester,
  ) async {
    await open(tester);

    await tester.sendKeyEvent(LogicalKeyboardKey.digit9);
    await _settle(tester);
    await tester.sendKeyEvent(LogicalKeyboardKey.digit0);
    await _settle(tester);
    await tester.sendKeyEvent(LogicalKeyboardKey.digit0);
    await _settle(tester);
    expect(find.byType(NumberEntry), findsOneWidget);
    expect(find.text('900_'), findsOneWidget);
    expect(find.text('Zebra TV'), findsWidgets);

    await tester.pump(const Duration(milliseconds: 1600));
    await _settle(tester);
    expect(find.byType(NumberEntry), findsNothing);
    expect(live.rig.engine.opened.last.url, contains('900'));

    live.rig.engine.firstFrame();
    await tester.sendKeyEvent(LogicalKeyboardKey.backspace);
    await _settle(tester);
    expect(live.rig.engine.opened.last.url, contains('201'));
    await finish(tester);
  });

  testWidgets('← opens the channel panel; Enter plays from it; → closes', (
    tester,
  ) async {
    await open(tester);

    await tester.sendKeyEvent(LogicalKeyboardKey.arrowLeft);
    await _settle(tester);
    expect(find.byType(ChannelPanel), findsOneWidget);

    await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
    await _settle(tester);
    // The arrow moved in the panel; it didn't zap.
    expect(find.byType(ChannelBanner), findsNothing);
    await tester.pump(const Duration(milliseconds: 400));
    expect(live.rig.engine.opened, hasLength(1));
    await tester.sendKeyEvent(LogicalKeyboardKey.enter);
    await _settle(tester);
    expect(find.byType(ChannelPanel), findsNothing);
    expect(live.rig.engine.opened.last.url, contains('202'));

    await tester.sendKeyEvent(LogicalKeyboardKey.arrowLeft);
    await _settle(tester);
    await tester.sendKeyEvent(LogicalKeyboardKey.arrowRight);
    await _settle(tester);
    expect(find.byType(ChannelPanel), findsNothing);
    await finish(tester);
  });

  testWidgets('I shows the stream info, with the address masked', (
    tester,
  ) async {
    await open(tester);
    live.rig.engine.info = const StreamInfo(
      width: 1920,
      height: 1080,
      fps: 50,
      videoCodec: 'h264',
      hardwareDecoder: 'vaapi',
      audioCodec: 'aac',
      audioChannels: 2,
      droppedFrames: 0,
    );

    await tester.sendKeyEvent(LogicalKeyboardKey.keyI);
    await _settle(tester);

    expect(find.byType(StreamInfoOverlay), findsOneWidget);
    expect(find.text('1920×1080 · 50 fps · h264'), findsOneWidget);
    expect(find.text('vaapi (hardware)'), findsOneWidget);
    expect(find.textContaining('/live/***/***/'), findsOneWidget);
    // Nothing said about the colour when the player knows none.
    expect(find.text('Colour'), findsNothing);
    await finish(tester);
  });

  testWidgets("stream info names an HDR picture's transfer and primaries", (
    tester,
  ) async {
    await open(tester);
    live.rig.engine.info = const StreamInfo(
      width: 3840,
      height: 2160,
      transfer: 'pq',
      primaries: 'bt.2020',
    );

    await tester.sendKeyEvent(LogicalKeyboardKey.keyI);
    await _settle(tester);

    expect(find.text('Colour'), findsOneWidget);
    expect(find.text('HDR10 · pq · bt.2020'), findsOneWidget);
    await finish(tester);
  });

  testWidgets('stream info calls an ordinary picture SDR', (tester) async {
    await open(tester);
    live.rig.engine.info = const StreamInfo(
      width: 1920,
      height: 1080,
      transfer: 'bt.1886',
      primaries: 'bt.709',
    );

    await tester.sendKeyEvent(LogicalKeyboardKey.keyI);
    await _settle(tester);

    expect(find.text('SDR · bt.1886 · bt.709'), findsOneWidget);
    await finish(tester);
  });

  group('the controls on the OSD (ADR-017)', () {
    testWidgets('Back leaves the player, as Esc does', (tester) async {
      await open(tester);

      await tester.tap(findByLabel('Back'));
      await _settle(tester);

      expect(app.location, AppDestination.liveTv.path);
      expect(live.window.changes, [true, false]);
      expect(live.rig.engine.playing, isTrue);
      await finish(tester);
    });

    testWidgets('+ and − turn the volume; the wheel does too', (tester) async {
      await open(tester);

      await tester.sendKeyEvent(LogicalKeyboardKey.minus);
      await tester.sendKeyEvent(LogicalKeyboardKey.minus);
      await _settle(tester);
      expect(
        live.rig.engine.calls,
        containsAllInOrder(['volume:95.0', 'volume:90.0']),
      );
      expect(findByLabel('Mute, volume 90%'), findsOneWidget);

      await tester.sendKeyEvent(LogicalKeyboardKey.equal);
      await _settle(tester);
      expect(live.rig.engine.calls.last, 'volume:95.0');

      // A notch of the wheel over the picture: down is quieter.
      final picture = tester.getCenter(find.byType(PlayerScreen));
      await tester.sendEventToBinding(
        PointerScrollEvent(position: picture, scrollDelta: const Offset(0, 40)),
      );
      await _settle(tester);
      expect(live.rig.engine.calls.last, 'volume:90.0');
      await finish(tester);
    });

    testWidgets('Mute is still on after leaving the player and coming back', (
      tester,
    ) async {
      await open(tester);

      await tester.sendKeyEvent(LogicalKeyboardKey.keyM);
      await _settle(tester);
      expect(findByLabel('Unmute'), findsOneWidget);

      await tester.sendKeyEvent(LogicalKeyboardKey.escape);
      await _settle(tester);
      await tester.sendKeyEvent(LogicalKeyboardKey.enter);
      await _settle(tester);

      expect(find.byType(PlayerScreen), findsOneWidget);
      expect(findByLabel('Unmute'), findsOneWidget);
      await tester.tap(findByLabel('Unmute'));
      await _settle(tester);
      expect(live.rig.engine.calls.last, 'muted:false');
      expect(findByLabel('Mute, volume 100%'), findsOneWidget);
      await finish(tester);
    });

    testWidgets('Channels opens the panel; Previous and Next zap', (
      tester,
    ) async {
      await open(tester);

      await tester.tap(findByLabel('Next channel'));
      await _settle(tester);
      expect(find.text('202  Arena Sports 2'), findsOneWidget);
      await tester.pump(const Duration(milliseconds: 400));
      await _settle(tester);
      expect(live.rig.engine.opened.last.url, contains('202'));

      live.rig.engine.firstFrame();
      await tester.tap(findByLabel('Previous channel'));
      await tester.pump(const Duration(milliseconds: 400));
      await _settle(tester);
      expect(live.rig.engine.opened.last.url, contains('201'));

      live.rig.engine.firstFrame();
      await tester.tap(findByLabel('Last channel'));
      await _settle(tester);
      expect(live.rig.engine.opened.last.url, contains('202'));

      await tester.tap(findByLabel('Channels'));
      await _settle(tester);
      expect(find.byType(ChannelPanel), findsOneWidget);
      await finish(tester);
    });

    testWidgets('the star makes the channel a favorite, and says so', (
      tester,
    ) async {
      await open(tester);
      expect(findByLabel('Remove from favorites'), findsNothing);

      await tester.tap(findByLabel('Add to favorites'));
      await _settle(tester);

      expect(findByLabel('Remove from favorites'), findsOneWidget);
      final stored = await tester.runAsync(
        () => DbChannelRepository(live.db).byRemoteKey('src-1', '201'),
      );
      expect(stored?.valueOrNull?.isFavorite, isTrue);
      await finish(tester);
    });

    testWidgets('Full screen leaves and enters it without leaving the player', (
      tester,
    ) async {
      await open(tester);

      await tester.tap(findByLabel('Exit full screen'));
      await _settle(tester);
      expect(live.window.changes, [true, false]);
      expect(find.byType(PlayerScreen), findsOneWidget);

      await tester.tap(findByLabel('Full screen'));
      await _settle(tester);
      expect(live.window.changes, [true, false, true]);
      expect(findByLabel('Exit full screen'), findsOneWidget);
      await finish(tester);
    });

    testWidgets('a control keeps the keyboard while the OSD shows, and gives '
        'it back when the OSD hides', (tester) async {
      await open(tester);

      await tester.sendKeyEvent(LogicalKeyboardKey.tab);
      await _settle(tester);
      expect(FocusManager.instance.primaryFocus?.debugLabel, isNot('player'));

      double opacity() => tester
          .widget<AnimatedOpacity>(
            find.ancestor(
              of: find.byType(OsdTop),
              matching: find.byType(AnimatedOpacity),
            ),
          )
          .opacity;

      // Still up after the mouse's three seconds: time to read it.
      await tester.pump(const Duration(seconds: 4));
      expect(opacity(), 1);
      await tester.pump(const Duration(seconds: 3));
      await _settle(tester);

      expect(opacity(), 0);
      expect(FocusManager.instance.primaryFocus?.debugLabel, 'player');
      await finish(tester);
    });

    testWidgets('a wide window names what Audio and Subtitles are set to; a '
        'narrow one draws their icons', (tester) async {
      await open(tester);
      live.rig.engine.emit(
        const PlayerTracks(
          audio: [MediaTrack(id: '1', language: 'eng')],
          subtitles: [MediaTrack(id: '2', language: 'fra')],
          audioId: '1',
          subtitleId: '2',
        ),
      );
      await _settle(tester);

      expect(find.text('Audio: English'), findsOneWidget);
      expect(find.text('Subtitles: French'), findsOneWidget);

      tester.view.physicalSize = const Size(1024, 640);
      await _settle(tester);
      expect(find.text('Audio: English'), findsNothing);
      expect(findByLabel('Subtitles: French'), findsOneWidget);
      await finish(tester);
    });
  });

  group('the time on screen: a small clock top right while the OSD is '
      'hidden (docs/03, ADR-051)', () {
    /// [text] in the corner, as drawn: nothing while it is gone.
    Finder corner(String text) => find.descendant(
      of: find.byType(PlayerTimeCorner),
      matching: find.text(text),
    );

    /// What the corner draws: no text at all while it is gone.
    Finder anyWords() => find.descendant(
      of: find.byType(PlayerTimeCorner),
      matching: find.byType(Text),
    );

    /// The match, 82 minutes in, 38 to go.
    NowNext match(DateTime now) => NowNext(
      now: Programme(
        title: 'Continental Cup · Semi-final',
        start: now.subtract(const Duration(minutes: 82)),
        end: now.add(const Duration(minutes: 38)),
      ),
    );

    /// The stream plays on for [seconds], a second at a time (a picture
    /// that stands still for 8 s is a stall).
    var played = 0;
    Future<void> playOn(WidgetTester tester, int seconds) async {
      for (var s = 0; s < seconds; s++) {
        live.rig.engine.progress(Duration(seconds: ++played));
        await tester.pump(const Duration(seconds: 1));
      }
    }

    setUp(() => played = 0);

    testWidgets('a channel with a programme: once the OSD has gone, the '
        'clock alone, no time left (ADR-051); it moves on with the clock, '
        'and only then', (tester) async {
      await open(tester, guide: match);
      expect(anyWords(), findsNothing, reason: 'not while the OSD shows');
      await playOn(tester, 4);
      await _settle(tester);

      expect(corner('12:00 PM'), findsOneWidget);
      expect(anyWords(), findsOneWidget, reason: 'the clock alone');
      final clock = tester.widget<Text>(corner('12:00 PM'));

      // The clock turns while the corner waits for its next minute, a
      // minute after it came: nothing looks before then.
      live.fakes.now = live.fakes.now.add(const Duration(minutes: 1));
      await playOn(tester, 54);
      expect(identical(tester.widget<Text>(corner('12:00 PM')), clock), isTrue);
      await playOn(tester, 6);
      expect(corner('12:01 PM'), findsOneWidget);
      expect(anyWords(), findsOneWidget);
      await finish(tester);
    });

    testWidgets('a channel the guide knows nothing about: the clock alone', (
      tester,
    ) async {
      await open(tester);
      await playOn(tester, 4);
      await _settle(tester);

      expect(corner('12:00 PM'), findsOneWidget);
      expect(anyWords(), findsOneWidget);
      await finish(tester);
    });

    testWidgets('not while the channel opens, though the OSD hides', (
      tester,
    ) async {
      await open(tester, guide: match, picture: false);
      await tester.pump(const Duration(seconds: 4));
      await _settle(tester);
      expect(anyWords(), findsNothing);

      live.rig.engine.firstFrame();
      await _settle(tester);
      await playOn(tester, 4);
      await _settle(tester);
      expect(corner('12:00 PM'), findsOneWidget);
      await finish(tester);
    });

    testWidgets('not while the channel panel is open', (tester) async {
      await open(tester, guide: match);
      await tester.sendKeyEvent(LogicalKeyboardKey.arrowLeft);
      await _settle(tester);
      expect(find.byType(ChannelPanel), findsOneWidget);
      await playOn(tester, 5);
      await _settle(tester);
      expect(anyWords(), findsNothing);
      await finish(tester);
    });

    testWidgets('clear of the stream info, and of the number overlay, which '
        'comes with the OSD', (tester) async {
      await open(tester, guide: match);
      await tester.sendKeyEvent(LogicalKeyboardKey.keyI);
      await _settle(tester);
      await playOn(tester, 4);
      await _settle(tester);

      expect(find.byType(StreamInfoOverlay), findsOneWidget);
      expect(corner('12:00 PM'), findsOneWidget);
      final shown = tester.getRect(
        find.descendant(
          of: find.byType(PlayerTimeCorner),
          matching: find.byType(RepaintBoundary),
        ),
      );
      expect(
        shown.overlaps(tester.getRect(find.byType(StreamInfoOverlay))),
        isFalse,
      );

      await tester.sendKeyEvent(LogicalKeyboardKey.digit2);
      await _settle(tester);
      expect(find.byType(NumberEntry), findsOneWidget);
      expect(anyWords(), findsNothing);
      expect(shown.overlaps(tester.getRect(find.byType(NumberEntry))), isFalse);
      expect(
        shown.bottom,
        lessThan(tester.getRect(find.byType(NumberEntry)).top),
      );
      await tester.pump(const Duration(seconds: 2));
      await finish(tester);
    });
  });
}

Future<void> _settle(WidgetTester tester) async {
  for (var i = 0; i < 5; i++) {
    await tester.runAsync(() => Future<void>.delayed(Duration.zero));
    await tester.pump(const Duration(milliseconds: 50));
  }
}
