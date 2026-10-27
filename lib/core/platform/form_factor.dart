import 'package:flutter/foundation.dart';

enum FormFactor {
  desktop,
  tv,

  /// A phone, a tablet or a Chromebook: Android with a touchscreen, or a
  /// pointer and keyboard, and no remote (ADR-068). The screens follow its
  /// width: a phone held upright gets the bottom bar, wider gets the rail.
  mobile;

  /// The device in the app's words: "this computer", "this TV".
  String get thisDevice => switch (this) {
    desktop => 'this computer',
    tv => 'this TV',
    mobile => 'this device',
  };

  /// Only a desktop has FFmpeg, a file system to keep videos in and a
  /// window: casting, downloads, the library and the keyboard's page are
  /// its own (docs/07; ADR-068 for a phone).
  bool get isDesktop => this == desktop;

  /// Driven by a remote from across a room (docs/07): the 10-foot canvas,
  /// Bijou's own keyboard, OK held for the menu.
  bool get isTv => this == tv;

  /// Android's limits, a TV's or a phone's: the smaller caches, the guide's
  /// shorter window, the sources a form can add without a file.
  bool get isAndroidDevice => this != desktop;
}

/// The form factor Android names in the activity's entrypoint arguments
/// (`--form-factor=tv` or `--form-factor=mobile`, MainActivity, from the
/// TV's UI mode, its leanback feature and its touchscreen; ADR-068).
const formFactorArgument = '--form-factor=';

/// Chooses the shell. On Android the activity says which ([args]): a TV or
/// a phone, tablet or Chromebook; an Android build with no word from it is
/// a TV, as every build was before ADR-068. Every other platform gets the
/// desktop shell.
///
/// Outside release builds, `--dart-define=FORM_FACTOR=tv` (or `mobile`)
/// forces a form factor, to try those layouts on the laptop.
FormFactor detectFormFactor({
  required TargetPlatform platform,
  List<String> args = const [],
  String override = const String.fromEnvironment('FORM_FACTOR'),
  bool allowOverride = !kReleaseMode,
}) {
  if (allowOverride) {
    for (final formFactor in FormFactor.values) {
      if (formFactor.name == override) return formFactor;
    }
  }
  if (platform != TargetPlatform.android) return FormFactor.desktop;
  for (final arg in args) {
    if (!arg.startsWith(formFactorArgument)) continue;
    final named = arg.substring(formFactorArgument.length);
    for (final formFactor in [FormFactor.tv, FormFactor.mobile]) {
      if (formFactor.name == named) return formFactor;
    }
  }
  return FormFactor.tv;
}
