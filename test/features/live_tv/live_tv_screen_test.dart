import 'package:drift/drift.dart' show Value;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:iptv_player/app/destinations.dart';
import 'package:iptv_player/core/result.dart';
import 'package:iptv_player/data/db/app_database.dart' show ChannelsCompanion;
import 'package:iptv_player/design/components.dart';
import 'package:iptv_player/features/favorites/data/db_favorites_repository.dart';
import 'package:iptv_player/features/live_tv/data/db_channel_repository.dart';
import 'package:iptv_player/features/live_tv/domain/channels.dart';
import 'package:iptv_player/features/live_tv/domain/now_next.dart';
import 'package:iptv_player/features/playback/domain/playback_state.dart';

import '../../app/app_harness.dart';
import 'live_tv_fakes.dart';

/// The rig of the test running, so the test's end can stop its timers.
LiveTvFakes? _live;

void main() {
  tearDown(() => _live = null);

  Future<LiveTvFakes> pump(WidgetTester tester, {bool seed = true}) async {
    final live = LiveTvFakes();
    addTearDown(() => tester.runAsync(live.db.close));
    if (seed) await tester.runAsync(live.seed);
    await pumpApp(
      tester,
      initialLocation: AppDestination.liveTv.path,
      overrides: live.overrides,
    );
    _live = live;
    await _settle(tester);
    return live;
  }

  testWidgets('no source: says so and offers to add one', (tester) async {
    await pump(tester, seed: false);

    expect(find.text('No channels yet'), findsOneWidget);
    expect(find.text('Add a source'), findsOneWidget);
    await _finish(tester);
  });

  testWidgets('categories with counts; All leaves out hidden categories', (
    tester,
  ) async {
    await pump(tester);

    expect(find.text('CATEGORIES'), findsOneWidget);
    expect(find.text('Sports'), findsOneWidget);
    expect(find.text('News'), findsNothing, reason: 'hidden');
    expect(find.text('1 category hidden'), findsOneWidget);
    expect(find.text('Uncategorized'), findsOneWidget);
    expect(find.text('4 channels'), findsOneWidget);
    expect(find.text('Arena Sports 1'), findsWidgets);
    expect(find.text('World News'), findsNothing);
    await _finish(tester);
  });

  testWidgets('choosing a category shows its channels', (tester) async {
    await pump(tester);

    await tester.tap(find.text('Uncategorized'));
    await _settle(tester);

    expect(find.text('1 channel'), findsOneWidget);
    expect(find.text('Zebra TV'), findsWidgets);
    expect(
      find.descendant(
        of: find.byType(ChannelRow),
        matching: find.text('Arena Sports 1'),
      ),
      findsNothing,
    );
    // The new list's first row took the focus once it loaded.
    expect(focusedLabel(), 'Zebra TV');
    await _finish(tester);
  });

  testWidgets('a click plays at once; moving with the arrows previews '
      'after a moment, not per row', (tester) async {
    final live = await pump(tester);

    await tester.tap(find.text('Arena Sports 1').first);
    await _settle(tester);
    expect(live.rig.engine.opened.single.url, contains('201'));
    expect(live.guide.asked, contains('201'));

    await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
    await tester.pump(const Duration(milliseconds: 100));
    await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
    await tester.pump(const Duration(milliseconds: 100));
    expect(live.rig.engine.opened, hasLength(1), reason: 'not per row');

    await tester.pump(const Duration(milliseconds: 400));
    await _settle(tester);
    expect(live.rig.engine.opened, hasLength(2));
    expect(live.rig.engine.opened.last.url, contains('203'));
    await _finish(tester);
  });

  testWidgets('arrows move through the channels; F adds a favorite', (
    tester,
  ) async {
    await pump(tester);
    await tester.tap(find.text('Arena Sports 1').first);
    await _settle(tester);

    expect(focusedLabel(), 'Arena Sports 1');
    await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
    await _settle(tester);
    expect(focusedLabel(), 'Arena Sports 2');

    await tester.sendKeyEvent(LogicalKeyboardKey.keyF);
    await _settle(tester);
    await tester.tap(find.text('Favorites').first);
    await _settle(tester);
    expect(find.text('1 channel'), findsOneWidget);
    expect(find.text('Arena Sports 2'), findsWidgets);
    await _finish(tester);
  });

  testWidgets('F shows the star on the row at once, and F again takes it '
      'off', (tester) async {
    await pump(tester);
    await tester.tap(find.text('Arena Sports 1').first);
    await _settle(tester);
    bool starred() => tester
        .widget<ChannelRow>(find.widgetWithText(ChannelRow, 'Arena Sports 1'))
        .isFavorite;

    await tester.sendKeyEvent(LogicalKeyboardKey.keyF);
    await _settle(tester);
    expect(starred(), isTrue);

    await tester.sendKeyEvent(LogicalKeyboardKey.keyF);
    await _settle(tester);
    expect(starred(), isFalse);
    await _finish(tester);
  });

  testWidgets('rows show the cleaned name with its badge, never the '
      "provider's tags", (tester) async {
    await pump(tester);

    ChannelRow row(String name) =>
        tester.widget<ChannelRow>(find.widgetWithText(ChannelRow, name));
    expect(row('Arena Sports 1').quality, 'FHD');
    expect(row('Arena Sports 2').quality, 'HD');
    expect(row('Velocity Motors').quality, 'FHD');
    expect(row('Zebra TV').quality, isNull);
    expect(
      find.descendant(
        of: find.widgetWithText(ChannelRow, 'Arena Sports 1'),
        matching: find.widgetWithText(ChannelBadge, 'FHD'),
      ),
      findsOneWidget,
    );
    expect(find.textContaining('UK'), findsNothing);
    await _finish(tester);
  });

  testWidgets("Rename… shows the provider's name, keeps the cleaned one "
      "unless changed, and Use provider's name goes back to it", (
    tester,
  ) async {
    final live = await pump(tester);
    Future<void> openRename() async {
      await tester.tap(find.text('Arena Sports 1').first);
      await _settle(tester);
      await tester.sendKeyEvent(LogicalKeyboardKey.contextMenu);
      await _settle(tester);
      await tester.tap(find.text('Rename…'));
      await _settle(tester);
    }

    Future<String?> stored() async => (await tester.runAsync(
      () => live.db.channelsDao.byRemoteKey('src-1', '201'),
    ))!.displayName;

    await openRename();
    expect(find.text('Rename channel'), findsOneWidget);
    expect(find.widgetWithText(AppTextField, 'Arena Sports 1'), findsOneWidget);
    expect(
      find.text("Provider's name: UK: Arena Sports 1 FHD"),
      findsOneWidget,
    );
    expect(find.text("Use provider's name"), findsNothing);
    // Saving the name as it is pins nothing.
    await tester.tap(find.text('Save'));
    await _settle(tester);
    expect(await stored(), isNull);

    await openRename();
    await tester.enterText(
      find.descendant(
        of: find.byType(AppDialog),
        matching: find.byType(EditableText),
      ),
      'Arena Main',
    );
    await tester.tap(find.text('Save'));
    await _settle(tester);
    expect(await stored(), 'Arena Main');
    expect(find.text('Arena Main'), findsWidgets);
    expect(
      tester
          .widget<ChannelRow>(find.widgetWithText(ChannelRow, 'Arena Main'))
          .quality,
      'FHD',
      reason: "the badge is the provider's, whatever the name",
    );

    await tester.tap(find.text('Arena Main').first);
    await _settle(tester);
    await tester.sendKeyEvent(LogicalKeyboardKey.contextMenu);
    await _settle(tester);
    await tester.tap(find.text('Rename…'));
    await _settle(tester);
    await tester.tap(find.text("Use provider's name"));
    await _settle(tester);
    expect(await stored(), isNull);
    expect(find.text('Arena Sports 1'), findsWidgets);
    await _finish(tester);
  });

  testWidgets('favorite groups show under Favorites, each a list of its '
      'own in your order', (tester) async {
    final live = LiveTvFakes();
    addTearDown(() => tester.runAsync(live.db.close));
    await tester.runAsync(() async {
      await live.seed();
      final channels = DbChannelRepository(live.db);
      final favorites = DbFavoritesRepository(live.db);
      Future<ChannelItem> channel(String key) async =>
          (await channels.byRemoteKey('src-1', key)).valueOrNull!;
      for (final key in ['201', '202', '203']) {
        await channels.setFavorite(await channel(key), on: true);
      }
      final motors = (await favorites.createGroup(
        'src-1',
        'Motors',
      )).valueOrNull!;
      await favorites.moveChannel(
        await channel('203'),
        groupId: motors,
        index: 0,
      );
      await favorites.moveChannel(
        await channel('201'),
        groupId: null,
        index: 5,
      );
    });
    await pumpApp(
      tester,
      initialLocation: AppDestination.liveTv.path,
      overrides: live.overrides,
    );
    _live = live;
    await _settle(tester);

    final favorites = tester.getTopLeft(find.text('Favorites').first).dy;
    final motors = tester.getTopLeft(find.text('Motors')).dy;
    final all = tester.getTopLeft(find.text('All channels').first).dy;
    expect(favorites < motors && motors < all, isTrue);

    await tester.tap(find.text('Favorites').first);
    await _settle(tester);
    List<String> rows() => [
      for (final row in tester.widgetList<ChannelRow>(find.byType(ChannelRow)))
        row.name,
    ];
    // The group first, then the favorites in no group, in their order.
    expect(rows(), ['Velocity Motors', 'Arena Sports 2', 'Arena Sports 1']);
    expect(find.text('Order'), findsOneWidget, reason: 'the sort says whose');

    await tester.tap(find.text('Motors'));
    await _settle(tester);
    expect(rows(), ['Velocity Motors']);
    expect(find.text('1 channel'), findsOneWidget);
    await _finish(tester);
  });

  testWidgets('Add to group…: New group… makes one with the channel in it', (
    tester,
  ) async {
    await pump(tester);
    await tester.tap(find.text('Arena Sports 1').first);
    await _settle(tester);
    await tester.sendKeyEvent(LogicalKeyboardKey.contextMenu);
    await _settle(tester);
    await tester.tap(find.text('Add to group…'));
    await _settle(tester);
    await tester.tap(find.text('New group…'));
    await _settle(tester);

    expect(find.text('New group'), findsOneWidget);
    await tester.enterText(
      find.descendant(
        of: find.byType(AppDialog),
        matching: find.byType(EditableText),
      ),
      'Sports',
    );
    await tester.tap(find.text('Create'));
    await _settle(tester);

    expect(find.text('Sports'), findsWidgets);
    final channel = (await tester.runAsync(
      () => DbChannelRepository(_live!.db).byRemoteKey('src-1', '201'),
    ))!.valueOrNull!;
    expect(channel.isFavorite, isTrue);
    expect(channel.favoriteGroupId, isNotNull);
    await _finish(tester);
  });

  testWidgets('scrolling the focused row away with the mouse leaves the '
      'keyboard on a row on screen', (tester) async {
    final live = LiveTvFakes();
    addTearDown(() => tester.runAsync(live.db.close));
    await tester.runAsync(() async {
      await live.seed();
      await live.db.channelsDao.upsertAll([
        for (var i = 0; i < 200; i++)
          ChannelsCompanion.insert(
            sourceId: 'src-1',
            remoteKey: 'x$i',
            name: 'Extra ${i + 1}',
            number: Value(1000 + i),
          ),
      ]);
    });
    await pumpApp(
      tester,
      initialLocation: AppDestination.liveTv.path,
      overrides: live.overrides,
    );
    _live = live;
    await _settle(tester);
    await tester.tap(find.text('Arena Sports 1').first);
    await _settle(tester);
    expect(focusedLabel(), 'Arena Sports 1');

    await tester.drag(find.byType(ListView).last, const Offset(0, -4000));
    await tester.pumpAndSettle();
    await _settle(tester);

    final focused = focusedLabel();
    expect(focused, isNotNull, reason: 'the keyboard is still in the list');
    expect(focused, startsWith('Extra'));
    final row = find.widgetWithText(ChannelRow, focused!);
    expect(tester.getTopLeft(row).dy, greaterThan(0), reason: 'on screen');

    await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
    await _settle(tester);
    expect(focusedLabel(), isNot(focused), reason: '↓ goes on from there');
    await _finish(tester);
  });

  testWidgets('an empty category offers to show hidden channels', (
    tester,
  ) async {
    final live = await pump(tester);
    final zebra = await tester.runAsync(
      () => live.db.channelsDao.byRemoteKey('src-1', '900'),
    );
    await tester.runAsync(
      () => live.db.channelsDao.setHidden(zebra!.id, hidden: true),
    );

    await tester.tap(find.text('Uncategorized'));
    await _settle(tester);

    expect(find.text('No channels in this category.'), findsOneWidget);
    await tester.tap(find.text('Show hidden channels'));
    await _settle(tester);
    expect(find.text('Zebra TV'), findsWidgets);
    await _finish(tester);
  });

  testWidgets("the preview shows what's on now and next", (tester) async {
    final live = await pump(tester);
    final now = live.fakes.now;
    live.guide.byKey['201'] = NowNext(
      now: Programme(
        title: 'Continental Cup · Semi-final',
        start: now.subtract(const Duration(minutes: 30)),
        end: now.add(const Duration(minutes: 38)),
        description: 'Holders Northport face Valencia Azul.',
      ),
      next: Programme(
        title: 'Match of the Week',
        start: now.add(const Duration(minutes: 38)),
        end: now.add(const Duration(minutes: 98)),
      ),
    );

    await tester.tap(find.text('Arena Sports 1').first);
    await _settle(tester);

    expect(find.text('Continental Cup · Semi-final'), findsWidgets);
    expect(find.text('38 min left'), findsOneWidget);
    expect(find.text('Match of the Week'), findsOneWidget);
    expect(find.text('Holders Northport face Valencia Azul.'), findsOneWidget);
    await _finish(tester);
  });

  testWidgets('a failed stream shows the card, with the server answer', (
    tester,
  ) async {
    final live = await pump(tester);
    live.rig.prober.next = PlaybackProblem(
      PlaybackProblemKind.offline,
      failure: NotFoundFailure('stream: HTTP 404', 404),
    );
    await tester.tap(find.text('Arena Sports 1').first);
    await tester.pump(const Duration(milliseconds: 400));
    await _settle(tester);

    live.rig.engine.fail();
    await _settle(tester);

    expect(find.text('This channel is off the air'), findsOneWidget);
    expect(
      find.textContaining('The server answered HTTP 404 (Not Found).'),
      findsOneWidget,
    );
    expect(find.text('Retry'), findsOneWidget);
    expect(find.text('Next channel'), findsOneWidget);
    await _finish(tester);
  });

  testWidgets('leaving Live TV stops playback', (tester) async {
    final live = await pump(tester);
    await tester.tap(find.text('Arena Sports 1').first);
    await tester.pump(const Duration(milliseconds: 400));
    await _settle(tester);
    live.rig.engine.firstFrame();
    await _settle(tester);
    expect(live.rig.coordinator.state, isA<PlaybackPlaying>());

    await tester.sendKeyDownEvent(LogicalKeyboardKey.controlLeft);
    await tester.sendKeyEvent(LogicalKeyboardKey.digit1);
    await tester.sendKeyUpEvent(LogicalKeyboardKey.controlLeft);
    await _settle(tester);

    expect(live.rig.coordinator.state, isA<PlaybackIdle>());
    await _finish(tester);
  });
}

/// Stops playback so no watchdog timer outlives the test.
Future<void> _finish(WidgetTester tester) async {
  // Let a pending preview (350 ms) fire, then stop what it started.
  await tester.pump(const Duration(milliseconds: 400));
  await _live?.rig.coordinator.stop();
  await _settle(tester);
}

Future<void> _settle(WidgetTester tester) async {
  for (var i = 0; i < 5; i++) {
    await tester.runAsync(() => Future<void>.delayed(Duration.zero));
    await tester.pump(const Duration(milliseconds: 50));
  }
}

String? focusedLabel() {
  final context = FocusManager.instance.primaryFocus?.context;
  if (context == null) return null;
  final surface = context.widget is FocusableSurface
      ? context.widget as FocusableSurface
      : context.findAncestorWidgetOfExactType<FocusableSurface>();
  return surface?.semanticLabel;
}
