import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:iptv_player/app/destinations.dart';
import 'package:iptv_player/design/components.dart';
import 'package:iptv_player/features/sources/domain/categories.dart';
import 'package:iptv_player/features/sources/presentation/hidden_channels.dart';

import '../../../app/app_harness.dart';
import '../../live_tv/live_tv_fakes.dart';

/// Settings → Categories → Hidden channels (Phase 6 step 7, sketch B), on
/// the Live TV fakes' real catalogue: Sports (Arena Sports 1 and 2,
/// Velocity Motors), News (hidden itself, not its channels) and Zebra TV
/// in no category.
void main() {
  late LiveTvFakes live;

  Future<void> hide(List<String> keys) async {
    for (final key in keys) {
      final row = (await live.db.channelsDao.byRemoteKey('src-1', key))!;
      await live.db.channelsDao.setHidden(row.id, hidden: true);
    }
  }

  Future<void> open(
    WidgetTester tester, {
    List<String> hidden = const [],
  }) async {
    live = LiveTvFakes();
    addTearDown(() => tester.runAsync(live.db.close));
    await tester.runAsync(() async {
      await live.seed();
      await hide(hidden);
    });
    await pumpApp(
      tester,
      initialLocation: AppDestination.settings.path,
      overrides: live.overrides,
    );
    await _settle(tester);
    await tester.tap(find.text('Categories').first);
    await _settle(tester);
  }

  Future<void> openTab(WidgetTester tester) async {
    await tester.tap(find.text('Hidden channels'));
    await _settle(tester);
  }

  Future<List<String>> stillHidden(WidgetTester tester) async {
    final rows = await tester.runAsync(
      () => live.db.select(live.db.channels).get(),
    );
    return [
      for (final row in rows!)
        if (row.isHidden) row.remoteKey,
    ]..sort();
  }

  /// The rows' names, top to bottom.
  List<String> rows(WidgetTester tester) => [
    for (final surface in tester.widgetList<FocusableSurface>(
      find.descendant(
        of: find.byType(HiddenChannelsView),
        matching: find.byType(FocusableSurface),
      ),
    ))
      if (surface.semanticLabel case final label?
          when label.endsWith(', hidden. Show'))
        label.substring(0, label.length - ', hidden. Show'.length),
  ];

  String? focused() {
    final label =
        FocusManager.instance.primaryFocus?.context
            ?.findAncestorWidgetOfExactType<FocusableSurface>()
            ?.semanticLabel ??
        FocusManager.instance.primaryFocus?.context
            ?.findAncestorWidgetOfExactType<Semantics>()
            ?.properties
            .label;
    return label?.replaceAll(', hidden. Show', '');
  }

  testWidgets('no channel hidden: no tab for them', (tester) async {
    await open(tester);

    expect(find.text('Hidden channels'), findsNothing);
    // Live TV's categories only: no tabs at all.
    expect(find.byType(SegmentedControl<CatalogueKind?>), findsNothing);
    expect(find.text('Sports'), findsOneWidget);
  });

  testWidgets('the tab shows once a channel is hidden, with its count, and '
      'lists them: number, name, category, Show', (tester) async {
    await open(tester, hidden: ['202', '900']);

    final tabs = tester.widget<SegmentedControl<CatalogueKind?>>(
      find.byType(SegmentedControl<CatalogueKind?>),
    );
    // Null is the Hidden channels tab.
    final tab = tabs.options.singleWhere((o) => o.value == null);
    expect((tab.label, tab.count), ('Hidden channels', '2'));

    await openTab(tester);
    expect(find.byType(HiddenChannelsView), findsOneWidget);
    expect(rows(tester), ['Arena Sports 2', 'Zebra TV']);
    expect(find.text('202'), findsOneWidget);
    expect(find.text('Sports'), findsOneWidget);
    expect(find.text('Uncategorized'), findsOneWidget);
    expect(find.text('Show'), findsNWidgets(2));
    expect(find.text('Show all'), findsOneWidget);
    expect(
      find.text(
        'Hidden channels are left out of Live TV, the Guide, Search and '
        'Home. They stay hidden after a re-sync.',
      ),
      findsOneWidget,
    );
    expect(
      find.text('World News'),
      findsNothing,
      reason: 'a hidden category hides its channels, but not one by one',
    );
  });

  testWidgets('the filter narrows the list, and says when nothing matches', (
    tester,
  ) async {
    await open(tester, hidden: ['201', '202', '900']);
    await openTab(tester);
    final filter = find.descendant(
      of: find.byWidgetPredicate(
        (w) => w is SearchField && w.hint == 'Filter hidden channels',
      ),
      matching: find.byType(EditableText),
    );

    await tester.enterText(filter, 'arena');
    await _settle(tester);
    expect(rows(tester), ['Arena Sports 1', 'Arena Sports 2']);

    await tester.enterText(filter, 'harbour');
    await _settle(tester);
    expect(rows(tester), isEmpty);
    expect(find.text('No hidden channel matches "harbour"'), findsOneWidget);
    expect(find.text('Show all'), findsNothing);
  });

  testWidgets('one Tab stop: ↓ inside it; Enter shows the channel, which '
      'leaves, and the focus goes to the next', (tester) async {
    await open(tester, hidden: ['201', '202', '900']);
    await openTab(tester);
    expect(rows(tester), ['Arena Sports 1', 'Arena Sports 2', 'Zebra TV']);

    // From the filter, one Tab past Show all lands in the list.
    final filter = find.descendant(
      of: find.byType(HiddenChannelsView),
      matching: find.byType(EditableText),
    );
    await tester.tap(filter);
    await tester.pump();
    for (var i = 0; i < 4 && focused() != 'Arena Sports 1'; i++) {
      await tester.sendKeyEvent(LogicalKeyboardKey.tab);
      await tester.pump();
    }
    expect(focused(), 'Arena Sports 1');
    await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
    await tester.pump();
    expect(focused(), 'Arena Sports 2');

    await tester.sendKeyEvent(LogicalKeyboardKey.enter);
    await _settle(tester);
    expect(rows(tester), ['Arena Sports 1', 'Zebra TV']);
    expect(focused(), 'Zebra TV');
    expect(await stillHidden(tester), ['201', '900']);

    // The last one shown: the focus stays in the list, on the one left.
    await tester.sendKeyEvent(LogicalKeyboardKey.enter);
    await _settle(tester);
    expect(rows(tester), ['Arena Sports 1']);
    expect(focused(), 'Arena Sports 1');

    // Tab leaves the list: it is one stop, not one per row.
    await tester.sendKeyEvent(LogicalKeyboardKey.tab);
    await tester.pump();
    expect(focused(), isNot('Arena Sports 1'));
  });

  testWidgets('Show all shows every one; the list says there are none', (
    tester,
  ) async {
    await open(tester, hidden: ['201', '900']);
    await openTab(tester);

    await tester.tap(find.text('Show all'));
    await _settle(tester);

    expect(await stillHidden(tester), isEmpty);
    expect(rows(tester), isEmpty);
    expect(find.text('No hidden channels'), findsOneWidget);
    expect(
      find.text(
        'Hide a channel from its menu in Live TV, the Guide or Search.',
      ),
      findsOneWidget,
    );
  });

  testWidgets("a click on a row's Show shows that one", (tester) async {
    await open(tester, hidden: ['202', '900']);
    await openTab(tester);

    await tester.tap(
      find.descendant(
        of: find.ancestor(
          of: find.text('Zebra TV'),
          matching: find.byType(FocusableSurface),
        ),
        matching: find.text('Show'),
      ),
    );
    await _settle(tester);

    expect(rows(tester), ['Arena Sports 2']);
    expect(await stillHidden(tester), ['202']);
  });
}

Future<void> _settle(WidgetTester tester) async {
  for (var i = 0; i < 5; i++) {
    await tester.runAsync(() => Future<void>.delayed(Duration.zero));
    await tester.pump(const Duration(milliseconds: 50));
  }
}
