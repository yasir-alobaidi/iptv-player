import 'package:flutter/foundation.dart';

enum FormFactor {
  desktop,
  tv;

  /// The device in the app's words: "this computer", "this TV".
  String get thisDevice => switch (this) {
    desktop => 'this computer',
    tv => 'this TV',
  };
}

/// Chooses the shell. Android means Google TV in this project (phones are a
/// non-goal); every other platform gets the desktop shell.
///
/// Outside release builds, `--dart-define=FORM_FACTOR=tv` forces a form
/// factor, to try TV layouts on the laptop.
FormFactor detectFormFactor({
  required TargetPlatform platform,
  String override = const String.fromEnvironment('FORM_FACTOR'),
  bool allowOverride = !kReleaseMode,
}) {
  if (allowOverride) {
    for (final formFactor in FormFactor.values) {
      if (formFactor.name == override) return formFactor;
    }
  }
  return platform == TargetPlatform.android
      ? FormFactor.tv
      : FormFactor.desktop;
}
