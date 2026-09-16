import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:iptv_player/design/components.dart';

import '../design_harness.dart';

void main() {
  group('AppButton', () {
    testWidgets('shows its label and leading icon', (tester) async {
      await pumpDesign(
        tester,
        AppButton(
          label: 'Play',
          icon: Icons.play_arrow_rounded,
          onPressed: () {},
        ),
      );

      expect(find.text('Play'), findsOneWidget);
      expect(find.byIcon(Icons.play_arrow_rounded), findsOneWidget);
    });

    testWidgets('activates on tap and on Enter', (tester) async {
      var taps = 0;
      await pumpDesign(
        tester,
        AppButton(label: 'Play', autofocus: true, onPressed: () => taps++),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.byType(AppButton));
      await tester.pump();
      expect(taps, 1);

      await tester.sendKeyEvent(LogicalKeyboardKey.enter);
      await tester.pump();
      expect(taps, 2);
    });

    testWidgets('without onPressed it is disabled and unfocusable', (
      tester,
    ) async {
      await pumpDesign(tester, const AppButton(label: 'Play'));
      await tester.pumpAndSettle();

      await tester.sendKeyEvent(LogicalKeyboardKey.tab);
      await tester.pumpAndSettle();

      expect(hasFocusRing(tester), isFalse);
      expect(tester.widget<Opacity>(find.byType(Opacity).first).opacity, 0.4);
    });

    testWidgets('loading shows a spinner and blocks activation', (
      tester,
    ) async {
      var taps = 0;
      await pumpDesign(
        tester,
        AppButton(label: 'Testing', loading: true, onPressed: () => taps++),
      );

      expect(find.byType(CircularProgressIndicator), findsOneWidget);
      await tester.tap(find.byType(AppButton));
      await tester.pump();
      expect(taps, isZero);
    });

    testWidgets('filled variants use the inverted focus ring', (tester) async {
      for (final variant in [
        AppButtonVariant.primary,
        AppButtonVariant.danger,
      ]) {
        await pumpDesign(
          tester,
          AppButton(
            label: 'Connect',
            variant: variant,
            autofocus: true,
            onPressed: () {},
          ),
        );
        await tester.pumpAndSettle();

        expect(
          focusRingPainter(tester)!.ringColor,
          const Color(0xFFF3F5F9),
          reason: variant.name,
        );
      }
    });

    testWidgets('ghost and secondary keep the accent ring', (tester) async {
      await pumpDesign(
        tester,
        AppButton(
          label: 'Details',
          variant: AppButtonVariant.ghost,
          autofocus: true,
          onPressed: () {},
        ),
      );
      await tester.pumpAndSettle();

      expect(focusRingPainter(tester)!.ringColor, const Color(0xFF5B8CFF));
    });
  });
}
