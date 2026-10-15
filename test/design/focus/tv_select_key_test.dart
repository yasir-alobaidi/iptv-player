import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:iptv_player/design/components.dart';

/// docs/07: a TV remote's OK activates on release, and held opens the
/// item's menu, the remote's only way to one.
void main() {
  late List<String> calls;

  Future<void> pumpItem(WidgetTester tester) async {
    calls = [];
    await tester.pumpWidget(
      MaterialApp(
        home: TvSelectKey(
          child: Center(
            child: Actions(
              actions: {
                ActivateIntent: CallbackAction<ActivateIntent>(
                  onInvoke: (_) => calls.add('activate'),
                ),
                AppMenuIntent: CallbackAction<AppMenuIntent>(
                  onInvoke: (_) => calls.add('menu'),
                ),
              },
              child: const Focus(autofocus: true, child: Text('Channel')),
            ),
          ),
        ),
      ),
    );
    await tester.pump();
  }

  testWidgets('a press activates when OK is let go, not before', (
    tester,
  ) async {
    await pumpItem(tester);
    await tester.sendKeyDownEvent(LogicalKeyboardKey.select);
    await tester.pump(const Duration(milliseconds: 100));
    expect(calls, isEmpty);
    await tester.sendKeyUpEvent(LogicalKeyboardKey.select);
    expect(calls, ['activate']);
  });

  testWidgets('a hold opens the menu, and letting go then does nothing', (
    tester,
  ) async {
    await pumpItem(tester);
    await tester.sendKeyDownEvent(LogicalKeyboardKey.select);
    await tester.pump(TvSelectKey.hold);
    expect(calls, ['menu']);
    await tester.sendKeyRepeatEvent(LogicalKeyboardKey.select);
    await tester.sendKeyUpEvent(LogicalKeyboardKey.select);
    expect(calls, ['menu']);
  });

  testWidgets('other keys pass by', (tester) async {
    await pumpItem(tester);
    await tester.sendKeyEvent(LogicalKeyboardKey.enter);
    // MaterialApp's own Enter → ActivateIntent, as on the desktop.
    expect(calls, ['activate']);
  });
}
