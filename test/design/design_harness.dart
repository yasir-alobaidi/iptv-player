import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:iptv_player/design/focus/focus_ring.dart';
import 'package:iptv_player/design/focus/focusable_surface.dart';
import 'package:iptv_player/design/theme.dart';
import 'package:iptv_player/design/tokens.dart';

/// Pumps [child] inside the app theme, sized like a desktop window.
Future<void> pumpDesign(
  WidgetTester tester,
  Widget child, {
  AppAccent accent = AppAccent.blue,
  AppDensity density = AppDensity.comfortable,
  bool reduceMotion = false,
}) async {
  // Focus highlights only render in "traditional" mode, which a real
  // desktop is always in.
  FocusManager.instance.highlightStrategy =
      FocusHighlightStrategy.alwaysTraditional;

  await tester.pumpWidget(
    MaterialApp(
      theme: buildAppTheme(
        accent: accent,
        density: density,
        reduceMotion: reduceMotion,
      ),
      home: Scaffold(body: Center(child: child)),
    ),
  );
}

/// The decoration [FocusableSurface] paints, including the focus ring.
BoxDecoration surfaceDecoration(WidgetTester tester, {Finder? of}) {
  final container = tester.widget<AnimatedContainer>(
    find.descendant(
      of: of ?? find.byType(FocusableSurface),
      matching: find.byType(AnimatedContainer),
    ),
  );
  return container.decoration! as BoxDecoration;
}

/// The focus ring painter, or null when no ring is drawn.
FocusRingPainter? focusRingPainter(WidgetTester tester, {Finder? of}) {
  final paints = tester.widgetList<CustomPaint>(
    find.descendant(
      of: of ?? find.byType(FocusableSurface),
      matching: find.byType(CustomPaint),
    ),
  );
  for (final paint in paints) {
    final painter = paint.foregroundPainter;
    if (painter is FocusRingPainter) return painter;
  }
  return null;
}

/// True when the 2 px ring plus glow is being drawn.
bool hasFocusRing(WidgetTester tester, {Finder? of}) =>
    focusRingPainter(tester, of: of) != null;
