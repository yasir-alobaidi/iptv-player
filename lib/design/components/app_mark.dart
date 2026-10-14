import 'package:flutter/material.dart';
import 'package:iptv_player/core/app_identity.dart' as identity;
import 'package:iptv_player/design/tokens.dart';

/// The app's mark (docs/05 "Brand"): Bijou's jewel, an emerald cut seen
/// from above with a play button in its table, on an accent tile —
/// optionally followed by the app's name. The tile and the jewel take
/// the user's accent.
class AppMark extends StatelessWidget {
  /// The nav rail's 40 px tile.
  const new({this.showName = false, super.key}) : _small = false;

  /// The onboarding header's 36 px tile, always named.
  const new small({super.key}) : showName = true, _small = true;

  final bool showName;
  final bool _small;

  static const String appName = identity.appName;

  @override
  Widget build(BuildContext context) {
    final tokens = context.tokens;
    final colors = tokens.colors;
    final size = _small ? 36.0 : 40.0;

    final mark = Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        borderRadius: _small ? tokens.radii.controlAll : tokens.radii.mdAll,
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [colors.accentBase, colors.accentDeep],
        ),
      ),
      child: CustomPaint(
        painter: JewelPainter(jewel: colors.onAccent, deep: colors.accentDeep),
      ),
    );
    if (!showName) return mark;

    final name = Text(
      appName,
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
      style: (_small ? tokens.text.titleSmall : tokens.text.bodyStrong)
          .copyWith(color: colors.textPrimary),
    );
    return Row(
      mainAxisSize: _small ? MainAxisSize.min : MainAxisSize.max,
      children: [
        mark,
        SizedBox(width: tokens.spacing.s12),
        if (_small) name else Expanded(child: name),
      ],
    );
  }
}

/// Bijou's jewel inside its tile, from the icon's own drawing
/// (`tools/brand/make_icons.py`): a 1024-unit canvas whose tile runs
/// from 64 to 960. Under 64 px the facet lines would be a blur, so the
/// jewel grows, its corners cut deeper, and only its lower facets are
/// shaded, as the small icons are.
class JewelPainter extends CustomPainter {
  const new({required this.jewel, required this.deep});

  /// The jewel's body (`onAccent`) and its shade and play button
  /// (`accentDeep`).
  final Color jewel;
  final Color deep;

  @override
  void paint(Canvas canvas, Size size) {
    final side = size.shortestSide;
    final small = side < 64;
    double at(double unit) => (unit - 64) / 896 * side;
    Offset point((double, double) p) => Offset(at(p.$1), at(p.$2));
    Path polygon(List<(double, double)> points) =>
        Path()..addPolygon([for (final p in points) point(p)], true);

    final outer = small
        ? _octagon(176, 248, 848, 776, 150)
        : _octagon(232, 288, 792, 736, 100);
    final table = small
        ? _octagon(276, 336, 748, 672, 104)
        : _octagon(312, 368, 712, 656, 66);
    final fill = Paint()..isAntiAlias = true;
    canvas.drawPath(polygon(outer), fill..color = jewel);

    // Lit from the top left: each step facet a shade of the deep accent,
    // from the top edge clockwise; small, the lower three alone.
    const shades = [0.0, 0.10, 0.16, 0.24, 0.30, 0.20, 0.10, 0.04];
    for (var i = 0; i < 8; i++) {
      final shade = small ? (i >= 3 && i <= 5 ? 0.34 : 0.0) : shades[i];
      if (shade == 0) continue;
      final facet = [
        outer[i],
        outer[(i + 1) % 8],
        table[(i + 1) % 8],
        table[i],
      ];
      canvas.drawPath(
        polygon(facet),
        fill..color = Color.lerp(jewel, deep, shade)!,
      );
    }
    if (!small) {
      final line = Paint()
        ..isAntiAlias = true
        ..style = PaintingStyle.stroke
        ..strokeWidth = 5 / 896 * side
        ..color = Color.lerp(jewel, deep, 0.38)!;
      for (var i = 0; i < 8; i++) {
        canvas.drawLine(point(outer[i]), point(table[i]), line);
      }
      canvas.drawPath(polygon(table), line);
    }

    // The play button: drawn smaller, then stroked round to its size.
    final play = small
        ? const [(440.0, 392.0), (440.0, 632.0), (648.0, 512.0)]
        : const [(452.0, 412.0), (452.0, 612.0), (625.0, 512.0)];
    final radius = small ? 34.0 : 22.0;
    final inset = _inset(play, radius);
    final button = Paint()
      ..isAntiAlias = true
      ..color = deep
      ..strokeWidth = 2 * radius / 896 * side
      ..strokeJoin = StrokeJoin.round;
    canvas
      ..drawPath(polygon(inset), button..style = PaintingStyle.fill)
      ..drawPath(polygon(inset), button..style = PaintingStyle.stroke);
  }

  static List<(double, double)> _octagon(
    double x0,
    double y0,
    double x1,
    double y1,
    double c,
  ) => [
    (x0 + c, y0),
    (x1 - c, y0),
    (x1, y0 + c),
    (x1, y1 - c),
    (x1 - c, y1),
    (x0 + c, y1),
    (x0, y1 - c),
    (x0, y0 + c),
  ];

  /// Each corner of [play] moved towards its middle by twice [radius]
  /// (a 60° corner's inset), so a round join of [radius] gives back its
  /// size.
  static List<(double, double)> _inset(
    List<(double, double)> play,
    double radius,
  ) {
    final middle = Offset(
      (play[0].$1 + play[1].$1 + play[2].$1) / 3,
      (play[0].$2 + play[1].$2 + play[2].$2) / 3,
    );
    final inset = <(double, double)>[];
    for (final (x, y) in play) {
      final toward = middle - Offset(x, y);
      final moved = Offset(x, y) + toward / toward.distance * 2 * radius;
      inset.add((moved.dx, moved.dy));
    }
    return inset;
  }

  @override
  bool shouldRepaint(JewelPainter old) =>
      old.jewel != jewel || old.deep != deep;
}
