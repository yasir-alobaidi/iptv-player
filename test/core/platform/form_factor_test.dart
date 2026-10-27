import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:iptv_player/core/platform/form_factor.dart';

void main() {
  test('desktop platforms get the desktop shell', () {
    for (final platform in [TargetPlatform.linux, TargetPlatform.windows]) {
      expect(detectFormFactor(platform: platform), FormFactor.desktop);
    }
  });

  test('Android with no word from the activity gets the TV shell', () {
    expect(detectFormFactor(platform: TargetPlatform.android), FormFactor.tv);
    expect(
      detectFormFactor(
        platform: TargetPlatform.android,
        args: ['--form-factor=watch'],
      ),
      FormFactor.tv,
    );
  });

  test('Android takes the form factor the activity names', () {
    expect(
      detectFormFactor(
        platform: TargetPlatform.android,
        args: ['--form-factor=mobile'],
      ),
      FormFactor.mobile,
    );
    expect(
      detectFormFactor(
        platform: TargetPlatform.android,
        args: ['--other', '--form-factor=tv'],
      ),
      FormFactor.tv,
    );
    // Only Android's activity speaks: a desktop is a desktop.
    expect(
      detectFormFactor(
        platform: TargetPlatform.linux,
        args: ['--form-factor=mobile'],
      ),
      FormFactor.desktop,
    );
  });

  test('override applies only when allowed', () {
    expect(
      detectFormFactor(platform: TargetPlatform.linux, override: 'tv'),
      FormFactor.tv,
    );
    expect(
      detectFormFactor(platform: TargetPlatform.linux, override: 'mobile'),
      FormFactor.mobile,
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

  test('what each form factor has', () {
    expect(FormFactor.desktop.isDesktop, isTrue);
    expect(FormFactor.mobile.isDesktop, isFalse);
    expect(FormFactor.mobile.isTv, isFalse);
    expect(FormFactor.mobile.isAndroidDevice, isTrue);
    expect(FormFactor.tv.isAndroidDevice, isTrue);
    expect(FormFactor.mobile.thisDevice, 'this device');
  });
}
