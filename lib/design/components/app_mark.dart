import 'package:flutter/material.dart';
import 'package:iptv_player/core/app_identity.dart' as identity;
import 'package:iptv_player/design/tokens.dart';

/// The app's mark (docs/05 "Brand"): Bijou's jewel, a trillion — the
/// triangular cut — pointing right, so the jewel is the play button, on
/// an accent tile; optionally followed by the app's name. The tile and
/// the jewel take the user's accent.
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

/// How much of the trillion's cut shows at a size.
enum JewelDetail {
  /// Nine crown facets and the table: 56 px tiles and up (64 px icons).
  full,

  /// One band along each edge and the table: 28 px tiles and up (32 px
  /// icons), the rail's and onboarding's.
  bands,

  /// The triangle alone: a facet would be under a pixel wide.
  flat;

  /// The detail for a tile [side] pixels wide.
  static JewelDetail forTile(double side) => side >= 56
      ? JewelDetail.full
      : side >= 28
      ? JewelDetail.bands
      : JewelDetail.flat;
}

/// One face of the jewel: its corners in the icon's 1024 units and how
/// far it is shaded from the jewel's color to the deep accent.
typedef JewelFacet = ({List<(double, double)> points, double shade});

/// Bijou's jewel inside its tile, from the icon's own drawing
/// (`tools/brand/make_icons.py`, `design/brand/bijou_icon.svg`): a
/// 1024-unit canvas whose tile runs from 64 to 960. A trillion pointing
/// right, its facets lit from the top left; smaller, they merge
/// ([JewelDetail]).
class JewelPainter extends CustomPainter {
  const new({required this.jewel, required this.deep});

  /// The jewel's light (`onAccent`) and the shade its facets turn
  /// towards (`accentDeep`).
  final Color jewel;
  final Color deep;

  /// The trillion's corners, clockwise from the top left; the second is
  /// the play button's point.
  static const corners = [(304.0, 260.0), (752.0, 512.0), (304.0, 764.0)];

  /// The table is the outline at this scale about its middle.
  static const tableScale = 0.5;

  /// Each edge's three crown facets, clockwise from the top edge and
  /// from its first corner (the deep accent over the jewel's color).
  static const facetShades = [
    (0.00, 0.08, 0.14),
    (0.37, 0.29, 0.44),
    (0.27, 0.17, 0.09),
  ];

  /// Each edge's one band, when the facets merge.
  static const bandShades = [0.14, 0.46, 0.26];

  /// The jewel's faces at [detail], back to front.
  static List<JewelFacet> facets(JewelDetail detail) {
    (double, double) lerp((double, double) a, (double, double) b, double t) =>
        (a.$1 + (b.$1 - a.$1) * t, a.$2 + (b.$2 - a.$2) * t);

    final faces = <JewelFacet>[(points: corners, shade: 0)];
    if (detail == JewelDetail.flat) return faces;
    final middle = (
      (corners[0].$1 + corners[1].$1 + corners[2].$1) / 3,
      (corners[0].$2 + corners[1].$2 + corners[2].$2) / 3,
    );
    final table = [for (final c in corners) lerp(middle, c, tableScale)];
    for (var i = 0; i < 3; i++) {
      final j = (i + 1) % 3;
      final (from, to) = (corners[i], corners[j]);
      final (inFrom, inTo) = (table[i], table[j]);
      if (detail == JewelDetail.bands) {
        faces.add((points: [from, to, inTo, inFrom], shade: bandShades[i]));
        continue;
      }
      final half = lerp(from, to, 0.5);
      final (first, between, last) = facetShades[i];
      faces
        ..add((points: [from, half, inFrom], shade: first))
        ..add((points: [inFrom, half, inTo], shade: between))
        ..add((points: [half, to, inTo], shade: last));
    }
    return faces..add((points: table, shade: 0));
  }

  @override
  void paint(Canvas canvas, Size size) {
    final side = size.shortestSide;
    double at(double unit) => (unit - 64) / 896 * side;
    final fill = Paint()..isAntiAlias = true;
    for (final face in facets(JewelDetail.forTile(side))) {
      final path = Path()
        ..addPolygon([
          for (final (x, y) in face.points) Offset(at(x), at(y)),
        ], true);
      canvas.drawPath(path, fill..color = Color.lerp(jewel, deep, face.shade)!);
    }
  }

  @override
  bool shouldRepaint(JewelPainter old) =>
      old.jewel != jewel || old.deep != deep;
}
