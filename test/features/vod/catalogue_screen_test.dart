import 'dart:async';

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/misc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:iptv_player/app/destinations.dart';
import 'package:iptv_player/core/result.dart';
import 'package:iptv_player/design/components.dart';
import 'package:iptv_player/features/sources/domain/sync.dart';
import 'package:iptv_player/features/vod/data/vod_providers.dart';
import 'package:iptv_player/features/vod/domain/catalogue.dart';
import 'package:iptv_player/features/vod/domain/titles.dart';
import 'package:iptv_player/features/vod/presentation/title_details_screen.dart';

import '../../app/app_harness.dart';
import 'vod_fakes.dart';

void main() {
  Future<(VodFakes, AppUnderTest)> pump(
    WidgetTester tester, {
    bool seed = true,
    bool movies = true,
    AppDestination at = AppDestination.movies,
    List<Override> overrides = const [],
  }) async {
    final vod = VodFakes();
    addTearDown(() => tester.runAsync(vod.db.close));
    if (seed) await tester.runAsync(() => vod.seed(movies: movies));
    final app = await pumpApp(
      tester,
      initialLocation: at.path,
      overrides: [
        // One override per provider: a test's own replaces the fake's.
        for (final o in vod.overrides)
          if (!overrides.any((mine) => mine.origin == o.origin)) o,
        ...overrides,
      ],
    );
    await settle(tester);
    return (vod, app);
  }

  Finder poster(String title) =>
      find.widgetWithText(PosterCard, title, skipOffstage: false);

  testWidgets('no source: says so and offers to add one', (tester) async {
    await pump(tester, seed: false);

    expect(find.text('No movies yet'), findsOneWidget);
    expect(find.text('Add a source'), findsOneWidget);
  });

  testWidgets("the grid: every movie but a hidden category's, newest first, "
      'with the heading, the count and the chips', (tester) async {
    await pump(tester);

    expect(find.text('All movies'), findsOneWidget);
    expect(find.text('3 movies'), findsOneWidget);
    final titles = [
      for (final card in tester.widgetList<PosterCard>(find.byType(PosterCard)))
        card.title,
    ];
    expect(titles, ['The Quiet Harbor', 'Copper Hollow', 'Ember Road']);
    // NEW on the one added two days ago.
    expect(
      find.descendant(
        of: poster('The Quiet Harbor'),
        matching: find.text('NEW'),
      ),
      findsOneWidget,
    );
    expect(
      find.descendant(of: poster('Copper Hollow'), matching: find.text('NEW')),
      findsNothing,
    );
    for (final chip in ['All', 'Favorites', 'Drama', 'Uncategorized', 'More']) {
      expect(find.widgetWithText(AppChip, chip), findsOneWidget, reason: chip);
    }
    expect(
      find.widgetWithText(AppChip, 'Kids'),
      findsNothing,
      reason: 'hidden',
    );
  });

  testWidgets('a category, the sort, and More', (tester) async {
    await pump(tester);

    await tester.tap(find.widgetWithText(AppChip, 'Drama'));
    await settle(tester);
    expect(find.text('Drama'), findsWidgets);
    expect(find.text('2 movies'), findsOneWidget);

    await tester.tap(find.text('Name'));
    await settle(tester);
    expect(
      [
        for (final card in tester.widgetList<PosterCard>(
          find.byType(PosterCard),
        ))
          card.title,
      ],
      ['Copper Hollow', 'The Quiet Harbor'],
    );

    await tester.tap(find.widgetWithText(AppChip, 'More'));
    await settle(tester);
    await tester.tap(
      find.descendant(
        of: find.byType(AppMenu),
        matching: find.text('Uncategorized'),
      ),
    );
    await settle(tester);
    expect(find.text('1 movie'), findsOneWidget);
  });

  testWidgets('a filter with no match says so, and Clear filter brings them '
      'back', (tester) async {
    await pump(tester);

    await tester.enterText(find.byType(TextField), 'zz');
    await settle(tester);
    expect(find.text('No movies match "zz"'), findsOneWidget);

    await tester.tap(find.text('Clear filter'));
    await settle(tester);
    expect(find.text('3 movies'), findsOneWidget);
  });

  testWidgets('favorites: empty at first; F on a poster adds it, with a '
      'star', (tester) async {
    await pump(tester);

    await tester.tap(find.widgetWithText(AppChip, 'Favorites'));
    await settle(tester);
    expect(find.text('No favorite movies yet'), findsOneWidget);

    await tester.tap(find.widgetWithText(AppChip, 'All'));
    await settle(tester);
    tester.widget<PosterCard>(poster('Ember Road')).focusNode!.requestFocus();
    await tester.pump();
    await tester.sendKeyEvent(LogicalKeyboardKey.keyF);
    await settle(tester);

    expect(
      find.descendant(
        of: poster('Ember Road'),
        matching: find.byWidgetPredicate(
          (w) => w is AppIcon && w.icon == AppIcons.starFilled && w.size == 14,
        ),
      ),
      findsOneWidget,
    );
    await tester.tap(find.widgetWithText(AppChip, 'Favorites'));
    await settle(tester);
    expect(find.text('1 movie'), findsOneWidget);
  });

  testWidgets('a source with no movies says so', (tester) async {
    await pump(tester, movies: false);

    expect(find.text("Your provider doesn't offer movies"), findsOneWidget);
  });

  testWidgets('while the first sync runs: getting your movies', (tester) async {
    final (vod, _) = await pump(tester, movies: false);
    vod.fakes.sync.emit(
      'src-1',
      const SyncRunning(SyncProgress(stage: SyncStage.movies)),
    );
    await settle(tester);

    expect(find.text('Getting your movies…'), findsOneWidget);
  });

  testWidgets('skeletons until the count comes; an error with Retry', (
    tester,
  ) async {
    final hanging = _FailingMovies(StreamController<int>());
    addTearDown(hanging.counts.close);
    await pump(
      tester,
      overrides: [movieRepositoryProvider.overrideWithValue(hanging)],
    );
    expect(find.byType(SkeletonPoster), findsWidgets);

    hanging.counts.addError(StateError('the database went away'));
    await settle(tester);
    expect(find.text("Couldn't load your movies"), findsOneWidget);
    expect(find.text('Retry'), findsOneWidget);
  });

  testWidgets("Enter opens the title's page; Esc goes back to the card it "
      'came from', (tester) async {
    final (_, app) = await pump(tester);
    tester
        .widget<PosterCard>(poster('Copper Hollow'))
        .focusNode!
        .requestFocus();
    await tester.pump();

    await tester.sendKeyEvent(LogicalKeyboardKey.enter);
    await settle(tester);
    expect(app.location, '/movies/src-1/502');
    expect(find.byType(MovieDetailsScreen), findsOneWidget);
    expect(find.text('Copper Hollow'), findsWidgets);

    await tester.sendKeyEvent(LogicalKeyboardKey.escape);
    await settle(tester);
    expect(app.location, AppDestination.movies.path);
    expect(focusedLabel(), 'Copper Hollow');
  });

  testWidgets('End and Home go to the last and the first card', (tester) async {
    await pump(tester);
    tester
        .widget<PosterCard>(poster('The Quiet Harbor'))
        .focusNode!
        .requestFocus();
    await tester.pump();

    await tester.sendKeyEvent(LogicalKeyboardKey.end);
    await settle(tester);
    expect(focusedLabel(), 'Ember Road');

    await tester.sendKeyEvent(LogicalKeyboardKey.home);
    await settle(tester);
    expect(focusedLabel(), 'The Quiet Harbor');
  });

  testWidgets('End lands on the last card once its page is read', (
    tester,
  ) async {
    final vod = VodFakes();
    addTearDown(() => tester.runAsync(vod.db.close));
    await tester.runAsync(() async {
      await vod.seed();
      // Three pages of 120: the last card's page isn't read until End.
      await vod.seedMany(300);
    });
    await pumpApp(
      tester,
      initialLocation: AppDestination.movies.path,
      overrides: vod.overrides,
    );
    await settle(tester);
    tester
        .widget<PosterCard>(poster('The Quiet Harbor'))
        .focusNode!
        .requestFocus();
    await tester.pump();

    await tester.sendKeyEvent(LogicalKeyboardKey.end);
    await settle(tester);
    // Undated, so last (as in the three-movie test above).
    expect(focusedLabel(), 'Ember Road');

    await tester.sendKeyEvent(LogicalKeyboardKey.home);
    await settle(tester);
    expect(focusedLabel(), 'The Quiet Harbor');
  });

  testWidgets('PageDown goes a screen of cards down, PageUp back', (
    tester,
  ) async {
    final vod = VodFakes();
    addTearDown(() => tester.runAsync(vod.db.close));
    await tester.runAsync(() async {
      await vod.seed();
      await vod.seedMany(80);
    });
    await pumpApp(
      tester,
      initialLocation: AppDestination.movies.path,
      overrides: vod.overrides,
    );
    await settle(tester);
    tester
        .widget<PosterCard>(poster('The Quiet Harbor'))
        .focusNode!
        .requestFocus();
    await tester.pump();

    await tester.sendKeyEvent(LogicalKeyboardKey.pageDown);
    await settle(tester);
    final below = focusedLabel();
    expect(below, startsWith('Movie '), reason: 'a card further down');
    // The grid is 7 across at 1440 px, and a screen shows 2 rows.
    final index = int.parse(below!.substring('Movie '.length));
    expect(index, greaterThanOrEqualTo(7));

    await tester.sendKeyEvent(LogicalKeyboardKey.pageUp);
    await settle(tester);
    expect(focusedLabel(), 'The Quiet Harbor');
  });

  testWidgets('scrolled away by the mouse, the keys carry on from what is '
      'on screen', (tester) async {
    final vod = VodFakes();
    addTearDown(() => tester.runAsync(vod.db.close));
    await tester.runAsync(() async {
      await vod.seed();
      await vod.seedMany(80);
    });
    await pumpApp(
      tester,
      initialLocation: AppDestination.movies.path,
      overrides: vod.overrides,
    );
    await settle(tester);
    tester
        .widget<PosterCard>(poster('The Quiet Harbor'))
        .focusNode!
        .requestFocus();
    await tester.pump();

    // The wheel, well past the focused card: it is no longer built.
    final grid = find.byType(GridView);
    final position = tester
        .state<ScrollableState>(
          find.descendant(of: grid, matching: find.byType(Scrollable)),
        )
        .position;
    final pointer = TestPointer(1, PointerDeviceKind.mouse);
    await tester.sendEventToBinding(pointer.hover(tester.getCenter(grid)));
    for (var i = 0; i < 6; i++) {
      await tester.sendEventToBinding(pointer.scroll(const Offset(0, 400)));
      await tester.pump();
    }
    await settle(tester);
    expect(poster('The Quiet Harbor'), findsNothing);
    final scrolled = position.pixels;
    expect(scrolled, greaterThan(1000));

    // The focus is on a card on screen, in the first card's column.
    final landed = focusedLabel();
    expect(landed, startsWith('Movie '), reason: 'a card of the view');
    final card = find.widgetWithText(PosterCard, landed!);
    final box = tester.getRect(card);
    expect(box.top, greaterThanOrEqualTo(tester.getRect(grid).top - 1));
    expect(
      box.left,
      closeTo(tester.getRect(find.byType(PosterCard).first).left, 1),
    );

    // ↓ goes on from there, and PageDown from the view, not from the top.
    await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
    await settle(tester);
    expect(focusedLabel(), isNot(landed));
    expect(focusedLabel(), startsWith('Movie '));
    await tester.sendKeyEvent(LogicalKeyboardKey.pageDown);
    await settle(tester);
    expect(position.pixels, greaterThan(scrolled));
    expect(focusedLabel(), startsWith('Movie '));
  });

  testWidgets('Series: the same grid', (tester) async {
    await pump(tester, at: AppDestination.series);

    expect(find.text('All series'), findsOneWidget);
    expect(find.text('1 series'), findsOneWidget);
    expect(poster('Glass Tide'), findsOneWidget);
  });
}

/// A movie repository whose count comes from [counts]: nothing, then an
/// error.
final class _FailingMovies implements MovieRepository {
  new(this.counts);

  final StreamController<int> counts;

  @override
  Stream<int> watchCount(TitleQuery query) => counts.stream;

  @override
  Future<Result<List<MovieItem>>> range(
    TitleQuery query,
    int offset,
    int limit,
  ) async => const Ok([]);

  @override
  Future<Result<MovieItem?>> byRemoteKey(
    String sourceId,
    String remoteKey,
  ) async => const Ok(null);

  @override
  Future<Result<void>> setFavorite(MovieItem movie, {required bool on}) async =>
      const Ok(null);

  @override
  Stream<Details<MovieDetails>> details(MovieItem movie) =>
      const Stream.empty();
}

String? focusedLabel() {
  final context = FocusManager.instance.primaryFocus?.context;
  if (context == null) return null;
  final surface = context.widget is FocusableSurface
      ? context.widget as FocusableSurface
      : context.findAncestorWidgetOfExactType<FocusableSurface>();
  return surface?.semanticLabel;
}
