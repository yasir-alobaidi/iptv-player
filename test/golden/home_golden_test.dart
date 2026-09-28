// Every test in this file is a golden; the tag is declared in
// dart_test.yaml so `flutter test --exclude-tags golden` can drop them
// on Windows.
@Tags(['golden'])
library;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:iptv_player/features/sources/presentation/source_shell_slots.dart';

import '../app/app_harness.dart';
import '../features/home/home_fakes.dart';
import '../features/vod/vod_fakes.dart';
import 'golden_harness.dart';

void main() {
  group('home', () {
    for (final (name, size, history) in const [
      ('first_run_1280x800', Size(1280, 800), false),
      ('1280x800', Size(1280, 800), true),
      ('1920x1080', Size(1920, 1080), true),
    ]) {
      testWidgets(name, (tester) async {
        hideDebugBanner();
        final home = HomeFakes();
        home.vod.fakes.now = goldenNow();
        addTearDown(() => tester.runAsync(home.db.close));
        await tester.runAsync(() async {
          await home.seed();
          await home.vod.seedMany(12);
          if (history) await home.seedHistory();
        });
        await pumpApp(
          tester,
          size: size,
          overrides: [...home.overrides, ...sourceShellOverrides],
        );
        await settle(tester);

        await expectLater(
          find.byType(MaterialApp),
          matchesGoldenFile('images/home_$name.png'),
        );
      });
    }
  }, skip: goldenSkipReason);
}
