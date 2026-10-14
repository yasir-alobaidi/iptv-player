import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:iptv_player/design/components/app_mark.dart';
import 'package:iptv_player/design/tokens.dart';

void main() {
  group('JewelPainter', () {
    test("draws the master icon's faces, as tools/brand/make_icons.py", () {
      // The SVG the script writes from its own coordinates: the painter
      // and the icons stay one drawing.
      final svg = File('design/brand/bijou_icon.svg').readAsStringSync();
      final drawn = [
        for (final m in RegExp(
          '<polygon points="([^"]+)" fill="#([0-9A-F]{6})"/>',
        ).allMatches(svg))
          (points: m.group(1)!, fill: int.parse(m.group(2)!, radix: 16)),
      ];
      final faces = JewelPainter.facets(JewelDetail.full);

      expect(drawn, hasLength(faces.length));
      for (var i = 0; i < faces.length; i++) {
        final points = [
          for (final (x, y) in faces[i].points) [x, y],
        ];
        final fromSvg = [
          for (final pair in drawn[i].points.split(' '))
            pair.split(',').map(double.parse).toList(),
        ];
        expect(fromSvg, hasLength(points.length), reason: 'face $i');
        for (var p = 0; p < points.length; p++) {
          expect(fromSvg[p][0], closeTo(points[p][0], 0.05), reason: 'face $i');
          expect(fromSvg[p][1], closeTo(points[p][1], 0.05), reason: 'face $i');
        }
        final fill = Color(0xFF000000 | drawn[i].fill);
        final shade = Color.lerp(
          const Color(0xFFFFFFFF),
          AppAccent.blue.deep,
          faces[i].shade,
        )!;
        expect(
          (fill.r - shade.r).abs() * 255,
          lessThanOrEqualTo(1),
          reason: 'face $i',
        );
        expect(
          (fill.g - shade.g).abs() * 255,
          lessThanOrEqualTo(1),
          reason: 'face $i',
        );
        expect(
          (fill.b - shade.b).abs() * 255,
          lessThanOrEqualTo(1),
          reason: 'face $i',
        );
      }
    });

    test('merges its facets as the tile gets smaller', () {
      expect(JewelDetail.forTile(16), JewelDetail.flat);
      expect(JewelDetail.forTile(27.9), JewelDetail.flat);
      expect(JewelDetail.forTile(28), JewelDetail.bands);
      expect(JewelDetail.forTile(40), JewelDetail.bands);
      expect(JewelDetail.forTile(56), JewelDetail.full);

      expect(JewelPainter.facets(JewelDetail.flat), hasLength(1));
      // The outline, a band per edge, the table.
      expect(JewelPainter.facets(JewelDetail.bands), hasLength(5));
      // The outline, three crown facets per edge, the table.
      expect(JewelPainter.facets(JewelDetail.full), hasLength(11));
    });

    test('every face is inside the trillion and on the tile', () {
      for (final detail in JewelDetail.values) {
        for (final face in JewelPainter.facets(detail)) {
          for (final (x, y) in face.points) {
            expect(x, inInclusiveRange(304, 752));
            expect(y, inInclusiveRange(260, 764));
          }
          expect(face.shade, inInclusiveRange(0, 1));
        }
      }
    });
  });
}
