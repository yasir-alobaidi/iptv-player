import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// Why the goldens are skipped, or null when they should run.
///
/// The reference images are recorded on Linux. Windows rasterizes the
/// same text with different hinting, a per-pixel difference on every
/// glyph, so the Windows CI job excludes the `golden` tag and a local
/// Windows run skips with this reason instead of failing (ADR-008).
final String? goldenSkipReason = Platform.isLinux
    ? null
    : 'Goldens are recorded on Linux only: text rasterization differs on '
          'this platform (ADR-008).';

/// Keeps the debug-mode banner out of the corner of a golden.
///
/// The app's `MaterialApp` leaves the banner on, which is right for a
/// debug run and only noise in a reference image; this is the global
/// switch Flutter provides for exactly that, so no test has to rebuild
/// the app to turn it off.
void hideDebugBanner() {
  WidgetsApp.debugAllowBannerOverride = false;
  addTearDown(() => WidgetsApp.debugAllowBannerOverride = true);
}
