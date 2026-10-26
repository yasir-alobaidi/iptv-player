import 'package:flutter/widgets.dart';
import 'package:iptv_player/design/tokens.dart';
import 'package:qr/qr.dart';

/// A QR code for a phone's camera (ADR-059): dark modules on a light tile
/// with the 4-module quiet zone the standard asks for, whatever the
/// theme. [data] too long for a code draws the tile alone.
class QrCodeView extends StatefulWidget {
  const new({
    required this.data,
    required this.size,
    this.semanticLabel,
    super.key,
  });

  final String data;

  /// The tile's side, quiet zone included.
  final double size;
  final String? semanticLabel;

  @override
  State<QrCodeView> createState() => _QrCodeViewState();
}

class _QrCodeViewState extends State<QrCodeView> {
  // Made once per [QrCodeView.data]: choosing the mask tries all eight.
  late QrImage? _image = qrImageOf(widget.data);

  @override
  void didUpdateWidget(QrCodeView old) {
    super.didUpdateWidget(old);
    if (old.data != widget.data) _image = qrImageOf(widget.data);
  }

  @override
  Widget build(BuildContext context) {
    final tokens = context.tokens;
    return Semantics(
      label: widget.semanticLabel ?? 'QR code',
      image: true,
      child: RepaintBoundary(
        child: CustomPaint(
          size: Size.square(widget.size),
          painter: QrCodePainter(
            image: _image,
            light: tokens.colors.codeLight,
            dark: tokens.colors.codeDark,
            radius: tokens.radii.sm,
          ),
        ),
      ),
    );
  }
}

/// [data] as a code with error correction M, the package's default (15 %:
/// a screen's glare, a shaky hand); null when it doesn't fit one.
QrImage? qrImageOf(String data) {
  try {
    return QrImage(QrCode(payload: QrPayload.fromString(data)));
  } on Object {
    // Too long (InputTooLongException): the tile alone, never a crash.
    return null;
  }
}

/// Paints [image] square in the shorter side: the light tile, then each
/// row's runs of dark modules as one rectangle, unblended so neighbours
/// meet without a seam.
class QrCodePainter extends CustomPainter {
  const new({
    required this.image,
    required this.light,
    required this.dark,
    this.radius = 0,
  });

  /// Light modules round the code, on each side (ISO/IEC 18004).
  static const quietZone = 4;

  final QrImage? image;
  final Color light;
  final Color dark;
  final double radius;

  /// Modules along a side of the code itself; 0 with no code.
  int get moduleCount => image?.moduleCount ?? 0;

  @override
  void paint(Canvas canvas, Size size) {
    final side = size.shortestSide;
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Offset.zero & Size.square(side),
        Radius.circular(radius),
      ),
      Paint()..color = light,
    );
    final image = this.image;
    if (image == null) return;
    final count = image.moduleCount;
    final module = side / (count + quietZone * 2);
    final path = Path();
    for (var row = 0; row < count; row++) {
      var col = 0;
      while (col < count) {
        if (!image.isDark(row, col)) {
          col++;
          continue;
        }
        final start = col;
        while (col < count && image.isDark(row, col)) {
          col++;
        }
        path.addRect(
          Rect.fromLTRB(
            (quietZone + start) * module,
            (quietZone + row) * module,
            (quietZone + col) * module,
            (quietZone + row + 1) * module,
          ),
        );
      }
    }
    canvas.drawPath(
      path,
      Paint()
        ..color = dark
        ..isAntiAlias = false,
    );
  }

  @override
  bool shouldRepaint(QrCodePainter old) =>
      old.image != image ||
      old.light != light ||
      old.dark != dark ||
      old.radius != radius;
}
