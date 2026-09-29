import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:iptv_player/app/destinations.dart';
import 'package:iptv_player/core/result.dart';
import 'package:iptv_player/design/components.dart';
import 'package:iptv_player/features/guide/domain/epg.dart';
import 'package:iptv_player/features/guide/presentation/guide_programme_request.dart';
import 'package:iptv_player/features/live_tv/domain/channels.dart';
import 'package:iptv_player/features/live_tv/domain/now_next.dart';
import 'package:iptv_player/features/search/data/search_providers.dart';
import 'package:iptv_player/features/search/domain/search.dart';
import 'package:iptv_player/features/search/presentation/search_overlay.dart';
import 'package:iptv_player/features/search/presentation/search_state.dart';
import 'package:iptv_player/features/sources/domain/categories.dart';
import 'package:iptv_player/features/sources/domain/sync.dart';
import 'package:iptv_player/features/vod/domain/titles.dart';
import 'package:iptv_player/features/vod/presentation/catalogue_state.dart';

import '../../app/app_harness.dart';
import '../live_tv/live_tv_fakes.dart';
import 'search_fakes.dart';

ChannelItem _channel(String key, String name, {int? number}) => ChannelItem(
  id: int.parse(key),
  sourceId: 'src-1',
  remoteKey: key,
  name: name,
  number: number ?? int.parse(key),
);

void main() {
  late LiveTvFakes live;
  late ScriptedSearch search;
  late AppUnderTest app;

  Future<void> settle(WidgetTester tester) async {
    for (var i = 0; i < 4; i++) {
      await tester.runAsync(() => Future<void>.delayed(Duration.zero));
      await tester.pump(const Duration(milliseconds: 60));
    }
  }

  Future<void> open(WidgetTester tester, {bool seed = true}) async {
    live = LiveTvFakes();
    addTearDown(() => tester.runAsync(live.db.close));
    if (seed) await tester.runAsync(live.seed);
    app = await pumpApp(
      tester,
      overrides: [
        ...live.overrides,
        searchRepositoryProvider.overrideWithValue(search),
      ],
    );
    await settle(tester);
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

  /// The name on the row the cursor is on: the row with the Enter
  /// keycap, whose name is the one rich text in it.
  String? cursorRow(WidgetTester tester) {
    final enter = find.widgetWithText(Kbd, 'Enter');
    final rows = find.ancestor(of: enter, matching: find.byType(Row));
    for (final element in rows.evaluate()) {
      final names = find
          .descendant(
            of: find.byWidget(element.widget),
            matching: find.byWidgetPredicate(
              (w) => w is Text && w.textSpan != null,
            ),
          )
          .evaluate();
      if (names.isNotEmpty) {
        return (names.first.widget as Text).textSpan!.toPlainText();
      }
      final plain = find
          .descendant(
            of: find.byWidget(element.widget),
            matching: find.byWidgetPredicate(
              (w) => w is Text && (w.data?.startsWith('Show all') ?? false),
            ),
          )
          .evaluate();
      if (plain.isNotEmpty) return (plain.first.widget as Text).data;
    }
    return null;
  }

  /// The bold words of a name, as the row draws them.
  List<String> boldIn(WidgetTester tester, String name) {
    final text = tester
        .widgetList<Text>(
          find.byWidgetPredicate((w) => w is Text && w.textSpan != null),
        )
        .firstWhere((t) => t.textSpan!.toPlainText() == name);
    final bold = <String>[];
    text.textSpan!.visitChildren((span) {
      if (span is TextSpan &&
          span.text != null &&
          span.style?.fontWeight == FontWeight.w800) {
        bold.add(span.text!);
      }
      return true;
    });
    return bold;
  }

  final now = DateTime.utc(2026, 9, 14, 12);
  final arena = _channel('201', 'Arena Sports 1');
  final arena2 = _channel('202', 'Arena Sports 2');
  final cup = ProgrammeHit(
    programme: EpgProgramme(
      id: 1,
      channelId: 'arena1',
      start: now.subtract(const Duration(minutes: 30)),
      end: now.add(const Duration(minutes: 55)),
      title: 'Arena Cup',
      subtitle: 'Final',
    ),
    channel: arena,
    sourceName: 'Northwind TV',
  );
  final later = ProgrammeHit(
    programme: EpgProgramme(
      id: 2,
      channelId: 'arena1',
      start: now.add(const Duration(days: 1, hours: 2)),
      end: now.add(const Duration(days: 1, hours: 3)),
      title: 'Arena Weekly',
    ),
    channel: arena,
    sourceName: 'Northwind TV',
  );
  const movie = MovieItem(
    id: 1,
    sourceId: 'src-1',
    remoteKey: 'm1',
    name: 'The Arena',
    year: 2024,
  );
  const series = SeriesItem(
    id: 1,
    sourceId: 'src-1',
    remoteKey: 's1',
    name: 'Arena Nine',
    genre: 'Crime',
  );
  SearchResults full(String text) => SearchResults(
    text: text,
    channels: SearchGroup([
      ChannelHit(
        channel: arena,
        sourceName: 'Northwind TV',
        categoryName: 'Sports',
      ),
      ChannelHit(
        channel: arena2,
        sourceName: 'Northwind TV',
        categoryName: 'Sports',
      ),
    ], hasMore: true),
    programmes: SearchGroup([cup, later]),
    movies: const SearchGroup([
      MovieHit(movie: movie, sourceName: 'Northwind TV', genre: 'Drama'),
    ], hasMore: true),
    series: const SearchGroup([
      SeriesHit(series: series, sourceName: 'Northwind TV', seasons: 3),
    ]),
  );

  setUp(() => search = ScriptedSearch());

  group('states', () {
    testWidgets('no text: what search covers, or the recent searches', (
      tester,
    ) async {
      await open(tester);
      expect(find.text(searchCoverageForTest), findsOneWidget);
      await tester.sendKeyEvent(LogicalKeyboardKey.escape);
      await settle(tester);

      search.recent = ['tennis open', 'cup final'];
      await tester.sendKeyDownEvent(LogicalKeyboardKey.controlLeft);
      await tester.sendKeyEvent(LogicalKeyboardKey.keyK);
      await tester.sendKeyUpEvent(LogicalKeyboardKey.controlLeft);
      await settle(tester);
      expect(find.text('RECENT SEARCHES'), findsOneWidget);
      expect(find.text('tennis open'), findsOneWidget);
      expect(find.text('Search again'), findsOneWidget);
    });

    testWidgets('the first results: skeletons; later keystrokes keep the '
        'old results until the new ones come', (tester) async {
      await open(tester);
      search.answers['arena'] = full('arena');
      search.gate = Completer<void>();

      await type(tester, 'arena');
      expect(find.byType(SkeletonRow), findsWidgets);
      search.gate!.complete();
      await settle(tester);
      expect(find.text('CHANNELS'), findsOneWidget);
      expect(find.text('6 results'), findsOneWidget);

      search.gate = Completer<void>();
      await type(tester, 'arena s');
      expect(find.byType(SkeletonRow), findsNothing);
      expect(find.text('CHANNELS'), findsOneWidget, reason: 'the old stay');
      search.gate!.complete();
      await settle(tester);
    });

    testWidgets('groups in the canvas order, with their lines and Show all', (
      tester,
    ) async {
      await open(tester);
      live.guide.byKey['201'] = NowNext(
        now: Programme(
          start: now.subtract(const Duration(minutes: 10)),
          end: DateTime(2026, 9, 14, 20, 30),
          title: 'Evening Bulletin',
        ),
      );

      search.answers['arena'] = full('arena');
      await type(tester, 'arena');

      final headings = [
        for (final text in [
          'CHANNELS',
          'ON TV NOW & UPCOMING',
          'MOVIES',
          'SERIES',
        ])
          tester.getTopLeft(find.text(text)).dy,
      ];
      expect(headings, [...headings]..sort());
      expect(
        find.text('201 · Evening Bulletin, until 8:30 PM'),
        findsOneWidget,
      );
      expect(find.textContaining('Arena Sports 1 · ends'), findsOneWidget);
      expect(find.text('LIVE'), findsOneWidget);
      expect(find.text('2024 · Drama'), findsOneWidget);
      expect(find.text('Series · 3 seasons · Crime'), findsOneWidget);
      expect(find.text('Show all in Live TV'), findsOneWidget);
      expect(find.text('Show all in Movies'), findsOneWidget);
      expect(find.text('Show all in Series'), findsNothing);
    });

    testWidgets('the words typed are bold in the names', (tester) async {
      await open(tester);
      search.answers['arena'] = full('arena');
      await type(tester, 'arena');

      expect(boldIn(tester, 'Arena Sports 1'), ['Arena']);
      expect(boldIn(tester, 'The Arena'), ['Arena']);
      await type(tester, 'sp ar');
      search.answers['sp ar'] = full('sp ar');
      await type(tester, 'sp are');
      await type(tester, 'sp ar');
      expect(boldIn(tester, 'Arena Sports 1'), ['Ar', 'Sp']);
    });

    testWidgets('no results: says so, and the hidden channels that match', (
      tester,
    ) async {
      await open(tester);
      search.answers['harbour'] = const SearchResults(
        text: 'harbour',
        hiddenChannels: 2,
      );
      await type(tester, 'harbour');

      expect(find.text('No results for "harbour"'), findsOneWidget);
      expect(find.text('2 hidden channels match.'), findsOneWidget);
      await tester.tap(find.text('Show in Settings'));
      await settle(tester);
      expect(app.location, AppDestination.settings.path);
    });

    testWidgets('a failed search: Retry runs it again', (tester) async {
      await open(tester);
      search.failure = StorageFailure('disk');
      await type(tester, 'arena');
      expect(find.text("Couldn't search"), findsOneWidget);

      search
        ..failure = null
        ..answers['arena'] = full('arena');
      await tester.tap(find.text('Retry'));
      await settle(tester);
      expect(find.text('CHANNELS'), findsOneWidget);
    });

    testWidgets('no source: Add a source', (tester) async {
      await open(tester, seed: false);
      final overlay = find.byType(SearchOverlay);
      expect(find.text('Nothing to search yet'), findsOneWidget);
      await tester.tap(
        find.descendant(of: overlay, matching: find.text('Add a source')),
      );
      await settle(tester);
      expect(app.location, '/add-source');
    });

    testWidgets('a first sync still running says the catalogue is arriving', (
      tester,
    ) async {
      await open(tester);
      expect(find.textContaining('still arriving'), findsNothing);
      live.fakes.sync.emit(
        'src-1',
        const SyncRunning(SyncProgress(stage: SyncStage.live)),
      );
      await settle(tester);
      expect(find.textContaining('still arriving'), findsOneWidget);
    });
  });

  group('keyboard', () {
    testWidgets('↓ moves through every group, Tab jumps to the next one, '
        'Shift+Tab back', (tester) async {
      await open(tester);
      search.answers['arena'] = full('arena');
      await type(tester, 'arena');

      expect(cursorRow(tester), 'Arena Sports 1');
      await key(tester, LogicalKeyboardKey.arrowDown);
      expect(cursorRow(tester), 'Arena Sports 2');
      await key(tester, LogicalKeyboardKey.tab);
      expect(cursorRow(tester), 'Arena Cup: Final');
      await key(tester, LogicalKeyboardKey.tab);
      expect(cursorRow(tester), 'The Arena');
      await tester.sendKeyDownEvent(LogicalKeyboardKey.shiftLeft);
      await key(tester, LogicalKeyboardKey.tab);
      await tester.sendKeyUpEvent(LogicalKeyboardKey.shiftLeft);
      expect(cursorRow(tester), 'Arena Cup: Final');
      await key(tester, LogicalKeyboardKey.arrowUp);
      expect(cursorRow(tester), 'Show all in Live TV');
      expect(
        FocusManager.instance.primaryFocus?.debugLabel,
        'search field',
        reason: 'the keyboard stays in the field',
      );
    });

    testWidgets('Enter on a channel plays it full screen and saves the '
        'search', (tester) async {
      await open(tester);
      search.answers['arena'] = full('arena');
      await type(tester, 'arena');

      await enter(tester);
      expect(app.location, '/player');
      expect(live.rig.coordinator.current?.remoteKey, '201');
      expect(search.remembered, ['arena']);
      await tester.runAsync(live.rig.coordinator.stop);
      await settle(tester);
    });

    testWidgets('Enter on an upcoming programme opens the Guide on it', (
      tester,
    ) async {
      await open(tester);
      search.answers['arena'] = full('arena');
      await type(tester, 'arena');
      await key(tester, LogicalKeyboardKey.tab);
      await key(tester, LogicalKeyboardKey.arrowDown);
      expect(cursorRow(tester), 'Arena Weekly');

      await enter(tester);
      expect(app.location, AppDestination.guide.path);
    });

    testWidgets('Enter on a movie opens its page', (tester) async {
      await open(tester);
      search.answers['arena'] = full('arena');
      await type(tester, 'arena');
      for (var i = 0; i < 2; i++) {
        await key(tester, LogicalKeyboardKey.tab);
      }
      expect(cursorRow(tester), 'The Arena');

      await enter(tester);
      expect(app.location, '/movies/src-1/m1');
    });

    testWidgets('Show all in Movies: the grid, every title, the text in its '
        'filter', (tester) async {
      await open(tester);
      search.answers['arena'] = full('arena');
      await type(tester, 'arena');
      await tester.tap(find.text('Show all in Movies'));
      await settle(tester);

      expect(app.location, AppDestination.movies.path);
      final container = ProviderScope.containerOf(
        tester.element(find.byType(Navigator).first),
      );
      expect(
        container.read(catalogueControllerProvider(CatalogueKind.movie))?.text,
        'arena',
      );
    });

    testWidgets('the Menu key opens the result menu', (tester) async {
      await open(tester);
      search.answers['arena'] = full('arena');
      await type(tester, 'arena');

      await key(tester, LogicalKeyboardKey.contextMenu);
      await settle(tester);
      expect(find.text('Add to favorites'), findsOneWidget);
      expect(find.text('Show in Live TV'), findsOneWidget);
      expect(find.text('Hide channel'), findsOneWidget);
    });

    testWidgets('Hide channel from the menu hides it, says so with Undo, and '
        'searches again', (tester) async {
      await open(tester);
      final row = (await tester.runAsync(
        () => live.db.channelsDao.byRemoteKey('src-1', '900'),
      ))!;
      final zebra = ChannelItem(
        id: row.id,
        sourceId: 'src-1',
        remoteKey: '900',
        name: 'Zebra TV',
      );
      search.answers['zebra'] = SearchResults(
        text: 'zebra',
        channels: SearchGroup([
          ChannelHit(channel: zebra, sourceName: 'Northwind TV'),
        ]),
      );
      await type(tester, 'zebra');
      expect(search.asked, ['zebra']);

      await key(tester, LogicalKeyboardKey.contextMenu);
      await settle(tester);
      await tester.tap(find.text('Hide channel'));
      // The menu fades out first (120 ms), then the item runs.
      await settle(tester);
      await settle(tester);

      Future<bool> hidden() async => (await tester.runAsync(
        () => live.db.channelsDao.byRemoteKey('src-1', '900'),
      ))!.isHidden;
      expect(await hidden(), isTrue);
      expect(find.text('Channel hidden'), findsOneWidget);
      expect(search.asked, ['zebra', 'zebra'], reason: 'searched again');

      await tester.tap(find.text('Undo'));
      await settle(tester);
      expect(await hidden(), isFalse);
      expect(search.asked, hasLength(3));
    });

    testWidgets('recent searches: Enter searches again, Delete removes one', (
      tester,
    ) async {
      search.recent = ['tennis open', 'cup final'];
      await open(tester);
      search.answers['cup final'] = full('cup final');

      await key(tester, LogicalKeyboardKey.delete);
      await settle(tester);
      expect(find.text('tennis open'), findsNothing);
      await enter(tester);
      await tester.pump(searchDelay);
      await settle(tester);
      expect(search.asked, ['cup final']);
      expect(find.text('CHANNELS'), findsOneWidget);
    });
  });

  test('guide requests are taken once', () {
    final container = ProviderContainer();
    addTearDown(container.dispose);
    final request = container.read(guideProgrammeRequestProvider.notifier)
      ..show(
        _channel('201', 'Arena Sports 1'),
        EpgProgramme(
          id: 1,
          channelId: 'a',
          start: DateTime.utc(2026),
          end: DateTime.utc(2026, 1, 1, 1),
          title: 'X',
        ),
      );
    expect(request.take()?.programme.title, 'X');
    expect(request.take(), isNull);
  });
}

const searchCoverageForTest =
    'Channels, what’s on now and next, movies and series, from every '
    'source.';
