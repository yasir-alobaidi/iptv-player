// Every test in this file is a golden; the tag is declared in
// dart_test.yaml so `flutter test --exclude-tags golden` can drop them
// on Windows.
@Tags(['golden'])
library;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:iptv_player/core/downloads/download_task.dart';
import 'package:iptv_player/core/library/library_item.dart';
import 'package:iptv_player/data/db/user_tables.dart';
import 'package:iptv_player/design/components.dart';
import 'package:iptv_player/features/sources/presentation/source_shell_slots.dart';

import '../features/library/presentation/library_ui_support.dart';
import '../features/vod/vod_fakes.dart';
import 'golden_harness.dart';

/// The canvas's Library: downloads and the user's own films, one in
/// progress, one on a drive that is away; a show in two seasons; home
/// videos.
Future<void> _canvas(LibraryUi ui) async {
  for (final (title, size, key) in [
    ('The Quiet Harbor', 2.1, '501'),
    ('Northwind Hotel', 3.4, '901'),
    ('Ember Road', 1.8, '504'),
    ('Quarry Lake', 1.6, '902'),
  ]) {
    await ui.add(
      ui.downloads,
      'Movies/$title.mp4',
      title,
      bytes: (size * gb).round(),
      provider: key,
      duration: const Duration(minutes: 110),
    );
  }
  for (final (title, year, away) in [
    ('Harbor Walk', 2021, false),
    ('Paper Kites', 2019, false),
    ('The Salt Flats', 2016, false),
    ('Winter Ferry', 2018, false),
    ('Coldwater', 2020, true),
    ('Night Bus', 2017, false),
    ('Birch and Ash', 2022, false),
    ('Lamplight', 2015, false),
    ('Tidewater', 2014, false),
  ]) {
    await ui.add(
      ui.hdd,
      '$title ($year)/$title ($year).mkv',
      title,
      year: year,
      bytes: 14 * gb,
      away: away,
      duration: const Duration(hours: 1, minutes: 52),
      media: {
        'video': {'codec': 'h264', 'width': 1920, 'height': 1080},
        'audio': [
          {'codec': 'ac3', 'channels': 6, 'language': 'eng'},
        ],
      },
      subtitles: [
        {'file': '$title ($year).en.srt', 'format': 'srt', 'language': 'en'},
      ],
    );
  }
  await ui.db.watchHistoryDao.touch(
    UserItemType.movie,
    'src-1',
    '501',
    ui.now,
    positionMs: 67 * 60000,
    durationMs: 110 * 60000,
    completed: false,
  );
  await ui.leftAt(
    'Paper Kites (2019)/Paper Kites (2019).mkv',
    const Duration(minutes: 42, seconds: 10),
    const Duration(hours: 1, minutes: 52),
  );
  for (final (season, episode, title) in [
    (1, 1, 'Pilot'),
    (1, 2, 'Slack Water'),
    (2, 1, 'The Breakwater'),
    (2, 2, 'Soundings'),
    (2, 3, 'The Long Tide'),
    (2, 4, 'Kettle Bay'),
  ]) {
    await ui.add(
      ui.hdd,
      'Kettle Bay/Kettle.Bay.S0${season}E0$episode.mkv',
      title,
      kind: LibraryKind.episode,
      show: 'Kettle Bay',
      season: season,
      episode: episode,
      duration: Duration(minutes: 40 + episode),
    );
  }
  for (final episode in [1, 2, 3]) {
    await ui.add(
      ui.hdd,
      'Harbor Nine/Harbor.Nine.S01E0$episode.mkv',
      'Harbor Nine',
      kind: LibraryKind.episode,
      show: 'Harbor Nine',
      season: 1,
      episode: episode,
    );
  }
  await ui.leftAt(
    'Kettle Bay/Kettle.Bay.S02E02.mkv',
    const Duration(minutes: 42),
    const Duration(minutes: 42),
    completed: true,
    at: ui.now.subtract(const Duration(days: 1)),
  );
  await ui.leftAt(
    'Kettle Bay/Kettle.Bay.S02E03.mkv',
    const Duration(minutes: 20),
    const Duration(minutes: 43),
  );
  for (final (title, minutes) in [
    ('Birthday at the lake', 12),
    ('Garden timelapse', 4),
    ('First steps', 2),
    ('Ferry crossing', 26),
  ]) {
    await ui.add(
      ui.home,
      '$title.mp4',
      title,
      kind: LibraryKind.unsorted,
      duration: Duration(minutes: minutes),
      bytes: gb ~/ 2,
    );
  }
  await ui.leftAt(
    'Garden timelapse.mp4',
    const Duration(minutes: 2, seconds: 30),
    const Duration(minutes: 4),
  );
}

void main() {
  Future<void> open(
    WidgetTester tester, {
    String location = '/library',
    Size size = const Size(1280, 800),
    Future<void> Function(LibraryUi ui) before = _canvas,
  }) async {
    hideDebugBanner();
    await openLibrary(
      tester,
      location: location,
      size: size,
      now: goldenNow(),
      before: before,
      overrides: sourceShellOverrides,
    );
    await settle(tester);
  }

  group('library', () {
    for (final size in const [Size(1280, 800), Size(1920, 1080)]) {
      final name = '${size.width.toInt()}x${size.height.toInt()}';
      testWidgets('movies $name', (tester) async {
        await open(tester, size: size);
        tester
            .widget<PosterCard>(
              find.widgetWithText(PosterCard, 'The Quiet Harbor'),
            )
            .focusNode!
            .requestFocus();
        await settle(tester);

        await expectLater(
          find.byType(MaterialApp),
          matchesGoldenFile('images/library_$name.png'),
        );
      });
    }

    testWidgets('series', (tester) async {
      await open(tester);
      await tester.tap(find.widgetWithText(CountTab, 'Series'));
      await settle(tester);

      await expectLater(
        find.byType(MaterialApp),
        matchesGoldenFile('images/library_series.png'),
      );
    });

    testWidgets('videos', (tester) async {
      await open(tester);
      await tester.tap(find.widgetWithText(CountTab, 'Videos'));
      await settle(tester);

      await expectLater(
        find.byType(MaterialApp),
        matchesGoldenFile('images/library_videos.png'),
      );
    });

    testWidgets('folders', (tester) async {
      await open(tester);
      await tester.tap(find.widgetWithText(CountTab, 'Folders'));
      await settle(tester);

      await expectLater(
        find.byType(MaterialApp),
        matchesGoldenFile('images/library_folders.png'),
      );
    });

    testWidgets('downloads', (tester) async {
      await open(
        tester,
        before: (ui) async {
          await _canvas(ui);
          ui.queue.set([
            download(
              1,
              'Copper Hollow',
              year: 2025,
              state: DownloadTaskState.downloading,
              downloaded: (1.03 * gb).round(),
              total: (2.1 * gb).round(),
              speed: 8.4 * 1024 * 1024,
            ),
            download(
              2,
              'Northbound',
              type: VodType.episode,
              show: 'Glass Tide',
              season: 2,
              episode: 5,
              total: (0.9 * gb).round(),
            ),
            download(
              3,
              'Tidelines',
              type: VodType.episode,
              show: 'Harbor Nine',
              season: 1,
              episode: 2,
              state: DownloadTaskState.failed,
              problem: DownloadProblem.notFound,
            ),
            download(
              4,
              'Northwind Hotel',
              state: DownloadTaskState.completed,
              total: (3.4 * gb).round(),
              completedAt: goldenNow().subtract(const Duration(minutes: 46)),
            ),
            download(
              5,
              'Undertow',
              type: VodType.episode,
              show: 'Glass Tide',
              season: 2,
              episode: 4,
              state: DownloadTaskState.completed,
              total: (1.1 * gb).round(),
              completedAt: goldenNow().subtract(const Duration(hours: 2)),
            ),
          ]);
        },
      );
      await tester.tap(find.widgetWithText(CountTab, 'Downloads'));
      await settle(tester);
      tester
          .widget<FocusableSurface>(
            find.byWidgetPredicate(
              (widget) =>
                  widget is FocusableSurface &&
                  (widget.semanticLabel?.startsWith('Copper Hollow') ?? false),
            ),
          )
          .focusNode!
          .requestFocus();
      await settle(tester);

      await expectLater(
        find.byType(MaterialApp),
        matchesGoldenFile('images/library_downloads.png'),
      );
    });

    testWidgets('the first run', (tester) async {
      await open(tester, before: (ui) async {});

      await expectLater(
        find.byType(MaterialApp),
        matchesGoldenFile('images/library_first_run.png'),
      );
    });

    testWidgets('a movie of the library', (tester) async {
      // Paper Kites is the sixth row written.
      await open(tester, location: '/library/movie/6');

      await expectLater(
        find.byType(MaterialApp),
        matchesGoldenFile('images/library_movie.png'),
      );
    });

    testWidgets('a show of the library', (tester) async {
      await open(tester, location: '/library/show/l%3Akettle%20bay');

      await expectLater(
        find.byType(MaterialApp),
        matchesGoldenFile('images/library_show.png'),
      );
    });
  }, skip: goldenSkipReason);
}
