// Every test in this file is a golden; the tag is declared in
// dart_test.yaml so `flutter test --exclude-tags golden` can drop them
// on Windows.
@Tags(['golden'])
library;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:iptv_player/app/destinations.dart';
import 'package:iptv_player/design/appearance.dart';
import 'package:iptv_player/design/components.dart';
import 'package:iptv_player/features/guide/presentation/guide_settings.dart';
import 'package:iptv_player/features/reminders/data/reminder_providers.dart';
import 'package:iptv_player/features/reminders/presentation/reminder_text.dart';
import 'package:iptv_player/features/settings/presentation/settings_section.dart';
import 'package:iptv_player/features/sources/presentation/source_shell_slots.dart';

import '../app/app_harness.dart';
import '../features/guide/guide_grid_fakes.dart';
import '../features/reminders/reminder_fakes.dart';
import '../features/settings/appearance_fakes.dart';
import 'golden_harness.dart';

/// Reminders on screen (Phase 9 decision 13, sketches G and H), on the
/// canvas's Guide: Tuesday 15 at 9:22 PM, three reminders set.
void main() {
  /// The Guide with its three reminders, the keyboard in the grid; or,
  /// with [inSettings], Settings → Guide, where their second door is.
  Future<void> open(
    WidgetTester tester, {
    Size size = const Size(1280, 800),
    AppearanceSettings? look,
    bool inSettings = false,
  }) async {
    hideDebugBanner();
    final fixture = GuideFixture();
    addTearDown(() => tester.runAsync(fixture.db.close));
    await tester.runAsync(fixture.seed);
    final reminders = FakeReminders()
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
    final app = await pumpApp(
      tester,
      size: size,
      initialLocation: inSettings ? '/' : AppDestination.guide.path,
      withAppearance: look != null,
      overrides: [
        ...fixture.overrides,
        ...sourceShellOverrides,
        reminderRepositoryProvider.overrideWithValue(reminders),
        if (look != null) ...appearanceOverrides(settings: look),
      ],
    );
    await _settle(tester);
    if (inSettings) {
      ProviderScope.containerOf(tester.element(find.byType(Navigator).first))
          .read(settingsLocationProvider.notifier)
          .showGuide('src-1');
      app.router.go(AppDestination.settings.path);
      await _settle(tester);
      return;
    }
    tester
        .widget<Focus>(
          find.byWidgetPredicate(
            (w) => w is Focus && w.focusNode?.debugLabel == 'guide grid',
          ),
        )
        .focusNode!
        .requestFocus();
    await _settle(tester);
  }

  group('reminders', () {
    sceneTest('the Guide: a bell in each cell that has one, and their '
        'count in the toolbar', (tester) async {
      await open(tester);

      await golden(tester, 'images/reminders_guide_1280x800.png');
    });

    sceneTest("a programme's sheet, its reminder set", (tester) async {
      await open(tester);
      await tester.sendKeyEvent(LogicalKeyboardKey.arrowRight);
      await _settle(tester);
      await tester.sendKeyEvent(LogicalKeyboardKey.enter);
      await _settle(tester);
      // The ring is drawn the frame after the focus lands.
      await settleApp(tester);

      await golden(tester, 'images/reminders_sheet.png');
    });

    sceneTest('the list', (tester) async {
      await open(tester);
      await tester.tap(findByLabel(remindersButtonLabel(3)));
      await _settle(tester);
      await settleApp(tester);

      await golden(tester, 'images/reminders_list.png');
    });

    // Decision 3: at 130 % a row grows with its text, and the smallest
    // window still holds the list, its hints and Close. Opened by its
    // second door: the Guide's own rows don't grow with the text until
    // the audit (step 7).
    sceneTest('the list at 130 % in the smallest window, from Settings → '
        'Guide', (tester) async {
      await open(
        tester,
        size: const Size(1024, 640),
        look: const AppearanceSettings(textSize: TextSizeChoice.s130),
        inSettings: true,
      );
      expect(tester.takeException(), isNull, reason: 'Settings → Guide');
      // The page scrolls as a whole in this window, and its list builds
      // only what is near the screen: the row is scrolled to.
      await tester.scrollUntilVisible(
        find.widgetWithText(AppButton, 'Manage'),
        100,
        scrollable: find
            .descendant(
              of: find.byType(GuideSettingsSection),
              matching: find.byType(Scrollable),
            )
            .first,
      );
      await _settle(tester);
      await tester.tap(find.widgetWithText(AppButton, 'Manage'));
      await _settle(tester);
      await settleApp(tester);

      expect(tester.takeException(), isNull);
      await golden(tester, 'images/reminders_list_130_1024x640.png');
    });
  }, skip: goldenSkipReason);
}

Future<void> _settle(WidgetTester tester) async {
  for (var i = 0; i < 5; i++) {
    await tester.runAsync(() => Future<void>.delayed(Duration.zero));
    await tester.pump(const Duration(milliseconds: 50));
  }
}
