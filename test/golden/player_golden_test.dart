// Every test in this file is a golden; the tag is declared in
// dart_test.yaml so `flutter test --exclude-tags golden` can drop them
// on Windows.
@Tags(['golden'])
library;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:iptv_player/app/destinations.dart';
import 'package:iptv_player/core/player/player_engine.dart';
import 'package:iptv_player/core/result.dart';
import 'package:iptv_player/features/live_tv/domain/now_next.dart';
import 'package:iptv_player/features/playback/domain/playback_state.dart';

import '../app/app_harness.dart';
import '../features/live_tv/live_tv_fakes.dart';
import 'golden_harness.dart';

void main() {
  group('player', () {
    Future<LiveTvFakes> open(WidgetTester tester) async {
      hideDebugBanner();
      final live = LiveTvFakes();
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

    testWidgets('OSD', (tester) async {
      final live = await open(tester);
      live.rig.engine
        ..firstFrame()
        ..emit(const PlayerVideoChanged(width: 1920, height: 1080));
      await _settle(tester);

      await expectLater(
        find.byType(MaterialApp),
        matchesGoldenFile('images/player_osd.png'),
      );
      await tester.pump(const Duration(seconds: 4));
      await live.rig.coordinator.stop();
      await _settle(tester);
    });

    testWidgets('failure card', (tester) async {
      final live = await open(tester);
      live.rig.prober.next = PlaybackProblem(
        PlaybackProblemKind.offline,
        failure: NotFoundFailure('stream: HTTP 404', 404),
      );
      live.rig.engine.fail();
      await _settle(tester);

      await expectLater(
        find.byType(MaterialApp),
        matchesGoldenFile('images/player_failure.png'),
      );
      await tester.pump(const Duration(seconds: 4));
      await live.rig.coordinator.stop();
      await _settle(tester);
    });
  }, skip: goldenSkipReason);
}

Future<void> _settle(WidgetTester tester) async {
  for (var i = 0; i < 5; i++) {
    await tester.runAsync(() => Future<void>.delayed(Duration.zero));
    await tester.pump(const Duration(milliseconds: 50));
  }
}
