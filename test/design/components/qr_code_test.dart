import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:iptv_player/design/components.dart';
import 'package:iptv_player/design/tokens.dart';
import 'package:qr/qr.dart';

import '../design_harness.dart';

/// ADR-059: the code a phone's camera reads, dark on light whatever the
/// theme, with its quiet zone.
void main() {
  const address = 'http://192.168.1.50:41234/k3v9q2mx7p/';

  QrCodePainter painterOf(WidgetTester tester) => tester
      .widgetList<CustomPaint>(
        find.descendant(
          of: find.byType(QrCodeView),
          matching: find.byType(CustomPaint),
        ),
      )
      .map((paint) => paint.painter)
      .whereType<QrCodePainter>()
      .single;

  testWidgets('paints the code for an address at its size, with its '
      'label', (tester) async {
    await pumpDesign(
      tester,
      const QrCodeView(data: address, size: 240, semanticLabel: 'The code'),
    );
    final colors = AppTokens.defaults().colors;
    final painter = painterOf(tester);
    expect(
      painter.moduleCount,
      QrCode(payload: QrPayload.fromString(address)).moduleCount,
    );
    expect(painter.moduleCount, greaterThan(0));
    expect(painter.light, colors.codeLight);
    expect(painter.dark, colors.codeDark);
    expect(tester.getSize(find.byType(QrCodeView)), const Size(240, 240));
    expect(
      find.descendant(
        of: find.byType(QrCodeView),
        matching: find.byType(RepaintBoundary),
      ),
      findsOneWidget,
    );
    expect(find.bySemanticsLabel('The code'), findsOneWidget);

    final box = tester.renderObject(
      find.descendant(
        of: find.byType(QrCodeView),
        matching: find.byType(CustomPaint),
      ),
    );
    // A module's middle, counted from the code's corner.
    final module = 240 / (painter.moduleCount + QrCodePainter.quietZone * 2);
    Offset at(int row, int col) => Offset(
      (QrCodePainter.quietZone + col + 0.5) * module,
      (QrCodePainter.quietZone + row + 0.5) * module,
    );
    expect(
      box,
      paints
        ..rrect(color: colors.codeLight)
        ..path(
          color: colors.codeDark,
          // The top-left finder pattern: its dark ring and middle, the
          // light ring between them.
          includes: [at(0, 0), at(3, 3), at(6, 6)],
          excludes: [
            at(1, 1),
            at(5, 5),
            // The quiet zone round it.
            at(-1, -1),
            at(0, -1),
            Offset(module / 2, module / 2),
          ],
        ),
    );
  });

  test('data too long for a code is no code, not a crash', () {
    expect(qrImageOf('x' * 8000), isNull);
    expect(qrImageOf(address), isNotNull);
  });

  testWidgets('a new address is a new code', (tester) async {
    await pumpDesign(tester, const QrCodeView(data: address, size: 200));
    final first = painterOf(tester).image;
    await pumpDesign(tester, QrCodeView(data: '${address}x' * 3, size: 200));
    expect(painterOf(tester).image, isNot(same(first)));
    expect(find.bySemanticsLabel('QR code'), findsOneWidget);
  });
}
