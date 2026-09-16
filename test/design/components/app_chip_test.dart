import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:iptv_player/design/components.dart';
import 'package:iptv_player/design/tokens.dart';

import '../design_harness.dart';

void main() {
  group('AppChip', () {
    testWidgets('shows its label and count', (tester) async {
      await pumpDesign(
        tester,
        AppChip(label: 'Sports', count: 214, onPressed: () {}),
      );

      expect(find.text('Sports'), findsOneWidget);
      expect(find.text('214'), findsOneWidget);
    });

    testWidgets('a selected chip uses the accent tint', (tester) async {
      await pumpDesign(
        tester,
        AppChip(label: 'All', selected: true, onPressed: () {}),
      );

      final tokens = AppTokens.defaults();
      expect(surfaceDecoration(tester).color, tokens.colors.accentSoft);
    });

    testWidgets('Space activates it', (tester) async {
      var taps = 0;
      await pumpDesign(
        tester,
        AppChip(label: 'News', autofocus: true, onPressed: () => taps++),
      );
      await tester.pumpAndSettle();

      await tester.sendKeyEvent(LogicalKeyboardKey.space);
      await tester.pump();

      expect(taps, 1);
    });

    testWidgets('a disabled chip is dimmed and unfocusable', (tester) async {
      await pumpDesign(tester, const AppChip(label: 'Kids', enabled: false));
      await tester.pumpAndSettle();

      await tester.sendKeyEvent(LogicalKeyboardKey.tab);
      await tester.pumpAndSettle();

      expect(hasFocusRing(tester), isFalse);
      expect(tester.widget<Opacity>(find.byType(Opacity).first).opacity, 0.4);
    });
  });

  group('AppBadge', () {
    testWidgets('renders every tone in upper case', (tester) async {
      for (final tone in AppBadgeTone.values) {
        await pumpDesign(tester, AppBadge('live', tone: tone));
        expect(find.text('LIVE'), findsOneWidget, reason: tone.name);
      }
    });

    testWidgets('the outline tone has a border and no fill', (tester) async {
      await pumpDesign(
        tester,
        const AppBadge('4K', tone: AppBadgeTone.outline),
      );

      final decoration =
          tester
                  .widget<Container>(
                    find.descendant(
                      of: find.byType(AppBadge),
                      matching: find.byType(Container),
                    ),
                  )
                  .decoration!
              as BoxDecoration;

      expect(decoration.color, isNull);
      expect(decoration.border, isNotNull);
    });
  });

  group('SegmentedControl', () {
    testWidgets('Enter selects the focused segment', (tester) async {
      var value = 'no';
      await pumpDesign(
        tester,
        StatefulBuilder(
          builder: (context, setState) => SegmentedControl<String>(
            options: const [
              SegmentOption(value: 'no', label: 'No.'),
              SegmentOption(value: 'az', label: 'A–Z'),
            ],
            value: value,
            onChanged: (v) => setState(() => value = v),
          ),
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.text('A–Z'));
      await tester.pump();
      expect(value, 'az');

      await tester.sendKeyEvent(LogicalKeyboardKey.tab);
      await tester.pumpAndSettle();
      await tester.sendKeyEvent(LogicalKeyboardKey.enter);
      await tester.pump();
      expect(value, 'no');
    });

    testWidgets('a disabled control ignores input', (tester) async {
      var changes = 0;
      await pumpDesign(
        tester,
        SegmentedControl<String>(
          options: const [
            SegmentOption(value: 'no', label: 'No.'),
            SegmentOption(value: 'az', label: 'A–Z'),
          ],
          value: 'no',
          enabled: false,
          onChanged: (_) => changes++,
        ),
      );

      await tester.tap(find.text('A–Z'));
      await tester.pump();

      expect(changes, isZero);
    });
  });
}
