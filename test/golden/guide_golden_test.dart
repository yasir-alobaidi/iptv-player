// Every test in this file is a golden; the tag is declared in
// dart_test.yaml so `flutter test --exclude-tags golden` can drop them
// on Windows.
@Tags(['golden'])
library;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:iptv_player/app/destinations.dart';
import 'package:iptv_player/features/sources/presentation/source_shell_slots.dart';

import '../app/app_harness.dart';
import '../features/guide/guide_grid_fakes.dart';
import 'golden_harness.dart';

/// The Guide as the canvas draws it: Tuesday 15 at 9:22 PM (a local time,
/// like `goldenNow()`), the canvas's channels and programmes, the focus
/// on what is on now on the first channel.
void main() {
  group('guide', () {
    for (final size in const [Size(1280, 800), Size(1920, 1080)]) {
      final name = '${size.width.toInt()}x${size.height.toInt()}';
      testWidgets(name, (tester) async {
        hideDebugBanner();
        final fixture = GuideFixture();
        addTearDown(() => tester.runAsync(fixture.db.close));
        await tester.runAsync(fixture.seed);
        await pumpApp(
          tester,
          size: size,
          initialLocation: AppDestination.guide.path,
          overrides: [...fixture.overrides, ...sourceShellOverrides],
        );
        await _settle(tester);
        tester
            .widget<Focus>(
              find.byWidgetPredicate(
                (w) => w is Focus && w.focusNode?.debugLabel == 'guide grid',
              ),
            )
            .focusNode!
            .requestFocus();
        await _settle(tester);

        await expectLater(
          find.byType(MaterialApp),
          matchesGoldenFile('images/guide_$name.png'),
        );
      });
    }
  }, skip: goldenSkipReason);
}

Future<void> _settle(WidgetTester tester) async {
  for (var i = 0; i < 5; i++) {
    await tester.runAsync(() => Future<void>.delayed(Duration.zero));
    await tester.pump(const Duration(milliseconds: 50));
  }
}
