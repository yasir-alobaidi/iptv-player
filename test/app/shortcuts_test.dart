import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:iptv_player/app/destinations.dart';
import 'package:iptv_player/app/router.dart';
import 'package:iptv_player/app/shortcuts.dart';
import 'package:iptv_player/features/search/presentation/search_overlay.dart';

import '../features/guide/guide_switch.dart';
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

/// A TV remote's Guide key; whether something took it. The simulated
/// Android event needs a scan code its map knows, and has none for the
/// Guide key's own: the shortcut reads the logical key only.
Future<bool> _remoteGuideKey(WidgetTester tester) async {
  final handled = await tester.sendKeyEvent(
    LogicalKeyboardKey.guide,
    physicalKey: PhysicalKeyboardKey.lang3,
  );
  await settleApp(tester);
  return handled;
}

void main() {
  testWidgets('Ctrl+1 … Ctrl+7 go to the first seven destinations', (
    tester,
  ) async {
    final app = await pumpApp(
      tester,
      overrides: [...emptyLibraryOverrides, guideSwitchedOn()],
    );

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

  testWidgets('G opens the Guide from anywhere, search included', (
    tester,
  ) async {
    final app = await pumpApp(tester, overrides: [guideSwitchedOn()]);

    await _press(tester, LogicalKeyboardKey.keyG);
    expect(app.location, AppDestination.guide.path);

    await _press(tester, LogicalKeyboardKey.digit2, control: true);
    await _press(tester, LogicalKeyboardKey.keyK, control: true);
    // Focus off the query field: the overlay's results are still the
    // overlay.
    FocusManager.instance.primaryFocus?.unfocus();
    await settleApp(tester);
    await _press(tester, LogicalKeyboardKey.keyG);

    expect(find.byType(SearchOverlay), findsNothing);
    expect(app.location, AppDestination.guide.path);
  });

  testWidgets('a remote’s Guide key opens the Guide', (tester) async {
    final app = await pumpApp(tester, overrides: [guideSwitchedOn()]);

    expect(await _remoteGuideKey(tester), isTrue);
    expect(app.location, AppDestination.guide.path);
  });

  testWidgets('with the Guide switched off, as by default (ADR-031): '
      'Ctrl+7 and G do nothing, a remote’s Guide key opens Live TV; '
      'Ctrl+1 … Ctrl+6 still work', (tester) async {
    final app = await pumpApp(tester, overrides: emptyLibraryOverrides);

    await _press(tester, LogicalKeyboardKey.digit7, control: true);
    expect(app.location, AppDestination.home.path, reason: 'Ctrl+7');

    // G is a letter again, for whatever has the focus.
    expect(await tester.sendKeyEvent(LogicalKeyboardKey.keyG), isFalse);
    await settleApp(tester);
    expect(app.location, AppDestination.home.path, reason: 'G');

    // Taken, so Android doesn't act on it instead: Live TV's channels
    // say what is on now and next.
    expect(await _remoteGuideKey(tester), isTrue);
    expect(app.location, AppDestination.liveTv.path, reason: 'Guide');

    await _press(tester, LogicalKeyboardKey.digit6, control: true);
    expect(app.location, AppDestination.library.path, reason: 'Ctrl+6');
  });

  testWidgets('G types into a text field instead of opening the Guide', (
    tester,
  ) async {
    final app = await pumpApp(tester, overrides: [guideSwitchedOn()]);

    await _press(tester, LogicalKeyboardKey.keyK, control: true);
    await tester.enterText(find.byType(EditableText), 'a');
    await settleApp(tester);
    expect(textInputHasFocus(), isTrue);

    await _press(tester, LogicalKeyboardKey.keyG);

    expect(app.location, searchRoutePath);
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
