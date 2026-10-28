// Every test in this file is a golden; the tag is declared in
// dart_test.yaml so `flutter test --exclude-tags golden` can drop them
// on Windows.
@Tags(['golden'])
library;

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:iptv_player/app/destinations.dart';
import 'package:iptv_player/core/core_providers.dart';
import 'package:iptv_player/core/images/artwork_store.dart';
import 'package:iptv_player/core/platform/app_version.dart';
import 'package:iptv_player/core/platform/licenses.dart';
import 'package:iptv_player/design/appearance.dart';
import 'package:iptv_player/design/tokens.dart';
import 'package:iptv_player/features/diagnostics/domain/log_lines.dart';
import 'package:iptv_player/features/guide/domain/epg.dart';
import 'package:iptv_player/features/guide/domain/epg_matcher.dart';
import 'package:iptv_player/features/guide/domain/guide_settings.dart';
import 'package:iptv_player/features/settings/data/data_providers.dart';
import 'package:iptv_player/features/settings/domain/settings_transfer.dart';
import 'package:iptv_player/features/settings/presentation/data_section.dart';
import 'package:iptv_player/features/settings/presentation/settings_screen.dart';
import 'package:iptv_player/features/sources/domain/provider_account.dart';
import 'package:iptv_player/features/sources/domain/source.dart';
import 'package:iptv_player/features/sources/domain/source_overview.dart';
import 'package:iptv_player/features/sources/presentation/source_shell_slots.dart';

import '../app/app_harness.dart';
import '../features/diagnostics/diagnostics_fakes.dart';
import '../features/guide/presentation/guide_settings_fakes.dart';
import '../features/live_tv/live_tv_fakes.dart';
import '../features/onboarding/onboarding_fakes.dart';
import '../features/settings/appearance_fakes.dart';
import '../features/settings/data_fakes.dart';
import 'golden_harness.dart';

void main() {
  group('settings', () {
    /// The sketch's two sources: one healthy, one whose last try failed.
    OnboardingFakes sketch() {
      final fakes = OnboardingFakes();
      fakes.sources
        ..seed(lastSyncedAt: fakes.now.subtract(const Duration(minutes: 12)))
        ..seed(id: 'src-2', type: SourceType.m3uUrl, name: 'Backup playlist');
      fakes.overviews
        ..set(
          'src-1',
          SourceOverview(
            account: ProviderAccount(
              status: 'Active',
              expiresAt: DateTime.utc(2026, 11, 3, 12),
            ),
            counts: const SourceCounts(
              channels: 12340,
              movies: 8021,
              series: 1204,
            ),
            lastSync: LastSync(
              outcome: LastSyncOutcome.succeeded,
              startedAt: fakes.now.subtract(const Duration(minutes: 13)),
            ),
          ),
        )
        ..set(
          'src-2',
          SourceOverview(
            lastSync: LastSync(
              outcome: LastSyncOutcome.failed,
              startedAt: fakes.now.subtract(const Duration(hours: 1)),
              failureCode: 'timeout',
            ),
          ),
        );
      fakes.categories.lists.addAll(sampleCategories());
      return fakes;
    }

    sceneTest('Sources', (tester) async {
      hideDebugBanner();
      await pumpApp(
        tester,
        initialLocation: AppDestination.settings.path,
        overrides: [...sketch().overrides, ...sourceShellOverrides],
      );
      // A phone's Settings opens on its list of sections (ADR-068).
      if (find.text('Add source').evaluate().isEmpty) {
        await tapShown(tester, find.text('Sources').first);
        await settleApp(tester);
      }

      await golden(tester, 'images/settings_sources.png');
    });

    sceneTest('Categories', (tester) async {
      hideDebugBanner();
      final fakes = sketch();
      await fakes.categories.rename(9, 'Radio & music');
      await pumpApp(
        tester,
        initialLocation: AppDestination.settings.path,
        overrides: [...fakes.overrides, ...sourceShellOverrides],
      );
      await tapShown(tester, find.text('Categories').first);
      await settleApp(tester);

      await golden(tester, 'images/settings_categories.png');
    });

    sceneTest('Playback', (tester) async {
      hideDebugBanner();
      final live = LiveTvFakes();
      addTearDown(() => tester.runAsync(live.db.close));
      await tester.runAsync(live.seed);
      await pumpApp(
        tester,
        initialLocation: AppDestination.settings.path,
        overrides: [...live.overrides, ...sourceShellOverrides],
      );
      await tapShown(tester, find.text('Playback').first);
      for (var i = 0; i < 5; i++) {
        await tester.runAsync(() => Future<void>.delayed(Duration.zero));
        await tester.pump(const Duration(milliseconds: 50));
      }

      await golden(tester, 'images/settings_playback.png');
    });

    /// Settings → Guide with a guide of 1,290 channels; [guideOn] false,
    /// the guide's switch off (its default, ADR-031) and nothing else.
    Future<void> guidePage(WidgetTester tester, {bool guideOn = true}) async {
      hideDebugBanner();
      final base = sketch();
      final fakes = GuideFakes(base);
      if (guideOn) {
        fakes.settingsStore.stored = const GuideSettings(enabled: true);
      }
      final updated = base.now.subtract(const Duration(hours: 2));
      fakes.guide
        ..setCoverage(
          'src-1',
          GuideCoverage(
            lastImport: GuideImport(
              id: 4,
              outcome: GuideImportOutcome.succeeded,
              startedAt: updated,
              finishedAt: updated,
              isLive: true,
            ),
            updatedAt: updated,
            guideChannels: 1290,
            programmes: 142880,
            lastEnd: DateTime.utc(2026, 9, 21, 12),
          ),
        )
        ..setChannels('src-1', [
          guideRow(1, 'Arena Sports 1'),
          guideRow(2, 'Velocity Motors HD'),
          guideRow(3, 'Harbour News 24'),
          guideRow(
            4,
            'Summit Outdoor',
            xmltvId: 'summit.outdoor.uk',
            rule: GuideMatchRule.manual,
            guideLabel: 'Summit Outdoor',
          ),
          for (var i = 5; i < 40; i++)
            guideRow(i, 'Channel $i', xmltvId: 'channel$i.uk'),
        ]);
      await pumpApp(
        tester,
        initialLocation: AppDestination.settings.path,
        overrides: [...fakes.overrides, ...sourceShellOverrides],
      );
      await tester.tap(
        find.descendant(
          of: find.byType(SettingsScreen),
          matching: find.text('Guide'),
        ),
      );
      await settleApp(tester);
      await settleApp(tester);
    }

    sceneTest('Guide', (tester) async {
      await guidePage(tester);

      await golden(tester, 'images/settings_guide.png');
    });

    sceneTest('Guide, switched off', (tester) async {
      await guidePage(tester, guideOn: false);

      await golden(tester, 'images/settings_guide_off.png');
    });

    /// Settings → Appearance with [settings] in use, at 8:05 in the
    /// evening wherever the test runs.
    Future<void> appearance(
      WidgetTester tester, {
      AppearanceSettings settings = const AppearanceSettings(),
      Size size = const Size(1440, 900),
    }) async {
      hideDebugBanner();
      final fakes = sketch()..now = DateTime(2026, 9, 14, 20, 5);
      await pumpApp(
        tester,
        initialLocation: AppDestination.settings.path,
        size: size,
        withAppearance: true,
        overrides: [
          ...fakes.overrides,
          ...sourceShellOverrides,
          ...appearanceOverrides(settings: settings),
        ],
      );
      await tapShown(tester, find.text('Appearance').first);
      await settleApp(tester);
    }

    sceneTest('Appearance', (tester) async {
      await appearance(tester);

      await golden(tester, 'images/settings_appearance.png');
    });

    sceneTest('Keyboard shortcuts', phone: false, (tester) async {
      hideDebugBanner();
      await pumpApp(
        tester,
        initialLocation: AppDestination.settings.path,
        overrides: [...sketch().overrides, ...sourceShellOverrides],
      );
      await tapShown(tester, find.text('Keyboard shortcuts').first);
      await settleApp(tester);

      await golden(tester, 'images/settings_shortcuts.png');
    });

    sceneTest(
      'the F1 panel, over Settings in the smallest window',
      phone: false,
      (tester) async {
        hideDebugBanner();
        await pumpApp(
          tester,
          size: const Size(1024, 640),
          initialLocation: AppDestination.settings.path,
          overrides: [...sketch().overrides, ...sourceShellOverrides],
        );
        await tester.sendKeyEvent(LogicalKeyboardKey.f1);
        await settleApp(tester);
        // Once more: the list takes the focus when it opens, and its ring
        // is drawn the frame after.
        await settleApp(tester);

        await golden(tester, 'images/shortcuts_panel_1024x640.png');
      },
    );

    /// Settings → Data, with 412 MB of pictures and a guide (switched on:
    /// one is kept only then, ADR-031); Import… answers with sketch C's
    /// file.
    Future<void> data(WidgetTester tester) async {
      hideDebugBanner();
      final base = sketch();
      final fakes = GuideFakes(base)
        ..settingsStore.stored = const GuideSettings(enabled: true);
      final updated = base.now.subtract(const Duration(hours: 2));
      fakes.guide.setCoverage(
        'src-1',
        GuideCoverage(
          lastImport: GuideImport(
            id: 4,
            outcome: GuideImportOutcome.succeeded,
            startedAt: updated,
            finishedAt: updated,
            isLive: true,
          ),
          updatedAt: updated,
          guideChannels: 1290,
          programmes: 142880,
          lastEnd: DateTime(2026, 10, 19, 6),
        ),
      );
      await pumpApp(
        tester,
        initialLocation: AppDestination.settings.path,
        overrides: [
          ...fakes.overrides,
          ...sourceShellOverrides,
          artworkStoreProvider.overrideWithValue(FakeArtworkStore()),
          settingsTransferProvider.overrideWithValue(
            FakeTransfer()..reading = SettingsFileReadable(sketchPlan()),
          ),
          settingsOpenPickerProvider.overrideWithValue(
            () async => sketchPlan().path,
          ),
          dataUpkeepProvider.overrideWithValue(FakeDataUpkeep()),
        ],
      );
      await tapShown(tester, find.text('Data').first);
      await settleApp(tester);
      await settleApp(tester);
    }

    sceneTest('Data', (tester) async {
      await data(tester);

      await golden(tester, 'images/settings_data.png');
    });

    sceneTest("Data: an import's preview", phone: false, (tester) async {
      await data(tester);
      // In the smallest window at the largest text its row is past what
      // the list has built yet.
      await tester.scrollUntilVisible(
        find.text('Import…'),
        120,
        scrollable: find
            .descendant(
              of: find.byType(DataSection),
              matching: find.byType(Scrollable),
            )
            .first,
      );
      await tapShown(tester, find.text('Import…'));
      await settleApp(tester);
      await settleApp(tester);

      await golden(tester, 'images/settings_data_import.png');
    });

    sceneTest('Data: what Clear watch history clears', (tester) async {
      await data(tester);
      // On a phone its row is past what the list has built yet.
      if (find.text('Clear…').evaluate().isEmpty) {
        await tester.scrollUntilVisible(
          find.text('Clear…'),
          120,
          scrollable: find
              .descendant(
                of: find.byType(DataSection),
                matching: find.byType(Scrollable),
              )
              .first,
        );
      }
      await tapShown(tester, find.text('Clear…'));
      await settleApp(tester);
      await settleApp(tester);

      await golden(tester, 'images/settings_data_history.png');
    });

    /// Settings → About & diagnostics, as a 0.1.0 build on Linux.
    Future<void> about(WidgetTester tester) async {
      hideDebugBanner();
      debugDefaultTargetPlatformOverride = TargetPlatform.linux;
      await pumpApp(
        tester,
        initialLocation: AppDestination.settings.path,
        overrides: [
          ...sketch().overrides,
          ...sourceShellOverrides,
          ...diagnosticsOverrides(
            diagnostics: FakeDiagnostics(),
            log: FakeLogReader([
              logRow(0, tag: 'bootstrap', text: 'Starting IPTV Player'),
              logRow(3, text: 'Opening channel 147'),
              logRow(4, text: 'First frame after 961 ms'),
              logRow(
                7,
                level: LogLevel.warning,
                tag: 'watchdog',
                text: 'Stalled for 4 s, reconnecting (1 of 6)',
              ),
              logRow(8, text: 'First frame after 1,204 ms'),
              logRow(
                12,
                level: LogLevel.error,
                tag: 'sync',
                text: 'The sync failed',
              ),
              const LogRow(
                level: LogLevel.error,
                text: 'error: TimeoutException after 0:00:30.000000',
                continuation: true,
              ),
              logRow(15, tag: 'epg', text: 'Guide updated · 1,284 matched'),
            ]),
          ),
          appVersionProvider.overrideWith(
            (ref) async => const AppVersion(version: '0.1.0', build: '1'),
          ),
          licensesProvider.overrideWith(
            (ref) async => const [
              PackageLicenses('FFmpeg', [
                LicenseEntryWithLineBreaks(
                  ['FFmpeg'],
                  'IPTV Player runs the ffmpeg and ffprobe programs as '
                  'separate processes, to read what a stream or a file '
                  'holds, to convert it for a TV when casting, and to save '
                  'downloads.\n\nGNU GENERAL PUBLIC LICENSE\n'
                  'Version 3, 29 June 2007',
                ),
              ]),
              PackageLicenses('flutter', [
                LicenseEntryWithLineBreaks(['flutter'], 'Flutter terms'),
              ]),
              PackageLicenses('JetBrains Mono', [
                LicenseEntryWithLineBreaks(['JetBrains Mono'], 'OFL'),
              ]),
              PackageLicenses('Manrope', [
                LicenseEntryWithLineBreaks(['Manrope'], 'OFL'),
              ]),
              PackageLicenses('mpv (libmpv)', [
                LicenseEntryWithLineBreaks(['mpv (libmpv)'], 'LGPL'),
              ]),
            ],
          ),
        ],
      );
      await tapShown(tester, find.text('About & diagnostics').first);
      await settleApp(tester);
    }

    sceneTest('About', (tester) async {
      await about(tester);

      await golden(tester, 'images/settings_about.png');
      debugDefaultTargetPlatformOverride = null;
    });

    sceneTest('About: the log', (tester) async {
      await about(tester);
      await tapShown(tester, find.text('Log'));
      await settleApp(tester);
      await settleApp(tester);

      await golden(tester, 'images/settings_about_log.png');
      debugDefaultTargetPlatformOverride = null;
    });

    sceneTest('Licences', (tester) async {
      await about(tester);
      await tapShown(tester, find.text('Licences'));
      await settleApp(tester);
      await settleApp(tester);

      await golden(tester, 'images/settings_licences.png');
      debugDefaultTargetPlatformOverride = null;
    });

    sceneTest('Appearance at 130 %, Compact, Rose, 24-hour, in the '
        'smallest window', (tester) async {
      await appearance(
        tester,
        size: const Size(1024, 640),
        settings: const AppearanceSettings(
          accent: AppAccent.rose,
          textSize: TextSizeChoice.s130,
          density: AppDensity.compact,
          reduceMotion: SystemSwitch.on,
          clock: ClockChoice.h24,
        ),
      );

      await golden(tester, 'images/settings_appearance_130_1024x640.png');
    });
  }, skip: goldenSkipReason);
}
