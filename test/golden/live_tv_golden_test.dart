// Every test in this file is a golden; the tag is declared in
// dart_test.yaml so `flutter test --exclude-tags golden` can drop them
// on Windows.
@Tags(['golden'])
library;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:iptv_player/app/destinations.dart';
import 'package:iptv_player/features/live_tv/domain/now_next.dart';
import 'package:iptv_player/features/sources/presentation/source_shell_slots.dart';

import '../app/app_harness.dart';
import '../features/live_tv/live_tv_fakes.dart';
import 'golden_harness.dart';

void main() {
  group('live tv', () {
    for (final size in const [Size(1280, 800), Size(1920, 1080)]) {
      final name = '${size.width.toInt()}x${size.height.toInt()}';
      testWidgets(name, (tester) async {
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
            description:
                'Holders Northport face Valencia Azul for a place in the '
                'final. Live from Estadio Costa, with build-up, full match '
                'coverage, and post-match analysis.',
          ),
          next: Programme(
            title: 'Match of the Week: Extended Highlights',
            start: now.add(const Duration(minutes: 38)),
            end: now.add(const Duration(minutes: 98)),
          ),
        );
        await pumpApp(
          tester,
          size: size,
          initialLocation: AppDestination.liveTv.path,
          overrides: [...live.overrides, ...sourceShellOverrides],
        );
        for (var i = 0; i < 5; i++) {
          await tester.runAsync(() => Future<void>.delayed(Duration.zero));
          await tester.pump(const Duration(milliseconds: 50));
        }
        await tester.tap(find.text('Arena Sports 1').first);
        for (var i = 0; i < 5; i++) {
          await tester.runAsync(() => Future<void>.delayed(Duration.zero));
          await tester.pump(const Duration(milliseconds: 50));
        }
        live.rig.engine.firstFrame();
        await tester.pump(const Duration(milliseconds: 300));

        await expectLater(
          find.byType(MaterialApp),
          matchesGoldenFile('images/live_tv_$name.png'),
        );
        await live.rig.coordinator.stop();
        await tester.pump(const Duration(milliseconds: 400));
      });
    }
  }, skip: goldenSkipReason);
}
