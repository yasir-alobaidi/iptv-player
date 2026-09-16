import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

/// Adds the bundled fonts' OFL licences to Flutter's licence page. Called
/// once from bootstrap; calling it again is harmless but wasteful, so it
/// guards itself.
void registerBundledFontLicenses() {
  if (_registered) return;
  _registered = true;
  LicenseRegistry.addLicense(() async* {
    for (final font in _licenses.entries) {
      final text = await rootBundle.loadString(font.value);
      yield LicenseEntryWithLineBreaks([font.key], text);
    }
  });
}

@visibleForTesting
void resetBundledFontLicensesForTest() => _registered = false;

bool _registered = false;

const _licenses = {
  'Manrope': 'assets/fonts/Manrope-OFL.txt',
  'JetBrains Mono': 'assets/fonts/JetBrainsMono-OFL.txt',
};
