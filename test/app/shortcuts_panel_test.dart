import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:iptv_player/app/destinations.dart';
import 'package:iptv_player/app/shell/shortcut_list.dart';
import 'package:iptv_player/app/shortcut_table.dart';
import 'package:iptv_player/design/components.dart';
import 'package:iptv_player/features/live_tv/presentation/live_tv_screen.dart';
import 'package:iptv_player/features/playback/presentation/player_screen.dart';
import 'package:iptv_player/features/search/presentation/search_overlay.dart';

import '../features/live_tv/live_tv_fakes.dart';
import 'app_harness.dart';

/// Phase 9 decision 5: F1 shows the shortcuts over whatever is on
/// screen, Esc closes them, and nothing under them stops.
void main() {
  Future<void> press(WidgetTester tester, LogicalKeyboardKey key) async {
    await tester.sendKeyEvent(key);
    await settleApp(tester);
  }

  Finder panel() => find.ancestor(
    of: find.byType(ShortcutList),
    matching: find.byType(AppDialog),
  );

  testWidgets('F1 opens the list over the shell, with every group and the '
      'keys as keycaps; Esc closes it', (tester) async {
    final app = await pumpApp(tester);

    await press(tester, LogicalKeyboardKey.f1);

    expect(panel(), findsOneWidget);
    expect(find.text('Keyboard shortcuts'), findsOneWidget);
    for (final group in shortcutTable) {
      expect(find.text(group.title.toUpperCase()), findsOneWidget);
    }
    // "Search": Ctrl, K, "or", /.
    final search = find.ancestor(
      of: find.text('Search'),
      matching: find.byType(Row),
    );
    expect(
      tester
          .widgetList<Kbd>(
            find.descendant(of: search.first, matching: find.byType(Kbd)),
          )
          .map((key) => key.keys),
      ['Ctrl', 'K', '/'],
    );
    expect(app.location, AppDestination.home.path, reason: 'no navigation');

    await press(tester, LogicalKeyboardKey.escape);

    expect(panel(), findsNothing);
    expect(app.location, AppDestination.home.path);
  });

  testWidgets('the list has the focus when it opens, and the arrows scroll '
      'it', (tester) async {
    await pumpApp(tester, size: const Size(1024, 640));
    await press(tester, LogicalKeyboardKey.f1);
    final scrollable = tester.state<ScrollableState>(
      find.descendant(of: panel(), matching: find.byType(Scrollable)),
    );
    expect(scrollable.position.pixels, 0);

    await press(tester, LogicalKeyboardKey.arrowDown);
    expect(scrollable.position.pixels, ScrollPane.lineStep);

    await press(tester, LogicalKeyboardKey.end);
    expect(scrollable.position.pixels, scrollable.position.maxScrollExtent);
    // The last group is on screen now.
    expect(
      tester.getRect(find.text(shortcutTable.last.entries.last.action)).bottom,
      lessThanOrEqualTo(640),
    );
  });

  testWidgets('a second F1 while it shows does not stack another', (
    tester,
  ) async {
    await pumpApp(tester);

    await press(tester, LogicalKeyboardKey.f1);
    await press(tester, LogicalKeyboardKey.f1);
    expect(panel(), findsOneWidget);

    await press(tester, LogicalKeyboardKey.escape);
    expect(panel(), findsNothing);

    // And it opens again afterwards.
    await press(tester, LogicalKeyboardKey.f1);
    expect(panel(), findsOneWidget);
  });

  testWidgets('F1 works from search, where the keyboard is in a text field', (
    tester,
  ) async {
    await pumpApp(tester);
    await tester.sendKeyDownEvent(LogicalKeyboardKey.control);
    await tester.sendKeyEvent(LogicalKeyboardKey.keyK);
    await tester.sendKeyUpEvent(LogicalKeyboardKey.control);
    await settleApp(tester);
    expect(find.byType(SearchOverlay), findsOneWidget);

    await press(tester, LogicalKeyboardKey.f1);
    expect(panel(), findsOneWidget);

    // Esc closes the list first, and search is still there under it.
    await press(tester, LogicalKeyboardKey.escape);
    expect(panel(), findsNothing);
    expect(find.byType(SearchOverlay), findsOneWidget);
  });

  testWidgets('F1 over the player leaves it playing, takes no player key '
      'while it shows, and Esc closes the list, not the player', (
    tester,
  ) async {
    final live = LiveTvFakes();
    addTearDown(() => tester.runAsync(live.db.close));
    await tester.runAsync(live.seed);
    final app = await pumpApp(
      tester,
      initialLocation: AppDestination.liveTv.path,
      overrides: live.overrides,
    );
    await _settle(tester);
    await tester.tap(find.text('Arena Sports 1').first);
    await _settle(tester);
    await tester.sendKeyEvent(LogicalKeyboardKey.enter);
    await _settle(tester);
    live.rig.engine.firstFrame();
    await _settle(tester);
    expect(app.location, playerRoutePath);
    final opened = live.rig.engine.opened.length;

    await tester.sendKeyEvent(LogicalKeyboardKey.f1);
    await _settle(tester);

    expect(panel(), findsOneWidget);
    expect(find.byType(PlayerScreen), findsOneWidget);
    expect(live.rig.engine.playing, isTrue);

    // ↓ scrolls the list: it must not zap the channel under it.
    await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
    await tester.pump(const Duration(milliseconds: 500));
    await _settle(tester);
    expect(live.rig.engine.opened, hasLength(opened));
    // M is no mute while the list is in front.
    await tester.sendKeyEvent(LogicalKeyboardKey.keyM);
    await _settle(tester);
    expect(live.rig.engine.calls, isNot(contains('muted:true')));

    await tester.sendKeyEvent(LogicalKeyboardKey.escape);
    await _settle(tester);

    expect(panel(), findsNothing);
    expect(app.location, playerRoutePath, reason: 'still in the player');
    expect(live.rig.engine.playing, isTrue);

    // The player has the keyboard back.
    await tester.sendKeyEvent(LogicalKeyboardKey.keyM);
    await _settle(tester);
    expect(live.rig.engine.calls, contains('muted:true'));

    await tester.pump(const Duration(seconds: 4));
    await live.rig.coordinator.stop();
    await _settle(tester);
  });
}

Future<void> _settle(WidgetTester tester) async {
  for (var i = 0; i < 5; i++) {
    await tester.runAsync(() => Future<void>.delayed(Duration.zero));
    await tester.pump(const Duration(milliseconds: 50));
  }
}
