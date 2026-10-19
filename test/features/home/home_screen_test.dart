import 'dart:async';

import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:iptv_player/app/destinations.dart';
import 'package:iptv_player/app/router.dart';
import 'package:iptv_player/core/core_providers.dart';
import 'package:iptv_player/core/platform/form_factor.dart';
import 'package:iptv_player/core/platform/network_status.dart';
import 'package:iptv_player/core/result.dart';
import 'package:iptv_player/data/db/app_database.dart';
import 'package:iptv_player/data/db/db_providers.dart';
import 'package:iptv_player/data/db/user_tables.dart';
import 'package:iptv_player/design/components.dart';
import 'package:iptv_player/features/downloads/data/download_providers.dart';
import 'package:iptv_player/features/home/data/db_home_repository.dart';
import 'package:iptv_player/features/home/data/home_providers.dart';
import 'package:iptv_player/features/home/domain/home.dart';
import 'package:iptv_player/features/home/presentation/home_rows.dart';
import 'package:iptv_player/features/library/data/library_providers.dart';
import 'package:iptv_player/features/library/data/library_scans.dart';
import 'package:iptv_player/features/live_tv/data/live_tv_providers.dart';
import 'package:iptv_player/features/live_tv/domain/channels.dart';
import 'package:iptv_player/features/live_tv/presentation/live_tv_screen.dart';
import 'package:iptv_player/features/live_tv/presentation/live_tv_state.dart';
import 'package:iptv_player/features/playback/domain/playback_state.dart';
import 'package:iptv_player/features/sources/data/source_providers.dart';
import 'package:iptv_player/features/sources/domain/source.dart';
import 'package:iptv_player/features/sources/domain/sync.dart';
import 'package:iptv_player/features/vod/data/vod_providers.dart';
import 'package:iptv_player/features/vod/domain/titles.dart';
import 'package:iptv_player/features/vod/presentation/title_cards.dart';

import '../../app/app_harness.dart';
import '../vod/vod_fakes.dart';
import '../vod/vod_test_support.dart';
import 'home_fakes.dart';

/// A card or a tile by its label, and its focus node.
/// The first one on Home: a Continue card comes before the same title's
/// poster.
FocusNode _node(WidgetTester tester, String label) =>
    tester.widget<FocusableSurface>(findByLabel(label).first).focusNode!;

String? _focused() {
  final context = FocusManager.instance.primaryFocus?.context;
  if (context == null) return null;
  final surface = context.widget is FocusableSurface
      ? context.widget as FocusableSurface
      : context.findAncestorWidgetOfExactType<FocusableSurface>();
  return surface?.semanticLabel;
}

void main() {
  Future<(HomeFakes, AppUnderTest)> open(
    WidgetTester tester, {
    bool history = false,
    List<Override> extra = const [],
    FutureOr<void> Function(HomeFakes home)? before,
    Size size = const Size(1440, 900),
  }) async {
    final home = HomeFakes();
    addTearDown(() => tester.runAsync(home.db.close));
    await tester.runAsync(() async {
      await home.seed();
      if (history) await home.seedHistory();
      await before?.call(home);
    });
    final app = await pumpApp(
      tester,
      size: size,
      overrides: [...home.overrides, ...extra],
    );
    await settle(tester);
    return (home, app);
  }

  testWidgets('offline: over Home too the shell says downloads and local '
      'files still play, and opens the Library', (tester) async {
    final (_, app) = await open(
      tester,
      extra: [
        appOfflineProvider.overrideWith((ref) => Stream.value(true)),
        libraryScanStateProvider.overrideWith(
          (ref) => Stream.value(const LibraryScanState()),
        ),
        downloadDiskSpaceProvider.overrideWith((ref) async => null),
        downloadFolderProvider.overrideWith((ref) async => '/downloads'),
      ],
    );

    expect(
      find.text("You're offline — downloads and local files still play."),
      findsOneWidget,
    );
    expect(find.text('WELCOME'), findsOneWidget, reason: 'Home is still there');

    await tester.tap(find.text('Open Library'));
    await settle(tester);
    expect(app.location, '/library');
  });

  testWidgets('online: no banner', (tester) async {
    await open(
      tester,
      extra: [appOfflineProvider.overrideWith((ref) => Stream.value(false))],
    );
    expect(find.textContaining("You're offline"), findsNothing);
  });

  group('first run', () {
    testWidgets('the hero says what the source holds; the rows with '
        'something follow', (tester) async {
      await open(tester);

      expect(find.text('WELCOME'), findsOneWidget);
      expect(find.text('Start watching'), findsOneWidget);
      expect(
        find.text('3 channels, 3 movies and 1 series from Northwind TV.'),
        findsOneWidget,
      );
      expect(find.text('Open Live TV'), findsOneWidget);
      expect(find.text('Browse movies'), findsOneWidget);

      expect(find.text('Favorite channels'), findsOneWidget);
      expect(find.text('Arena Sports 1'), findsOneWidget);
      expect(find.text('Continental Cup · Semi-final'), findsOneWidget);
      expect(find.text('Recently added movies'), findsOneWidget);
      expect(find.text('The Quiet Harbor'), findsOneWidget);
      expect(find.text('Recently added series'), findsOneWidget);
      expect(find.text('Glass Tide'), findsOneWidget);

      expect(find.text('Continue watching'), findsNothing);
      expect(find.text('Recently watched channels'), findsNothing);
    });

    testWidgets('Open Live TV and Browse movies go there', (tester) async {
      final (_, app) = await open(tester);

      await tester.tap(find.text('Browse movies'));
      await settle(tester);
      expect(app.location, AppDestination.movies.path);

      app.router.go('/');
      await settle(tester);
      await tester.tap(find.text('Open Live TV'));
      await settle(tester);
      expect(app.location, AppDestination.liveTv.path);
    });

    testWidgets('a source with no movies offers its series instead', (
      tester,
    ) async {
      await open(
        tester,
        before: (home) => home.db.customStatement('DELETE FROM movies'),
      );

      expect(find.text('Browse movies'), findsNothing);
      expect(find.text('Browse series'), findsOneWidget);
      expect(
        find.text('3 channels and 1 series from Northwind TV.'),
        findsOneWidget,
      );
    });

    testWidgets('a first sync still running says so over what has arrived', (
      tester,
    ) async {
      await open(
        tester,
        before: (home) async {
          await home.db.customStatement('DELETE FROM favorites');
          await home.db.customStatement('DELETE FROM movies');
          await home.db.customStatement('DELETE FROM series');
          home.vod.fakes.sync.emit(
            'src-1',
            const SyncRunning(SyncProgress(stage: SyncStage.movies)),
          );
        },
      );

      expect(find.text('Getting your catalogue…'), findsOneWidget);
      expect(find.text('Start watching'), findsOneWidget);
    });
  });

  group('with history', () {
    testWidgets('Continue watching and the channel rows, and no hero', (
      tester,
    ) async {
      await open(tester, history: true);

      expect(find.text('Start watching'), findsNothing);
      expect(find.text('Continue watching'), findsOneWidget);
      expect(find.text('Movie · 46 min left'), findsOneWidget);
      expect(find.text('Recently watched channels'), findsOneWidget);
      expect(find.text('Velocity Motors'), findsOneWidget);
      expect(find.text('No guide information'), findsOneWidget);
    });

    testWidgets('Ctrl+1 lands on the first card', (tester) async {
      final (_, app) = await open(tester, history: true);
      app.router.go(AppDestination.movies.path);
      await settle(tester);

      await tester.sendKeyDownEvent(LogicalKeyboardKey.controlLeft);
      await tester.sendKeyEvent(LogicalKeyboardKey.digit1);
      await tester.sendKeyUpEvent(LogicalKeyboardKey.controlLeft);
      await settle(tester);

      expect(app.location, AppDestination.home.path);
      expect(
        _focused(),
        'The Quiet Harbor',
        reason: '${FocusManager.instance.primaryFocus}',
      );
    });

    testWidgets('Ctrl+1 lands on the first card of a Continue watching row '
        'that appeared above the others', (tester) async {
      // Home first had the hero and the rows under it; the rows' controls
      // were in the focus tree before Continue watching was built above
      // them.
      final (home, app) = await open(tester);
      expect(find.text('Start watching'), findsOneWidget);
      unawaited(home.seedHistory());
      await settle(tester);
      expect(find.text('Continue watching'), findsOneWidget);
      // Left from a card further down: Ctrl+1 means the first control.
      _node(tester, 'Velocity Motors').requestFocus();
      await tester.pump();

      app.router.go(AppDestination.movies.path);
      await settle(tester);
      await tester.sendKeyDownEvent(LogicalKeyboardKey.controlLeft);
      await tester.sendKeyEvent(LogicalKeyboardKey.digit1);
      await tester.sendKeyUpEvent(LogicalKeyboardKey.controlLeft);
      await settle(tester);

      expect(app.location, AppDestination.home.path);
      expect(
        _focused(),
        'The Quiet Harbor',
        reason: '${FocusManager.instance.primaryFocus}',
      );
    });

    testWidgets('Enter on a Continue card resumes it where it was left', (
      tester,
    ) async {
      final (home, _) = await open(tester, history: true);

      _node(tester, 'The Quiet Harbor').requestFocus();
      await tester.pump();
      await tester.sendKeyEvent(LogicalKeyboardKey.enter);
      await settle(tester);

      expect(home.launcher.played, ['501 from 72']);
    });

    testWidgets('Enter on a poster opens its page; its F toggles the '
        'favorite', (tester) async {
      final (home, app) = await open(tester, history: true);

      _node(tester, 'Copper Hollow').requestFocus();
      await tester.pump();
      await tester.sendKeyEvent(LogicalKeyboardKey.keyF);
      await settle(tester);
      final favorites = await tester.runAsync(
        () => home.db.favoritesDao.watchKeys(UserItemType.movie, 'src-1').first,
      );
      expect(favorites, contains('502'));

      await tester.sendKeyEvent(LogicalKeyboardKey.enter);
      await settle(tester);
      expect(app.location, '/movies/src-1/502');
      // The page's own first focus, not its top-left "‹ Movies" chip.
      expect(_focused(), 'Play');
    });

    testWidgets('D on a poster downloads its movie; on a Continue card, '
        'what it continues', (tester) async {
      final (home, _) = await open(
        tester,
        history: true,
        before: (home) async {
          final series = (await home.db.seriesDao.byRemoteKey('src-1', '77'))!;
          await addEpisodes(home.db, series.id, [(2, 4)]);
          await home.db.watchHistoryDao.touch(
            UserItemType.episode,
            'src-1',
            'e2-4',
            home.now,
            positionMs: 19 * 60000,
            durationMs: 50 * 60000,
            completed: false,
            seriesKey: '77',
          );
        },
      );

      _node(tester, 'Copper Hollow').requestFocus();
      await tester.pump();
      await tester.sendKeyEvent(LogicalKeyboardKey.keyD);
      await settle(tester);
      expect(home.vod.queue.calls, ['enqueue 502']);
      expect(find.text('Downloading Copper Hollow'), findsOneWidget);

      // The episode to continue, on its Continue card.
      _node(tester, 'Glass Tide').requestFocus();
      await tester.pump();
      await tester.sendKeyEvent(LogicalKeyboardKey.keyD);
      await settle(tester);
      expect(home.vod.queue.calls, ['enqueue 502', 'enqueue e2-4']);

      // A channel has nothing to download: D does nothing there.
      _node(tester, 'Arena Sports 1').requestFocus();
      await tester.pump();
      await tester.sendKeyEvent(LogicalKeyboardKey.keyD);
      await settle(tester);
      expect(home.vod.queue.calls, hasLength(2));
    });

    testWidgets('what is on this computer says so: DOWNLOADED on its '
        'Continue card, the mark on its poster', (tester) async {
      await open(
        tester,
        history: true,
        before: (home) => home.vod.downloadMovie('501', 'The Quiet Harbor'),
      );

      Finder on(Type card, String title, Type mark) => find.descendant(
        of: find.widgetWithText(card, title),
        matching: find.byType(mark),
      );
      expect(
        on(LandscapeCard, 'The Quiet Harbor', DownloadedPill),
        findsOneWidget,
      );
      expect(find.text('DOWNLOADED'), findsOneWidget);
      expect(
        on(PosterCard, 'The Quiet Harbor', DownloadedMark),
        findsOneWidget,
      );
      expect(on(PosterCard, 'Copper Hollow', DownloadedMark), findsNothing);
    });

    testWidgets('Enter on a channel plays it full screen; back on Home it '
        'stops', (tester) async {
      final (home, app) = await open(tester, history: true);

      await tester.tap(find.text('Arena Sports 1'));
      await settle(tester);
      home.rig.engine.firstFrame();
      await settle(tester);

      expect(app.location, playerRoutePath);
      expect(home.rig.engine.opened.single.url, contains('201'));
      expect(home.rig.state, isA<PlaybackPlaying>());

      await tester.sendKeyEvent(LogicalKeyboardKey.escape);
      await settle(tester);
      expect(app.location, AppDestination.home.path);
      expect(home.rig.state, isA<PlaybackIdle>());
      await tester.pump(const Duration(seconds: 4));
    });

    testWidgets('the arrows: ↓ to the nearest card of the next row, ←/→ '
        'within a row, stopping at its end', (tester) async {
      await open(tester, history: true);

      _node(tester, 'The Quiet Harbor').requestFocus();
      await tester.pump();
      expect(_focused(), 'The Quiet Harbor');

      await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
      await tester.pump();
      expect(_focused(), 'Arena Sports 1');

      // One favorite: → has nowhere to go, and goes nowhere.
      await tester.sendKeyEvent(LogicalKeyboardKey.arrowRight);
      await tester.pump();
      expect(_focused(), 'Arena Sports 1');

      await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
      await tester.pump();
      expect(_focused(), 'Velocity Motors');

      await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
      await settle(tester);
      expect(_focused(), 'The Quiet Harbor', reason: 'the first poster');

      await tester.sendKeyEvent(LogicalKeyboardKey.arrowRight);
      await settle(tester);
      expect(_focused(), 'Copper Hollow');

      await tester.sendKeyEvent(LogicalKeyboardKey.arrowUp);
      await settle(tester);
      expect(_focused(), 'Velocity Motors');
    });

    testWidgets('the menu takes a movie out of Continue watching', (
      tester,
    ) async {
      await open(tester, history: true);

      _node(tester, 'The Quiet Harbor').requestFocus();
      await tester.pump();
      await tester.sendKeyEvent(LogicalKeyboardKey.contextMenu);
      await settle(tester);
      await tester.tap(find.text('Remove from Continue watching'));
      await settle(tester);

      expect(find.text('Continue watching'), findsNothing);
      expect(find.text('Movie · 46 min left'), findsNothing);
    });

    testWidgets('an episode to continue says S · E and what is left', (
      tester,
    ) async {
      await open(
        tester,
        history: true,
        before: (home) async {
          final series = (await home.db.seriesDao.byRemoteKey('src-1', '77'))!;
          await addEpisodes(home.db, series.id, [(2, 4), (2, 5)]);
          await home.db.watchHistoryDao.touch(
            UserItemType.episode,
            'src-1',
            'e2-4',
            home.now,
            positionMs: 19 * 60000,
            durationMs: 50 * 60000,
            completed: false,
            seriesKey: '77',
          );
        },
      );

      expect(find.text('S2 · E4 · 31 min left'), findsOneWidget);
    });
  });

  group('See all', () {
    testWidgets('Favorite channels opens Live TV on its Favorites', (
      tester,
    ) async {
      final (_, app) = await open(tester);

      await tester.tap(findByLabel('See all Favorite channels'));
      await settle(tester);

      expect(app.location, AppDestination.liveTv.path);
      final view = ProviderScope.containerOf(
        tester.element(find.byType(LiveTvScreen)),
      ).read(liveTvControllerProvider);
      expect(view?.query.filter, const FavoriteChannels());
    });

    testWidgets('Recently added movies opens Movies, newest first', (
      tester,
    ) async {
      final (_, app) = await open(tester);

      await tester.tap(findByLabel('See all Recently added movies'));
      await settle(tester);

      expect(app.location, AppDestination.movies.path);
      expect(find.text('Recently added'), findsWidgets);
    });
  });

  testWidgets('on a TV a row ends in a See all card, where → at its end '
      "lands (the header link is out of a remote's reach)", (tester) async {
    final (_, app) = await open(
      tester,
      extra: [formFactorProvider.overrideWithValue(FormFactor.tv)],
    );
    final row = find.ancestor(
      of: find.text('Recently added movies'),
      matching: find.byType(HomeRow),
    );
    tester
        .widget<FocusableSurface>(
          find
              .descendant(
                of: find.descendant(of: row, matching: find.byType(MovieCard)),
                matching: find.byType(FocusableSurface),
              )
              .first,
        )
        .focusNode!
        .requestFocus();
    await settle(tester);
    for (var i = 0; i < 40 && _focused() != 'See all'; i++) {
      await tester.sendKeyEvent(LogicalKeyboardKey.arrowRight);
      await settle(tester);
    }
    expect(_focused(), 'See all');

    await tester.sendKeyEvent(LogicalKeyboardKey.select);
    await settle(tester);
    expect(app.location, AppDestination.movies.path);
  });

  testWidgets("on a TV, a card focused again shows its row's heading whole, "
      'not half under the top bar (the Bedroom TV)', (tester) async {
    await open(
      tester,
      history: true,
      size: const Size(960, 540),
      extra: [formFactorProvider.overrideWithValue(FormFactor.tv)],
    );
    _node(tester, 'The Quiet Harbor').requestFocus();
    await settle(tester);
    for (var i = 0; i < 3; i++) {
      await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
      await settle(tester);
    }
    final heading = find.text('Continue watching');
    final page = find
        .ancestor(of: heading, matching: find.byType(Scrollable))
        .first;
    expect(
      tester.getRect(heading).top,
      lessThan(tester.getRect(page).top),
      reason: 'scrolled down past it',
    );

    // As the focus comes back to Home's first card (Back to Home).
    _node(tester, 'The Quiet Harbor').requestFocus();
    await settle(tester);
    await tester.pump(const Duration(milliseconds: 500));
    expect(_focused(), 'The Quiet Harbor');
    expect(
      tester.getRect(heading).top,
      greaterThanOrEqualTo(tester.getRect(page).top),
    );
  });

  testWidgets("on a TV, Left from Home lands on the rail's Home, not the "
      'rail item focused last (the Bedroom TV: Settings, from a poster)', (
    tester,
  ) async {
    await open(
      tester,
      history: true,
      size: const Size(960, 540),
      extra: [formFactorProvider.overrideWithValue(FormFactor.tv)],
    );
    // The rail was last left from Settings.
    Focus.of(
      tester.element(
        find
            .descendant(
              of: find.byWidgetPredicate(
                (w) =>
                    w is FocusableSurface &&
                    w.semanticLabel == AppDestination.settings.label,
              ),
              matching: find.byType(GestureDetector),
            )
            .first,
      ),
    ).requestFocus();
    // On before a rest there opens Settings (NavRail.openAfter).
    await tester.pump();
    expect(_focused(), AppDestination.settings.label);
    _node(tester, 'The Quiet Harbor').requestFocus();
    await settle(tester);

    await tester.sendKeyEvent(LogicalKeyboardKey.arrowLeft);
    await settle(tester);
    expect(_focused(), AppDestination.home.label);
  });

  group("on a TV, at launch: Home's first card has the focus", () {
    Future<_LateHome> launch(
      WidgetTester tester, {
      Future<void>? sources,
    }) async {
      final rows = _LateHome();
      await open(
        tester,
        history: true,
        size: const Size(960, 540),
        extra: [
          formFactorProvider.overrideWithValue(FormFactor.tv),
          if (sources != null)
            sourcesProvider.overrideWith((ref) async* {
              await sources;
              yield* ref.watch(sourceRepositoryProvider).watchAll();
            }),
          homeRepositoryProvider.overrideWith(
            (ref) => rows
              ..rows = DbHomeRepository(
                ref.watch(appDatabaseProvider),
                channels: ref.watch(channelRepositoryProvider),
                movies: ref.watch(movieRepositoryProvider),
                series: ref.watch(seriesRepositoryProvider),
              ),
          ),
        ],
      );
      if (sources != null) return rows;
      // Seconds on the skeletons: the rail's Home holds the focus
      // meanwhile, as something always has it.
      await tester.pump(const Duration(seconds: 3));
      expect(find.byType(SkeletonPoster), findsWidgets);
      expect(_focused(), AppDestination.home.label);
      return rows;
    }

    testWidgets('once its rows arrive, however late (the Bedroom TV, a '
        "provider's Home: it stayed on the rail's Home)", (tester) async {
      final rows = await launch(tester);

      rows.arrive();
      await settle(tester);
      expect(find.text('Continue watching'), findsOneWidget);
      expect(_focused(), 'The Quiet Harbor');
    });

    testWidgets('after the source is read too: until then Home offers to '
        'add one, and its button had the focus', (tester) async {
      final sources = Completer<void>();
      final rows = await launch(tester, sources: sources.future);
      expect(find.text('Add a source'), findsOneWidget);
      expect(_focused(), 'Add a source');

      sources.complete();
      await settle(tester);
      await tester.pump(const Duration(seconds: 3));
      expect(find.byType(SkeletonPoster), findsWidgets);
      expect(_focused(), AppDestination.home.label);

      rows.arrive();
      await settle(tester);
      expect(_focused(), 'The Quiet Harbor');
    });

    testWidgets('but not once the user has moved it: their place is kept', (
      tester,
    ) async {
      final rows = await launch(tester);
      // Down and back up before a rest on Live TV opens it
      // (NavRail.openAfter): the rail's Home, where the user put it.
      await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
      await tester.pump();
      expect(_focused(), AppDestination.liveTv.label);
      await tester.sendKeyEvent(LogicalKeyboardKey.arrowUp);
      await settle(tester);
      expect(_focused(), AppDestination.home.label);

      rows.arrive();
      await settle(tester);
      expect(find.text('Continue watching'), findsOneWidget);
      expect(_focused(), AppDestination.home.label);
    });
  });

  testWidgets('the desktop has no See all card: its header links stay', (
    tester,
  ) async {
    await open(tester);
    expect(findByLabel('See all'), findsNothing);
    expect(findByLabel('See all Recently added movies'), findsOneWidget);
  });

  group('states', () {
    testWidgets('no source: nothing yet, and the way to add one', (
      tester,
    ) async {
      final app = await pumpApp(tester);

      expect(find.text('Nothing here yet'), findsOneWidget);
      await tester.tap(find.text('Add a source'));
      await settleApp(tester);
      expect(app.location, addSourceRoutePath);
    });

    testWidgets('loading: skeleton rows', (tester) async {
      final rows = _ScriptedHome();
      await open(
        tester,
        extra: [homeRepositoryProvider.overrideWithValue(rows)],
      );

      expect(find.byType(SkeletonPoster), findsWidgets);
      expect(find.text('Start watching'), findsNothing);
      rows.close();
    });

    testWidgets('an error says so; Retry reads again', (tester) async {
      final rows = _ScriptedHome()..fail = true;
      await open(
        tester,
        extra: [homeRepositoryProvider.overrideWithValue(rows)],
      );

      expect(find.text("Home couldn't load"), findsOneWidget);

      rows.fail = false;
      await tester.tap(find.text('Retry'));
      await settle(tester);
      expect(find.text("Home couldn't load"), findsNothing);
      expect(find.text('Start watching'), findsOneWidget);
    });

    testWidgets('a source with nothing on Home after something was watched '
        'somewhere: says so', (tester) async {
      await open(
        tester,
        before: (home) async {
          await home.db.customStatement('DELETE FROM favorites');
          await home.db.customStatement('DELETE FROM movies');
          await home.db.customStatement('DELETE FROM series');
          await home.db
              .into(home.db.sources)
              .insert(
                SourcesCompanion.insert(
                  id: 'src-2',
                  type: SourceType.xtream,
                  name: 'Other',
                  url: 'http://other.test',
                  createdAt: home.now,
                  updatedAt: home.now,
                ),
              );
          await home.db.watchHistoryDao.touch(
            UserItemType.live,
            'src-2',
            '1',
            home.now,
          );
        },
      );

      expect(find.text('Nothing here yet'), findsOneWidget);
      expect(find.text('Open Live TV'), findsOneWidget);
    });
  });
}

/// A [HomeRepository] that answers nothing ([fail] false and never
/// answered), or fails once until [fail] is cleared.
final class _ScriptedHome implements HomeRepository {
  bool? fail;
  final _open = <StreamController<Object?>>[];

  Stream<T> _answer<T>(T empty) {
    if (fail == null) {
      final controller = StreamController<T>();
      _open.add(controller as StreamController<Object?>);
      return controller.stream;
    }
    if (fail!) return Stream.error(NetworkFailure('no database'));
    return Stream.value(empty);
  }

  void close() {
    for (final controller in _open) {
      unawaited(controller.close());
    }
  }

  @override
  Stream<List<ChannelItem>> favoriteChannels(String id, {int limit = 20}) =>
      _answer(const []);

  @override
  Stream<List<ChannelItem>> recentChannels(String id, {int limit = 20}) =>
      _answer(const []);

  @override
  Stream<List<MovieItem>> recentMovies(String id, {int limit = 20}) =>
      _answer(const []);

  @override
  Stream<List<SeriesItem>> recentSeries(String id, {int limit = 20}) =>
      _answer(const []);

  @override
  Stream<bool> watchedAnything() => _answer(false);
}

/// Home's rows from [rows], held back until [arrive]: a provider's Home
/// read from a large catalogue comes seconds after the first frames.
final class _LateHome implements HomeRepository {
  late HomeRepository rows;
  final _arrived = Completer<void>();

  void arrive() => _arrived.complete();

  Stream<T> _late<T>(Stream<T> Function() read) async* {
    await _arrived.future;
    yield* read();
  }

  @override
  Stream<List<ChannelItem>> favoriteChannels(String id, {int limit = 20}) =>
      _late(() => rows.favoriteChannels(id, limit: limit));

  @override
  Stream<List<ChannelItem>> recentChannels(String id, {int limit = 20}) =>
      _late(() => rows.recentChannels(id, limit: limit));

  @override
  Stream<List<MovieItem>> recentMovies(String id, {int limit = 20}) =>
      _late(() => rows.recentMovies(id, limit: limit));

  @override
  Stream<List<SeriesItem>> recentSeries(String id, {int limit = 20}) =>
      _late(() => rows.recentSeries(id, limit: limit));

  @override
  Stream<bool> watchedAnything() => _late(rows.watchedAnything);
}
