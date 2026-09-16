// Every test in this file is a golden; the tag is declared in
// dart_test.yaml so `flutter test --exclude-tags golden` can drop them
// on Windows.
@Tags(['golden'])
library;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:iptv_player/design/gallery/gallery_screen.dart';
import 'package:iptv_player/design/gallery/gallery_section.dart';
import 'package:iptv_player/design/theme.dart';

import 'golden_harness.dart';

/// Pumps the Component Gallery in a 1280x800 window, the size docs/06
/// records component goldens at.
Future<void> _pumpSheet(WidgetTester tester) async {
  hideDebugBanner();
  FocusManager.instance.highlightStrategy =
      FocusHighlightStrategy.alwaysTraditional;
  tester.view.physicalSize = const Size(1280, 800);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);

  await tester.pumpWidget(
    MaterialApp(theme: buildAppTheme(), home: const GalleryScreen()),
  );
  // Not pumpAndSettle: the skeleton shimmer and the indeterminate
  // progress bar animate forever by design. The test clock is fake, so
  // stopping at a fixed offset lands on the same frame every run.
  await tester.pump(const Duration(milliseconds: 400));
}

/// Scrolls the sheet so the section titled [title] starts at the top of
/// the viewport. Anchoring on a section rather than a pixel offset keeps
/// the frame recognizable when sections above it change height.
Future<void> _scrollToSection(WidgetTester tester, String title) async {
  final section = find.ancestor(
    of: find.text(title),
    matching: find.byType(GallerySection),
  );
  // The default alignment and (zero) duration put the section's leading
  // edge at the top of the viewport in one frame.
  await Scrollable.ensureVisible(tester.element(section));
  await tester.pump(const Duration(milliseconds: 400));
}

void main() {
  group('component sheet', () {
    testWidgets('controls', (tester) async {
      await _pumpSheet(tester);

      await expectLater(
        find.byType(MaterialApp),
        matchesGoldenFile('images/component_sheet_controls_1280x800.png'),
      );
    });

    testWidgets('media', (tester) async {
      await _pumpSheet(tester);
      await _scrollToSection(tester, 'Channel rows and logos');

      await expectLater(
        find.byType(MaterialApp),
        matchesGoldenFile('images/component_sheet_media_1280x800.png'),
      );
    });
  }, skip: goldenSkipReason);
}
