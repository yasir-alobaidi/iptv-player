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

    group('tabStop', () {
      Widget screen() => Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          AppButton(label: 'above', onPressed: () {}),
          FocusPane(debugLabel: 'list', tabStop: true, child: _buttons('i', 6)),
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              AppButton(label: 'back', onPressed: () {}),
              AppButton(label: 'finish', onPressed: () {}),
            ],
          ),
        ],
      );

      Future<void> press(
        WidgetTester tester,
        LogicalKeyboardKey key, {
        bool shift = false,
      }) async {
        if (shift) await tester.sendKeyDownEvent(LogicalKeyboardKey.shiftLeft);
        await tester.sendKeyEvent(key);
        if (shift) await tester.sendKeyUpEvent(LogicalKeyboardKey.shiftLeft);
        await tester.pumpAndSettle();
      }

      String? label() => FocusManager.instance.primaryFocus?.context
          ?.findAncestorWidgetOfExactType<AppButton>()
          ?.label;

      testWidgets('Tab enters it once, arrows move inside, Tab leaves it for '
          'the next control below', (tester) async {
        await pumpDesign(tester, screen());
        await tester.pumpAndSettle();

        await press(tester, LogicalKeyboardKey.tab);
        expect(label(), 'above');
        await press(tester, LogicalKeyboardKey.tab);
        expect(label(), 'i0');
        await press(tester, LogicalKeyboardKey.arrowDown);
        await press(tester, LogicalKeyboardKey.arrowDown);
        expect(label(), 'i2');
        await press(tester, LogicalKeyboardKey.tab);
        expect(label(), 'back');
        await press(tester, LogicalKeyboardKey.tab);
        expect(label(), 'finish');
      });

      testWidgets('Shift+Tab leaves it for the control above', (tester) async {
        await pumpDesign(tester, screen());
        await tester.pumpAndSettle();
        await press(tester, LogicalKeyboardKey.tab);
        await press(tester, LogicalKeyboardKey.tab);
        await press(tester, LogicalKeyboardKey.arrowDown);
        expect(label(), 'i1');

        await press(tester, LogicalKeyboardKey.tab, shift: true);

        expect(label(), 'above');
      });

      testWidgets('with nothing below, Tab wraps to the top', (tester) async {
        await pumpDesign(
          tester,
          Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              AppButton(label: 'above', onPressed: () {}),
              FocusPane(tabStop: true, child: _buttons('i', 3)),
            ],
          ),
        );
        await tester.pumpAndSettle();
        await press(tester, LogicalKeyboardKey.tab);
        await press(tester, LogicalKeyboardKey.tab);
        expect(label(), 'i0');

        await press(tester, LogicalKeyboardKey.tab);

        expect(label(), 'above');
      });

      testWidgets('Tab comes back into it where it was left, from either '
          'side', (tester) async {
        await pumpDesign(tester, screen());
        await tester.pumpAndSettle();
        await press(tester, LogicalKeyboardKey.tab);
        await press(tester, LogicalKeyboardKey.tab);
        await press(tester, LogicalKeyboardKey.arrowDown);
        await press(tester, LogicalKeyboardKey.arrowDown);
        await press(tester, LogicalKeyboardKey.arrowDown);
        expect(label(), 'i3');

        // Out below and back: on i3, not on the row nearest "back".
        await press(tester, LogicalKeyboardKey.tab);
        expect(label(), 'back');
        await press(tester, LogicalKeyboardKey.tab, shift: true);
        expect(label(), 'i3');

        // Out above and back: on i3, not on the first row.
        await press(tester, LogicalKeyboardKey.tab, shift: true);
        expect(label(), 'above');
        await press(tester, LogicalKeyboardKey.tab);
        expect(label(), 'i3');
      });

      testWidgets('Shift+Tab into one never entered lands on its first '
          'item, not its last', (tester) async {
        await pumpDesign(tester, screen());
        await tester.pumpAndSettle();
        Focus.of(tester.element(find.text('back'))).requestFocus();
        await tester.pumpAndSettle();

        await press(tester, LogicalKeyboardKey.tab, shift: true);

        expect(label(), 'i0');
      });

      testWidgets('a remembered item that has gone is not asked for: Tab '
          'lands on the first', (tester) async {
        Widget list(int rows) => Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            AppButton(label: 'above', onPressed: () {}),
            FocusPane(tabStop: true, child: _buttons('i', rows)),
            AppButton(label: 'back', onPressed: () {}),
          ],
        );
        await pumpDesign(tester, list(6));
        await tester.pumpAndSettle();
        await press(tester, LogicalKeyboardKey.tab);
        await press(tester, LogicalKeyboardKey.tab);
        for (var i = 0; i < 4; i++) {
          await press(tester, LogicalKeyboardKey.arrowDown);
        }
        expect(label(), 'i4');
        await press(tester, LogicalKeyboardKey.tab);
        expect(label(), 'back');

        // The list is shorter now: i4 is no more.
        await pumpDesign(tester, list(3));
        await tester.pumpAndSettle();
        await press(tester, LogicalKeyboardKey.tab, shift: true);

        expect(tester.takeException(), isNull);
        expect(label(), 'i0');
      });

      testWidgets('a click on an item is that item, whatever was '
          'remembered', (tester) async {
        await pumpDesign(tester, screen());
        await tester.pumpAndSettle();
        await press(tester, LogicalKeyboardKey.tab);
        await press(tester, LogicalKeyboardKey.tab);
        await press(tester, LogicalKeyboardKey.tab);
        expect(label(), 'back');

        Focus.of(tester.element(find.text('i4'))).requestFocus();
        await tester.pumpAndSettle();

        expect(label(), 'i4');
      });

      testWidgets('a control beside it is not passed: Tab goes round in the '
          "screen's order, the pane one stop in it", (tester) async {
        // A details page: actions at the left, a list at the right, the
        // way back above both.
        await pumpDesign(
          tester,
          SizedBox(
            width: 900,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                AppButton(label: 'back', onPressed: () {}),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    AppButton(label: 'play', onPressed: () {}),
                    AppButton(label: 'cast', onPressed: () {}),
                    const Spacer(),
                    FocusPane(tabStop: true, child: _buttons('e', 5)),
                  ],
                ),
              ],
            ),
          ),
        );
        await tester.pumpAndSettle();

        final walk = <String?>[];
        for (var i = 0; i < 9; i++) {
          await press(tester, LogicalKeyboardKey.tab);
          walk.add(label());
        }
        expect(walk, [
          'back', 'play', 'cast', 'e0', //
          'back', 'play', 'cast', 'e0', 'back',
        ]);

        final back = <String?>[];
        for (var i = 0; i < 4; i++) {
          await press(tester, LogicalKeyboardKey.tab, shift: true);
          back.add(label());
        }
        expect(back, ['e0', 'cast', 'play', 'back']);
      });
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
