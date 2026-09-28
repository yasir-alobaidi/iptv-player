// Every test in this file is a golden; the tag is declared in
// dart_test.yaml so `flutter test --exclude-tags golden` can drop them
// on Windows.
@Tags(['golden'])
library;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:iptv_player/app/destinations.dart';
import 'package:iptv_player/data/db/user_tables.dart';
import 'package:iptv_player/features/sources/presentation/source_shell_slots.dart';

import '../app/app_harness.dart';
import '../features/vod/vod_fakes.dart';
import 'golden_harness.dart';

void main() {
  group('movies', () {
    for (final size in const [Size(1280, 800), Size(1920, 1080)]) {
      final name = '${size.width.toInt()}x${size.height.toInt()}';
      testWidgets(name, (tester) async {
        hideDebugBanner();
        final vod = VodFakes();
        vod.fakes.now = goldenNow();
        addTearDown(() => tester.runAsync(vod.db.close));
        await tester.runAsync(() async {
          await vod.seed();
          await vod.seedMany(24);
          await vod.db.favoritesDao.add(
            UserItemType.movie,
            'src-1',
            '504',
            vod.now,
          );
          await vod.db.watchHistoryDao.touch(
            UserItemType.movie,
            'src-1',
            '501',
            vod.now,
            positionMs: 72 * 60000,
            durationMs: 118 * 60000,
            completed: false,
          );
        });
        await pumpApp(
          tester,
          size: size,
          initialLocation: AppDestination.movies.path,
          overrides: [...vod.overrides, ...sourceShellOverrides],
        );
        await settle(tester);

        await expectLater(
          find.byType(MaterialApp),
          matchesGoldenFile('images/movies_$name.png'),
        );
      });
    }
  }, skip: goldenSkipReason);
}
