// Phase 6 exit criterion 4, keys only, on the real app, database, sync and
// guide against the fake panel: a channel hidden from Live TV's menu, and
// a category hidden from Live TV's categories pane, are gone from Live TV,
// the Guide, Search and Home — the channel a favorite, the category's
// channel watched a moment ago — and both come back from Settings →
// Categories: the channel through Search's "Show in Settings" and the
// Hidden channels tab, the category from its row.
//
// The test reads state to check it and to pick its channels; everything
// it does goes through the keyboard.

import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:iptv_player/app/app.dart';
import 'package:iptv_player/app/destinations.dart';
import 'package:iptv_player/design/components.dart';
import 'package:iptv_player/features/guide/data/guide_providers.dart';
import 'package:iptv_player/features/guide/presentation/guide_view_state.dart';
import 'package:iptv_player/features/live_tv/data/live_tv_providers.dart';
import 'package:iptv_player/features/live_tv/domain/channels.dart';
import 'package:iptv_player/features/live_tv/presentation/categories_pane.dart';
import 'package:iptv_player/features/live_tv/presentation/live_tv_state.dart';
import 'package:iptv_player/features/playback/data/db_playback_history.dart';
import 'package:iptv_player/features/search/data/search_providers.dart';
import 'package:iptv_player/features/search/presentation/search_overlay.dart';
import 'package:iptv_player/features/sources/domain/categories.dart';
import 'package:iptv_player/features/sources/presentation/hidden_channels.dart';

import 'support/fake_panel.dart';
import 'support/keyboard.dart';
import 'support/panel_app.dart';

void main() {
  final binding = IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  final video = Platform.environment['IPTV_PLAYER_VIDEO'] != '0';

  testWidgets('a hidden channel and a hidden category are gone from Live '
      'TV, the Guide, Search and Home, and come back from Settings', (
    tester,
  ) async {
    HttpOverrides.global = null;
    tester.view.physicalSize = const Size(1440, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    FocusManager.instance.highlightStrategy =
        FocusHighlightStrategy.alwaysTraditional;
    tester.testTextInput.register();
    addTearDown(tester.testTextInput.unregister);
    binding.framePolicy = LiveTestWidgetsFlutterBindingFramePolicy.fullyLive;

    final panel = (await tester.runAsync(
      () => FakePanel.start(streams: streamsAvailable),
    ))!;
    addTearDown(() => tester.runAsync(panel.stop));
    final app = (await tester.runAsync(
      () => PanelApp.open(panel, video: video),
    ))!;
    addTearDown(() => tester.runAsync(app.close));
    final container = app.container;
    final id = app.sourceId;
    final channels = container.read(channelRepositoryProvider);

    // ── The guide, and the two channels: [hidden] a favorite whose name
    // finds nothing else, [inCategory] watched a moment ago, in another
    // category. Both near the top of the number order, where the lists
    // start.
    late final ChannelItem hidden;
    late final ChannelItem inCategory;
    late final String category;
    late final String firstCategory;
    await tester.runAsync(() async {
      final imported = await container
          .read(guideImportServiceProvider)
          .importGuide(id);
      if (!imported.isOk) throw StateError('${imported.failureOrNull}');
      final all = (await channels.range(
        ChannelQuery(sourceId: id),
        0,
        1000,
      )).valueOrNull!;
      final named = <String, int>{};
      for (final c in all) {
        named[c.name] = (named[c.name] ?? 0) + 1;
      }
      final search = container.read(searchRepositoryProvider);
      for (final c in all.take(60)) {
        if (named[c.name] != 1) continue;
        final found = (await search.search(
          c.name,
          now: DateTime.now(),
          preferredSourceId: id,
        )).valueOrNull!;
        if ([for (final h in found.channels.hits) h.channel.id].join() ==
                '${c.id}' &&
            found.programmes.isEmpty &&
            found.movies.isEmpty &&
            found.series.isEmpty) {
          hidden = c;
          break;
        }
      }
      inCategory = all.firstWhere(
        (c) =>
            named[c.name] == 1 &&
            c.categoryId != null &&
            c.categoryId != hidden.categoryId,
      );
      final rows = await app.db.categoriesDao
          .watchForSource(id, CatalogueKind.live)
          .first;
      final row = rows.firstWhere((r) => r.id == inCategory.categoryId);
      category = row.displayName ?? row.name;
      firstCategory = rows.first.displayName ?? rows.first.name;
      await channels.setFavorite(hidden, on: true);
      await DbPlaybackHistory(app.db).recordLive(inCategory);
    });

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: const IptvPlayerApp(),
      ),
    );
    SystemChannels.lifecycle.setMessageHandler((message) async => null);
    tester.binding.platformDispatcher.onViewFocusChange = (_) {};
    final k = Keys(tester)..resume();
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    Finder tile(ChannelItem c) =>
        find.byWidgetPredicate((w) => w is ChannelTile && w.name == c.name);
    Finder row(ChannelItem c) =>
        find.byWidgetPredicate((w) => w is ChannelRow && w.name == c.name);
    Finder inPane(String name) => find.descendant(
      of: find.byType(CategoriesPane),
      matching: find.text(name),
    );

    /// The names a list shows for [query] (any text filter aside). Plain
    /// for `waitUntil`, which runs it outside the test's fake zone.
    Future<List<String>> names(ChannelQuery query) async => [
      for (final c in (await channels.range(
        query.copyWith(text: ''),
        0,
        1000,
      )).valueOrNull!)
        c.name,
    ];
    Future<List<String>> listed(ChannelQuery query) async =>
        (await tester.runAsync(() => names(query)))!;

    // ── Home: the favorite and the channel just watched.
    await k.waitFor(tile(hidden), seconds: 30);
    await k.waitFor(tile(inCategory));

    // ── Ctrl+2: Live TV; ↓ Enter: All channels; the filter finds the
    // favorite; Tab to its row; the menu: Hide channel.
    await k.chord(LogicalKeyboardKey.digit2);
    await k.waitFor(find.text('All channels'));
    await k.waitUntil(
      () => k.focusIsOn(find.text('Favorites').first),
      'the focus on Favorites',
    );
    await k.press(LogicalKeyboardKey.arrowDown);
    await k.press(LogicalKeyboardKey.enter);
    final filter = find.descendant(
      of: find.byWidgetPredicate(
        (w) => w is SearchField && w.hint == 'Filter All channels',
      ),
      matching: find.byType(EditableText),
    );
    await k.waitFor(filter);
    await k.tabTo(filter, back: true);
    await k.typeIn(filter, hidden.name);
    await k.waitFor(row(hidden));
    await k.tabTo(row(hidden));
    await k.press(LogicalKeyboardKey.contextMenu);
    await k.waitFor(find.text('Hide channel'));
    for (var i = 0; i < 8 && !k.focusIsOn(find.text('Hide channel')); i++) {
      await k.press(LogicalKeyboardKey.arrowDown);
    }
    await k.press(LogicalKeyboardKey.enter);
    await k.waitFor(find.text('Channel hidden'));
    await k.waitUntil(
      () => row(hidden).evaluate().isEmpty,
      'the row gone from the filtered list',
    );
    await k.tabTo(filter, back: true);
    await tester.enterText(filter, '');
    await tester.pump();

    // ── The categories pane: ↓ to the watched channel's category; the
    // menu's first item, Hide category.
    bool inCategories() =>
        FocusManager.instance.primaryFocus?.context
            ?.findAncestorWidgetOfExactType<CategoriesPane>() !=
        null;
    for (var i = 0; i < 8 && !inCategories(); i++) {
      await k.shift(LogicalKeyboardKey.tab);
    }
    expect(inCategories(), isTrue, reason: 'Shift+Tab into the pane');
    for (final key in [
      LogicalKeyboardKey.arrowUp,
      LogicalKeyboardKey.arrowDown,
    ]) {
      for (var i = 0; i < 20 && !k.focusIsOn(inPane(category)); i++) {
        await k.press(key);
      }
    }
    expect(k.focusIsOn(inPane(category)), isTrue, reason: category);
    await k.press(LogicalKeyboardKey.contextMenu);
    await k.waitFor(find.text('Hide category'));
    expect(k.focusIsOn(find.text('Hide category')), isTrue);
    await k.press(LogicalKeyboardKey.enter);
    await k.waitFor(find.text('Category hidden'));
    await k.waitUntil(
      () => inPane(category).evaluate().isEmpty,
      'the category gone from the pane',
    );

    // ── Gone from Live TV's list.
    final liveQuery = container.read(liveTvControllerProvider)!.query;
    expect(liveQuery.filter, const AllChannels());
    var shown = await listed(liveQuery);
    expect(shown, isNot(contains(hidden.name)));
    expect(shown, isNot(contains(inCategory.name)));
    expect(shown, isNotEmpty);

    // ── G: the Guide, neither in its list nor on screen.
    await k.press(LogicalKeyboardKey.keyG);
    await k.waitUntil(
      () => app.location == AppDestination.guide.path,
      'the Guide (${app.location})',
    );
    shown = await listed(container.read(guideChannelsProvider)!);
    expect(shown, isNot(contains(hidden.name)));
    expect(shown, isNot(contains(inCategory.name)));
    await k.waitFor(find.text(shown.first));
    expect(find.text(hidden.name), findsNothing);
    expect(find.text(inCategory.name), findsNothing);

    // ── Ctrl+K: the favorite's name finds nothing, and says a hidden
    // channel matches; the other one's finds no channel.
    final overlay = find.byType(SearchOverlay);
    final field = find.descendant(
      of: overlay,
      matching: find.byType(EditableText),
    );
    final other = (await tester.runAsync(
      () => container
          .read(searchRepositoryProvider)
          .search(inCategory.name, now: DateTime.now(), preferredSourceId: id),
    ))!.valueOrNull!;
    expect([
      for (final h in other.channels.hits) h.channel.id,
    ], isNot(contains(inCategory.id)));
    await k.chord(LogicalKeyboardKey.keyK);
    await k.waitFor(field);
    await k.typeIn(field, hidden.name);
    await k.waitFor(find.text('No results for "${hidden.name}"'), seconds: 10);
    expect(find.text('1 hidden channel matches.'), findsOneWidget);

    // ── Esc, Ctrl+1: Home, without either.
    await k.press(LogicalKeyboardKey.escape);
    await k.waitUntil(() => overlay.evaluate().isEmpty, 'search closed');
    await k.chord(LogicalKeyboardKey.digit1);
    await k.waitUntil(() => app.location == '/', 'Home (${app.location})');
    await k.waitUntil(
      () =>
          tile(hidden).evaluate().isEmpty &&
          tile(inCategory).evaluate().isEmpty,
      'both gone from Home',
    );

    // ── Ctrl+K again: Show in Settings, to the Hidden channels tab; Tab
    // into its list, Enter shows the favorite.
    await k.chord(LogicalKeyboardKey.keyK);
    await k.waitFor(field);
    await k.typeIn(field, hidden.name);
    await k.waitFor(find.text('Show in Settings'), seconds: 10);
    await k.tabTo(find.text('Show in Settings'));
    await k.press(LogicalKeyboardKey.enter);
    await k.waitFor(find.byType(HiddenChannelsView));
    final hiddenRow = find.byWidgetPredicate(
      (w) =>
          w is FocusableSurface &&
          w.semanticLabel == '${hidden.name}, hidden. Show',
    );
    await k.waitFor(hiddenRow);
    await k.tabTo(hiddenRow);
    await k.press(LogicalKeyboardKey.enter);
    await k.waitFor(find.text('No hidden channels'));

    // ── The Live TV tab: Tab into its list (one stop, on its first
    // row), ↓ to the category, Space.
    await k.tabTo(
      find.descendant(
        of: find.byType(SegmentedControl<CatalogueKind?>),
        matching: find.text('Live TV'),
      ),
      back: true,
    );
    await k.press(LogicalKeyboardKey.enter);
    Finder categoryRow(String name) => find.ancestor(
      of: find.text(name),
      matching: find.byType(FocusableSurface),
    );
    await k.waitFor(categoryRow(category));
    await k.tabTo(categoryRow(firstCategory));
    for (var i = 0; i < 20 && !k.focusIsOn(categoryRow(category)); i++) {
      await k.press(LogicalKeyboardKey.arrowDown);
    }
    expect(k.focusIsOn(categoryRow(category)), isTrue, reason: category);
    await k.press(LogicalKeyboardKey.space);

    // ── Back everywhere: Live TV's list, the Guide's, Search, Home.
    await k.waitUntil(() async {
      final back = await names(liveQuery);
      return back.contains(hidden.name) && back.contains(inCategory.name);
    }, "both back in Live TV's list");
    shown = await listed(container.read(guideChannelsProvider)!);
    expect(shown, containsAll([hidden.name, inCategory.name]));
    final again = (await tester.runAsync(
      () => container
          .read(searchRepositoryProvider)
          .search(hidden.name, now: DateTime.now(), preferredSourceId: id),
    ))!.valueOrNull!;
    expect([
      for (final h in again.channels.hits) h.channel.id,
    ], contains(hidden.id));
    await k.chord(LogicalKeyboardKey.digit1);
    await k.waitUntil(() => app.location == '/', 'Home again');
    await k.waitFor(tile(hidden));
    await k.waitFor(tile(inCategory));
    expect(tester.takeException(), isNull);
  }, timeout: const Timeout(Duration(minutes: 4)));
}
