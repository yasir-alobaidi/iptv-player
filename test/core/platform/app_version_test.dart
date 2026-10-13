import 'dart:convert';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:iptv_player/core/platform/app_version.dart';

/// A bundle that holds only what a test gives it.
final class _Bundle extends CachingAssetBundle {
  new(this.files);

  final Map<String, String> files;

  @override
  Future<ByteData> load(String key) async {
    final text = files[key];
    if (text == null) throw StateError('Unable to load asset: "$key".');
    return ByteData.sublistView(utf8.encode(text));
  }
}

void main() {
  test(
    "reads the version file the build wrote beside the app's assets",
    () async {
      final version = await readAppVersion(
        _Bundle({
          'version.json':
              '{"app_name":"iptv_player","version":"0.1.0",'
              '"build_number":"1","package_name":"iptv_player"}',
        }),
      );

      expect(version, const AppVersion(version: '0.1.0', build: '1'));
      expect(version.isKnown, isTrue);
      expect(version.label, '0.1.0 (build 1)');
      expect(version.short, '0.1.0+1');
    },
  );

  test('a bundle without the file, or with a damaged one, is unknown: never '
      'an error', () async {
    expect(await readAppVersion(_Bundle({})), AppVersion.unknown);
    expect(
      await readAppVersion(_Bundle({'version.json': '{"version": '})),
      AppVersion.unknown,
    );
    expect(
      await readAppVersion(_Bundle({'version.json': '[1, 2]'})),
      AppVersion.unknown,
    );
    expect(AppVersion.unknown.isKnown, isFalse);
    expect(AppVersion.unknown.label, 'version unknown');
    expect(AppVersion.unknown.short, 'unknown');
  });

  test('a version without a build number says only the version', () async {
    final version = await readAppVersion(
      _Bundle({'version.json': '{"version":"1.2.3","build_number":7}'}),
    );

    expect(version.label, '1.2.3');
    expect(version.short, '1.2.3');
  });
}
