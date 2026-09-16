import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:iptv_player/design/app_icon.dart';

void main() {
  group('canvas icons', () {
    test('every AppIcons entry has an extracted asset', () {
      for (final icon in AppIcons.values) {
        expect(
          File(icon.path).existsSync(),
          isTrue,
          reason:
              '${icon.path} is missing — re-run '
              'dart run tools/extract_icons.dart',
        );
      }
    });

    test('assets are tintable and sized by AppIcon', () {
      final openTag = RegExp('<svg[^>]*>');
      for (final icon in AppIcons.values) {
        final svg = File(icon.path).readAsStringSync();
        final tag = openTag.stringMatch(svg)!;

        expect(tag, contains('viewBox'), reason: icon.asset);
        expect(svg, contains('currentColor'), reason: icon.asset);
        // Only the <svg> tag: inner rects legitimately have a size.
        expect(
          tag,
          isNot(contains(' width=')),
          reason: '${icon.asset} must size from AppIcon',
        );
        expect(
          tag,
          isNot(contains(' height=')),
          reason: '${icon.asset} must size from AppIcon',
        );
        expect(
          RegExp('#[0-9A-Fa-f]{3,8}').hasMatch(svg),
          isFalse,
          reason: '${icon.asset} still has a hard-coded color',
        );
      }
    });

    test('no extracted asset is orphaned', () {
      final onDisk = Directory('assets/icons')
          .listSync()
          .whereType<File>()
          .map((f) => f.uri.pathSegments.last.replaceAll('.svg', ''))
          .toSet();
      final named = AppIcons.values.map((i) => i.asset).toSet();

      expect(
        onDisk.difference(named),
        isEmpty,
        reason: 'extracted but not in AppIcons',
      );
      expect(
        named.difference(onDisk),
        isEmpty,
        reason: 'in AppIcons but not extracted',
      );
    });
  });
}
