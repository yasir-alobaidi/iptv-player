import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:iptv_player/app/destinations.dart';
import 'package:iptv_player/app/router.dart';
import 'package:iptv_player/app/shell/desktop_shell.dart';
import 'package:iptv_player/app/shell/shell_state.dart';
import 'package:iptv_player/core/settings/ui_preferences.dart';
import 'package:iptv_player/features/settings/presentation/settings_section.dart';
import 'package:iptv_player/features/sources/domain/provider_account.dart';
import 'package:iptv_player/features/sources/domain/source_overview.dart';
import 'package:iptv_player/features/sources/domain/sync.dart';
import 'package:iptv_player/features/sources/presentation/source_shell_slots.dart';

import '../../../app/app_harness.dart';
import '../../onboarding/onboarding_fakes.dart';

void main() {
  late OnboardingFakes fakes;
  late InMemoryUiPreferences preferences;
  setUp(() {
    fakes = OnboardingFakes();
    preferences = InMemoryUiPreferences();
  });

  Future<AppUnderTest> pump(WidgetTester tester) => pumpApp(
    tester,
    overrides: [
      ...fakes.overrides,
      ...sourceShellOverrides,
      uiPreferencesProvider.overrideWithValue(preferences),
    ],
  );

  ProviderContainer containerOf(WidgetTester tester) =>
      ProviderScope.containerOf(tester.element(find.byType(DesktopShell)));

  SourceOverview accountEnding(DateTime at, {String status = 'Active'}) =>
      SourceOverview(
        account: ProviderAccount(status: status, expiresAt: at),
      );

  group('source chip', () {
    testWidgets('with no source it reads "No source"', (tester) async {
      await pump(tester);

      expect(findByLabel('Source: No source'), findsOneWidget);
    });

    testWidgets('one source: its name; a press opens Settings → Sources', (
      tester,
    ) async {
      fakes.sources.seed();
      final app = await pump(tester);

      expect(findByLabel('Source: Northwind TV'), findsOneWidget);
      await tester.tap(findByLabel('Source: Northwind TV'));
      await settleApp(tester);

      expect(app.location, AppDestination.settings.path);
      expect(
        containerOf(tester).read(settingsLocationProvider).section,
        SettingsSection.sources,
      );
    });

    testWidgets('two sources: a menu switches, and the choice is kept', (
      tester,
    ) async {
      fakes.sources
        ..seed()
        ..seed(id: 'src-2', name: 'Backup');
      await pump(tester);

      await tester.tap(findByLabel('Source: Northwind TV'));
      await settleApp(tester);
      expect(find.text('Manage sources…'), findsOneWidget);
      // Arrows walk the menu; Enter picks.
      await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
      await tester.sendKeyEvent(LogicalKeyboardKey.enter);
      await settleApp(tester);

      expect(findByLabel('Source: Backup'), findsOneWidget);
      expect(find.text('Manage sources…'), findsNothing);
      expect(preferences.currentSourceId, 'src-2');
    });

    testWidgets('Esc closes the switcher and leaves the source alone', (
      tester,
    ) async {
      fakes.sources
        ..seed()
        ..seed(id: 'src-2', name: 'Backup');
      await pump(tester);

      await tester.tap(findByLabel('Source: Northwind TV'));
      await settleApp(tester);
      await tester.sendKeyEvent(LogicalKeyboardKey.escape);
      await settleApp(tester);

      expect(find.text('Manage sources…'), findsNothing);
      expect(findByLabel('Source: Northwind TV'), findsOneWidget);
    });

    testWidgets('the dot turns amber after a failed sync', (tester) async {
      fakes.sources.seed();
      fakes.overviews.set(
        'src-1',
        SourceOverview(
          lastSync: LastSync(
            outcome: LastSyncOutcome.failed,
            startedAt: fakes.now,
            failureCode: 'network',
          ),
        ),
      );
      await pump(tester);

      expect(containerOf(tester).read(shellSourceProvider)!.connected, false);
    });
  });

  group('sync status', () {
    testWidgets('shows while a sync runs, then goes', (tester) async {
      fakes.sources.seed();
      await pump(tester);
      expect(find.text('Signing in'), findsNothing);

      fakes.sync.emit(
        'src-1',
        const SyncRunning(SyncProgress(stage: SyncStage.account)),
      );
      await settleApp(tester);
      expect(find.text('Signing in'), findsOneWidget);

      fakes.sync.emit(
        'src-1',
        const SyncRunning(SyncProgress(stage: SyncStage.movies, movies: 8021)),
      );
      await tester.pump();
      expect(find.text('Syncing movies · 8,021'), findsOneWidget);

      fakes.sync.emit('src-1', const SyncSucceeded(SyncReport()));
      await tester.pump();
      expect(find.textContaining('Syncing'), findsNothing);
    });
  });

  group('notice banner', () {
    testWidgets('an account ending within a week warns, and can be closed', (
      tester,
    ) async {
      fakes.sources.seed();
      fakes.overviews.set(
        'src-1',
        accountEnding(fakes.now.add(const Duration(days: 3, hours: 2))),
      );
      await pump(tester);

      expect(
        find.textContaining('Your Northwind TV subscription ends in 3 days'),
        findsOneWidget,
      );
      await tester.tap(findByLabel('Dismiss'));
      await settleApp(tester);
      expect(find.textContaining('subscription ends'), findsNothing);
    });

    testWidgets('an expired account is an error with Open Sources', (
      tester,
    ) async {
      fakes.sources.seed();
      fakes.overviews.set(
        'src-1',
        accountEnding(DateTime.utc(2026, 9, 1, 12), status: 'Expired'),
      );
      final app = await pump(tester);

      expect(
        find.text('Your Northwind TV subscription expired on Sep 1, 2026.'),
        findsOneWidget,
      );
      await tester.tap(find.text('Open Sources'));
      await settleApp(tester);
      expect(app.location, AppDestination.settings.path);
    });

    testWidgets('a banned account says what the provider said', (tester) async {
      fakes.sources.seed();
      fakes.overviews.set(
        'src-1',
        accountEnding(DateTime.utc(2027), status: 'Banned'),
      );
      await pump(tester);

      expect(
        find.textContaining('Northwind TV says this account is Banned.'),
        findsOneWidget,
      );
    });

    testWidgets('refused sign-in offers Edit source', (tester) async {
      fakes.sources.seed();
      fakes.overviews.set(
        'src-1',
        SourceOverview(
          lastSync: LastSync(
            outcome: LastSyncOutcome.failed,
            startedAt: fakes.now,
            failureCode: 'auth',
          ),
        ),
      );
      final app = await pump(tester);

      expect(
        find.textContaining("didn't accept the saved username or password"),
        findsOneWidget,
      );
      await tester.tap(find.text('Edit source'));
      await settleApp(tester);
      expect(app.location, editSourcePath('src-1'));
    });

    testWidgets('a healthy account shows nothing', (tester) async {
      fakes.sources.seed();
      fakes.overviews.set('src-1', accountEnding(DateTime.utc(2027)));
      await pump(tester);

      expect(containerOf(tester).read(shellNoticeProvider), isNull);
    });
  });
}
