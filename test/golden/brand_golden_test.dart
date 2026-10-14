// Every test in this file is a golden; the tag is declared in
// dart_test.yaml so `flutter test --exclude-tags golden` can drop them
// on Windows.
@Tags(['golden'])
library;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:iptv_player/design/components/app_mark.dart';
import 'package:iptv_player/design/theme.dart';
import 'package:iptv_player/design/tokens.dart';

import 'golden_harness.dart';

/// The mark's tile at each size the app and the icons draw it, from the
/// favicon's flat triangle to every facet (docs/05 "Brand").
const _tiles = [16.0, 24.0, 36.0, 40.0, 64.0, 128.0];

class _Marks extends StatelessWidget {
  const new();

  @override
  Widget build(BuildContext context) {
    final tokens = context.tokens;
    final colors = tokens.colors;
    return Scaffold(
      backgroundColor: colors.bg,
      body: Padding(
        padding: EdgeInsets.all(tokens.spacing.s24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                for (final side in _tiles) ...[
                  Container(
                    width: side,
                    height: side,
                    decoration: BoxDecoration(
                      // The icon's: 208 of its 896-unit tile.
                      borderRadius: BorderRadius.circular(side * 208 / 896),
                      gradient: LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: [colors.accentBase, colors.accentDeep],
                      ),
                    ),
                    child: CustomPaint(
                      painter: JewelPainter(
                        jewel: colors.onAccent,
                        deep: colors.accentDeep,
                      ),
                    ),
                  ),
                  SizedBox(width: tokens.spacing.s24),
                ],
              ],
            ),
            SizedBox(height: tokens.spacing.s24),
            const SizedBox(width: 240, child: AppMark(showName: true)),
            SizedBox(height: tokens.spacing.s16),
            const AppMark.small(),
          ],
        ),
      ),
    );
  }
}

Future<void> _pump(WidgetTester tester, AppAccent accent) async {
  hideDebugBanner();
  tester.view.physicalSize = const Size(560, 320);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(
    MaterialApp(
      theme: buildAppTheme(accent: accent),
      home: const _Marks(),
    ),
  );
}

void main() {
  group('brand', () {
    testWidgets('the mark at every size', (tester) async {
      await _pump(tester, AppAccent.blue);
      await expectLater(
        find.byType(MaterialApp),
        matchesGoldenFile('images/brand_mark_sizes.png'),
      );
    });

    testWidgets('the mark takes the accent', (tester) async {
      await _pump(tester, AppAccent.amber);
      await expectLater(
        find.byType(MaterialApp),
        matchesGoldenFile('images/brand_mark_sizes_amber.png'),
      );
    });
  }, skip: goldenSkipReason);
}
