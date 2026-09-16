import 'dart:async';
import 'dart:io';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:iptv_player/design/tokens.dart';

/// Runs once per test file, before any test in it.
///
/// Its only job is the bundled fonts: without them `flutter test`
/// rasterizes every glyph as an Ahem box, so goldens would record
/// rectangles instead of type and any layout that depends on real text
/// metrics would be measured against the wrong font. Everything else is
/// left to the tests themselves — this hook is on the path of the whole
/// suite.
Future<void> testExecutable(FutureOr<void> Function() testMain) async {
  // FontLoader needs a binding to publish the font change to; tests that
  // use `testWidgets` would create the same one anyway.
  TestWidgetsFlutterBinding.ensureInitialized();
  await _loadBundledFonts();
  await testMain();
}

/// The families the theme names (`AppFonts`) mapped to the variable font
/// files `pubspec.yaml` bundles for them.
const _bundledFonts = <String, String>{
  AppFonts.sans: 'assets/fonts/Manrope[wght].ttf',
  AppFonts.mono: 'assets/fonts/JetBrainsMono[wght].ttf',
};

/// Loaded from disk rather than through `rootBundle`: the test runner's
/// working directory is the package root, and this needs no asset
/// manifest to be built first.
Future<void> _loadBundledFonts() async {
  for (final font in _bundledFonts.entries) {
    final loader = FontLoader(font.key)
      ..addFont(File(font.value).readAsBytes().then(ByteData.sublistView));
    await loader.load();
  }
}
