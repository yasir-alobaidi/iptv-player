import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:iptv_player/design/components.dart';

import '../design_harness.dart';

Widget _buttons(String prefix, int count) => Column(
  mainAxisSize: MainAxisSize.min,
  children: [
    for (var i = 0; i < count; i++)
      AppButton(label: '$prefix$i', onPressed: () {}),
  ],
);

void main() {
  group('FocusPane', () {
    testWidgets('Tab leaves the pane instead of cycling inside it', (
      tester,
    ) async {
      // A FocusScope would trap Tab here and strand the user in the
      // first pane; a traversal group must not.
      await pumpDesign(
        tester,
        Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            FocusPane(debugLabel: 'a', child: _buttons('a', 2)),
            FocusPane(debugLabel: 'b', child: _buttons('b', 2)),
          ],
        ),
      );
      await tester.pumpAndSettle();

      final visited = <FocusNode>{};
      for (var press = 0; press < 4; press++) {
        await tester.sendKeyEvent(LogicalKeyboardKey.tab);
        await tester.pumpAndSettle();
        visited.add(FocusManager.instance.primaryFocus!);
      }

      expect(visited.length, 4);
    });

    testWidgets('it remembers the item focus left from', (tester) async {
      final controller = FocusPaneController();
      addTearDown(controller.dispose);

      await pumpDesign(
        tester,
        Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            FocusPane(controller: controller, child: _buttons('a', 2)),
            FocusPane(child: _buttons('b', 2)),
          ],
        ),
      );
      await tester.pumpAndSettle();

      expect(controller.lastFocused, isNull);

      // Walk to the last item of the first pane, then leave it.
      await tester.sendKeyEvent(LogicalKeyboardKey.tab);
      await tester.pumpAndSettle();
      await tester.sendKeyEvent(LogicalKeyboardKey.tab);
      await tester.pumpAndSettle();
      final inside = FocusManager.instance.primaryFocus;
      expect(find.text('a1'), findsOneWidget);

      await tester.sendKeyEvent(LogicalKeyboardKey.tab);
      await tester.pumpAndSettle();
      expect(FocusManager.instance.primaryFocus, isNot(inside));

      expect(controller.focusLast(), isTrue);
      await tester.pumpAndSettle();
      expect(FocusManager.instance.primaryFocus, inside);
    });

    testWidgets('focusLast reports false with nothing to return to', (
      tester,
    ) async {
      final controller = FocusPaneController();
      addTearDown(controller.dispose);

      await pumpDesign(
        tester,
        FocusPane(controller: controller, child: _buttons('a', 2)),
      );
      await tester.pumpAndSettle();

      expect(controller.focusLast(), isFalse);
    });

    testWidgets('focusFirst takes the pane from the top', (tester) async {
      final controller = FocusPaneController();
      addTearDown(controller.dispose);

      await pumpDesign(
        tester,
        FocusPane(controller: controller, child: _buttons('a', 3)),
      );
      await tester.pumpAndSettle();

      expect(controller.focusFirst(), isTrue);
      await tester.pumpAndSettle();

      expect(
        find.descendant(
          of: find.byType(AppButton).first,
          matching: find.byType(Focus),
        ),
        findsWidgets,
      );
      expect(controller.hasFocus, isTrue);
      expect(controller.lastFocused, isNotNull);
    });

    testWidgets('focusPane falls back from last to first', (tester) async {
      final controller = FocusPaneController();
      addTearDown(controller.dispose);

      await pumpDesign(
        tester,
        FocusPane(controller: controller, child: _buttons('a', 2)),
      );
      await tester.pumpAndSettle();

      // Nothing was ever focused here, so this is the fallback path the
      // shell's Left/Right relies on.
      expect(controller.focusLast(), isFalse);
      expect(controller.focusPane(), isTrue);
      await tester.pumpAndSettle();

      final first = FocusManager.instance.primaryFocus;

      FocusManager.instance.primaryFocus!.unfocus();
      await tester.pumpAndSettle();

      expect(controller.focusPane(), isTrue, reason: 'now it remembers');
      await tester.pumpAndSettle();
      expect(FocusManager.instance.primaryFocus, first);
    });

    testWidgets('an empty pane reports that it has nothing to focus', (
      tester,
    ) async {
      final controller = FocusPaneController();
      addTearDown(controller.dispose);

      await pumpDesign(
        tester,
        FocusPane(controller: controller, child: const Text('nothing here')),
      );
      await tester.pumpAndSettle();

      expect(controller.items, isEmpty);
      expect(controller.focusFirst(), isFalse);
      expect(controller.focusPane(), isFalse);
    });
  });
}
