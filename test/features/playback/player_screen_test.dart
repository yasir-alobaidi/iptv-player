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
import 'package:iptv_player/features/live_tv/presentation/live_tv_screen.dart';
import 'package:iptv_player/features/playback/presentation/player_overlays.dart';
import 'package:iptv_player/features/playback/presentation/player_screen.dart';

import '../../app/app_harness.dart';
import '../live_tv/live_tv_fakes.dart';

void main() {
  late LiveTvFakes live;
  late AppUnderTest app;

  /// Live TV with Arena Sports 1 (201) opened full screen with Enter.
  Future<void> open(
    WidgetTester tester, {
    FormFactor formFactor = FormFactor.desktop,
  }) async {
    live = LiveTvFakes();
    addTearDown(() => tester.runAsync(live.db.close));
    await tester.runAsync(live.seed);
    app = await pumpApp(
      tester,
      initialLocation: AppDestination.liveTv.path,
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

    testWidgets('→ walks every control to the last, never to the picture '
        '(the user: "I cant do anything with the remote")', (tester) async {
      await open(tester, formFactor: FormFactor.tv);
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

  testWidgets('↓↓ shows the banner at once and opens one stream after a '
      'moment', (tester) async {
    await open(tester);

    await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
    await _settle(tester);
    await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
    await _settle(tester);
    expect(find.byType(ChannelBanner), findsOneWidget);
    expect(find.text('203  Velocity Motors'), findsOneWidget);
    expect(live.rig.engine.opened, hasLength(1));

    await tester.pump(const Duration(milliseconds: 400));
    await _settle(tester);
    expect(live.rig.engine.opened, hasLength(2));
    expect(live.rig.engine.opened.last.url, contains('203'));
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
}

Future<void> _settle(WidgetTester tester) async {
  for (var i = 0; i < 5; i++) {
    await tester.runAsync(() => Future<void>.delayed(Duration.zero));
    await tester.pump(const Duration(milliseconds: 50));
  }
}
