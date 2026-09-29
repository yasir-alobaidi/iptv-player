// Every test in this file is a golden; the tag is declared in
// dart_test.yaml so `flutter test --exclude-tags golden` can drop them
// on Windows.
@Tags(['golden'])
library;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:iptv_player/app/destinations.dart';
import 'package:iptv_player/features/favorites/data/db_favorites_repository.dart';
import 'package:iptv_player/features/live_tv/data/db_channel_repository.dart';
import 'package:iptv_player/features/live_tv/domain/channels.dart';
import 'package:iptv_player/features/live_tv/domain/now_next.dart';
import 'package:iptv_player/features/sources/presentation/source_shell_slots.dart';

import '../app/app_harness.dart';
import '../features/live_tv/live_tv_fakes.dart';
import 'golden_harness.dart';

void main() {
  group('favorites', () {
    for (final size in const [Size(1280, 800), Size(1920, 1080)]) {
      final name = '${size.width.toInt()}x${size.height.toInt()}';
      testWidgets(name, (tester) async {
        hideDebugBanner();
        final live = LiveTvFakes();
        live.fakes.now = goldenNow();
        addTearDown(() => tester.runAsync(live.db.close));
        await tester.runAsync(() async {
          await live.seed();
          final channels = DbChannelRepository(live.db);
          final favorites = DbFavoritesRepository(live.db);
          Future<ChannelItem> channel(String key) async =>
              (await channels.byRemoteKey('src-1', key)).valueOrNull!;
          for (final key in ['201', '202', '203', '900']) {
            await channels.setFavorite(await channel(key), on: true);
          }
          final sports = (await favorites.createGroup(
            'src-1',
            'Sports',
          )).valueOrNull!;
          for (final (i, key) in ['201', '202', '203'].indexed) {
            await favorites.moveChannel(
              await channel(key),
              groupId: sports,
              index: i,
            );
          }
          await favorites.createGroup('src-1', 'News');
        });
        final now = live.fakes.now;
        Programme on(String title, int started, int left) => Programme(
          title: title,
          start: now.subtract(Duration(minutes: started)),
          end: now.add(Duration(minutes: left)),
        );
        live.guide.byKey
          ..['201'] = NowNext(now: on('Continental Cup · Semi-final', 82, 38))
          ..['202'] = NowNext(now: on('Tennis Open · Quarter-finals', 36, 84))
          ..['203'] = NowNext(now: on('Grand Prix Qualifying', 48, 12));
        await pumpApp(
          tester,
          size: size,
          initialLocation: AppDestination.favorites.path,
          overrides: [...live.overrides, ...sourceShellOverrides],
        );
        for (var i = 0; i < 6; i++) {
          await tester.runAsync(() => Future<void>.delayed(Duration.zero));
          await tester.pump(const Duration(milliseconds: 50));
        }

        await expectLater(
          find.byType(MaterialApp),
          matchesGoldenFile('images/favorites_$name.png'),
        );
      });
    }
  }, skip: goldenSkipReason);
}
