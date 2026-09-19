// Every test in this file is a golden; the tag is declared in
// dart_test.yaml so `flutter test --exclude-tags golden` can drop them
// on Windows.
@Tags(['golden'])
library;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:iptv_player/app/destinations.dart';
import 'package:iptv_player/features/sources/domain/provider_account.dart';
import 'package:iptv_player/features/sources/domain/source.dart';
import 'package:iptv_player/features/sources/domain/source_overview.dart';
import 'package:iptv_player/features/sources/presentation/source_shell_slots.dart';

import '../app/app_harness.dart';
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
  }, skip: goldenSkipReason);
}
