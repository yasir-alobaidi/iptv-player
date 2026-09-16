import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:iptv_player/app/destinations.dart';
import 'package:iptv_player/design/components.dart';

import 'app_harness.dart';

/// The label of whatever has keyboard focus, so a test can follow the
/// focus the way a user follows the focus ring.
String? _focusedLabel(WidgetTester tester) {
  final node = FocusManager.instance.primaryFocus;
  if (node?.context == null) return null;
  final surface = node!.context!
      .findAncestorWidgetOfExactType<FocusableSurface>();
  return surface?.semanticLabel;
}

Future<void> _tab(WidgetTester tester, {bool shift = false}) async {
  if (shift) await tester.sendKeyDownEvent(LogicalKeyboardKey.shift);
  await tester.sendKeyEvent(LogicalKeyboardKey.tab);
  if (shift) await tester.sendKeyUpEvent(LogicalKeyboardKey.shift);
  await settleApp(tester);
}

Future<void> _arrow(WidgetTester tester, LogicalKeyboardKey key) async {
  await tester.sendKeyEvent(key);
  await settleApp(tester);
}

/// Tabs until [label] has focus, or gives up. Returns the number of
/// stops it took, so a test can show how far away the control was.
Future<int> _tabTo(WidgetTester tester, String label, {int limit = 20}) async {
  for (var stop = 1; stop <= limit; stop++) {
    await _tab(tester);
    if (_focusedLabel(tester) == label) return stop;
  }
  return -1;
}

void main() {
  testWidgets('Tab walks out of the rail and into the rest of the shell', (
    tester,
  ) async {
    await pumpApp(tester);

    // Every rail item, the toggle and Settings, then the top bar: the
    // pane must not trap Tab (the bug that made FocusPane a traversal
    // group rather than a scope).
    final stopsToSource = await _tabTo(tester, 'Source: No source');

    expect(stopsToSource, greaterThan(0), reason: 'focus never left the rail');
  });

  testWidgets('Enter on a rail item opens that destination', (tester) async {
    final app = await pumpApp(tester);

    await _tabTo(tester, AppDestination.guide.label);
    expect(_focusedLabel(tester), AppDestination.guide.label);

    await tester.sendKeyEvent(LogicalKeyboardKey.enter);
    await settleApp(tester);

    expect(app.location, AppDestination.guide.path);
  });

  testWidgets('Space activates too', (tester) async {
    final app = await pumpApp(tester);

    await _tabTo(tester, AppDestination.movies.label);
    await tester.sendKeyEvent(LogicalKeyboardKey.space);
    await settleApp(tester);

    expect(app.location, AppDestination.movies.path);
  });

  testWidgets('the focused rail item draws the focus ring', (tester) async {
    await pumpApp(tester);

    await _tabTo(tester, AppDestination.home.label);

    final painters = tester
        .widgetList<CustomPaint>(
          find.descendant(
            of: findByLabel(AppDestination.home.label),
            matching: find.byType(CustomPaint),
          ),
        )
        .map((paint) => paint.foregroundPainter)
        .whereType<FocusRingPainter>();

    expect(painters, isNotEmpty, reason: 'hard rule 5: the focus is visible');
  });

  testWidgets('arrows move down the rail', (tester) async {
    await pumpApp(tester);

    await _tabTo(tester, AppDestination.home.label);
    await _arrow(tester, LogicalKeyboardKey.arrowDown);

    expect(_focusedLabel(tester), AppDestination.liveTv.label);

    await _arrow(tester, LogicalKeyboardKey.arrowUp);

    expect(_focusedLabel(tester), AppDestination.home.label);
  });

  testWidgets('Right leaves the rail for the screen, Left comes back', (
    tester,
  ) async {
    await pumpApp(tester);

    await _tabTo(tester, AppDestination.liveTv.label);
    await _arrow(tester, LogicalKeyboardKey.arrowRight);

    expect(
      _focusedLabel(tester),
      isNot(AppDestination.liveTv.label),
      reason: 'focus should be on the screen now',
    );
    expect(find.byType(AppButton), findsWidgets);

    await _arrow(tester, LogicalKeyboardKey.arrowLeft);

    expect(
      _focusedLabel(tester),
      AppDestination.liveTv.label,
      reason: 'the rail remembers the item the user left from',
    );
  });

  testWidgets('a disabled control is not a stop in the tab order', (
    tester,
  ) async {
    await pumpApp(tester);

    // The cast button is disabled until Phase 7.
    final stops = await _tabTo(tester, 'Cast');

    expect(stops, -1, reason: 'a disabled button must not take focus');
  });
}
