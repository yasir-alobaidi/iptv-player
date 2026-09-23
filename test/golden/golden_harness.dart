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

/// The moment a golden is drawn at, as a *local* wall-clock time.
///
/// Screens show times in the viewer's zone, so a golden pinned to an
/// instant draws different clock labels in every zone: the Phase 3
/// images, recorded here in America/New_York, failed on the UTC runner.
/// A local 8 AM is the same instant the fakes' 12:00 UTC was when they
/// were recorded, and 8 AM wherever the test runs.
DateTime goldenNow() => DateTime(2026, 9, 14, 8);
