import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:iptv_player/design/components.dart';

import '../design_harness.dart';

/// docs/07 and ADR-026: on a TV the remote types with Bijou's keyboard;
/// Android's never opens.
/// Frames enough for a route's fade; not pumpAndSettle, which a blinking
/// caret never lets settle.
Future<void> settle(WidgetTester tester) async {
  for (var i = 0; i < 4; i++) {
    await tester.pump(const Duration(milliseconds: 100));
  }
}

void main() {
  Finder key(String label) => find.byWidgetPredicate(
    (widget) => widget is FocusableSurface && widget.semanticLabel == label,
  );

  Future<void> press(WidgetTester tester, String label) async {
    await tester.tap(key(label));
    await tester.pump();
  }

  /// What the field asked Android's keyboard for.
  String? inputType(WidgetTester tester) =>
      (tester.testTextInput.setClientArgs?['inputType'] as Map?)?['name']
          as String?;

  Future<void> ok(WidgetTester tester) async {
    await tester.sendKeyEvent(LogicalKeyboardKey.select);
    await settle(tester);
  }

  group('RemoteKeyboard', () {
    late TextEditingController controller;
    late List<String> changes;
    late List<String> submitted;

    Future<void> open(
      WidgetTester tester, {
      bool obscure = false,
      TextInputType? type,
    }) async {
      controller = TextEditingController();
      addTearDown(controller.dispose);
      changes = [];
      submitted = [];
      await pumpDesign(
        tester,
        Builder(
          builder: (context) => AppButton(
            label: 'Open',
            onPressed: () => showRemoteKeyboard(
              context,
              controller: controller,
              label: 'Server address',
              obscure: obscure,
              keyboardType: type,
              onChanged: changes.add,
              onSubmitted: submitted.add,
            ),
          ),
        ),
        tv: true,
      );
      tester.view.physicalSize = const Size(960, 540);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      await tester.tap(find.text('Open'));
      await settle(tester);
    }

    testWidgets('the remote types: the arrows move over the keys and OK '
        'presses one; each key edits the field at once', (tester) async {
      await open(tester);
      // The first letter has the focus.
      await ok(tester);
      expect(controller.text, 'q');
      await tester.sendKeyEvent(LogicalKeyboardKey.arrowRight);
      await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
      await settle(tester);
      await ok(tester);
      expect(controller.text, 'qs');
      expect(changes, ['q', 'qs']);
      expect(controller.selection, const TextSelection.collapsed(offset: 2));
    });

    testWidgets('ABC types capitals, #+= symbols; Delete, Space and Clear', (
      tester,
    ) async {
      await open(tester);
      await press(tester, 'ABC');
      await press(tester, 'H');
      await press(tester, 'abc');
      await press(tester, 'i');
      await press(tester, 'Space');
      await press(tester, '#+=');
      await press(tester, '!');
      expect(controller.text, 'Hi !');
      await press(tester, 'Delete');
      expect(controller.text, 'Hi ');
      await press(tester, 'Clear');
      expect(controller.text, '');
      expect(changes.last, '');
    });

    testWidgets("an address's pieces for a URL; the digits first for a "
        'number', (tester) async {
      await open(tester, type: TextInputType.url);
      await press(tester, 'http://');
      await press(tester, '1');
      await press(tester, ':');
      expect(controller.text, 'http://1:');
      await tester.sendKeyEvent(LogicalKeyboardKey.escape);
      await settle(tester);

      await open(tester, type: TextInputType.number);
      expect(key('http://'), findsNothing);
      await ok(tester);
      expect(controller.text, '1');
    });

    testWidgets('Done closes and submits; Back closes and keeps the text', (
      tester,
    ) async {
      await open(tester);
      await press(tester, 'a');
      await press(tester, 'Done');
      await settle(tester);
      expect(find.byType(RemoteKeyboard), findsNothing);
      expect(submitted, ['a']);

      await tester.tap(find.text('Open'));
      await settle(tester);
      await press(tester, 'b');
      await tester.binding.handlePopRoute();
      await settle(tester);
      expect(find.byType(RemoteKeyboard), findsNothing);
      expect(controller.text, 'ab');
      expect(submitted, ['a']);
    });

    testWidgets('the focused key fills white with dark letters, and draws no '
        'ring a neighbour could paint over (the user, on the TV)', (
      tester,
    ) async {
      await open(tester);
      Color? ink(String label) => tester
          .widget<Text>(
            find.descendant(of: key(label), matching: find.text(label)),
          )
          .style!
          .color;
      // q has the focus: dark on white; w rests: light on dark.
      expect(ink('q'), isNot(ink('w')));
      expect(
        tester
            .widgetList<FocusRing>(
              find.descendant(
                of: find.byType(RemoteKeyboard),
                matching: find.byType(FocusRing),
              ),
            )
            .where((ring) => ring.visible),
        isEmpty,
      );
    });

    testWidgets('the caret blinks; a long text shows its end, where the '
        'typing is', (tester) async {
      await open(tester);
      Opacity caret() => tester.widget<Opacity>(
        find
            .descendant(
              of: find.byType(RemoteKeyboard),
              matching: find.byType(Opacity),
            )
            .last,
      );
      expect(caret().opacity, 1);
      await tester.pump(const Duration(milliseconds: 600));
      expect(caret().opacity, 0);
      await tester.pump(const Duration(milliseconds: 500));
      expect(caret().opacity, 1);

      for (var i = 0; i < 30; i++) {
        await tester.tap(key('w'));
        await tester.pump();
      }
      final text = find.descendant(
        of: find.byType(RemoteKeyboard),
        matching: find.text('w' * 30),
      );
      final keyboard = tester.getRect(find.byType(RemoteKeyboard));
      // Cut at the left, its end in the box.
      expect(tester.getRect(text).left, lessThan(keyboard.left));
      expect(tester.getRect(text).right, lessThan(keyboard.right));
    });

    testWidgets('a password shows dots until Show', (tester) async {
      await open(tester, obscure: true);
      await press(tester, 'p');
      await press(tester, 'w');
      expect(find.text('••'), findsOneWidget);
      await press(tester, 'Show');
      expect(find.text('pw'), findsOneWidget);
    });
  });

  group('a field on a TV', () {
    testWidgets("never asks for Android's keyboard; OK opens the remote's, "
        'and the arrows move from field to field', (tester) async {
      final first = FocusNode(debugLabel: 'first');
      final second = FocusNode(debugLabel: 'second');
      addTearDown(first.dispose);
      addTearDown(second.dispose);
      final submitted = <String>[];
      await pumpDesign(
        tester,
        SizedBox(
          width: 320,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              AppTextField(
                label: 'Username',
                focusNode: first,
                autofocus: true,
                onSubmitted: submitted.add,
              ),
              AppTextField(label: 'Password', focusNode: second),
            ],
          ),
        ),
        tv: true,
      );
      await settle(tester);
      expect(first.hasPrimaryFocus, isTrue);
      expect(inputType(tester), 'TextInputType.none');

      await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
      await settle(tester);
      expect(second.hasPrimaryFocus, isTrue);
      await tester.sendKeyEvent(LogicalKeyboardKey.arrowUp);
      await settle(tester);
      expect(first.hasPrimaryFocus, isTrue);

      await ok(tester);
      expect(find.byType(RemoteKeyboard), findsOneWidget);
      expect(find.text('Username'), findsWidgets);
      await ok(tester);
      await press(tester, 'Done');
      await settle(tester);
      expect(find.text('q'), findsOneWidget);
      expect(submitted, ['q']);
      expect(first.hasPrimaryFocus, isTrue);
      expect(inputType(tester), 'TextInputType.none');
    });

    testWidgets('off a TV a field is typed in as ever', (tester) async {
      await pumpDesign(
        tester,
        const SizedBox(width: 320, child: AppTextField(autofocus: true)),
      );
      await settle(tester);
      expect(inputType(tester), 'TextInputType.text');
      await tester.sendKeyEvent(LogicalKeyboardKey.select);
      await settle(tester);
      expect(find.byType(RemoteKeyboard), findsNothing);
    });
  });
}
