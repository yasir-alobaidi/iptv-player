import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../audit/audit_harness.dart';

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

/// A golden that is also an audit scene (Phase 9 decision 14): [body]
/// runs once as itself and is compared with its picture, then once in
/// each of the audit's looks, where its [golden] is the audit's look at
/// the screen instead of a comparison. So a screen that has a golden is
/// checked at every text size and by keyboard with nothing more written.
///
/// [audit] false for a second size of the same scene (the audit has its
/// own windows) and for a golden that is about a look of its own.
/// [allow] and [keyboard] as on an `AuditScene`.
void sceneTest(
  String description,
  Future<void> Function(WidgetTester tester) body, {
  bool audit = true,
  Map<String, String> allow = const {},
  bool keyboard = true,
}) {
  testWidgets(description, body);
  if (!audit) return;
  // The file the scene is in names its pictures (`AUDIT_SHOTS`): two
  // files may each have a scene called "content".
  final file = RegExp(r'(\w+?)(_golden)?_test\.dart')
      .firstMatch('${StackTrace.current}'.split('\n').skip(1).join('\n'))?[1];
  for (final look in auditLooks) {
    testWidgets('$description — audit, ${look.name}', (tester) async {
      final scene = '${file ?? 'scene'} $description';
      final findings = await auditRun(tester, look, name: scene, (check) async {
        _auditCheck = () => check(keyboard: keyboard);
        try {
          await body(tester);
        } finally {
          _auditCheck = null;
        }
      });
      auditReport(description, look, findings, allow: allow);
    });
  }
}

Future<void> Function()? _auditCheck;

/// The app as drawn now against the picture at [name]; while the audit
/// runs a scene, the audit's checks of what is drawn.
Future<void> golden(WidgetTester tester, String name) async {
  final check = _auditCheck;
  if (check != null) {
    await check();
    return;
  }
  await expectLater(find.byType(MaterialApp), matchesGoldenFile(name));
}

/// Taps [finder] once it is on screen: in the audit's smallest window, at
/// its largest text, a scene's control can be below the fold of a list
/// that scrolls.
Future<void> tapShown(WidgetTester tester, Finder finder) async {
  await tester.ensureVisible(finder);
  await tester.pump();
  await tester.tap(finder);
}
