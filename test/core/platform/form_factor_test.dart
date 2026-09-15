import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:iptv_player/core/platform/form_factor.dart';

void main() {
  test('desktop platforms get the desktop shell', () {
    for (final platform in [TargetPlatform.linux, TargetPlatform.windows]) {
      expect(detectFormFactor(platform: platform), FormFactor.desktop);
    }
  });

  test('Android gets the TV shell', () {
    expect(detectFormFactor(platform: TargetPlatform.android), FormFactor.tv);
  });

  test('override applies only when allowed', () {
    expect(
      detectFormFactor(platform: TargetPlatform.linux, override: 'tv'),
      FormFactor.tv,
    );
    expect(
      detectFormFactor(
        platform: TargetPlatform.linux,
        override: 'tv',
        allowOverride: false,
      ),
      FormFactor.desktop,
    );
    expect(
      detectFormFactor(platform: TargetPlatform.linux, override: 'phone'),
      FormFactor.desktop,
    );
  });
}
