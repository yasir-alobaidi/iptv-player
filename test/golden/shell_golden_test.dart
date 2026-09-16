// Every test in this file is a golden; the tag is declared in
// dart_test.yaml so `flutter test --exclude-tags golden` can drop them
// on Windows.
@Tags(['golden'])
library;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../app/app_harness.dart';
import 'golden_harness.dart';

void main() {
  group('desktop shell', () {
    // The two window sizes docs/06 records goldens at: the minimum
    // supported width, where the rail is collapsed, and a full 1080p
    // window, where the content pane is at its widest.
    for (final size in const [Size(1280, 800), Size(1920, 1080)]) {
      final name = '${size.width.toInt()}x${size.height.toInt()}';

      testWidgets('renders at $name', (tester) async {
        hideDebugBanner();
        await pumpApp(tester, size: size);

        await expectLater(
          find.byType(MaterialApp),
          matchesGoldenFile('images/shell_$name.png'),
        );
      });
    }
  }, skip: goldenSkipReason);
}
