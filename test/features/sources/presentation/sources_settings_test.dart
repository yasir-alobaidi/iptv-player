import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:iptv_player/app/destinations.dart';
import 'package:iptv_player/app/router.dart';
import 'package:iptv_player/core/result.dart';
import 'package:iptv_player/design/components.dart';
import 'package:iptv_player/features/onboarding/presentation/onboarding_state.dart';
import 'package:iptv_player/features/settings/presentation/settings_section.dart';
import 'package:iptv_player/features/sources/data/source_providers.dart';
import 'package:iptv_player/features/sources/domain/provider_account.dart';
import 'package:iptv_player/features/sources/domain/source.dart';
import 'package:iptv_player/features/sources/domain/source_overview.dart';
import 'package:iptv_player/features/sources/domain/sync.dart';
import 'package:iptv_player/features/sources/presentation/source_shell_slots.dart';

import '../../../app/app_harness.dart';
import '../../onboarding/onboarding_fakes.dart';

void main() {
  late OnboardingFakes fakes;
  setUp(() => fakes = OnboardingFakes());

  final settings = AppDestination.settings.path;

  Future<AppUnderTest> pump(
    WidgetTester tester, {
    List<Override> extra = const [],
  }) => pumpApp(
    tester,
    initialLocation: settings,
    overrides: [...fakes.overrides, ...sourceShellOverrides, ...extra],
  );

  /// Two sources: Northwind synced 12 minutes ago with an active account,
  /// Backup never synced and failing.
  void seedTwo() {
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
            activeConnections: 0,
            maxConnections: 2,
            allowedFormats: const ['ts', 'm3u8'],
            serverTimezone: 'Europe/London',
          ),
          counts: const SourceCounts(channels: 12340, movies: 8021),
          lastSync: LastSync(
            outcome: LastSyncOutcome.succeeded,
            startedAt: fakes.now.subtract(const Duration(minutes: 13)),
            finishedAt: fakes.now.subtract(const Duration(minutes: 12)),
          ),
        ),
      )
      ..set(
        'src-2',
        SourceOverview(
          lastSync: LastSync(
            outcome: LastSyncOutcome.failed,
            startedAt: fakes.now.subtract(const Duration(hours: 2)),
            finishedAt: fakes.now.subtract(const Duration(hours: 2)),
            failureCode: 'timeout',
          ),
        ),
      );
  }

  Finder card(String name) =>
      find.ancestor(of: find.text(name), matching: find.byType(Container));

  Finder inCard(String name, Finder finder) => find.descendant(
    of: find.byWidgetPredicate(
      (w) => w is Semantics && w.properties.label == name,
    ),
    matching: finder,
  );

  group('states', () {
    testWidgets('loading shows skeleton cards', (tester) async {
      final never = StreamController<List<Source>>();
      addTearDown(never.close);
      await pump(
        tester,
        extra: [sourcesProvider.overrideWith((ref) => never.stream)],
      );

      expect(find.byType(Skeleton), findsNWidgets(2));
    });

    testWidgets('an error offers Retry', (tester) async {
      await pump(
        tester,
        extra: [
          sourcesProvider.overrideWith(
            (ref) => Stream<List<Source>>.error(StorageFailure('disk')),
          ),
        ],
      );

      expect(find.text("Couldn't load your sources"), findsOneWidget);
      expect(find.text('Retry'), findsOneWidget);
    });

    testWidgets('empty offers to add one, and comes back here', (tester) async {
      final app = await pump(tester);

      expect(find.text('No sources yet'), findsOneWidget);
      await tester.tap(find.text('Add a source'));
      await settleApp(tester);

      expect(app.location, addSourceRoutePath);
      final container = ProviderScope.containerOf(
        tester.element(find.byType(Navigator).first),
      );
      expect(container.read(onboardingReturnPathProvider), settings);
    });

    testWidgets('each source says what it holds and how its sync went', (
      tester,
    ) async {
      seedTwo();
      await pump(tester);

      expect(find.text('Northwind TV'), findsWidgets);
      expect(find.text('Xtream · Active · exp Nov 3'), findsOneWidget);
      expect(
        find.text('12,340 channels · 8,021 movies · synced 12 min ago'),
        findsOneWidget,
      );
      expect(find.text('Refresh'), findsOneWidget);

      expect(find.text('M3U URL · never synced'), findsOneWidget);
      expect(
        find.text('Last attempt failed: The server took too long to answer.'),
        findsOneWidget,
      );
      expect(find.text('Retry'), findsOneWidget);
      // The first source is the one browsed.
      expect(find.text('BROWSING'), findsOneWidget);
      expect(find.textContaining('Alt+↑ / Alt+↓'), findsOneWidget);
    });

    testWidgets('an expired account says so', (tester) async {
      fakes.sources.seed(lastSyncedAt: DateTime.utc(2026, 9, 1, 12));
      fakes.overviews.set(
        'src-1',
        SourceOverview(
          account: ProviderAccount(
            status: 'Expired',
            expiresAt: DateTime.utc(2026, 9, 1, 12),
          ),
        ),
      );
      await pump(tester);

      expect(find.text('Xtream · Expired Sep 1, 2026'), findsOneWidget);
    });

    testWidgets('a failed sync says what the server answered', (tester) async {
      fakes.sources.seed();
      fakes.overviews.set(
        'src-1',
        SourceOverview(
          lastSync: LastSync(
            outcome: LastSyncOutcome.failed,
            startedAt: fakes.now.subtract(const Duration(hours: 1)),
            finishedAt: fakes.now.subtract(const Duration(hours: 1)),
            failureCode: 'network',
            failureStatus: 503,
          ),
        ),
      );
      await pump(tester);

      expect(
        find.textContaining(
          'Last attempt failed: The server answered with an error.',
        ),
        findsOneWidget,
      );
      expect(
        find.textContaining('HTTP 503 (Service Unavailable)'),
        findsOneWidget,
      );
    });
  });

  group('actions', () {
    testWidgets('Refresh syncs; a running sync shows progress and Cancel', (
      tester,
    ) async {
      seedTwo();
      await pump(tester);

      await tester.tap(find.text('Refresh'));
      await tester.pump();
      expect(fakes.sync.syncCalls, ['src-1']);

      fakes.sync.emit(
        'src-1',
        const SyncRunning(SyncProgress(stage: SyncStage.live, channels: 1200)),
      );
      await tester.pump();
      // In the card and, naming the source, in the top bar.
      expect(find.text('Syncing channels · 1,200'), findsOneWidget);
      expect(
        find.text('Northwind TV · Syncing channels · 1,200'),
        findsOneWidget,
      );

      await tester.tap(find.text('Cancel sync'));
      await tester.pump();
      expect(fakes.sync.cancelCalls, ['src-1']);
    });

    testWidgets('Retry on a failed source syncs it', (tester) async {
      seedTwo();
      await pump(tester);

      await tester.tap(find.text('Retry'));
      await tester.pump();

      expect(fakes.sync.syncCalls, ['src-2']);
    });

    testWidgets('Edit opens the filled-in form', (tester) async {
      seedTwo();
      final app = await pump(tester);

      await tester.tap(inCard('Northwind TV', find.text('Edit')));
      await settleApp(tester);

      expect(app.location, editSourcePath('src-1'));
    });

    testWidgets('Alt+Down and Alt+Up move a source', (tester) async {
      seedTwo();
      await pump(tester);

      final refresh = inCard('Northwind TV', find.text('Refresh'));
      Focus.of(tester.element(refresh)).requestFocus();
      await tester.pump();
      await tester.sendKeyDownEvent(LogicalKeyboardKey.altLeft);
      await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
      await tester.sendKeyUpEvent(LogicalKeyboardKey.altLeft);
      await settleApp(tester);

      expect(fakes.sources.reorders, [
        ['src-2', 'src-1'],
      ]);
      // Moving the top one up again does nothing more than one move.
      await tester.sendKeyDownEvent(LogicalKeyboardKey.altLeft);
      await tester.sendKeyEvent(LogicalKeyboardKey.arrowUp);
      await tester.sendKeyUpEvent(LogicalKeyboardKey.altLeft);
      await settleApp(tester);
      expect(fakes.sources.reorders.last, ['src-1', 'src-2']);
    });

    testWidgets('the more menu moves, shows details, and closes with Esc', (
      tester,
    ) async {
      seedTwo();
      await pump(tester);

      await tester.tap(findByLabel('More for Northwind TV'));
      await settleApp(tester);
      expect(find.text('Move up'), findsOneWidget);
      await tester.tap(find.text('Move down'));
      await settleApp(tester);
      expect(fakes.sources.reorders, [
        ['src-2', 'src-1'],
      ]);

      await tester.tap(findByLabel('More for Northwind TV'));
      await settleApp(tester);
      await tester.tap(find.text('Account details…'));
      await settleApp(tester);
      expect(find.text('Europe/London'), findsOneWidget);
      expect(find.text('0 of 2 in use'), findsOneWidget);
      expect(find.text('TS, M3U8'), findsOneWidget);
      expect(find.text('alice'), findsOneWidget);
      // The password is never shown.
      expect(find.textContaining('s3cret'), findsNothing);

      await tester.sendKeyEvent(LogicalKeyboardKey.escape);
      await settleApp(tester);
      expect(find.text('Europe/London'), findsNothing);
      expect(find.text('Sources'), findsWidgets);
    });

    testWidgets('Remove asks first, with Keep focused', (tester) async {
      seedTwo();
      await pump(tester);

      await tester.tap(findByLabel('More for Backup playlist'));
      await settleApp(tester);
      await tester.tap(find.text('Remove…'));
      await settleApp(tester);
      expect(find.text('Remove Backup playlist?'), findsOneWidget);

      // Enter straight away keeps it.
      await tester.sendKeyEvent(LogicalKeyboardKey.enter);
      await settleApp(tester);
      expect(find.text('Remove Backup playlist?'), findsNothing);
      expect(fakes.sync.removeCalls, isEmpty);

      await tester.tap(findByLabel('More for Backup playlist'));
      await settleApp(tester);
      await tester.tap(find.text('Remove…'));
      await settleApp(tester);
      await tester.tap(find.text('Remove'));
      await settleApp(tester);

      expect(fakes.sync.removeCalls, ['src-2']);
      expect(find.text('Backup playlist'), findsNothing);
      expect(find.text('Northwind TV'), findsWidgets);
    });

    testWidgets('removing the last source goes back to Welcome', (
      tester,
    ) async {
      fakes.sources.seed();
      final app = await pump(tester);

      await tester.tap(findByLabel('More for Northwind TV'));
      await settleApp(tester);
      await tester.tap(find.text('Remove…'));
      await settleApp(tester);
      await tester.tap(find.text('Remove'));
      await settleApp(tester);

      expect(app.location, welcomeRoutePath);
    });

    testWidgets('a failed reorder says so and keeps the old order', (
      tester,
    ) async {
      seedTwo();
      fakes.sources.writeFailure = StorageFailure('disk full');
      await pump(tester);

      await tester.tap(findByLabel('More for Northwind TV'));
      await settleApp(tester);
      await tester.tap(find.text('Move down'));
      await settleApp(tester);

      expect(find.textContaining("Couldn't save the new order"), findsOne);
      final first = tester.getTopLeft(card('Northwind TV').first).dy;
      final second = tester.getTopLeft(card('Backup playlist').first).dy;
      expect(first, lessThan(second));
    });
  });

  group('settings navigation', () {
    testWidgets('sections are walked with arrows and chosen with Enter', (
      tester,
    ) async {
      seedTwo();
      await pump(tester);

      Focus.of(tester.element(find.text('Sources').first)).requestFocus();
      await tester.pump();
      await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
      await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
      await tester.sendKeyEvent(LogicalKeyboardKey.enter);
      await settleApp(tester);

      expect(find.text('Casting comes in Phase 7'), findsOneWidget);
      // Focus stays in the list, as in the nav rail.
      expect(focusIsOn(tester, find.text('Casting').first), isTrue);
    });

    testWidgets("a source's Categories… opens the manager on it", (
      tester,
    ) async {
      seedTwo();
      await pump(tester);

      await tester.tap(findByLabel('More for Backup playlist'));
      await settleApp(tester);
      await tester.tap(find.text('Categories…'));
      await settleApp(tester);

      final container = ProviderScope.containerOf(
        tester.element(find.byType(Navigator).first),
      );
      final location = container.read(settingsLocationProvider);
      expect(location.section, SettingsSection.categories);
      expect(location.categoriesSourceId, 'src-2');
      expect(find.text('Backup playlist'), findsWidgets);
    });
  });
}
