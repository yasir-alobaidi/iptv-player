import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:iptv_player/design/components.dart';
import 'package:iptv_player/design/gallery/gallery_availability.dart';
import 'package:iptv_player/design/gallery/gallery_screen.dart';
import 'package:iptv_player/design/gallery/gallery_section.dart';
import 'package:iptv_player/design/theme.dart';
import 'package:iptv_player/design/tokens.dart';

Future<void> _pumpGallery(WidgetTester tester) async {
  FocusManager.instance.highlightStrategy =
      FocusHighlightStrategy.alwaysTraditional;
  tester.view.physicalSize = const Size(1440, 900);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);

  await tester.pumpWidget(
    MaterialApp(theme: buildAppTheme(), home: const GalleryScreen()),
  );
  // Not pumpAndSettle: the skeleton shimmer and the indeterminate
  // progress bar animate forever by design.
  await settle(tester);
}

/// Advances past the token durations without waiting for the endless
/// animations the gallery shows on purpose.
Future<void> settle(WidgetTester tester) =>
    tester.pump(const Duration(milliseconds: 400));

void main() {
  testWidgets('the gallery builds with every section', (tester) async {
    await _pumpGallery(tester);

    expect(find.text('Component Gallery'), findsOneWidget);
    expect(find.byType(GallerySection), findsWidgets);
    expect(find.text('Buttons'), findsOneWidget);
    expect(find.text('Icon buttons'), findsOneWidget);
    expect(find.text('Badges'), findsOneWidget);
  });

  testWidgets('every interaction state is on the sheet', (tester) async {
    await _pumpGallery(tester);

    for (final label in gallerySurfaceStates.keys) {
      expect(find.textContaining(label), findsWidgets, reason: label);
    }
    expect(find.textContaining('disabled'), findsWidgets);
    expect(find.textContaining('loading'), findsWidgets);
  });

  testWidgets('Tab moves through the gallery', (tester) async {
    await _pumpGallery(tester);

    // Exact traversal order depends on where the scroll views sit, so
    // this checks that Tab keeps moving to new elements rather than
    // asserting a fixed first stop.
    final visited = <FocusNode>{};
    for (var press = 0; press < 8; press++) {
      await tester.sendKeyEvent(LogicalKeyboardKey.tab);
      await settle(tester);
      final focused = FocusManager.instance.primaryFocus;
      expect(focused, isNotNull);
      visited.add(focused!);
    }

    expect(visited.length, greaterThanOrEqualTo(5));
  });

  testWidgets('the accent switch repaints the gallery', (tester) async {
    await _pumpGallery(tester);

    await tester.tap(find.text(AppAccent.rose.label));
    await settle(tester);

    final context = tester.element(find.byType(GallerySection).first);
    expect(context.tokens.colors.accentBase, AppAccent.rose.base);
  });

  testWidgets('density and reduce motion switch at runtime', (tester) async {
    await _pumpGallery(tester);

    await tester.tap(find.text(AppDensity.compact.label));
    await settle(tester);
    var context = tester.element(find.byType(GallerySection).first);
    expect(context.tokens.density, AppDensity.compact);

    await tester.tap(find.text('Reduce motion'));
    await settle(tester);
    context = tester.element(find.byType(GallerySection).first);
    expect(context.tokens.motion.reduceMotion, isTrue);
  });

  testWidgets('the media and icon sections are on the sheet', (tester) async {
    await _pumpGallery(tester);

    for (final title in const [
      'Channel rows and logos',
      'Cards and rails',
      'Banners and toasts',
      'Dialog, sheet and menu',
      'Casting',
      'Downloads',
      'Icons',
    ]) {
      expect(find.text(title), findsOneWidget, reason: title);
    }
    expect(find.byType(AppIcon), findsWidgets);
  });

  test('the gallery is available in debug builds', () {
    expect(galleryEnabled, isTrue);
  });
}
