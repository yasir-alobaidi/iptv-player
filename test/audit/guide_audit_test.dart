import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:iptv_player/app/destinations.dart';
import 'package:iptv_player/features/reminders/data/reminder_providers.dart';
import 'package:iptv_player/features/reminders/presentation/reminder_text.dart';
import 'package:iptv_player/features/sources/presentation/source_shell_slots.dart';

import '../app/app_harness.dart';
import '../features/guide/guide_grid_fakes.dart';
import '../features/reminders/reminder_fakes.dart';
import 'audit_harness.dart';

/// The Guide in the audit (Phase 9 decision 14): the canvas's evening,
/// Tuesday 15 at 9:22 PM.
void main() {
  Future<GuideFixture> open(
    WidgetTester tester,
    AuditLook look, {
    bool guide = true,
    FakeReminders? reminders,
  }) async {
    final fixture = GuideFixture();
    addTearDown(() => tester.runAsync(fixture.db.close));
    await tester.runAsync(() => fixture.seed(guide: guide));
    await pumpApp(
      tester,
      size: look.size,
      initialLocation: AppDestination.guide.path,
      overrides: [
        ...fixture.overrides,
        ...sourceShellOverrides,
        reminderRepositoryProvider.overrideWithValue(
          reminders ?? FakeReminders(),
        ),
      ],
    );
    await auditSettle(tester);
    return fixture;
  }

  FakeReminders three() => FakeReminders()
    ..add(
      start: GuideFixture.at(22),
      length: const Duration(minutes: 90),
      title: 'Match of the Week: Extended Highlights',
      channelName: 'Arena Sports 1',
      channelKey: '201',
      xmltvId: 'arena1',
    )
    ..add(
      start: GuideFixture.at(22, 5),
      title: 'Harbor to Harbor',
      channelKey: '208',
      xmltvId: 'bluewater',
    )
    ..add(
      start: GuideFixture.at(4 * 24 + 10),
      title: 'Weekend Preview',
      channelName: 'Arena Sports 1',
      channelKey: '201',
      xmltvId: 'arena1',
    );

  auditScreen('the Guide', [
    AuditScene('the grid', open),
    AuditScene(
      'the grid with reminders',
      (tester, look) => open(tester, look, reminders: three()),
    ),
    AuditScene(
      'no guide yet',
      (tester, look) => open(tester, look, guide: false),
    ),
    AuditScene("a programme's sheet", (tester, look) async {
      await open(tester, look, reminders: three());
      await tester.sendKeyEvent(LogicalKeyboardKey.arrowRight);
      await auditSettle(tester);
      await tester.sendKeyEvent(LogicalKeyboardKey.enter);
      await auditSettle(tester);
    }),
    AuditScene('Reminders', (tester, look) async {
      await open(tester, look, reminders: three());
      await tester.tap(findByLabel(remindersButtonLabel(3)));
      await auditSettle(tester);
    }),
    AuditScene('Reminders, none set', (tester, look) async {
      await open(tester, look);
      await tester.tap(findByLabel(remindersButtonLabel(0)));
      await auditSettle(tester);
    }),
  ]);
}
