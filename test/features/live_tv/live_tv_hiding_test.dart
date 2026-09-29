import 'package:drift/drift.dart' show Value;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:iptv_player/app/destinations.dart';
import 'package:iptv_player/data/db/app_database.dart'
    show CategoriesCompanion, ChannelsCompanion;
import 'package:iptv_player/design/components.dart';
import 'package:iptv_player/features/live_tv/presentation/categories_pane.dart';
import 'package:iptv_player/features/sources/domain/categories.dart';
import 'package:iptv_player/features/sources/presentation/hidden_channels.dart';

import '../../app/app_harness.dart';
import 'live_tv_fakes.dart';

/// Hiding in Live TV (Phase 6 step 7): the channel menu's Hide with Undo
/// and Show hidden channels; the categories pane's menu (Hide with Undo,
/// Rename…, Move up/down), Alt+↑/↓, and its foot's Manage.
void main() {
  late LiveTvFakes live;

  Future<void> pump(
    WidgetTester tester, {
    Future<void> Function()? before,
  }) async {
    live = LiveTvFakes();
    addTearDown(() => tester.runAsync(live.db.close));
    await tester.runAsync(() async {
      await live.seed();
      await before?.call();
    });
    await pumpApp(
      tester,
      initialLocation: AppDestination.liveTv.path,
      overrides: live.overrides,
    );
    await _settle(tester);
  }

  Future<void> finish(WidgetTester tester) async {
    // A preview's 350 ms, then stop what it started.
    await tester.pump(const Duration(milliseconds: 400));
    await tester.runAsync(live.rig.coordinator.stop);
    await _settle(tester);
  }

  Future<bool> isHidden(WidgetTester tester, String key) async =>
      (await tester.runAsync(
        () => live.db.channelsDao.byRemoteKey('src-1', key),
      ))!.isHidden;

  List<String> rows(WidgetTester tester) => [
    for (final row in tester.widgetList<ChannelRow>(find.byType(ChannelRow)))
      row.name,
  ];

  Future<void> menuOn(WidgetTester tester, Finder target) async {
    Focus.of(tester.element(target)).requestFocus();
    await tester.pump();
    await tester.sendKeyEvent(LogicalKeyboardKey.contextMenu);
    await _settle(tester);
  }

  Finder channel(String name) => find.descendant(
    of: find.widgetWithText(ChannelRow, name),
    matching: find.text(name),
  );

  /// [name] in the categories pane (a chosen category's name is the
  /// list's title too).
  Finder inPane(String name) => find.descendant(
    of: find.byType(CategoriesPane),
    matching: find.text(name),
  );

  group('the channel menu', () {
    testWidgets('Hide channel hides it at once and says so; Undo brings it '
        'back', (tester) async {
      await pump(tester);
      expect(rows(tester), contains('Arena Sports 2'));

      await menuOn(tester, channel('Arena Sports 2'));
      await tester.tap(find.text('Hide channel'));
      await _settle(tester);

      expect(rows(tester), isNot(contains('Arena Sports 2')));
      expect(await isHidden(tester, '202'), isTrue);
      expect(find.text('Channel hidden'), findsOneWidget);
      expect(find.text('1 category · 1 channel hidden'), findsOneWidget);

      await tester.tap(find.text('Undo'));
      await _settle(tester);
      expect(rows(tester), contains('Arena Sports 2'));
      expect(await isHidden(tester, '202'), isFalse);
      expect(find.text('1 category hidden'), findsOneWidget);
      await finish(tester);
    });

    testWidgets('Show hidden channels draws them dimmed and tagged, and '
        'Show channel brings one back', (tester) async {
      await pump(
        tester,
        before: () async => await live.db.channelsDao.setHidden(
          (await live.db.channelsDao.byRemoteKey('src-1', '900'))!.id,
          hidden: true,
        ),
      );
      expect(rows(tester), isNot(contains('Zebra TV')));

      await menuOn(tester, channel('Arena Sports 1'));
      await tester.tap(find.text('Show hidden channels'));
      await _settle(tester);

      final zebra = tester.widget<ChannelRow>(
        find.widgetWithText(ChannelRow, 'Zebra TV'),
      );
      expect(zebra.hidden, isTrue);
      expect(
        tester
            .widget<ChannelRow>(
              find.widgetWithText(ChannelRow, 'Arena Sports 1'),
            )
            .hidden,
        isFalse,
      );
      expect(
        find.descendant(
          of: find.widgetWithText(ChannelRow, 'Zebra TV'),
          matching: find.text('Hidden'),
        ),
        findsOneWidget,
      );

      await menuOn(tester, channel('Zebra TV'));
      expect(find.text('Show channel'), findsOneWidget);
      expect(find.text("Don't show hidden channels"), findsOneWidget);
      await tester.tap(find.text('Show channel'));
      await _settle(tester);
      expect(await isHidden(tester, '900'), isFalse);
      expect(
        tester
            .widget<ChannelRow>(find.widgetWithText(ChannelRow, 'Zebra TV'))
            .hidden,
        isFalse,
      );
      await finish(tester);
    });
  });

  group('the categories pane', () {
    /// A second shown category after Sports, and the hidden News between
    /// them in the order of all three.
    Future<void> kids() async {
      final id = await live.db
          .into(live.db.categories)
          .insert(
            CategoriesCompanion.insert(
              sourceId: 'src-1',
              kind: CatalogueKind.live,
              remoteKey: '3',
              name: 'Kids',
              position: const Value(3),
            ),
          );
      await live.db.channelsDao.upsertAll([
        ChannelsCompanion.insert(
          sourceId: 'src-1',
          remoteKey: '401',
          name: 'Cartoon Bay',
          categoryId: Value(id),
        ),
      ]);
    }

    List<String> pane(WidgetTester tester) =>
        [
          for (final name in ['Sports', 'Kids'])
            if (inPane(name).evaluate().isNotEmpty) name,
        ]..sort(
          (a, b) => tester
              .getTopLeft(inPane(a))
              .dy
              .compareTo(tester.getTopLeft(inPane(b)).dy),
        );

    testWidgets('Hide category takes it out at once; Undo puts it back', (
      tester,
    ) async {
      await pump(tester, before: kids);
      await tester.tap(inPane('Sports'));
      await _settle(tester);

      await menuOn(tester, inPane('Sports'));
      expect(find.text('Rename…'), findsOneWidget);
      expect(find.text('Move up'), findsOneWidget);
      expect(find.text('Move down'), findsOneWidget);
      await tester.tap(find.text('Hide category'));
      await _settle(tester);

      expect(inPane('Sports'), findsNothing);
      expect(find.text('Category hidden'), findsOneWidget);
      expect(find.text('2 categories hidden'), findsOneWidget);
      expect(
        rows(tester),
        isNot(contains('Arena Sports 1')),
        reason: 'the list it showed went back to All channels, without it',
      );

      await tester.tap(find.text('Undo'));
      await _settle(tester);
      expect(inPane('Sports'), findsOneWidget);
      expect(find.text('1 category hidden'), findsOneWidget);
      await finish(tester);
    });

    testWidgets('Rename… names it; the name shows in the pane', (tester) async {
      await pump(tester);

      await menuOn(tester, inPane('Sports'));
      await tester.tap(find.text('Rename…'));
      await _settle(tester);
      expect(find.text('Rename category'), findsOneWidget);
      await tester.enterText(
        find.descendant(
          of: find.byType(AppDialog),
          matching: find.byType(EditableText),
        ),
        'Live Sport',
      );
      await tester.tap(find.text('Save'));
      await _settle(tester);

      expect(inPane('Live Sport'), findsOneWidget);
      expect(inPane('Sports'), findsNothing);
      await finish(tester);
    });

    testWidgets('Alt+↓ and Alt+↑ move it past its neighbour, the focus with '
        'it; so do Move down and Move up', (tester) async {
      await pump(tester, before: kids);
      expect(pane(tester), ['Sports', 'Kids']);

      Focus.of(tester.element(inPane('Sports'))).requestFocus();
      await tester.pump();
      await _alt(tester, LogicalKeyboardKey.arrowDown);
      expect(pane(tester), ['Kids', 'Sports']);
      expect(
        Focus.of(tester.element(inPane('Sports'))).hasPrimaryFocus,
        isTrue,
        reason: 'the focus follows the category',
      );

      await _alt(tester, LogicalKeyboardKey.arrowUp);
      expect(pane(tester), ['Sports', 'Kids']);

      await menuOn(tester, inPane('Kids'));
      await tester.tap(find.text('Move up'));
      await _settle(tester);
      expect(pane(tester), ['Kids', 'Sports']);
      await menuOn(tester, inPane('Kids'));
      await tester.tap(find.text('Move down'));
      await _settle(tester);
      expect(pane(tester), ['Sports', 'Kids']);

      // Moved in the order of all of them, the hidden one included, as
      // the Categories manager moves them.
      final order = await tester.runAsync(
        () => live.db.categoriesDao
            .watchForSource('src-1', CatalogueKind.live)
            .first,
      );
      expect([for (final c in order!) c.name], ['News', 'Sports', 'Kids']);
      await finish(tester);
    });

    testWidgets("the foot's Manage: to Hidden channels when only channels "
        'are hidden, else to the categories', (tester) async {
      await pump(
        tester,
        before: () async {
          final news = await live.db.categoriesDao
              .watchForSource('src-1', CatalogueKind.live)
              .first;
          await live.db.categoriesDao.setHidden(
            news.firstWhere((c) => c.name == 'News').id,
            hidden: false,
          );
          await live.db.channelsDao.setHidden(
            (await live.db.channelsDao.byRemoteKey('src-1', '900'))!.id,
            hidden: true,
          );
        },
      );
      expect(find.text('1 channel hidden'), findsOneWidget);

      await tester.tap(find.text('Manage'));
      await _settle(tester);
      expect(find.byType(HiddenChannelsView), findsOneWidget);
      expect(find.text('Zebra TV'), findsOneWidget);
      await finish(tester);
    });

    testWidgets('Manage with a category hidden opens the categories', (
      tester,
    ) async {
      await pump(tester);

      await tester.tap(find.text('Manage'));
      await _settle(tester);
      expect(find.byType(HiddenChannelsView), findsNothing);
      expect(find.byType(CategoriesPane), findsNothing, reason: 'Settings');
      expect(find.text('News'), findsOneWidget);
      await finish(tester);
    });
  });
}

Future<void> _alt(WidgetTester tester, LogicalKeyboardKey key) async {
  await tester.sendKeyDownEvent(LogicalKeyboardKey.altLeft);
  await tester.sendKeyEvent(key);
  await tester.sendKeyUpEvent(LogicalKeyboardKey.altLeft);
  await _settle(tester);
}

/// Rounds enough for a menu's item (run once the menu has faded out,
/// 120 ms) and the reads it starts.
Future<void> _settle(WidgetTester tester) async {
  for (var i = 0; i < 8; i++) {
    await tester.runAsync(() => Future<void>.delayed(Duration.zero));
    await tester.pump(const Duration(milliseconds: 50));
  }
}
