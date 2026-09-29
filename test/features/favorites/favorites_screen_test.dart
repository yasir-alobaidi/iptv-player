import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:iptv_player/app/destinations.dart';
import 'package:iptv_player/design/components.dart';
import 'package:iptv_player/features/favorites/data/db_favorites_repository.dart';
import 'package:iptv_player/features/live_tv/data/db_channel_repository.dart';
import 'package:iptv_player/features/live_tv/domain/channels.dart';

import '../../app/app_harness.dart';
import '../live_tv/live_tv_fakes.dart';

void main() {
  late LiveTvFakes live;
  late AppUnderTest app;

  Future<void> settle(WidgetTester tester) async {
    for (var i = 0; i < 5; i++) {
      await tester.runAsync(() => Future<void>.delayed(Duration.zero));
      await tester.pump(const Duration(milliseconds: 50));
    }
  }

  /// Favorites on the fakes' catalogue; with [groups], Arena Sports 2 and
  /// Velocity Motors in "Motors", Arena Sports 1 and Zebra TV in none.
  Future<void> open(
    WidgetTester tester, {
    bool seed = true,
    bool favorites = true,
    bool groups = true,
  }) async {
    live = LiveTvFakes();
    addTearDown(() => tester.runAsync(live.db.close));
    await tester.runAsync(() async {
      if (!seed) return;
      await live.seed();
      if (!favorites) return;
      final channels = DbChannelRepository(live.db);
      final repo = DbFavoritesRepository(live.db);
      Future<ChannelItem> channel(String key) async =>
          (await channels.byRemoteKey('src-1', key)).valueOrNull!;
      for (final key in ['201', '202', '203', '900']) {
        await channels.setFavorite(await channel(key), on: true);
      }
      if (!groups) return;
      final motors = (await repo.createGroup('src-1', 'Motors')).valueOrNull!;
      await repo.moveChannel(await channel('202'), groupId: motors, index: 0);
      await repo.moveChannel(await channel('203'), groupId: motors, index: 1);
    });
    app = await pumpApp(
      tester,
      initialLocation: AppDestination.favorites.path,
      overrides: live.overrides,
    );
    await settle(tester);
  }

  Future<void> finish(WidgetTester tester) async {
    await tester.runAsync(live.rig.coordinator.stop);
    await settle(tester);
  }

  List<String> rows(WidgetTester tester) => [
    for (final row in tester.widgetList<ChannelRow>(find.byType(ChannelRow)))
      row.name,
  ];

  Future<void> focusRow(WidgetTester tester, String name) async {
    final row = tester.widget<ChannelRow>(
      find.widgetWithText(ChannelRow, name),
    );
    row.focusNode!.requestFocus();
    await tester.pump();
  }

  Future<void> alt(WidgetTester tester, LogicalKeyboardKey key) async {
    await tester.sendKeyDownEvent(LogicalKeyboardKey.altLeft);
    await tester.sendKeyEvent(key);
    await tester.sendKeyUpEvent(LogicalKeyboardKey.altLeft);
    await settle(tester);
  }

  testWidgets('no source: Add a source', (tester) async {
    await open(tester, seed: false);
    expect(find.text('No favorites yet'), findsOneWidget);
    expect(find.text('Add a source'), findsWidgets);
  });

  testWidgets('no favorite channel yet: says how, and offers Live TV', (
    tester,
  ) async {
    await open(tester, favorites: false);
    expect(find.text('No favorite channels yet'), findsOneWidget);
    await tester.tap(find.text('Open Live TV'));
    await settle(tester);
    expect(app.location, AppDestination.liveTv.path);
  });

  testWidgets('the canvas: tabs with counts, groups with theirs, then '
      'Ungrouped; rows with the badge; the hint', (tester) async {
    await open(tester);

    expect(find.text('Channels'), findsOneWidget);
    expect(find.text('4'), findsWidgets);
    expect(find.text('MOTORS'), findsOneWidget);
    expect(find.text('UNGROUPED'), findsOneWidget);
    expect(rows(tester), [
      'Arena Sports 2',
      'Velocity Motors',
      'Arena Sports 1',
      'Zebra TV',
    ]);
    expect(
      tester
          .widget<ChannelRow>(
            find.widgetWithText(ChannelRow, 'Velocity Motors'),
          )
          .quality,
      'FHD',
    );
    expect(find.text('Drag to reorder'), findsOneWidget);
    expect(find.textContaining('to add it here or remove it'), findsOneWidget);
    await finish(tester);
  });

  testWidgets('Alt+↑/↓ move a channel, past the group edge into the next', (
    tester,
  ) async {
    await open(tester);
    await focusRow(tester, 'Velocity Motors');

    await alt(tester, LogicalKeyboardKey.arrowDown);
    expect(rows(tester), [
      'Arena Sports 2',
      'Velocity Motors',
      'Arena Sports 1',
      'Zebra TV',
    ]);
    expect(find.text('UNGROUPED'), findsOneWidget);
    // It left the group: the group's count is now 1.
    final motorsCount = find.descendant(
      of: find.ancestor(of: find.text('MOTORS'), matching: find.byType(Row)),
      matching: find.text('1'),
    );
    expect(motorsCount, findsOneWidget);

    await alt(tester, LogicalKeyboardKey.arrowDown);
    expect(rows(tester), [
      'Arena Sports 2',
      'Arena Sports 1',
      'Velocity Motors',
      'Zebra TV',
    ]);
    await alt(tester, LogicalKeyboardKey.arrowUp);
    await alt(tester, LogicalKeyboardKey.arrowUp);
    expect(rows(tester), [
      'Arena Sports 2',
      'Velocity Motors',
      'Arena Sports 1',
      'Zebra TV',
    ]);
    await finish(tester);
  });

  testWidgets('F removes with Undo, which puts it back where it was', (
    tester,
  ) async {
    await open(tester);
    await focusRow(tester, 'Velocity Motors');

    await tester.sendKeyEvent(LogicalKeyboardKey.keyF);
    await settle(tester);
    expect(rows(tester), ['Arena Sports 2', 'Arena Sports 1', 'Zebra TV']);
    expect(find.text('Removed Velocity Motors from favorites'), findsOneWidget);

    await tester.tap(find.text('Undo'));
    await settle(tester);
    expect(rows(tester), [
      'Arena Sports 2',
      'Velocity Motors',
      'Arena Sports 1',
      'Zebra TV',
    ]);
    await finish(tester);
  });

  testWidgets("a group's header: ← folds it, → unfolds it, its menu moves "
      'and deletes it', (tester) async {
    await open(tester);
    final header = find.ancestor(
      of: find.text('MOTORS'),
      matching: find.byType(FocusableSurface),
    );
    tester.widget<FocusableSurface>(header).focusNode!.requestFocus();
    await tester.pump();

    await tester.sendKeyEvent(LogicalKeyboardKey.arrowLeft);
    await settle(tester);
    expect(rows(tester), ['Arena Sports 1', 'Zebra TV']);
    await tester.sendKeyEvent(LogicalKeyboardKey.arrowRight);
    await settle(tester);
    expect(rows(tester), hasLength(4));

    await tester.sendKeyEvent(LogicalKeyboardKey.contextMenu);
    await settle(tester);
    expect(find.text('Move up'), findsOneWidget);
    await tester.tap(find.text('Delete group'));
    await settle(tester);
    expect(find.text('MOTORS'), findsNothing);
    expect(find.text('UNGROUPED'), findsNothing, reason: 'no group left');
    // Its channels stayed favorites, after the ones in no group.
    expect(rows(tester), [
      'Arena Sports 1',
      'Zebra TV',
      'Arena Sports 2',
      'Velocity Motors',
    ]);
    await finish(tester);
  });

  testWidgets('New group asks for a name and adds the group, empty', (
    tester,
  ) async {
    await open(tester, groups: false);
    expect(find.text('UNGROUPED'), findsNothing);

    await tester.tap(find.text('New group'));
    await settle(tester);
    await tester.enterText(
      find.descendant(
        of: find.byType(AppDialog),
        matching: find.byType(EditableText),
      ),
      'Kids',
    );
    await tester.tap(find.text('Create'));
    await settle(tester);

    expect(find.text('KIDS'), findsOneWidget);
    expect(find.text('UNGROUPED'), findsOneWidget);
    await finish(tester);
  });

  testWidgets('Enter plays a channel full screen, zapping through the '
      'favorites', (tester) async {
    await open(tester);
    await focusRow(tester, 'Arena Sports 1');

    await tester.sendKeyEvent(LogicalKeyboardKey.enter);
    await settle(tester);
    expect(app.location, '/player');
    expect(live.rig.coordinator.current?.remoteKey, '201');
    await finish(tester);
  });

  testWidgets('the Movies tab: the poster grid, or how to add one', (
    tester,
  ) async {
    await open(tester);
    await tester.tap(find.text('Movies'));
    await settle(tester);
    expect(find.text('No favorite movies yet'), findsOneWidget);
    expect(find.text('Open Movies'), findsOneWidget);
    await finish(tester);
  });
}
