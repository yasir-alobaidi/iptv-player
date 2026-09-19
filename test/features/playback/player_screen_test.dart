import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:iptv_player/app/destinations.dart';
import 'package:iptv_player/core/player/player_engine.dart';
import 'package:iptv_player/features/live_tv/presentation/live_tv_screen.dart';
import 'package:iptv_player/features/playback/presentation/player_overlays.dart';
import 'package:iptv_player/features/playback/presentation/player_screen.dart';

import '../../app/app_harness.dart';
import '../live_tv/live_tv_fakes.dart';

void main() {
  late LiveTvFakes live;
  late AppUnderTest app;

  /// Live TV with Arena Sports 1 (201) opened full screen with Enter.
  Future<void> open(WidgetTester tester) async {
    live = LiveTvFakes();
    addTearDown(() => tester.runAsync(live.db.close));
    await tester.runAsync(live.seed);
    app = await pumpApp(
      tester,
      initialLocation: AppDestination.liveTv.path,
      overrides: live.overrides,
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
}

Future<void> _settle(WidgetTester tester) async {
  for (var i = 0; i < 5; i++) {
    await tester.runAsync(() => Future<void>.delayed(Duration.zero));
    await tester.pump(const Duration(milliseconds: 50));
  }
}
