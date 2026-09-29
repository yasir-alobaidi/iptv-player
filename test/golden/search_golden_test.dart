// Every test in this file is a golden; the tag is declared in
// dart_test.yaml so `flutter test --exclude-tags golden` can drop them
// on Windows.
@Tags(['golden'])
library;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:iptv_player/features/guide/domain/epg.dart';
import 'package:iptv_player/features/live_tv/domain/channels.dart';
import 'package:iptv_player/features/live_tv/domain/now_next.dart';
import 'package:iptv_player/features/search/data/search_providers.dart';
import 'package:iptv_player/features/search/domain/search.dart';
import 'package:iptv_player/features/search/presentation/search_state.dart';
import 'package:iptv_player/features/sources/presentation/source_shell_slots.dart';
import 'package:iptv_player/features/vod/domain/titles.dart';
import 'package:iptv_player/features/vod/domain/watch_progress.dart';

import '../app/app_harness.dart';
import '../features/live_tv/live_tv_fakes.dart';
import '../features/search/search_fakes.dart';
import 'golden_harness.dart';

/// The canvas's `Search` example: "harbor" over two channels, a match on
/// now and one tomorrow, a movie to resume and a series.
SearchResults _harbor(DateTime now) {
  ChannelItem channel(String key, String name) => ChannelItem(
    id: int.parse(key),
    sourceId: 'src-1',
    remoteKey: key,
    name: name,
    number: int.parse(key),
  );
  final courtside = channel('231', 'Courtside');
  final blueWater = channel('310', 'Blue Water');
  return SearchResults(
    text: 'harbor',
    channels: SearchGroup([
      ChannelHit(
        channel: channel('118', 'Harbor City Local'),
        sourceName: 'Northwind TV',
      ),
      ChannelHit(
        channel: channel('147', 'Harborview Weather'),
        sourceName: 'Northwind TV',
      ),
    ]),
    programmes: SearchGroup([
      ProgrammeHit(
        programme: EpgProgramme(
          id: 1,
          channelId: 'courtside',
          start: now.subtract(const Duration(minutes: 70)),
          end: now.add(const Duration(minutes: 95)),
          title: 'Harbor Kings vs Ridge City',
        ),
        channel: courtside,
        sourceName: 'Northwind TV',
      ),
      ProgrammeHit(
        programme: EpgProgramme(
          id: 2,
          channelId: 'bluewater',
          start: now.add(const Duration(days: 1, hours: 13, minutes: 30)),
          end: now.add(const Duration(days: 1, hours: 14, minutes: 30)),
          title: 'The Harbor Pilot',
        ),
        channel: blueWater,
        sourceName: 'Northwind TV',
      ),
    ]),
    movies: SearchGroup([
      MovieHit(
        movie: MovieItem(
          id: 1,
          sourceId: 'src-1',
          remoteKey: 'm1',
          name: 'The Quiet Harbor',
          year: 2024,
          watch: WatchMark(
            position: const Duration(hours: 1, minutes: 12, seconds: 40),
            duration: const Duration(hours: 1, minutes: 58),
            updatedAt: now,
          ),
        ),
        sourceName: 'Northwind TV',
        genre: 'Drama',
      ),
    ]),
    series: const SearchGroup([
      SeriesHit(
        series: SeriesItem(
          id: 1,
          sourceId: 'src-1',
          remoteKey: 's1',
          name: 'Harbor Nine',
          genre: 'Crime',
        ),
        sourceName: 'Northwind TV',
        seasons: 3,
      ),
    ]),
  );
}

void main() {
  Future<LiveTvFakes> open(
    WidgetTester tester,
    Size size,
    ScriptedSearch search,
  ) async {
    hideDebugBanner();
    final live = LiveTvFakes();
    live.fakes.now = goldenNow();
    addTearDown(() => tester.runAsync(live.db.close));
    await tester.runAsync(live.seed);
    await pumpApp(
      tester,
      size: size,
      overrides: [
        ...live.overrides,
        ...sourceShellOverrides,
        searchRepositoryProvider.overrideWithValue(search),
      ],
    );
    await _settle(tester);
    await tester.sendKeyDownEvent(LogicalKeyboardKey.controlLeft);
    await tester.sendKeyEvent(LogicalKeyboardKey.keyK);
    await tester.sendKeyUpEvent(LogicalKeyboardKey.controlLeft);
    await _settle(tester);
    return live;
  }

  group('search', () {
    for (final size in const [Size(1280, 800), Size(1920, 1080)]) {
      final name = '${size.width.toInt()}x${size.height.toInt()}';
      testWidgets('results $name', (tester) async {
        final search = ScriptedSearch()
          ..recent = ['tennis open', 'cup final']
          ..answers['harbor'] = _harbor(goldenNow());
        final live = await open(tester, size, search);
        final now = live.fakes.now;
        live.guide.byKey['118'] = NowNext(
          now: Programme(
            title: 'Evening Bulletin',
            start: now.subtract(const Duration(minutes: 20)),
            end: now.add(const Duration(minutes: 30)),
          ),
        );
        live.guide.byKey['147'] = NowNext(
          now: Programme(
            title: 'Coastal Forecast',
            start: now.subtract(const Duration(minutes: 5)),
            end: now.add(const Duration(minutes: 60)),
          ),
        );
        await tester.enterText(find.byType(EditableText), 'harbor');
        await tester.pump(searchDelay);
        await _settle(tester);

        await expectLater(
          find.byType(MaterialApp),
          matchesGoldenFile('images/search_results_$name.png'),
        );
      });
    }

    testWidgets('recent searches 1280x800', (tester) async {
      final search = ScriptedSearch()..recent = ['tennis open', 'cup final'];
      await open(tester, const Size(1280, 800), search);

      await expectLater(
        find.byType(MaterialApp),
        matchesGoldenFile('images/search_recent_1280x800.png'),
      );
    });

    testWidgets('no results 1280x800', (tester) async {
      final search = ScriptedSearch()
        ..answers['harbour'] = const SearchResults(
          text: 'harbour',
          hiddenChannels: 2,
        );
      await open(tester, const Size(1280, 800), search);
      await tester.enterText(find.byType(EditableText), 'harbour');
      await tester.pump(searchDelay);
      await _settle(tester);

      await expectLater(
        find.byType(MaterialApp),
        matchesGoldenFile('images/search_no_results_1280x800.png'),
      );
    });
  }, skip: goldenSkipReason);
}

Future<void> _settle(WidgetTester tester) async {
  for (var i = 0; i < 5; i++) {
    await tester.runAsync(() => Future<void>.delayed(Duration.zero));
    await tester.pump(const Duration(milliseconds: 50));
  }
}
