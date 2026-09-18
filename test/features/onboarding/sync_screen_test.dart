import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:iptv_player/app/router.dart';
import 'package:iptv_player/core/result.dart';
import 'package:iptv_player/design/components.dart';
import 'package:iptv_player/features/onboarding/presentation/onboarding_state.dart';
import 'package:iptv_player/features/sources/domain/provider_account.dart';
import 'package:iptv_player/features/sources/domain/source.dart';
import 'package:iptv_player/features/sources/domain/sync.dart';

import '../../app/app_harness.dart';
import 'onboarding_fakes.dart';

void main() {
  late OnboardingFakes fakes;
  setUp(() => fakes = OnboardingFakes());

  const id = 'src-1';

  Future<AppUnderTest> pump(
    WidgetTester tester, {
    SourceType type = SourceType.xtream,
    SyncStatus? status,
  }) {
    fakes.sources.seed(type: type);
    if (status != null) fakes.sync.emit(id, status);
    return pumpApp(
      tester,
      initialLocation: sourceSyncPath(id),
      overrides: fakes.overrides,
    );
  }

  Future<void> emit(WidgetTester tester, SyncStatus status) async {
    fakes.sync.emit(id, status);
    await settleApp(tester);
  }

  AppButton button(WidgetTester tester, String label) =>
      tester.widget<AppButton>(find.widgetWithText(AppButton, label));

  final movies = SyncRunning(
    SyncProgress(
      stage: SyncStage.movies,
      account: ProviderAccount(
        status: 'Active',
        expiresAt: DateTime.utc(2026, 11, 3, 12),
      ),
      categories: 549,
      channels: 12340,
      movies: 8021,
      stageTotal: 13800,
    ),
  );

  testWidgets('starts the sync when nothing is running', (tester) async {
    await pump(tester);

    expect(fakes.sync.syncCalls, [id]);
    expect(find.text('Signing in'), findsOneWidget);
  });

  testWidgets('joins a sync already running rather than starting one', (
    tester,
  ) async {
    await pump(tester, status: movies);

    expect(fakes.sync.syncCalls, isEmpty);
  });

  testWidgets('shows each Xtream stage with live counts', (tester) async {
    await pump(tester, status: movies);

    expect(find.text('Getting your lists'), findsOneWidget);
    expect(find.text('Saving movies'), findsOneWidget);
    expect(find.text('58%'), findsOneWidget);
    expect(find.text('Active · expires Nov 3, 2026'), findsOneWidget);
    expect(find.text('549'), findsOneWidget);
    expect(find.text('12,340'), findsOneWidget);
    expect(find.text('8,021 of about 13,800'), findsOneWidget);
    expect(find.text('Waiting'), findsOneWidget);
    expect(button(tester, 'Pick categories').onPressed, isNull);
    expect(
      find.text('Next step unlocks when the lists are in.'),
      findsOneWidget,
    );
  });

  testWidgets('a list still downloading says so', (tester) async {
    await pump(
      tester,
      status: const SyncRunning(SyncProgress(stage: SyncStage.series)),
    );

    expect(find.text('Downloading series'), findsOneWidget);
    expect(find.text('Downloading…'), findsOneWidget);
  });

  testWidgets('a playlist counts everything at once', (tester) async {
    await pump(
      tester,
      type: SourceType.m3uUrl,
      status: const SyncRunning(
        SyncProgress(
          stage: SyncStage.playlist,
          channels: 1200,
          movies: 30,
          series: 4,
          episodes: 96,
        ),
      ),
    );

    expect(find.text('Reading your playlist'), findsOneWidget);
    expect(find.text('Reading…'), findsOneWidget);
    expect(find.text('1,200'), findsOneWidget);
    expect(find.text('30'), findsOneWidget);
    expect(find.text('4 · 96 episodes'), findsOneWidget);
    expect(find.text('Account'), findsNothing);
  });

  testWidgets('a finished sync unlocks Pick categories and focuses it', (
    tester,
  ) async {
    final app = await pump(tester, status: movies);

    await emit(
      tester,
      const SyncSucceeded(
        SyncReport(
          categories: 549,
          channels: 12340,
          movies: 13800,
          series: 1204,
          duration: Duration(seconds: 42),
        ),
      ),
    );

    expect(find.text('All lists are in'), findsOneWidget);
    expect(find.text('Done in 42 s.'), findsOneWidget);
    expect(find.text('1,204'), findsOneWidget);
    expect(find.text('Cancel'), findsNothing);
    expect(
      focusIsOn(tester, find.widgetWithText(AppButton, 'Pick categories')),
      isTrue,
    );

    await tester.sendKeyEvent(LogicalKeyboardKey.enter);
    await settleApp(tester);
    expect(app.location, pickCategoriesPath(id));
  });

  testWidgets('a failure says why, marks the stage, and offers Retry', (
    tester,
  ) async {
    await pump(tester, status: movies);

    await emit(tester, SyncFailed(NetworkFailure('reset')));

    expect(find.text('Stopped'), findsOneWidget);
    expect(find.textContaining("Can't reach the server"), findsOneWidget);
    expect(focusIsOn(tester, find.text('Retry')), isTrue);
    expect(find.text('Change details'), findsOneWidget);

    await tester.tap(find.text('Retry'));
    await settleApp(tester);
    expect(fakes.sync.syncCalls, [id]);
    expect(find.text('Signing in'), findsOneWidget);
  });

  testWidgets('a rejected sign-in asks for other details', (tester) async {
    await pump(tester, status: SyncFailed(AuthFailure('auth 0')));

    expect(
      find.text(
        'Your provider rejected these details. Change them and try again.',
      ),
      findsOneWidget,
    );
  });

  for (final label in ['Cancel', 'Change details']) {
    testWidgets('$label removes the source and returns to the form', (
      tester,
    ) async {
      final app = await pump(
        tester,
        status: label == 'Cancel' ? movies : SyncFailed(AuthFailure('auth 0')),
      );
      final container = ProviderScope.containerOf(
        tester.element(find.byType(MaterialApp)),
      );
      container
          .read(pendingSourceDraftProvider.notifier)
          .draft = const SourceDraft(
        type: SourceType.xtream,
        name: 'Northwind',
        url: 'line.northwind.test',
        username: 'living-room',
        password: 'secret',
      );

      await tester.tap(find.text(label));
      await settleApp(tester);

      expect(fakes.sync.removeCalls, [id]);
      expect(fakes.sources.removed, [id]);
      expect(app.location, addSourceRoutePath);
      // The form is filled in again.
      expect(find.text('living-room'), findsOneWidget);
    });
  }

  testWidgets('Esc does not leave a sync half-way', (tester) async {
    final app = await pump(tester, status: movies);

    await tester.sendKeyEvent(LogicalKeyboardKey.escape);
    await settleApp(tester);

    expect(app.location, sourceSyncPath(id));
    expect(fakes.sync.removeCalls, isEmpty);
  });
}
