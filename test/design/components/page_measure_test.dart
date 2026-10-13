import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:iptv_player/design/components.dart';
import 'package:iptv_player/design/theme.dart';
import 'package:iptv_player/design/tokens.dart';

void main() {
  const measure = 1336.0;
  const page = Key('page');

  Future<void> pump(
    WidgetTester tester,
    Size window, {
    double? maxWidth,
    AlignmentGeometry alignment = Alignment.topLeft,
  }) async {
    tester.view.physicalSize = window;
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      MaterialApp(
        theme: buildAppTheme(),
        home: PageMeasure(
          maxWidth: maxWidth,
          alignment: alignment,
          // A page as the screens build it: rows that fill the height.
          child: const Column(
            key: page,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              SizedBox(height: 40),
              Expanded(child: SizedBox.shrink()),
            ],
          ),
        ),
      ),
    );
  }

  test("the measure is the canvas's widest page", () {
    expect(const AppLayoutTokens().pageMeasure, measure);
  });

  testWidgets('a window narrower than the measure is filled', (tester) async {
    await pump(tester, const Size(1024, 640));

    expect(
      tester.getRect(find.byKey(page)),
      const Rect.fromLTWH(0, 0, 1024, 640),
    );
  });

  testWidgets('a wider window keeps the page to its measure, at the left, '
      'at its full height', (tester) async {
    await pump(tester, const Size(2560, 1440));

    expect(
      tester.getRect(find.byKey(page)),
      const Rect.fromLTWH(0, 0, measure, 1440),
    );
  });

  testWidgets('a page that stands alone sits in the middle', (tester) async {
    await pump(tester, const Size(2560, 1440), alignment: Alignment.topCenter);

    final rect = tester.getRect(find.byKey(page));
    expect(rect.width, measure);
    expect(rect.left, (2560 - measure) / 2);
  });

  testWidgets('a tab that is a grid passes no limit and fills the window', (
    tester,
  ) async {
    await pump(tester, const Size(2560, 1440), maxWidth: double.infinity);

    expect(tester.getSize(find.byKey(page)).width, 2560);
  });
}
