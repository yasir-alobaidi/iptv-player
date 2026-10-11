import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:iptv_player/core/library/library_item.dart';
import 'package:iptv_player/design/components.dart';
import 'package:iptv_player/features/library/presentation/library_routes.dart';
import 'package:iptv_player/features/search/presentation/search_overlay.dart';
import 'package:iptv_player/features/search/presentation/search_state.dart';

import '../../app/app_harness.dart';
import '../library/presentation/library_ui_support.dart';
import '../vod/vod_fakes.dart';

/// Search's LIBRARY group (canvas `Search`, Phase 8 step 6), on the real
/// search repository over the library's own database: what is found, how
/// a row reads, and what Enter and the menu do.
void main() {
  /// A library of things called "kite", and the provider's catalogue of
  /// [VodFakes] ("Glass Tide" is its series, "The Quiet Harbor" a movie).
  Future<void> library(LibraryUi ui) async {
    await ui.add(
      ui.home,
      'Kite Walk (2021).mkv',
      'Kite Walk',
      year: 2021,
      duration: const Duration(minutes: 12),
    );
    await ui.add(
      ui.home,
      'clips/kite-timelapse.mp4',
      'Kite timelapse',
      kind: LibraryKind.unsorted,
      duration: const Duration(minutes: 4),
    );
    await ui.leftAt(
      'clips/kite-timelapse.mp4',
      const Duration(minutes: 2),
      const Duration(minutes: 4),
    );
    for (final (season, episode, title) in [
      (1, 1, 'Pilot'),
      (2, 3, 'The Long Tide'),
    ]) {
      await ui.add(
        ui.hdd,
        'Kite Nine/S0${season}E0$episode.mkv',
        title,
        kind: LibraryKind.episode,
        show: 'Kite Nine',
        season: season,
        episode: episode,
        duration: const Duration(minutes: 44),
      );
    }
    // The provider dropped it: only the library finds it.
    await ui.add(
      ui.downloads,
      'Kite Dropped.mkv',
      'Kite Dropped',
      provider: 'gone',
      duration: const Duration(hours: 1, minutes: 52),
    );
    // The provider lists it: MOVIES finds it, the library leaves it out.
    await ui.add(
      ui.downloads,
      'The Quiet Harbor.mkv',
      'The Quiet Harbor',
      provider: '501',
    );
    await ui.add(
      ui.hdd,
      'Kite Away.mkv',
      'Kite Away',
      duration: const Duration(minutes: 90),
      away: true,
    );
  }

  late LibraryUi ui;
  late AppUnderTest app;

  Future<void> open(WidgetTester tester) async {
    (ui, app) = await openLibrary(tester, before: library);
    await tester.sendKeyDownEvent(LogicalKeyboardKey.controlLeft);
    await tester.sendKeyEvent(LogicalKeyboardKey.keyK);
    await tester.sendKeyUpEvent(LogicalKeyboardKey.controlLeft);
    await settle(tester);
  }

  Future<void> type(WidgetTester tester, String text) async {
    await tester.enterText(find.byType(EditableText), text);
    await tester.pump(searchDelay);
    await settle(tester);
  }

  Future<void> key(WidgetTester tester, LogicalKeyboardKey key) async {
    await tester.sendKeyEvent(key);
    await tester.pump();
  }

  Future<void> enter(WidgetTester tester) async {
    await tester.testTextInput.receiveAction(TextInputAction.search);
    await settle(tester);
  }

  /// The names of the rows, top to bottom (each is the one rich text of
  /// its row).
  List<String> rows(WidgetTester tester) => [
    for (final text in tester.widgetList<Text>(
      find.byWidgetPredicate((w) => w is Text && w.textSpan != null),
    ))
      text.textSpan!.toPlainText(),
  ];

  /// The name on the row the cursor is on: the one with the Enter keycap.
  String? cursorRow(WidgetTester tester) {
    final row = find
        .ancestor(
          of: find.widgetWithText(Kbd, 'Enter'),
          matching: find.byType(Row),
        )
        .evaluate()
        .map((element) => element.widget)
        .firstOrNull;
    if (row == null) return null;
    final names = tester.widgetList<Text>(
      find.descendant(
        of: find.byWidget(row),
        matching: find.byWidgetPredicate(
          (w) => w is Text && w.textSpan != null,
        ),
      ),
    );
    return names.firstOrNull?.textSpan!.toPlainText();
  }

  /// Moves the cursor down to the row named [name].
  Future<void> moveTo(WidgetTester tester, String name) async {
    for (var i = 0; i < 12 && cursorRow(tester) != name; i++) {
      await key(tester, LogicalKeyboardKey.arrowDown);
    }
    expect(cursorRow(tester), name);
  }

  testWidgets('the LIBRARY group: a movie with its year, a show as one row, '
      'a video, a download the provider dropped, a drive that is away', (
    tester,
  ) async {
    await open(tester);
    await type(tester, 'kite');

    expect(find.text('LIBRARY'), findsOneWidget);
    expect(
      rows(tester),
      unorderedEquals([
        'Kite Walk (2021)',
        'Kite timelapse',
        'Kite Nine',
        'Kite Dropped',
        'Kite Away',
      ]),
    );
    expect(find.text('5 results'), findsOneWidget);
    expect(find.text('Home videos · 12 min'), findsOneWidget);
    expect(find.text('Home videos · 4 min'), findsOneWidget);
    expect(find.text('Movies HDD · 2 seasons'), findsOneWidget);
    expect(find.text('Downloaded · 1 h 52 min'), findsOneWidget);
    // The Library under the overlay says it on the movie's card too.
    expect(
      find.descendant(
        of: find.byType(SearchOverlay),
        matching: find.text('Drive not connected'),
      ),
      findsOneWidget,
    );
    expect(find.textContaining('Show all'), findsNothing);
  });

  testWidgets('after SERIES; a download the provider lists is its movie, '
      'once', (tester) async {
    await open(tester);
    await ui.add(
      ui.home,
      'Glass Kites.mkv',
      'Glass Kites',
      duration: const Duration(minutes: 30),
    );
    await type(tester, 'glass');

    expect(
      tester.getTopLeft(find.text('SERIES')).dy,
      lessThan(tester.getTopLeft(find.text('LIBRARY')).dy),
    );
    expect(rows(tester), ['Glass Tide', 'Glass Kites']);

    await type(tester, 'quiet');
    expect(find.text('MOVIES'), findsOneWidget);
    expect(find.text('LIBRARY'), findsNothing);
    expect(rows(tester), ['The Quiet Harbor']);
  });

  testWidgets('a movie on this computer says DOWNLOADED in its row; one '
      "that isn't downloads with Ctrl+D or from its menu", (tester) async {
    await open(tester);
    await type(tester, 'quiet');
    expect(rows(tester), ['The Quiet Harbor']);
    expect(find.byType(DownloadedPill), findsOneWidget);
    // Nothing left to download: the menu has the favorite alone.
    await key(tester, LogicalKeyboardKey.contextMenu);
    await settle(tester);
    expect(find.text('Add to favorites'), findsOneWidget);
    expect(find.text('Download'), findsNothing);
    await tester.sendKeyEvent(LogicalKeyboardKey.escape);
    await settle(tester);

    await type(tester, 'copper');
    expect(rows(tester), ['Copper Hollow']);
    expect(find.byType(DownloadedPill), findsNothing);
    await tester.sendKeyDownEvent(LogicalKeyboardKey.controlLeft);
    await tester.sendKeyEvent(LogicalKeyboardKey.keyD);
    await tester.sendKeyUpEvent(LogicalKeyboardKey.controlLeft);
    await settle(tester);
    expect(ui.queue.calls, ['enqueue 502']);
    expect(find.text('Downloading Copper Hollow'), findsOneWidget);
    expect(find.text('MOVIES'), findsOneWidget, reason: 'search stays open');

    await key(tester, LogicalKeyboardKey.contextMenu);
    await settle(tester);
    expect(find.text('Ctrl+D'), findsOneWidget);
    await tester.tap(find.text('Download'));
    await settle(tester);
    await settle(tester);
    expect(ui.queue.calls, ['enqueue 502', 'enqueue 502']);

    // Ctrl+D on a series does nothing: it downloads by its episodes.
    await type(tester, 'glass');
    expect(rows(tester), ['Glass Tide']);
    await tester.sendKeyDownEvent(LogicalKeyboardKey.controlLeft);
    await tester.sendKeyEvent(LogicalKeyboardKey.keyD);
    await tester.sendKeyUpEvent(LogicalKeyboardKey.controlLeft);
    await settle(tester);
    expect(ui.queue.calls, hasLength(2));
  });

  testWidgets('an episode found by its own title names its show', (
    tester,
  ) async {
    await open(tester);
    await type(tester, 'long tide');

    expect(rows(tester), ['The Long Tide']);
    expect(find.text('Kite Nine · S2 · E3 · 44 min'), findsOneWidget);
  });

  testWidgets('Tab jumps to the LIBRARY group', (tester) async {
    await open(tester);
    await ui.add(ui.home, 'Glass Kites.mkv', 'Glass Kites');
    await type(tester, 'glass');

    expect(cursorRow(tester), 'Glass Tide');
    await key(tester, LogicalKeyboardKey.tab);
    expect(cursorRow(tester), 'Glass Kites');
  });

  testWidgets('Enter on a movie of your own opens its page in the Library, '
      'and saves the search', (tester) async {
    await open(tester);
    await type(tester, 'kite walk');

    await enter(tester);
    final id = (await tester.runAsync(
      () => ui.db.libraryDao.watchItems(kind: LibraryKind.movie).first,
    ))!.firstWhere((row) => row.title == 'Kite Walk').id;
    expect(app.location, '/library/movie/$id');
    expect(find.text('Kite Walk'), findsWidgets);
    expect(find.text('LIBRARY'), findsNothing, reason: 'search closed');
    final recent = await tester.runAsync(
      () => ui.db.settingsDao.read('search.recent'),
    );
    expect(recent, contains('kite walk'));
  });

  testWidgets('Enter on a show opens its page', (tester) async {
    await open(tester);
    await type(tester, 'kite nine');

    await enter(tester);
    expect(app.router.state.uri.toString(), libraryShowPath('l:kite nine'));
    expect(find.text('Kite Nine'), findsWidgets);
  });

  testWidgets('Enter on a video plays it from where it was left; on an '
      'episode found by its title, the episode', (tester) async {
    await open(tester);
    await type(tester, 'kite timelapse');
    await enter(tester);

    expect(ui.launcher.played, ['Kite timelapse from 120']);
    expect(find.text('LIBRARY'), findsNothing, reason: 'search closed');

    await tester.sendKeyDownEvent(LogicalKeyboardKey.controlLeft);
    await tester.sendKeyEvent(LogicalKeyboardKey.keyK);
    await tester.sendKeyUpEvent(LogicalKeyboardKey.controlLeft);
    await settle(tester);
    await type(tester, 'long tide');
    await enter(tester);
    expect(ui.launcher.played.last, 'The Long Tide from 0');
  });

  testWidgets("a video whose drive is away says so and doesn't play; a "
      'movie still opens its page', (tester) async {
    await open(tester);
    await ui.add(
      ui.hdd,
      'clips/kite-away.mp4',
      'Kite clip away',
      kind: LibraryKind.unsorted,
      away: true,
    );
    await type(tester, 'kite clip');
    await enter(tester);

    expect(ui.launcher.played, isEmpty);
    expect(
      find.text("Movies HDD isn't connected. Connect its drive to play this."),
      findsOneWidget,
    );
  });

  testWidgets("the Menu key opens the Library's menu; Play closes search", (
    tester,
  ) async {
    await open(tester);
    await type(tester, 'kite timelapse');

    await key(tester, LogicalKeyboardKey.contextMenu);
    await settle(tester);
    expect(find.text('Resume'), findsOneWidget);
    expect(find.text('Play from the start'), findsOneWidget);
    expect(find.text('Edit details…'), findsOneWidget);
    expect(find.text('Delete file…'), findsOneWidget);

    await tester.tap(find.text('Play from the start'));
    await settle(tester);
    await settle(tester);
    expect(ui.launcher.played, ['Kite timelapse from 0']);
    expect(find.text('LIBRARY'), findsNothing, reason: 'search closed');
  });

  testWidgets('Hide from the menu takes the row away, with Undo', (
    tester,
  ) async {
    await open(tester);
    await type(tester, 'kite');
    await moveTo(tester, 'Kite Walk (2021)');

    await key(tester, LogicalKeyboardKey.contextMenu);
    await settle(tester);
    await tester.tap(find.text('Hide'));
    await settle(tester);
    await settle(tester);

    expect(rows(tester), isNot(contains('Kite Walk (2021)')));
    expect(rows(tester), contains('Kite Nine'));
    expect(find.text('Hidden · Kite Walk'), findsOneWidget);
  });

  testWidgets('Edit details from the menu: the row follows the new title', (
    tester,
  ) async {
    await open(tester);
    await type(tester, 'kite');
    await moveTo(tester, 'Kite Walk (2021)');

    await key(tester, LogicalKeyboardKey.contextMenu);
    await settle(tester);
    await tester.tap(find.text('Edit details…'));
    await settle(tester);
    await settle(tester);
    await tester.enterText(
      find.descendant(
        of: find.widgetWithText(AppTextField, 'Title'),
        matching: find.byType(EditableText),
      ),
      'Kite Promenade',
    );
    await tester.tap(find.text('Save'));
    await settle(tester);
    await settle(tester);

    expect(rows(tester), contains('Kite Promenade (2021)'));
    expect(rows(tester), isNot(contains('Kite Walk (2021)')));
  });

  testWidgets('a show has no menu', (tester) async {
    await open(tester);
    await type(tester, 'kite nine');

    await key(tester, LogicalKeyboardKey.contextMenu);
    await settle(tester);
    expect(find.text('Add to favorites'), findsNothing);
    expect(find.text('Hide'), findsNothing);
    expect(cursorRow(tester), 'Kite Nine');
  });
}
