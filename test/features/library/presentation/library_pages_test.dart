import 'package:flutter/gestures.dart' show kSecondaryMouseButton;
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:iptv_player/core/library/library_item.dart';
import 'package:iptv_player/design/components.dart';

import '../../../app/app_harness.dart';
import '../../vod/catalogue_screen_test.dart' show focusedLabel;
import '../../vod/vod_fakes.dart';
import 'library_ui_support.dart';

const _kites = 'Paper Kites (2019)/Paper Kites (2019).mkv';

/// A film of the user's own, as the scanner leaves it: probed, with an
/// English subtitle file beside it and a forced track inside.
Future<int> _paperKites(LibraryUi ui, {bool away = false}) => ui.add(
  ui.hdd,
  _kites,
  'Paper Kites',
  year: 2019,
  bytes: (2.1 * gb).round(),
  duration: const Duration(hours: 1, minutes: 52),
  away: away,
  media: {
    'video': {'codec': 'h264', 'width': 1920, 'height': 1080},
    'audio': [
      {'codec': 'ac3', 'channels': 6, 'language': 'eng'},
    ],
    'subtitles': [
      {'codec': 'subrip', 'language': 'eng', 'forced': true},
    ],
  },
  subtitles: [
    {'file': 'Paper Kites (2019).en.srt', 'format': 'srt', 'language': 'en'},
  ],
);

/// Kettle Bay in two seasons; S2 E4's name gave no title.
Future<List<int>> _kettleBay(LibraryUi ui, {bool away = false}) async => [
  for (final (season, episode, title) in [
    (1, 1, 'Pilot'),
    (2, 3, 'The Long Tide'),
    (2, 4, 'Kettle Bay'),
  ])
    await ui.add(
      ui.hdd,
      'Kettle Bay/Kettle.Bay.S0${season}E0$episode.mkv',
      title,
      kind: LibraryKind.episode,
      show: 'Kettle Bay',
      season: season,
      episode: episode,
      duration: Duration(minutes: 40 + episode),
      away: away,
    ),
];

String _episode(int season, int episode) =>
    'Kettle Bay/Kettle.Bay.S0${season}E0$episode.mkv';

void main() {
  group('a movie of the library', () {
    testWidgets('a file of your own: what it is, where it is, its '
        'subtitles; Play has the focus and starts it', (tester) async {
      late int id;
      final (ui, _) = await openLibrary(
        tester,
        location: '/library/movie/1',
        before: (ui) async => id = await _paperKites(ui),
      );
      expect(id, 1);

      expect(find.text('MOVIE'), findsOneWidget);
      expect(find.text('Paper Kites'), findsWidgets);
      for (final part in ['2019', '1 h 52 min', '1080p', 'H.264', 'AC-3 5.1']) {
        expect(find.text(part), findsOneWidget, reason: part);
      }
      expect(find.text('Movies HDD · $_kites · 2.1 GB'), findsOneWidget);
      expect(
        find.text('Subtitles: English · English (forced)'),
        findsOneWidget,
      );
      expect(findByLabel('Back to Library'), findsOneWidget);
      expect(find.text('Start over'), findsNothing);
      expect(focusedLabel(), 'Play');

      await tester.sendKeyEvent(LogicalKeyboardKey.enter);
      await settle(tester);
      expect(ui.launcher.played, ['Paper Kites from 0']);
    });

    testWidgets('left part-way: Resume from where, Start over and the time '
        'left', (tester) async {
      final (ui, _) = await openLibrary(
        tester,
        location: '/library/movie/1',
        before: (ui) async {
          await _paperKites(ui);
          await ui.leftAt(
            _kites,
            const Duration(minutes: 42, seconds: 10),
            const Duration(hours: 1, minutes: 52),
          );
        },
      );

      expect(find.text('Resume from 42:10'), findsOneWidget);
      expect(find.text('1 h 9 min left'), findsOneWidget);
      expect(focusedLabel(), 'Resume from 42:10');

      await tester.sendKeyEvent(LogicalKeyboardKey.enter);
      await tester.tap(find.text('Start over'));
      await settle(tester);
      expect(ui.launcher.played, [
        'Paper Kites from 2530',
        'Paper Kites from 0',
      ]);
    });

    testWidgets('F keeps it as a favorite; Esc goes back to the Library', (
      tester,
    ) async {
      final (_, app) = await openLibrary(
        tester,
        location: '/library/movie/1',
        before: _paperKites,
      );
      expect(findByLabel('Add to favorites'), findsOneWidget);

      await tester.sendKeyEvent(LogicalKeyboardKey.keyF);
      await settle(tester);
      expect(findByLabel('Remove from favorites'), findsOneWidget);

      await tester.sendKeyEvent(LogicalKeyboardKey.escape);
      await settle(tester);
      expect(app.location, '/library');
      expect(
        tester
            .widget<PosterCard>(
              find.widgetWithText(PosterCard, 'Paper Kites (2019)'),
            )
            .cornerBadge,
        isNotNull,
        reason: 'the star on its card',
      );
    });

    testWidgets('its drive away: says so, and Play explains instead of '
        'playing', (tester) async {
      final (ui, _) = await openLibrary(
        tester,
        location: '/library/movie/1',
        before: (ui) => _paperKites(ui, away: true),
      );

      expect(find.textContaining('Drive not connected · Movies HDD'), findsOne);
      await tester.sendKeyEvent(LogicalKeyboardKey.enter);
      await settle(tester);
      expect(ui.launcher.played, isEmpty);
      expect(
        find.text(
          "Movies HDD isn't connected. Connect its drive to play this.",
        ),
        findsOneWidget,
      );
    });

    testWidgets('a download the provider dropped: Downloaded, with the '
        'plot and the genre it was downloaded with', (tester) async {
      await openLibrary(
        tester,
        location: '/library/movie/1',
        before: (ui) => ui.add(
          ui.downloads,
          'Movies/Northwind Hotel.mp4',
          'Northwind Hotel',
          provider: '999',
          bytes: (3.4 * gb).round(),
          details: {
            'name': 'Northwind Hotel',
            'year': 2023,
            'rating': 7.4,
            'plot':
                'A night porter keeps the guest book of a hotel '
                'nobody checks out of.',
            'genre': 'Mystery, Drama',
            'runtime_minutes': 104,
          },
        ),
      );

      expect(find.text('MOVIE  /  MYSTERY'), findsOneWidget);
      expect(find.text('1 h 44 min'), findsOneWidget);
      expect(find.text('7.4'), findsOneWidget);
      expect(find.textContaining('A night porter keeps'), findsOneWidget);
      expect(
        find.text('Downloaded · Movies/Northwind Hotel.mp4 · 3.4 GB'),
        findsOneWidget,
      );
      expect(find.textContaining('Subtitles'), findsNothing);
    });

    testWidgets('no longer in the library: says so, with the way back', (
      tester,
    ) async {
      final (_, app) = await openLibrary(tester, location: '/library/movie/41');

      expect(find.text('Not available'), findsOneWidget);
      expect(
        find.text('This video is no longer in your library.'),
        findsOneWidget,
      );
      await tester.tap(find.text('Back'));
      await settle(tester);
      expect(app.location, '/library');
    });

    testWidgets('an address that names no item is the same page', (
      tester,
    ) async {
      await openLibrary(tester, location: '/library/movie/kites');
      expect(find.text('Not available'), findsOneWidget);
    });
  });

  group('a show of the library', () {
    const page = '/library/show/l%3Akettle%20bay';

    testWidgets('nothing watched: Play S1 · E1; the seasons as tabs, the '
        'episodes with their numbers, and "Episode 4" for a name with no '
        'title', (tester) async {
      final (ui, _) = await openLibrary(
        tester,
        location: page,
        before: _kettleBay,
      );

      expect(find.text('Kettle Bay'), findsWidgets);
      expect(find.text('2 seasons · Movies HDD'), findsOneWidget);
      expect(find.text('Season 1'), findsOneWidget);
      expect(find.text('Season 2'), findsOneWidget);
      expect(find.text('1 episode'), findsOneWidget);
      expect(find.text('Pilot'), findsOneWidget);
      expect(find.text('41 min'), findsOneWidget);
      expect(focusedLabel(), 'Play S1 · E1');
      expect(findByLabel('Add to favorites'), findsNothing);

      await tester.tap(find.text('Season 2'));
      await settle(tester);
      expect(find.text('2 episodes'), findsOneWidget);
      expect(find.text('S2 · E3'), findsOneWidget);
      expect(find.text('The Long Tide'), findsOneWidget);
      expect(find.text('Episode 4'), findsOneWidget);
      expect(find.text('Pilot'), findsNothing);

      await tester.tap(find.text('Episode 4'));
      await settle(tester);
      expect(ui.launcher.played, ['Kettle Bay from 0']);
    });

    testWidgets('an episode in progress: Continue it from there, its '
        'season shown, its row with the time left', (tester) async {
      final (ui, _) = await openLibrary(
        tester,
        location: page,
        before: (ui) async {
          await _kettleBay(ui);
          await ui.leftAt(
            _episode(1, 1),
            const Duration(minutes: 41),
            const Duration(minutes: 41),
            completed: true,
            at: ui.now.subtract(const Duration(days: 2)),
          );
          await ui.leftAt(
            _episode(2, 3),
            const Duration(minutes: 20),
            const Duration(minutes: 43),
          );
        },
      );

      expect(focusedLabel(), 'Continue S2 · E3');
      expect(find.text('The Long Tide'), findsOneWidget, reason: 'season 2');
      expect(find.text('23 min left'), findsOneWidget);

      await tester.sendKeyEvent(LogicalKeyboardKey.enter);
      await settle(tester);
      expect(ui.launcher.played, ['The Long Tide from 1200']);

      await tester.tap(find.text('Season 1'));
      await settle(tester);
      expect(find.text('41 min · Watched'), findsOneWidget);
    });

    testWidgets('the last one watched finished: Continue with the next', (
      tester,
    ) async {
      await openLibrary(
        tester,
        location: page,
        before: (ui) async {
          await _kettleBay(ui);
          await ui.leftAt(
            _episode(2, 3),
            const Duration(minutes: 43),
            const Duration(minutes: 43),
            completed: true,
          );
        },
      );

      expect(focusedLabel(), 'Continue S2 · E4');
    });

    testWidgets("an episode's menu marks it as watched", (tester) async {
      await openLibrary(tester, location: page, before: _kettleBay);

      await tester.tap(find.text('Pilot'), buttons: kSecondaryMouseButton);
      await settle(tester);
      await tester.tap(find.text('Mark as watched'));
      await settle(tester);
      await settle(tester);
      // The season stays; Continue moves on to the next episode.
      expect(find.text('41 min · Watched'), findsOneWidget);
      expect(find.text('Continue S2 · E3'), findsOneWidget);
    });

    testWidgets('its drive away: the rows say so and Enter explains', (
      tester,
    ) async {
      final (ui, _) = await openLibrary(
        tester,
        location: page,
        before: (ui) => _kettleBay(ui, away: true),
      );

      expect(find.text('Drive not connected'), findsWidgets);
      await tester.sendKeyEvent(LogicalKeyboardKey.enter);
      await settle(tester);
      expect(ui.launcher.played, isEmpty);
      expect(find.textContaining("Movies HDD isn't connected"), findsOne);
    });

    testWidgets('by keys: Tab from Continue to the seasons to the '
        'episodes, the arrows inside, Esc back to the Library', (tester) async {
      final (_, app) = await openLibrary(
        tester,
        location: page,
        before: (ui) async {
          await _kettleBay(ui);
          await ui.add(
            ui.hdd,
            'Kettle Bay/Kettle.Bay.S01E02.mkv',
            'Ledger',
            kind: LibraryKind.episode,
            show: 'Kettle Bay',
            season: 1,
            episode: 2,
          );
        },
      );
      expect(focusedLabel(), 'Play S1 · E1');

      // Tab goes down the page — Cast beside Play, the episodes, round to
      // the way back, the seasons — each list one stop with the arrows
      // inside.
      await tester.sendKeyEvent(LogicalKeyboardKey.tab);
      await tester.pump();
      expect(focusedLabel(), 'Cast');
      await tester.sendKeyEvent(LogicalKeyboardKey.tab);
      await tester.pump();
      expect(focusedLabel(), 'S1 · E1, Pilot');
      await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
      await tester.pump();
      expect(focusedLabel(), 'S1 · E2, Ledger');

      await tester.sendKeyEvent(LogicalKeyboardKey.tab);
      await tester.pump();
      expect(focusedLabel(), 'Back to Library');
      await tester.sendKeyEvent(LogicalKeyboardKey.tab);
      await tester.pump();
      expect(focusedLabel(), 'Season 1');
      await tester.sendKeyEvent(LogicalKeyboardKey.arrowRight);
      await tester.pump();
      expect(focusedLabel(), 'Season 2');
      await tester.sendKeyEvent(LogicalKeyboardKey.arrowLeft);
      await tester.pump();
      expect(focusedLabel(), 'Season 1');

      // Play is beside the list: ← from an episode, → past Cast back to
      // it.
      await tester.sendKeyEvent(LogicalKeyboardKey.tab);
      await tester.pump();
      expect(focusedLabel(), startsWith('S1 · E'));
      await tester.sendKeyEvent(LogicalKeyboardKey.arrowLeft);
      await tester.pump();
      expect(focusedLabel(), 'Play S1 · E1');
      await tester.sendKeyEvent(LogicalKeyboardKey.arrowRight);
      await tester.pump();
      expect(focusedLabel(), 'Cast');
      await tester.sendKeyEvent(LogicalKeyboardKey.arrowRight);
      await tester.pump();
      expect(focusedLabel(), startsWith('S1 · E'));

      await tester.sendKeyEvent(LogicalKeyboardKey.escape);
      await settle(tester);
      expect(app.location, '/library');
    });

    testWidgets('no longer in the library: says so', (tester) async {
      await openLibrary(tester, location: '/library/show/l%3Agone');

      expect(find.text('Not available'), findsOneWidget);
      expect(
        find.text('This show is no longer in your library.'),
        findsOneWidget,
      );
    });
  });
}
