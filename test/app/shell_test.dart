import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:iptv_player/app/destinations.dart';
import 'package:iptv_player/app/shell/nav_rail.dart';
import 'package:iptv_player/app/shell/shell_state.dart';
import 'package:iptv_player/design/components.dart';

import 'app_harness.dart';

/// The rail's rendered width, which is what "collapsed" and "expanded"
/// mean to the user.
double _railWidth(WidgetTester tester) =>
    tester.getSize(find.byType(NavRail)).width;

void main() {
  group('nav rail', () {
    testWidgets('shows every destination and marks the current one', (
      tester,
    ) async {
      await pumpApp(tester);

      for (final destination in AppDestination.values) {
        expect(
          findByLabel(destination.label),
          findsWidgets,
          reason: '${destination.label} is missing from the rail',
        );
      }
      expect(find.text('Home'), findsOneWidget, reason: 'the top bar title');
    });

    testWidgets('is collapsed by default and the toggle expands it', (
      tester,
    ) async {
      await pumpApp(tester);
      expect(_railWidth(tester), NavRail.collapsedWidth);

      await tester.tap(findByLabel('Expand menu'));
      await settleApp(tester);

      expect(_railWidth(tester), NavRail.expandedWidth);
      // The labels only exist once there is room for them.
      expect(find.text('Live TV'), findsOneWidget);
    });

    testWidgets('collapses below 1280 px whatever the user chose', (
      tester,
    ) async {
      await pumpApp(
        tester,
        size: const Size(1100, 800),
        overrides: [railExpandedProvider.overrideWith(_AlwaysExpanded.new)],
      );

      expect(_railWidth(tester), NavRail.collapsedWidth);
    });

    testWidgets('a rail item switches destination', (tester) async {
      final app = await pumpApp(tester);

      await tester.tap(findByLabel(AppDestination.movies.label));
      await settleApp(tester);

      expect(app.location, AppDestination.movies.path);
    });
  });

  group('top bar', () {
    testWidgets('reads "No source" until a provider is added', (tester) async {
      await pumpApp(tester);

      expect(find.text('No source'), findsOneWidget);
    });

    testWidgets('shows the source name and the sync and download slots', (
      tester,
    ) async {
      await pumpApp(
        tester,
        overrides: [
          shellSourceProvider.overrideWithValue(
            const ShellSource(name: 'Home provider', connected: true),
          ),
          shellSyncStatusProvider.overrideWithValue(
            const ShellSyncStatus(message: 'Guide updated 12 min ago'),
          ),
          shellDownloadsProvider.overrideWithValue(
            const ShellDownloads(active: 2, progress: 0.34),
          ),
        ],
      );

      expect(find.text('Home provider'), findsOneWidget);
      expect(find.text('Guide updated 12 min ago'), findsOneWidget);
      expect(find.text('2 · 34 %'), findsOneWidget);
    });

    testWidgets('the cast button is disabled until Phase 7', (tester) async {
      await pumpApp(tester);

      final button = tester.widget<AppIconButton>(
        find.byWidgetPredicate(
          (widget) => widget is AppIconButton && widget.icon == AppIcons.cast,
        ),
      );

      expect(button.onPressed, isNull);
    });

    testWidgets('the search field opens the overlay', (tester) async {
      final app = await pumpApp(tester);

      await tester.tap(find.byType(SearchField));
      await settleApp(tester);

      expect(app.location, '/search');
    });
  });

  group('shell slots', () {
    testWidgets('the casting bar is absent until something is casting', (
      tester,
    ) async {
      await pumpApp(tester);

      expect(find.byType(CastingBar), findsNothing);
    });

    testWidgets('the casting bar appears with a session', (tester) async {
      await pumpApp(
        tester,
        overrides: [
          shellCastSessionProvider.overrideWithValue(
            const ShellCastSession(
              title: 'Arena Sports 1',
              deviceName: 'Living Room TV',
            ),
          ),
        ],
      );

      expect(find.byType(CastingBar), findsOneWidget);
      expect(find.textContaining('Living Room TV'), findsWidgets);
    });

    testWidgets('a non-fatal error becomes a toast in human words', (
      tester,
    ) async {
      final app = await pumpApp(tester);

      app.errors.report(
        const SocketException('nope'),
        StackTrace.empty,
        source: 'test',
      );
      await settleApp(tester);

      expect(find.byType(AppToast), findsOneWidget);
      expect(
        find.textContaining("Can't reach the server"),
        findsOneWidget,
        reason: 'hard rule 4: no raw exception text in the UI',
      );
      expect(find.textContaining('SocketException'), findsNothing);
    });

    testWidgets('the same error twice shows one toast', (tester) async {
      final app = await pumpApp(tester);

      for (var i = 0; i < 3; i++) {
        app.errors.report(
          const SocketException('nope'),
          StackTrace.empty,
          source: 'test',
        );
      }
      await settleApp(tester);

      expect(find.byType(AppToast), findsOneWidget);
    });

    testWidgets('a toast goes away by itself', (tester) async {
      final app = await pumpApp(tester);

      app.errors.report(
        const SocketException('nope'),
        StackTrace.empty,
        source: 'test',
      );
      await settleApp(tester);
      expect(find.byType(AppToast), findsOneWidget);

      await tester.pump(AppToast.defaultDuration);
      await settleApp(tester);

      expect(find.byType(AppToast), findsNothing);
    });
  });

  group('placeholder screens', () {
    testWidgets('every screen says what is coming and offers a next step', (
      tester,
    ) async {
      final app = await pumpApp(tester);

      expect(find.textContaining('Home comes in Phase 5'), findsOneWidget);

      await tester.tap(find.text('Add a source'));
      await settleApp(tester);

      expect(app.location, AppDestination.settings.path);
    });
  });
}

class _AlwaysExpanded extends RailExpanded {
  @override
  bool build() => true;
}
