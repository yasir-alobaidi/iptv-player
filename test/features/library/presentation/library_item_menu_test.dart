import 'dart:io';

import 'package:drift/drift.dart' show Value;
import 'package:flutter/gestures.dart' show kSecondaryMouseButton;
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart' show EditableText;
import 'package:flutter_test/flutter_test.dart';
import 'package:iptv_player/core/library/library_item.dart';
import 'package:iptv_player/data/db/app_database.dart';
import 'package:iptv_player/design/components.dart';
import 'package:iptv_player/features/library/presentation/library_edit_dialog.dart';
import 'package:path/path.dart' as p;

import '../../../app/app_harness.dart';
import '../../vod/catalogue_screen_test.dart' show focusedLabel;
import '../../vod/vod_fakes.dart';
import 'library_ui_support.dart';

const _kites = 'Paper Kites (2019)/Paper Kites (2019).mkv';

Future<void> _two(LibraryUi ui) async {
  await ui.add(ui.hdd, _kites, 'Paper Kites', year: 2019);
  await ui.add(ui.hdd, 'Lamplight (2015).mkv', 'Lamplight', year: 2015);
}

void main() {
  Finder card(String title) => find.widgetWithText(PosterCard, title);

  List<String> posters(WidgetTester tester) => [
    for (final each in tester.widgetList<PosterCard>(find.byType(PosterCard)))
      each.title,
  ];

  /// Opens the menu of the card titled [title] with the menu key.
  Future<void> menu(WidgetTester tester, String title) async {
    tester.widget<PosterCard>(card(title)).focusNode!.requestFocus();
    await tester.pump();
    await tester.sendKeyEvent(LogicalKeyboardKey.contextMenu);
    await settle(tester);
  }

  /// The dialog's field labelled [label] (the top bar has a field too).
  Finder field(String label) => find.descendant(
    of: find.descendant(
      of: find.byType(AppDialog),
      matching: find.widgetWithText(AppTextField, label),
    ),
    matching: find.byType(EditableText),
  );

  Future<void> choose(WidgetTester tester, String item) async {
    await tester.tap(find.text(item));
    await settle(tester);
    await settle(tester);
  }

  testWidgets('the menu of a movie never played: Play, the favorite, Mark '
      'as watched, and what can be done with the file', (tester) async {
    final (ui, _) = await openLibrary(tester, before: _two);
    await menu(tester, 'Paper Kites (2019)');

    for (final item in [
      'Play',
      'Add to favorites',
      'Mark as watched',
      'Show in folder',
      'Edit details…',
      'Hide',
      'Remove from library',
      'Delete file…',
    ]) {
      expect(find.text(item), findsOneWidget, reason: item);
    }
    expect(find.text('Play from the start'), findsNothing);

    await choose(tester, 'Play');
    expect(ui.launcher.played, ['Paper Kites from 0']);
  });

  testWidgets('left part-way: Resume from there, or Play from the start; '
      'a right-click opens the same menu', (tester) async {
    final (ui, _) = await openLibrary(
      tester,
      before: (ui) async {
        await _two(ui);
        await ui.leftAt(
          _kites,
          const Duration(minutes: 42),
          const Duration(hours: 1, minutes: 52),
        );
      },
    );

    await tester.tap(
      card('Paper Kites (2019)'),
      buttons: kSecondaryMouseButton,
    );
    await settle(tester);
    await choose(tester, 'Resume');
    await menu(tester, 'Paper Kites (2019)');
    await choose(tester, 'Play from the start');
    expect(ui.launcher.played, ['Paper Kites from 2520', 'Paper Kites from 0']);
  });

  testWidgets('Hide takes it out of the Library, and Undo puts it back', (
    tester,
  ) async {
    await openLibrary(tester, before: _two);

    await menu(tester, 'Paper Kites (2019)');
    await choose(tester, 'Hide');
    expect(posters(tester), ['Lamplight (2015)']);
    expect(find.text('Hidden · Paper Kites'), findsOneWidget);

    await tester.tap(find.text('Undo'));
    await settle(tester);
    await settle(tester);
    expect(posters(tester), ['Lamplight (2015)', 'Paper Kites (2019)']);
  });

  testWidgets('Remove from library says the file stays', (tester) async {
    await openLibrary(tester, before: _two);

    await menu(tester, 'Lamplight (2015)');
    await choose(tester, 'Remove from library');
    expect(posters(tester), ['Paper Kites (2019)']);
    expect(
      find.text(
        'Removed Lamplight from the library. The file stays where it is.',
      ),
      findsOneWidget,
    );
  });

  testWidgets('Show in folder asks the file manager for the file', (
    tester,
  ) async {
    final (ui, _) = await openLibrary(tester, before: _two);

    await menu(tester, 'Paper Kites (2019)');
    await choose(tester, 'Show in folder');
    expect(ui.revealed, [p.join('/media/hdd/Movies', _kites)]);
  });

  testWidgets('Mark as watched, and the favorite, from the menu', (
    tester,
  ) async {
    await openLibrary(tester, before: _two);

    await menu(tester, 'Paper Kites (2019)');
    await choose(tester, 'Add to favorites');
    expect(
      tester.widget<PosterCard>(card('Paper Kites (2019)')).cornerBadge,
      isNotNull,
    );

    await menu(tester, 'Paper Kites (2019)');
    await choose(tester, 'Mark as watched');
    await menu(tester, 'Paper Kites (2019)');
    expect(find.text('Mark as unwatched'), findsOneWidget);
    expect(find.text('Remove from favorites'), findsOneWidget);
  });

  group('Edit details (sketch F)', () {
    testWidgets("the file's name, what it is, and its fields; Save changes "
        'what the Library shows', (tester) async {
      await openLibrary(tester, before: _two);
      await menu(tester, 'Paper Kites (2019)');
      await choose(tester, 'Edit details…');

      expect(find.text('Edit details'), findsOneWidget);
      expect(find.text('Paper Kites (2019).mkv'), findsOneWidget);
      expect(find.text('Year'), findsOneWidget);
      expect(find.text('Show'), findsNothing, reason: 'a movie has none');
      expect(find.text("Use the file's name"), findsNothing);

      // Enter in a field saves.
      await tester.enterText(field('Title'), 'Kites');
      await tester.testTextInput.receiveAction(TextInputAction.done);
      await settle(tester);
      await settle(tester);
      expect(posters(tester), ['Kites (2019)', 'Lamplight (2015)']);
    });

    testWidgets('an empty title is refused, in the field', (tester) async {
      await openLibrary(tester, before: _two);
      await menu(tester, 'Paper Kites (2019)');
      await choose(tester, 'Edit details…');

      await tester.enterText(field('Title'), '  ');
      await tester.tap(find.widgetWithText(AppButton, 'Save'));
      await settle(tester);
      expect(find.text('A title is needed'), findsOneWidget);
      expect(find.text('Edit details'), findsOneWidget, reason: 'still open');

      await tester.tap(find.widgetWithText(AppButton, 'Cancel'));
      await settle(tester);
      expect(posters(tester), contains('Paper Kites (2019)'));
    });

    testWidgets('made an episode: it has a show, a season and an episode, '
        'and moves to Series', (tester) async {
      await openLibrary(tester, before: _two);
      await menu(tester, 'Lamplight (2015)');
      await choose(tester, 'Edit details…');

      await tester.tap(find.text('Episode'));
      await settle(tester);
      expect(field('Year'), findsNothing);
      await tester.enterText(field('Show'), 'Harbor Nine');
      await tester.enterText(field('Season'), '1');
      await tester.enterText(field('Episode'), 'x');
      await tester.tap(find.widgetWithText(AppButton, 'Save'));
      await settle(tester);
      expect(find.text('A number'), findsOneWidget);

      await tester.enterText(field('Episode'), '3');
      await tester.enterText(field('Title'), '');
      await tester.tap(find.widgetWithText(AppButton, 'Save'));
      await settle(tester);
      await settle(tester);
      expect(posters(tester), ['Paper Kites (2019)']);
      expect(
        tester.widget<CountTab>(find.widgetWithText(CountTab, 'Series')).count,
        1,
      );
    });
  });

  testWidgets('Delete file… asks first with Keep focused; Move to trash '
      'takes the file and its card', (tester) async {
    final temp = Directory.systemTemp.createTempSync('library_menu_');
    addTearDown(() => temp.deleteSync(recursive: true));
    final file = File(p.join(temp.path, 'Lamplight (2015).mkv'))
      ..writeAsStringSync('video');
    await openLibrary(
      tester,
      before: (ui) async {
        await _two(ui);
        await ui.db.libraryDao.changeFolder(
          ui.hdd,
          LibraryFoldersCompanion(path: Value(temp.path)),
        );
      },
    );

    await menu(tester, 'Lamplight (2015)');
    await choose(tester, 'Delete file…');
    expect(find.text('Delete "Lamplight (2015).mkv"?'), findsOneWidget);
    expect(focusedLabel(), 'Keep');
    await tester.sendKeyEvent(LogicalKeyboardKey.enter);
    await settle(tester);
    expect(file.existsSync(), isTrue);
    expect(posters(tester), hasLength(2));
  });

  testWidgets("a movie's page: ⋯ has the menu, and removing the movie goes "
      'back to the Library', (tester) async {
    final (_, app) = await openLibrary(
      tester,
      location: '/library/movie/1',
      before: _two,
    );

    await tester.tap(findByLabel('More'));
    await settle(tester);
    expect(find.text('Edit details…'), findsOneWidget);
    await choose(tester, 'Remove from library');
    expect(app.location, '/library');
    expect(posters(tester), ['Lamplight (2015)']);
  });

  testWidgets("a show's page: an episode's menu is the same one", (
    tester,
  ) async {
    await openLibrary(
      tester,
      location: '/library/show/l%3Akettle%20bay',
      before: (ui) async {
        for (final episode in [1, 2]) {
          await ui.add(
            ui.hdd,
            'Kettle Bay/Kettle.Bay.S01E0$episode.mkv',
            'Part $episode',
            kind: LibraryKind.episode,
            show: 'Kettle Bay',
            season: 1,
            episode: episode,
          );
        }
      },
    );

    await tester.tap(find.text('Part 2'), buttons: kSecondaryMouseButton);
    await settle(tester);
    expect(find.text('Edit details…'), findsOneWidget);
    await choose(tester, 'Hide');
    expect(find.text('Part 2'), findsNothing);
    expect(find.text('Part 1'), findsOneWidget);
  });

  group('what the fields of Edit details make', () {
    test('a movie: its title, and a year if one is given', () {
      expect(
        libraryEditFrom(
          kind: LibraryKind.movie,
          title: ' Paper Kites ',
          year: '2019',
        ).edit,
        const LibraryItemEdit(
          kind: LibraryKind.movie,
          title: 'Paper Kites',
          year: 2019,
        ),
      );
      expect(
        libraryEditFrom(kind: LibraryKind.movie, title: 'A').edit?.year,
        isNull,
      );
      expect(
        libraryEditFrom(kind: LibraryKind.movie, title: 'A', year: '19').errors,
        {'year': 'A year, like 2019'},
      );
      expect(libraryEditFrom(kind: LibraryKind.movie, title: '').errors, {
        'title': 'A title is needed',
      });
    });

    test("an episode: its show, numbers, and the show's name for a title "
        'it does not have', () {
      final made = libraryEditFrom(
        kind: LibraryKind.episode,
        title: '',
        show: 'Kettle Bay',
        season: '2',
        episode: '4',
        year: 'ignored',
      );
      expect(
        made.edit,
        const LibraryItemEdit(
          kind: LibraryKind.episode,
          title: 'Kettle Bay',
          showTitle: 'Kettle Bay',
          season: 2,
          episode: 4,
        ),
      );
      expect(
        libraryEditFrom(
          kind: LibraryKind.episode,
          title: 'x',
          episode: '-1',
        ).errors.keys,
        {'show', 'episode'},
      );
    });

    test('a video: only its title', () {
      expect(
        libraryEditFrom(
          kind: LibraryKind.unsorted,
          title: 'Birthday',
          year: '2019',
          show: 'x',
        ).edit,
        const LibraryItemEdit(kind: LibraryKind.unsorted, title: 'Birthday'),
      );
    });
  });
}
