import 'dart:async';
import 'dart:io';

import 'package:drift/drift.dart' show Value;
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:iptv_player/core/library/library_item.dart';
import 'package:iptv_player/core/library/library_repository.dart';
import 'package:iptv_player/data/db/app_database.dart';
import 'package:iptv_player/data/library/library_scan.dart';
import 'package:iptv_player/design/components.dart';
import 'package:iptv_player/features/library/data/library_providers.dart';
import 'package:iptv_player/features/library/presentation/library_routes.dart';
import 'package:iptv_player/features/vod/presentation/title_grid.dart';
import 'package:path/path.dart' as p;

import '../../../app/app_harness.dart';
import '../../vod/catalogue_screen_test.dart' show focusedLabel;
import '../../vod/vod_fakes.dart';
import 'library_ui_support.dart';

/// A library that never answers, or fails: the screen's loading and
/// error states.
final class _StuckLibrary implements LibraryRepository {
  new({this.fails = false});

  final bool fails;

  @override
  Stream<LibraryCount> watchCount(LibraryQuery query) =>
      fails ? Stream.error(StateError('disk I/O error')) : const Stream.empty();

  @override
  Stream<List<LibraryShow>> watchShows({
    LibraryOrigin origin = LibraryOrigin.all,
  }) => const Stream.empty();

  @override
  Stream<List<LibraryFolder>> watchFolders() => const Stream.empty();

  @override
  Stream<Map<int, LibraryFolderTotals>> watchFolderTotals() =>
      const Stream.empty();

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

/// The library the canvas draws, in small: two downloads (one the
/// provider still lists, one in progress), two films of the user's own
/// (one on a drive that is away), a show in two seasons, a downloaded
/// episode, and two home videos.
Future<void> _canvas(LibraryUi ui) async {
  await ui.add(
    ui.downloads,
    'Movies/The Quiet Harbor.mp4',
    'The Quiet Harbor',
    bytes: (2.1 * gb).round(),
    provider: '501',
  );
  await ui.add(
    ui.downloads,
    'Movies/Northwind Hotel.mp4',
    'Northwind Hotel',
    bytes: (3.4 * gb).round(),
    provider: '999',
  );
  await ui.add(
    ui.hdd,
    'Paper Kites (2019)/Paper Kites (2019).mkv',
    'Paper Kites',
    year: 2019,
    bytes: 4 * gb,
  );
  await ui.add(
    ui.hdd,
    'Coldwater (2020).mkv',
    'Coldwater',
    year: 2020,
    bytes: 2 * gb,
    away: true,
  );
  for (final (season, episode) in [(1, 1), (1, 2), (2, 1)]) {
    await ui.add(
      ui.hdd,
      'Kettle Bay/S0$season/Kettle.Bay.S0${season}E0$episode.mkv',
      'Episode $episode',
      kind: LibraryKind.episode,
      show: 'Kettle Bay',
      season: season,
      episode: episode,
    );
  }
  await ui.add(
    ui.downloads,
    'Series/Glass Tide/S01E01.mp4',
    'Low Water',
    kind: LibraryKind.episode,
    show: 'Glass Tide',
    season: 1,
    episode: 1,
    provider: '7101',
    series: '77',
  );
  await ui.add(
    ui.home,
    'Birthday at the lake.mp4',
    'Birthday at the lake',
    kind: LibraryKind.unsorted,
    duration: const Duration(minutes: 12),
  );
  await ui.add(
    ui.home,
    'Garden timelapse.mp4',
    'Garden timelapse',
    kind: LibraryKind.unsorted,
    duration: const Duration(minutes: 4),
    away: true,
  );
}

void main() {
  List<String> posters(WidgetTester tester) => [
    for (final card in tester.widgetList<PosterCard>(find.byType(PosterCard)))
      card.title,
  ];

  Finder tab(String label) => find.widgetWithText(CountTab, label);

  Future<void> show(WidgetTester tester, String label) async {
    await tester.tap(tab(label));
    await settle(tester);
  }

  testWidgets('before the library has answered: the tabs and a grid of '
      'skeletons', (tester) async {
    await openLibrary(
      tester,
      overrides: [libraryRepositoryProvider.overrideWithValue(_StuckLibrary())],
    );

    expect(tab('Movies'), findsOneWidget);
    expect(find.byType(TitleGridSkeleton), findsOneWidget);
    expect(find.byType(SkeletonPoster), findsWidgets);
    expect(find.byType(EmptyState), findsNothing);
  });

  testWidgets("a list that can't be read: says so, with Retry", (tester) async {
    await openLibrary(
      tester,
      overrides: [
        libraryRepositoryProvider.overrideWithValue(_StuckLibrary(fails: true)),
      ],
    );

    expect(find.text("Couldn't load your movies"), findsOneWidget);
    expect(find.text('Retry'), findsOneWidget);
    expect(find.textContaining('StateError'), findsNothing);
  });

  testWidgets('the first run: what to do, Add folder, and the folder added '
      'is scanned', (tester) async {
    final temp = Directory.systemTemp.createTempSync('library_ui_');
    addTearDown(() => temp.deleteSync(recursive: true));
    final (ui, _) = await openLibrary(tester);

    expect(
      find.text('Add a folder with your own movies and shows'),
      findsOneWidget,
    );
    expect(
      find.text('Press D on a movie or episode to download it.'),
      findsOneWidget,
    );
    expect(find.text('All'), findsNothing, reason: 'no chips with nothing');

    // Nothing chosen in the dialog: nothing happens.
    await tester.tap(find.widgetWithText(AppButton, 'Add folder').last);
    await settle(tester);
    expect(ui.scanned, isEmpty);

    ui.picked = temp.path;
    await tester.tap(find.widgetWithText(AppButton, 'Add folder').last);
    await settle(tester);
    expect(find.textContaining('Its videos appear as it is scanned'), findsOne);
    expect(ui.scanned, hasLength(1));

    // The same folder again: refused in our words.
    await tester.tap(find.widgetWithText(AppButton, 'Add folder').first);
    await settle(tester);
    // Toasts take turns: the first one's time passes.
    await tester.pump(AppToast.defaultDuration);
    await settle(tester);
    expect(find.textContaining('is already in the library'), findsOneWidget);
  });

  testWidgets('Movies as the canvas draws them: the counts, the size, each '
      "movie's place, and a drive that is away", (tester) async {
    await openLibrary(tester, before: _canvas);

    expect(find.widgetWithText(CountTab, '4'), findsOneWidget);
    expect(
      tester.widget<CountTab>(tab('Series')).count,
      2,
      reason: 'Kettle Bay and Glass Tide',
    );
    expect(tester.widget<CountTab>(tab('Videos')).count, 2);
    expect(tester.widget<CountTab>(tab('Folders')).count, isNull);
    expect(find.text('4 movies · 11.5 GB on this computer'), findsOneWidget);

    expect(posters(tester), [
      'Coldwater (2020)',
      'Northwind Hotel',
      'Paper Kites (2019)',
      'The Quiet Harbor',
    ]);
    PosterCard card(String title) =>
        tester.widget(find.widgetWithText(PosterCard, title));
    expect(card('The Quiet Harbor').meta, 'Downloaded · 2.1 GB');
    expect(card('The Quiet Harbor').metaTone, CardMetaTone.success);
    expect(card('Paper Kites (2019)').meta, 'Movies HDD');
    expect(card('Paper Kites (2019)').dimmed, isFalse);
    expect(card('Coldwater (2020)').meta, 'Drive not connected');
    expect(card('Coldwater (2020)').metaTone, CardMetaTone.warning);
    expect(card('Coldwater (2020)').dimmed, isTrue);
  });

  testWidgets('the chips: Downloaded, Local folders, and what an empty one '
      'says', (tester) async {
    final (_, app) = await openLibrary(
      tester,
      before: (ui) => ui.add(ui.hdd, 'Paper Kites (2019).mkv', 'Paper Kites'),
    );

    await tester.tap(find.text('Local folders'));
    await settle(tester);
    expect(posters(tester), ['Paper Kites']);
    expect(find.text('1 movie · 1.0 GB on this computer'), findsOneWidget);

    await tester.tap(find.text('Downloaded'));
    await settle(tester);
    expect(find.text('No downloaded movies'), findsOneWidget);
    expect(find.textContaining('on this computer'), findsNothing);
    // The tab still counts the whole library.
    expect(tester.widget<CountTab>(tab('Movies')).count, 1);

    await tester.tap(find.text('Open Movies'));
    await settle(tester);
    expect(app.location, '/movies');
  });

  testWidgets('the chip is kept from Movies to Series, and Videos has '
      'none', (tester) async {
    await openLibrary(tester, before: _canvas);

    await tester.tap(find.text('Downloaded'));
    await settle(tester);
    expect(posters(tester), ['Northwind Hotel', 'The Quiet Harbor']);

    await show(tester, 'Series');
    expect(posters(tester), ['Glass Tide']);
    expect(find.text('1 show · 1.0 GB on this computer'), findsOneWidget);

    await show(tester, 'Videos');
    expect(find.byType(SegmentedControl<LibraryOrigin>), findsNothing);
    expect(find.byType(LandscapeCard), findsNWidgets(2));
  });

  testWidgets('Series: a show across its seasons with its folder, a '
      "download with its episodes; Enter opens the show's page", (
    tester,
  ) async {
    final (_, app) = await openLibrary(
      tester,
      before: (ui) async {
        await _canvas(ui);
        // The provider no longer lists Glass Tide: its page is the
        // Library's.
        await ui.db.delete(ui.db.series).go();
      },
    );
    await show(tester, 'Series');

    expect(posters(tester), ['Glass Tide', 'Kettle Bay']);
    PosterCard card(String title) =>
        tester.widget(find.widgetWithText(PosterCard, title));
    expect(card('Kettle Bay').meta, '2 seasons · Movies HDD');
    expect(card('Glass Tide').meta, '1 episode · Downloaded');
    expect(find.text('2 shows · 4.0 GB on this computer'), findsOneWidget);

    card('Kettle Bay').focusNode!.requestFocus();
    await tester.pump();
    await tester.sendKeyEvent(LogicalKeyboardKey.enter);
    await settle(tester);
    expect(app.location, libraryShowPath('l:kettle bay'));
    expect(find.text('Kettle Bay'), findsWidgets);

    await tester.sendKeyEvent(LogicalKeyboardKey.escape);
    await settle(tester);
    expect(app.location, '/library');
    expect(focusedLabel(), contains('Kettle Bay'), reason: 'back on its card');
  });

  testWidgets('a downloaded series the provider still lists opens the '
      "provider's page, inside the Library", (tester) async {
    final (_, app) = await openLibrary(tester, before: _canvas);
    await show(tester, 'Series');

    await tester.tap(find.widgetWithText(PosterCard, 'Glass Tide'));
    await settle(tester);
    expect(app.location, '/library/series/src-1/77');
    expect(findByLabel('Back to Library'), findsOneWidget);
  });

  testWidgets('Enter on a movie: its own page for a file and for a '
      "download the provider dropped, the provider's for one it lists", (
    tester,
  ) async {
    final (_, app) = await openLibrary(tester, before: _canvas);
    Future<String> open(String title) async {
      await tester.tap(find.widgetWithText(PosterCard, title));
      await settle(tester);
      final at = app.location;
      await tester.sendKeyEvent(LogicalKeyboardKey.escape);
      await settle(tester);
      expect(app.location, '/library');
      return at;
    }

    expect(await open('Paper Kites (2019)'), startsWith('/library/movie/'));
    expect(await open('Northwind Hotel'), startsWith('/library/movie/'));
    expect(await open('The Quiet Harbor'), '/library/movies/src-1/501');
  });

  testWidgets('Videos: frames with their length and folder; Enter plays '
      'from where it was left; a drive that is away says so', (tester) async {
    final (ui, _) = await openLibrary(
      tester,
      before: (ui) async {
        await _canvas(ui);
        await ui.leftAt(
          'Birthday at the lake.mp4',
          const Duration(minutes: 5),
          const Duration(minutes: 12),
        );
      },
    );
    await show(tester, 'Videos');

    expect(find.text('2 videos · 2.0 GB on this computer'), findsOneWidget);
    LandscapeCard card(String title) =>
        tester.widget(find.widgetWithText(LandscapeCard, title));
    expect(card('Birthday at the lake').subtitle, '12 min · Home videos');
    expect(card('Birthday at the lake').progress, closeTo(5 / 12, 0.01));
    expect(card('Garden timelapse').subtitle, 'Drive not connected');
    expect(card('Garden timelapse').dimmed, isTrue);

    card('Birthday at the lake').focusNode!.requestFocus();
    await tester.pump();
    await tester.sendKeyEvent(LogicalKeyboardKey.enter);
    await settle(tester);
    expect(ui.launcher.played, ['Birthday at the lake from 300']);

    await tester.tap(find.widgetWithText(LandscapeCard, 'Garden timelapse'));
    await settle(tester);
    expect(ui.launcher.played, hasLength(1));
    expect(
      find.text("Home videos isn't connected. Connect its drive to play this."),
      findsOneWidget,
    );
  });

  testWidgets('an empty Videos tab says what goes there', (tester) async {
    await openLibrary(
      tester,
      before: (ui) => ui.add(ui.hdd, 'Paper Kites (2019).mkv', 'Paper Kites'),
    );
    await show(tester, 'Videos');

    expect(find.text('No other videos'), findsOneWidget);
    expect(find.textContaining('on this computer'), findsNothing);
  });

  testWidgets('Folders: the list Settings has, the download folder first, '
      'and what they hold together', (tester) async {
    await openLibrary(tester, before: _canvas);
    await show(tester, 'Folders');

    expect(find.text('3 folders · 17.5 GB on this computer'), findsOneWidget);
    expect(find.text(p.join('~', 'Videos', 'IPTV Player')), findsOneWidget);
    expect(find.text('/media/hdd/Movies'), findsOneWidget);
    expect(find.textContaining('Movies HDD · 5 videos'), findsOneWidget);
    expect(find.text('Rescan'), findsWidgets);
  });

  testWidgets('a scan running shows beside the count, and goes when it '
      'ends', (tester) async {
    final (ui, _) = await openLibrary(tester, before: _canvas);
    ui
      ..scanGate = Completer<void>()
      ..scanProgress = const LibraryScanProgress(
        folderId: 2,
        found: 1204,
        written: 800,
      );
    unawaited(ui.scans.scan(folderId: ui.hdd));
    await settle(tester);

    expect(find.text('Scanning · 1,204 found'), findsOneWidget);
    expect(find.byType(AppSpinner), findsOneWidget);
    expect(posters(tester), hasLength(4), reason: 'the grid stays');

    ui.scanGate!.complete();
    await settle(tester);
    expect(find.textContaining('Scanning'), findsNothing);
  });

  testWidgets('F keeps a movie as a favorite, and takes it back', (
    tester,
  ) async {
    await openLibrary(tester, before: _canvas);
    final card = find.widgetWithText(PosterCard, 'Paper Kites (2019)');
    tester.widget<PosterCard>(card).focusNode!.requestFocus();
    await tester.pump();

    await tester.sendKeyEvent(LogicalKeyboardKey.keyF);
    await settle(tester);
    expect(tester.widget<PosterCard>(card).cornerBadge, isNotNull);

    await tester.sendKeyEvent(LogicalKeyboardKey.keyF);
    await settle(tester);
    expect(tester.widget<PosterCard>(card).cornerBadge, isNull);
  });

  testWidgets('by keys alone: Ctrl+7 opens it; Tab walks the tabs, Add '
      'folder, the chips and the grid; the arrows move in the grid', (
    tester,
  ) async {
    final (_, app) = await openLibrary(
      tester,
      location: '/movies',
      before: _canvas,
    );
    await tester.sendKeyDownEvent(LogicalKeyboardKey.controlLeft);
    await tester.sendKeyEvent(LogicalKeyboardKey.digit7);
    await tester.sendKeyUpEvent(LogicalKeyboardKey.controlLeft);
    await settle(tester);
    expect(app.location, '/library');

    final walked = <String?>[focusedLabel()];
    for (var i = 0; i < 9; i++) {
      await tester.sendKeyEvent(LogicalKeyboardKey.tab);
      await tester.pump();
      walked.add(focusedLabel());
    }
    expect(walked.take(7), [
      'Movies, 4',
      'Series, 2',
      'Videos, 2',
      'Downloads',
      'Folders',
      'Add folder',
      'All',
    ]);
    final grid = walked.indexWhere((label) => label == 'Coldwater (2020)');
    expect(grid, greaterThan(6), reason: '$walked');

    // Back in the grid by Shift+Tab from past it; the arrows move by card.
    tester
        .widget<PosterCard>(find.widgetWithText(PosterCard, 'Coldwater (2020)'))
        .focusNode!
        .requestFocus();
    await tester.pump();
    await tester.sendKeyEvent(LogicalKeyboardKey.arrowRight);
    await settle(tester);
    expect(focusedLabel(), 'Northwind Hotel');
    await tester.sendKeyEvent(LogicalKeyboardKey.end);
    await settle(tester);
    expect(focusedLabel(), 'The Quiet Harbor');
  });

  testWidgets('a folder the system cannot watch is scanned when the '
      'Library opens, each time', (tester) async {
    final temp = Directory.systemTemp.createTempSync('library_ui_');
    addTearDown(() => temp.deleteSync(recursive: true));
    final (ui, app) = await openLibrary(
      tester,
      location: '/movies',
      watcher: (path) => throw const FileSystemException('no watches left'),
      before: (ui) async {
        await _canvas(ui);
        // Only a folder that is there is watched at all.
        await ui.db.libraryDao.changeFolder(
          ui.hdd,
          LibraryFoldersCompanion(path: Value(temp.path)),
        );
        await ui.scans.startUp();
        await Future<void>.delayed(const Duration(milliseconds: 50));
      },
    );
    expect(ui.scanned, [null], reason: "the launch's scan");
    expect(ui.scans.watched(ui.hdd), isFalse);

    app.router.go('/library');
    await settle(tester);
    expect(ui.scanned, [null, ui.hdd]);

    app.router.go('/movies');
    await settle(tester);
    app.router.go('/library');
    await settle(tester);
    expect(ui.scanned, [null, ui.hdd, ui.hdd]);
  });
}
