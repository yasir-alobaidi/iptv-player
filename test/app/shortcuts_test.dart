import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:iptv_player/app/destinations.dart';
import 'package:iptv_player/app/router.dart';
import 'package:iptv_player/app/shortcuts.dart';
import 'package:iptv_player/features/search/presentation/search_overlay.dart';

import 'app_harness.dart';

Future<void> _press(
  WidgetTester tester,
  LogicalKeyboardKey key, {
  bool control = false,
}) async {
  if (control) await tester.sendKeyDownEvent(LogicalKeyboardKey.control);
  await tester.sendKeyEvent(key);
  if (control) await tester.sendKeyUpEvent(LogicalKeyboardKey.control);
  await settleApp(tester);
}

void main() {
  testWidgets('Ctrl+1 … Ctrl+7 go to the first seven destinations', (
    tester,
  ) async {
    final app = await pumpApp(tester);

    const numberKeys = [
      LogicalKeyboardKey.digit1,
      LogicalKeyboardKey.digit2,
      LogicalKeyboardKey.digit3,
      LogicalKeyboardKey.digit4,
      LogicalKeyboardKey.digit5,
      LogicalKeyboardKey.digit6,
      LogicalKeyboardKey.digit7,
    ];

    for (var number = 1; number <= 7; number++) {
      await _press(tester, numberKeys[number - 1], control: true);

      expect(
        app.location,
        AppDestination.forNumberKey(number)!.path,
        reason: 'Ctrl+$number',
      );
    }
  });

  testWidgets('Ctrl+, opens Settings', (tester) async {
    final app = await pumpApp(tester);

    await _press(tester, LogicalKeyboardKey.comma, control: true);

    expect(app.location, AppDestination.settings.path);
  });

  testWidgets('Ctrl+K opens search and Esc closes it', (tester) async {
    final app = await pumpApp(tester);

    await _press(tester, LogicalKeyboardKey.keyK, control: true);
    expect(find.byType(SearchOverlay), findsOneWidget);
    expect(isSearchOpen(app.router), isTrue);

    await _press(tester, LogicalKeyboardKey.escape);

    expect(find.byType(SearchOverlay), findsNothing);
    expect(app.location, AppDestination.home.path);
  });

  testWidgets('a second Ctrl+K does not stack a second overlay', (
    tester,
  ) async {
    await pumpApp(tester);

    await _press(tester, LogicalKeyboardKey.keyK, control: true);
    await _press(tester, LogicalKeyboardKey.keyK, control: true);

    expect(find.byType(SearchOverlay), findsOneWidget);
  });

  testWidgets('slash opens search', (tester) async {
    final app = await pumpApp(tester);

    await _press(tester, LogicalKeyboardKey.slash);

    expect(isSearchOpen(app.router), isTrue);
  });

  testWidgets('slash types into a text field instead of opening search', (
    tester,
  ) async {
    final app = await pumpApp(tester);

    // The overlay's query field is the one text field the shell has
    // today; Ctrl+K gets us there.
    await _press(tester, LogicalKeyboardKey.keyK, control: true);
    expect(find.byType(EditableText), findsOneWidget);

    await tester.enterText(find.byType(EditableText), 'a');
    await settleApp(tester);
    expect(textInputHasFocus(), isTrue, reason: 'the query field has focus');

    await _press(tester, LogicalKeyboardKey.slash);

    expect(app.location, searchRoutePath, reason: 'still the one overlay');
    expect(find.byType(SearchOverlay), findsOneWidget);
  });

  testWidgets('Esc with nothing open leaves the screen alone', (tester) async {
    final app = await pumpApp(tester);

    await _press(tester, LogicalKeyboardKey.escape);

    expect(app.location, AppDestination.home.path);
  });

  testWidgets('Ctrl+2 from search leaves the overlay behind', (tester) async {
    final app = await pumpApp(tester);

    await _press(tester, LogicalKeyboardKey.keyK, control: true);
    await _press(tester, LogicalKeyboardKey.digit2, control: true);

    expect(find.byType(SearchOverlay), findsNothing);
    expect(app.location, AppDestination.liveTv.path);
  });
}
