import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:iptv_player/app/destinations.dart';
import 'package:iptv_player/app/shell/shortcut_list.dart';
import 'package:iptv_player/app/shortcut_table.dart';
import 'package:iptv_player/design/components.dart';
import 'package:iptv_player/features/settings/presentation/shortcuts_section.dart';
import 'package:iptv_player/features/sources/presentation/source_shell_slots.dart';

import '../../../app/app_harness.dart';
import '../../../design/design_harness.dart';
import '../../onboarding/onboarding_fakes.dart';

void main() {
  // The list as the page shows it by default: no Guide keys while the
  // Guide is switched off (ADR-031).
  final shortcutTable = shortcutTableFor(guide: false);

  Future<void> open(
    WidgetTester tester, {
    Size size = const Size(1440, 900),
  }) async {
    final fakes = OnboardingFakes()..sources.seed();
    await pumpApp(
      tester,
      initialLocation: AppDestination.settings.path,
      size: size,
      overrides: [...fakes.overrides, ...sourceShellOverrides],
    );
    await tester.tap(find.text('Keyboard shortcuts').first);
    await settleApp(tester);
  }

  testWidgets('the page is the list F1 shows, and says so', (tester) async {
    await open(tester);

    expect(find.byType(ShortcutsSection), findsOneWidget);
    expect(find.text('F1 shows this list anywhere.'), findsOneWidget);
    expect(find.byType(ShortcutList), findsOneWidget);
    for (final group in shortcutTable) {
      expect(find.text(group.title.toUpperCase()), findsOneWidget);
    }
    expect(find.text('THE GUIDE'), findsNothing);
  });

  testWidgets('in a wide window the groups sit in two columns; in the '
      'smallest window, in one', (tester) async {
    await open(tester);
    final first = tester.getTopLeft(
      find.text(shortcutTable.first.title.toUpperCase()),
    );
    final last = tester.getTopLeft(
      find.text(shortcutTable.last.title.toUpperCase()),
    );
    expect(last.dx, greaterThan(first.dx + 200));

    await open(tester, size: const Size(1024, 640));
    expect(tester.takeException(), isNull);
    final columns = {
      for (final group in shortcutTable)
        tester.getTopLeft(find.text(group.title.toUpperCase())).dx,
    };
    expect(columns, hasLength(1));
  });

  testWidgets('the list is one Tab stop with the focus ring, and the '
      'keyboard scrolls it to its last row', (tester) async {
    await open(tester, size: const Size(1024, 640));
    Focus.of(tester.element(find.text('Keyboard shortcuts').first))
        .requestFocus();
    await tester.pump();

    // Out of Settings' list: the next stops are the rest of the list,
    // then the page.
    final pane = find.byType(ScrollPane);
    for (var i = 0; i < 6; i++) {
      await tester.sendKeyEvent(LogicalKeyboardKey.tab);
      await tester.pump();
      final focused = FocusManager.instance.primaryFocus!.context!;
      if (focused.findAncestorWidgetOfExactType<ScrollPane>() != null) break;
    }
    await tester.pump(const Duration(milliseconds: 200));
    expect(
      FocusManager.instance.primaryFocus!.context!
          .findAncestorWidgetOfExactType<ScrollPane>(),
      isNotNull,
    );
    expect(hasFocusRing(tester, of: pane), isTrue);

    await tester.sendKeyEvent(LogicalKeyboardKey.end);
    await tester.pump();

    final lastRow = find.text(shortcutTable.last.entries.last.action);
    expect(tester.getRect(lastRow).bottom, lessThanOrEqualTo(640));
  });
}
