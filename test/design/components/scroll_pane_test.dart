import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:iptv_player/design/components.dart';

import '../../features/onboarding/onboarding_fakes.dart' show focusIsOn;
import '../design_harness.dart';

void main() {
  /// A 300 px pane over 40 lines of 30 px, between two buttons.
  Future<ScrollController> pump(WidgetTester tester) async {
    final controller = ScrollController();
    addTearDown(controller.dispose);
    await pumpDesign(
      tester,
      Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          AppButton(label: 'Above', onPressed: () {}),
          SizedBox(
            width: 400,
            height: 300,
            child: ScrollPane.child(
              semanticLabel: 'Something long',
              controller: controller,
              child: Column(
                children: [
                  for (var i = 0; i < 40; i++)
                    SizedBox(
                      height: 30,
                      // A control inside is no stop of its own.
                      child: i == 3
                          ? AppButton(label: 'Inside', onPressed: () {})
                          : Text('Line $i'),
                    ),
                ],
              ),
            ),
          ),
          AppButton(label: 'Below', onPressed: () {}),
        ],
      ),
    );
    return controller;
  }

  Future<void> press(WidgetTester tester, LogicalKeyboardKey key) async {
    await tester.sendKeyEvent(key);
    await tester.pump();
  }

  bool focusIsIn(WidgetTester tester, Finder finder) =>
      focusIsOn(tester, finder);

  testWidgets('is one Tab stop with the focus ring; nothing inside is', (
    tester,
  ) async {
    await pump(tester);
    final pane = find.byType(ScrollPane);

    await press(tester, LogicalKeyboardKey.tab);
    expect(focusIsIn(tester, find.text('Above')), isTrue);

    await press(tester, LogicalKeyboardKey.tab);
    await tester.pump(const Duration(milliseconds: 200));
    expect(focusIsIn(tester, pane), isTrue);
    // The pane itself, not the button it holds.
    expect(
      FocusManager.instance.primaryFocus!.context!
          .findAncestorWidgetOfExactType<AppButton>(),
      isNull,
    );
    expect(hasFocusRing(tester, of: pane), isTrue);

    await press(tester, LogicalKeyboardKey.tab);
    expect(focusIsIn(tester, find.text('Below')), isTrue);
    await tester.pump(const Duration(milliseconds: 200));
    expect(hasFocusRing(tester, of: pane), isFalse);
  });

  testWidgets('on a desktop a click hides its ring, the focus kept; a key '
      'shows it again', (tester) async {
    final controller = await pump(tester);
    FocusVisibility.install();
    addTearDown(FocusVisibility.uninstall);
    final pane = find.byType(ScrollPane);
    await press(tester, LogicalKeyboardKey.tab);
    await press(tester, LogicalKeyboardKey.tab);
    await tester.pump(const Duration(milliseconds: 200));
    expect(hasFocusRing(tester, of: pane), isTrue);

    await tester.tap(find.text('Line 0'), kind: PointerDeviceKind.mouse);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 200));
    expect(focusIsIn(tester, pane), isTrue);
    expect(hasFocusRing(tester, of: pane), isFalse);

    await press(tester, LogicalKeyboardKey.arrowDown);
    await tester.pump(const Duration(milliseconds: 200));
    expect(hasFocusRing(tester, of: pane), isTrue);
    expect(controller.offset, greaterThan(0));
  });

  testWidgets('↓ and ↑ move a line, PageDown and PageUp a boxful, End and '
      'Home to the ends', (tester) async {
    final controller = await pump(tester);
    await press(tester, LogicalKeyboardKey.tab);
    await press(tester, LogicalKeyboardKey.tab);
    final end = controller.position.maxScrollExtent;
    expect(end, 40 * 30 - 300);

    await press(tester, LogicalKeyboardKey.arrowDown);
    expect(controller.offset, ScrollPane.lineStep);
    await press(tester, LogicalKeyboardKey.arrowUp);
    expect(controller.offset, 0);

    await press(tester, LogicalKeyboardKey.pageDown);
    expect(controller.offset, 300 - ScrollPane.pageOverlap);
    await press(tester, LogicalKeyboardKey.pageUp);
    expect(controller.offset, 0);

    await press(tester, LogicalKeyboardKey.end);
    expect(controller.offset, end);
    await press(tester, LogicalKeyboardKey.home);
    expect(controller.offset, 0);
  });

  testWidgets('a held key keeps scrolling, and stops at the end', (
    tester,
  ) async {
    final controller = await pump(tester);
    await press(tester, LogicalKeyboardKey.tab);
    await press(tester, LogicalKeyboardKey.tab);

    await tester.sendKeyDownEvent(LogicalKeyboardKey.arrowDown);
    for (var i = 0; i < 30; i++) {
      await tester.sendKeyRepeatEvent(LogicalKeyboardKey.arrowDown);
    }
    await tester.sendKeyUpEvent(LogicalKeyboardKey.arrowDown);
    await tester.pump();

    expect(controller.offset, controller.position.maxScrollExtent);
  });

  testWidgets('at an end the arrow is not taken: the focus leaves the way '
      'it came, so the pane is no trap', (tester) async {
    final controller = await pump(tester);
    await press(tester, LogicalKeyboardKey.tab);
    await press(tester, LogicalKeyboardKey.tab);
    expect(controller.offset, 0);

    // At the top, ↑ goes to what is above.
    await press(tester, LogicalKeyboardKey.arrowUp);
    expect(focusIsIn(tester, find.text('Above')), isTrue);

    await press(tester, LogicalKeyboardKey.arrowDown);
    expect(focusIsIn(tester, find.byType(ScrollPane)), isTrue);
    await press(tester, LogicalKeyboardKey.end);
    // At the bottom, ↓ goes to what is below.
    await press(tester, LogicalKeyboardKey.arrowDown);
    expect(focusIsIn(tester, find.text('Below')), isTrue);
  });

  testWidgets('a line is taller at larger text', (tester) async {
    final controller = ScrollController();
    addTearDown(controller.dispose);
    await pumpDesign(
      tester,
      SizedBox(
        width: 400,
        height: 300,
        child: ScrollPane.child(
          semanticLabel: 'Something long',
          controller: controller,
          autofocus: true,
          child: const SizedBox(height: 2000),
        ),
      ),
      textScale: 1.3,
    );
    await tester.pump();

    await press(tester, LogicalKeyboardKey.arrowDown);

    expect(controller.offset, closeTo(ScrollPane.lineStep * 1.3, 1e-6));
  });

  testWidgets('it says what it is to assistive technology', (tester) async {
    await pump(tester);

    expect(find.bySemanticsLabel('Something long'), findsOneWidget);
  });
}
