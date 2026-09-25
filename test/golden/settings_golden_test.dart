// Every test in this file is a golden; the tag is declared in
// dart_test.yaml so `flutter test --exclude-tags golden` can drop them
// on Windows.
@Tags(['golden'])
library;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:iptv_player/app/destinations.dart';
import 'package:iptv_player/features/guide/domain/epg.dart';
import 'package:iptv_player/features/guide/domain/epg_matcher.dart';
import 'package:iptv_player/features/settings/presentation/settings_screen.dart';
import 'package:iptv_player/features/sources/domain/provider_account.dart';
import 'package:iptv_player/features/sources/domain/source.dart';
import 'package:iptv_player/features/sources/domain/source_overview.dart';
import 'package:iptv_player/features/sources/presentation/source_shell_slots.dart';

import '../app/app_harness.dart';
import '../features/guide/presentation/guide_settings_fakes.dart';
import '../features/live_tv/live_tv_fakes.dart';
import '../features/onboarding/onboarding_fakes.dart';
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

    testWidgets('Sources', (tester) async {
      hideDebugBanner();
      await pumpApp(
        tester,
        initialLocation: AppDestination.settings.path,
        overrides: [...sketch().overrides, ...sourceShellOverrides],
      );

      await expectLater(
        find.byType(MaterialApp),
        matchesGoldenFile('images/settings_sources.png'),
      );
    });

    testWidgets('Categories', (tester) async {
      hideDebugBanner();
      final fakes = sketch();
      await fakes.categories.rename(9, 'Radio & music');
      await pumpApp(
        tester,
        initialLocation: AppDestination.settings.path,
        overrides: [...fakes.overrides, ...sourceShellOverrides],
      );
      await tester.tap(find.text('Categories').first);
      await settleApp(tester);

      await expectLater(
        find.byType(MaterialApp),
        matchesGoldenFile('images/settings_categories.png'),
      );
    });

    testWidgets('Playback', (tester) async {
      hideDebugBanner();
      final live = LiveTvFakes();
      addTearDown(() => tester.runAsync(live.db.close));
      await tester.runAsync(live.seed);
      await pumpApp(
        tester,
        initialLocation: AppDestination.settings.path,
        overrides: [...live.overrides, ...sourceShellOverrides],
      );
      await tester.tap(find.text('Playback').first);
      for (var i = 0; i < 5; i++) {
        await tester.runAsync(() => Future<void>.delayed(Duration.zero));
        await tester.pump(const Duration(milliseconds: 50));
      }

      await expectLater(
        find.byType(MaterialApp),
        matchesGoldenFile('images/settings_playback.png'),
      );
    });

    testWidgets('Guide', (tester) async {
      hideDebugBanner();
      final base = sketch();
      final fakes = GuideFakes(base);
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

      await expectLater(
        find.byType(MaterialApp),
        matchesGoldenFile('images/settings_guide.png'),
      );
    });
  }, skip: goldenSkipReason);
}
