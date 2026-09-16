import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:iptv_player/design/focus/focusable_surface.dart';
import 'package:iptv_player/design/tokens.dart';

import '../design_harness.dart';

void main() {
  group('FocusableSurface', () {
    testWidgets('Enter activates the focused element', (tester) async {
      var taps = 0;
      await pumpDesign(
        tester,
        FocusableSurface.child(
          autofocus: true,
          onPressed: () => taps++,
          child: const SizedBox(width: 120, height: 40),
        ),
      );
      await tester.pumpAndSettle();

      await tester.sendKeyEvent(LogicalKeyboardKey.enter);
      await tester.pump();

      expect(taps, 1);
    });

    testWidgets('Space activates the focused element', (tester) async {
      var taps = 0;
      await pumpDesign(
        tester,
        FocusableSurface.child(
          autofocus: true,
          onPressed: () => taps++,
          child: const SizedBox(width: 120, height: 40),
        ),
      );
      await tester.pumpAndSettle();

      await tester.sendKeyEvent(LogicalKeyboardKey.space);
      await tester.pump();

      expect(taps, 1);
    });

    testWidgets('Shift+F10 opens the item menu', (tester) async {
      var menus = 0;
      await pumpDesign(
        tester,
        FocusableSurface.child(
          autofocus: true,
          onPressed: () {},
          onMenu: () => menus++,
          child: const SizedBox(width: 120, height: 40),
        ),
      );
      await tester.pumpAndSettle();

      await tester.sendKeyDownEvent(LogicalKeyboardKey.shiftLeft);
      await tester.sendKeyEvent(LogicalKeyboardKey.f10);
      await tester.sendKeyUpEvent(LogicalKeyboardKey.shiftLeft);
      await tester.pump();

      expect(menus, 1);
    });

    testWidgets('focus draws the ring and glow', (tester) async {
      await pumpDesign(
        tester,
        FocusableSurface.child(
          onPressed: () {},
          child: const SizedBox(width: 120, height: 40),
        ),
      );
      await tester.pumpAndSettle();

      expect(hasFocusRing(tester), isFalse);

      await tester.sendKeyEvent(LogicalKeyboardKey.tab);
      await tester.pumpAndSettle();

      expect(hasFocusRing(tester), isTrue);
      final painter = focusRingPainter(tester)!;
      final tokens = AppTokens.defaults();
      expect(painter.ringWidth, tokens.focus.ringWidth);
      expect(painter.glowWidth, tokens.focus.glowWidth);
      expect(painter.ringColor, tokens.colors.accentBase);
      expect(painter.glowColor.a, closeTo(tokens.focus.glowOpacity, 0.01));
    });

    testWidgets('on an accent surface the ring inverts', (tester) async {
      await pumpDesign(
        tester,
        FocusableSurface.child(
          onPressed: () {},
          onAccent: true,
          autofocus: true,
          child: const SizedBox(width: 120, height: 40),
        ),
      );
      await tester.pumpAndSettle();

      final tokens = AppTokens.defaults();
      final painter = focusRingPainter(tester)!;
      expect(painter.ringColor, tokens.colors.textPrimary);
      expect(painter.glowWidth, tokens.focus.onAccentGlowWidth);
      expect(
        painter.glowColor.a,
        closeTo(tokens.focus.onAccentGlowOpacity, 0.01),
      );
    });

    testWidgets('a disabled surface is not focusable', (tester) async {
      var taps = 0;
      await pumpDesign(
        tester,
        Column(
          children: [
            FocusableSurface.child(
              onPressed: () => taps++,
              enabled: false,
              child: const SizedBox(width: 120, height: 40),
            ),
          ],
        ),
      );
      await tester.pumpAndSettle();

      await tester.sendKeyEvent(LogicalKeyboardKey.tab);
      await tester.pumpAndSettle();

      expect(hasFocusRing(tester), isFalse);
      await tester.sendKeyEvent(LogicalKeyboardKey.enter);
      await tester.pump();
      expect(taps, isZero);
    });

    testWidgets('tiles scale on focus, rows do not', (tester) async {
      await pumpDesign(
        tester,
        FocusableSurface.child(
          onPressed: () {},
          autofocus: true,
          growth: FocusGrowth.tile,
          child: const SizedBox(width: 120, height: 160),
        ),
      );
      await tester.pumpAndSettle();

      expect(
        tester.widget<AnimatedScale>(find.byType(AnimatedScale)).scale,
        AppTokens.defaults().focus.tileScale,
      );
    });

    testWidgets('reduce motion turns the focus scale off', (tester) async {
      await pumpDesign(
        tester,
        FocusableSurface.child(
          onPressed: () {},
          autofocus: true,
          growth: FocusGrowth.tile,
          child: const SizedBox(width: 120, height: 160),
        ),
        reduceMotion: true,
      );
      await tester.pumpAndSettle();

      expect(find.byType(AnimatedScale), findsNothing);
    });

    testWidgets('SurfaceStateOverride forces the visual state', (tester) async {
      await pumpDesign(
        tester,
        SurfaceStateOverride(
          states: const SurfaceStates(focused: true),
          child: FocusableSurface.child(
            onPressed: () {},
            child: const SizedBox(width: 120, height: 40),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(hasFocusRing(tester), isTrue);
    });
  });
}
