import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:iptv_player/app/destinations.dart';
import 'package:iptv_player/app/shell/shell_state.dart';
import 'package:iptv_player/design/components.dart';

import 'app_harness.dart';

/// The search field's own default hint is the only name it has, so the
/// walk asks the component for it instead of copying the string.
final String _searchLabel = const SearchField().hint;

/// The placeholder screens' one action (Phase 2 replaces it), which is
/// where Tab lands once it has left the shell's chrome.
const _screenActionLabel = 'Add a source';

/// The label of whatever has keyboard focus, so a test can follow the
/// focus the way a user follows the focus ring.
String? _focusedLabel(WidgetTester tester) {
  final node = FocusManager.instance.primaryFocus;
  if (node?.context == null) return null;
  final surface = node!.context!
      .findAncestorWidgetOfExactType<FocusableSurface>();
  return surface?.semanticLabel;
}

/// True while the design system's ring is painted around the control
/// labelled [label] — the visible half of hard rule 5.
bool _hasFocusRing(WidgetTester tester, String label) => tester
    .widgetList<CustomPaint>(
      find.descendant(
        of: findByLabel(label),
        matching: find.byType(CustomPaint),
      ),
    )
    .map((paint) => paint.foregroundPainter)
    .whereType<FocusRingPainter>()
    .isNotEmpty;

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

Future<void> _pressCtrl(WidgetTester tester, LogicalKeyboardKey key) async {
  await tester.sendKeyDownEvent(LogicalKeyboardKey.control);
  await tester.sendKeyEvent(key);
  await tester.sendKeyUpEvent(LogicalKeyboardKey.control);
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

    expect(
      _hasFocusRing(tester, AppDestination.home.label),
      isTrue,
      reason: 'hard rule 5: the focus is visible',
    );
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

    // The cast button is disabled until Phase 7. A disabled icon button
    // still carries a label — its tooltip, which explains why it is
    // dimmed — so the walk has to be checked against that label rather
    // than against "Cast".
    final cast = tester.widget<AppIconButton>(
      find.byWidgetPredicate(
        (widget) => widget is AppIconButton && widget.icon == AppIcons.cast,
      ),
    );
    expect(cast.onPressed, isNull, reason: 'casting arrives in Phase 7');

    final stops = await _tabTo(tester, cast.tooltip);

    expect(stops, -1, reason: 'a disabled button must not take focus');
  });

  testWidgets('Tab walks the top bar in the order docs/05 draws it', (
    tester,
  ) async {
    // Every slot filled, so the walk sees the controls a later phase
    // will actually show; the sync slot is text and never a stop.
    await pumpApp(
      tester,
      overrides: [
        shellSourceProvider.overrideWithValue(
          const ShellSource(name: 'Home provider', connected: true),
        ),
        shellSyncStatusProvider.overrideWithValue(
          const ShellSyncStatus(message: 'Guide updated 12 min ago'),
        ),
        shellDownloadsProvider.overrideWithValue(
          const ShellDownloads(active: 2, progress: 0.34),
        ),
      ],
    );

    expect(
      await _tabTo(tester, AppDestination.settings.label),
      greaterThan(0),
      reason: 'Settings is the rail stop the top bar follows',
    );

    final topBar = [
      'Source: Home provider',
      _searchLabel,
      // Composed by the download indicator from the slot above.
      '2 downloads, 34 per cent',
    ];

    for (final label in topBar) {
      await _tab(tester);

      expect(_focusedLabel(tester), label, reason: 'the top bar in order');
      expect(
        _hasFocusRing(tester, label),
        isTrue,
        reason: 'hard rule 5: $label shows the focus',
      );
    }

    await _tab(tester);

    expect(
      topBar,
      isNot(contains(_focusedLabel(tester))),
      reason: 'the top bar hands Tab on to the screen',
    );
  });

  testWidgets('arrows walk the top bar and cross at its edges', (tester) async {
    await pumpApp(tester);

    await _tabTo(tester, 'Source: No source');
    await _arrow(tester, LogicalKeyboardKey.arrowRight);

    expect(_focusedLabel(tester), _searchLabel);
    expect(
      _hasFocusRing(tester, _searchLabel),
      isTrue,
      reason: 'hard rule 5: the focus is visible in the top bar too',
    );

    // Right has nowhere further to go: the cast button is disabled, so
    // the search field is the top bar's last stop.
    await _arrow(tester, LogicalKeyboardKey.arrowRight);

    expect(_focusedLabel(tester), _searchLabel);

    await _arrow(tester, LogicalKeyboardKey.arrowLeft);

    expect(_focusedLabel(tester), 'Source: No source');

    // Left at the top bar's left edge crosses into the rail (docs/05:
    // Left/Right move between panes).
    await _arrow(tester, LogicalKeyboardKey.arrowLeft);

    expect(
      AppDestination.values.map((destination) => destination.label),
      contains(_focusedLabel(tester)),
      reason: 'Left at the edge lands on a rail item',
    );
  });

  testWidgets('every stop from the rail to the screen shows the focus ring', (
    tester,
  ) async {
    await pumpApp(tester);

    await _tabTo(tester, AppDestination.home.label);

    // One pass over the whole shell: rail, top bar, screen. Hard rule 5
    // is only kept if the ring is on every one of these stops, not just
    // on the rail's.
    final walk = <String>[];
    for (var stop = 1; stop <= 20; stop++) {
      final label = _focusedLabel(tester);

      expect(label, isNotNull, reason: 'stop $stop has no labelled control');
      expect(
        _hasFocusRing(tester, label!),
        isTrue,
        reason: 'hard rule 5: $label shows the focus',
      );

      walk.add(label);
      if (label == _screenActionLabel) break;
      await _tab(tester);
    }

    expect(
      walk,
      containsAllInOrder([
        ...AppDestination.primary.map((destination) => destination.label),
        'Expand menu',
        AppDestination.settings.label,
        'Source: No source',
        _searchLabel,
        _screenActionLabel,
      ]),
      reason: 'the rail, then the top bar, then the screen',
    );
  });

  testWidgets('Shift+Tab walks back out of the top bar', (tester) async {
    await pumpApp(tester);

    await _tabTo(tester, _searchLabel);

    // The forward order reversed: the search field, the source chip,
    // then back into the rail at its bottom.
    for (final label in [
      'Source: No source',
      AppDestination.settings.label,
      'Expand menu',
      AppDestination.library.label,
    ]) {
      await _tab(tester, shift: true);

      expect(_focusedLabel(tester), label, reason: 'Shift+Tab reverses');
      expect(
        _hasFocusRing(tester, label),
        isTrue,
        reason: 'hard rule 5: $label shows the focus',
      );
    }
  });

  testWidgets('Esc on a top bar control leaves focus and route alone', (
    tester,
  ) async {
    final app = await pumpApp(tester);

    await _tabTo(tester, 'Source: No source');
    await tester.sendKeyEvent(LogicalKeyboardKey.escape);
    await settleApp(tester);

    // Nothing is open, so Esc has nothing to close; it must not drop the
    // user's place in the top bar either (docs/05: Esc is back/close).
    expect(_focusedLabel(tester), 'Source: No source');
    expect(_hasFocusRing(tester, 'Source: No source'), isTrue);
    expect(app.location, AppDestination.home.path);
  });

  testWidgets('a destination change leaves focus inside the new screen', (
    tester,
  ) async {
    final app = await pumpApp(tester);

    await _tabTo(tester, 'Source: No source');
    await _pressCtrl(tester, LogicalKeyboardKey.digit3);
    // The branch switch moves focus one frame after the route changes,
    // so the ring's fade starts in the frame after that: a second settle
    // is what makes this test independent of that ordering.
    await settleApp(tester);

    expect(app.location, AppDestination.guide.path);
    expect(
      _hasFocusRing(tester, 'Source: No source'),
      isFalse,
      reason: 'no stale ring on the control the jump left behind',
    );

    await _tab(tester);

    expect(
      _focusedLabel(tester),
      _screenActionLabel,
      reason: 'Tab continues in the destination the shortcut opened',
    );
    expect(
      find.descendant(
        of: find.byWidgetPredicate(
          (widget) => widget is FocusPane && widget.debugLabel == 'content',
        ),
        matching: findByLabel(_screenActionLabel),
      ),
      findsOneWidget,
      reason: 'that stop is in the screen, not in the shell chrome',
    );
    expect(_hasFocusRing(tester, _screenActionLabel), isTrue);
  });
}
