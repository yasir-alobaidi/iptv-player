import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:iptv_player/app/destinations.dart';
import 'package:iptv_player/app/router.dart';
import 'package:iptv_player/app/shell/nav_rail.dart';
import 'package:iptv_player/app/shell/shell_state.dart';
import 'package:iptv_player/app/shell/top_bar.dart';
import 'package:iptv_player/core/core_providers.dart';
import 'package:iptv_player/core/notices/app_notices.dart';
import 'package:iptv_player/core/platform/network_status.dart';
import 'package:iptv_player/core/settings/ui_preferences.dart';
import 'package:iptv_player/design/components.dart';
import 'package:iptv_player/design/theme.dart';

import '../features/guide/guide_switch.dart';
import 'app_harness.dart';

/// The rail's rendered width, which is what "collapsed" and "expanded"
/// mean to the user.
double _railWidth(WidgetTester tester) =>
    tester.getSize(find.byType(NavRail)).width;

void main() {
  group("You're offline (Phase 9 step 7: from the app's network status, on "
      'every screen)', () {
    const words = "You're offline — downloads and local files still play.";

    testWidgets('online: nothing is said', (tester) async {
      await pumpApp(
        tester,
        overrides: [
          appOfflineProvider.overrideWith((ref) => Stream.value(false)),
        ],
      );

      expect(find.text(words), findsNothing);
    });

    testWidgets('offline: said under the top bar of every destination, with '
        'the way to the Library; on the Library, without it', (tester) async {
      final app = await pumpApp(
        tester,
        overrides: [
          appOfflineProvider.overrideWith((ref) => Stream.value(true)),
          ...emptyLibraryOverrides,
        ],
      );

      for (final destination in AppDestination.values) {
        app.router.go(destination.path);
        await settleApp(tester);
        expect(find.text(words), findsOneWidget, reason: destination.label);
        expect(
          find.text('Open Library'),
          destination == AppDestination.library ? findsNothing : findsOneWidget,
          reason: destination.label,
        );
      }

      app.router.go(AppDestination.guide.path);
      await settleApp(tester);
      await tester.tap(find.text('Open Library'));
      await settleApp(tester);
      expect(app.location, AppDestination.library.path);
    });

    testWidgets('the network coming back takes the words away', (tester) async {
      final network = StreamController<bool>();
      addTearDown(network.close);
      await pumpApp(
        tester,
        overrides: [appOfflineProvider.overrideWith((ref) => network.stream)],
      );
      expect(find.text(words), findsNothing);

      network.add(true);
      await settleApp(tester);
      expect(find.text(words), findsOneWidget);

      network.add(false);
      await settleApp(tester);
      expect(find.text(words), findsNothing);
    });
  });

  group('nav rail', () {
    testWidgets('shows every destination and marks the current one', (
      tester,
    ) async {
      await pumpApp(tester, overrides: [guideSwitchedOn()]);

      for (final destination in AppDestination.values) {
        expect(
          findByLabel(destination.label),
          findsWidgets,
          reason: '${destination.label} is missing from the rail',
        );
      }
      expect(find.text('Home'), findsOneWidget, reason: 'the top bar title');
    });

    testWidgets('has no Guide while its switch is off, as it is by default '
        '(ADR-031)', (tester) async {
      await pumpApp(tester);

      expect(findByLabel(AppDestination.guide.label), findsNothing);
      for (final destination in AppDestination.values) {
        if (destination == AppDestination.guide) continue;
        expect(
          findByLabel(destination.label),
          findsWidgets,
          reason: '${destination.label} is missing from the rail',
        );
      }
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

    testWidgets('opens expanded when that is what was remembered', (
      tester,
    ) async {
      final preferences = InMemoryUiPreferences();
      await preferences.setRailExpanded(expanded: true);

      await pumpApp(
        tester,
        overrides: [uiPreferencesProvider.overrideWithValue(preferences)],
      );

      expect(_railWidth(tester), NavRail.expandedWidth);
    });

    testWidgets('the toggle writes the choice through', (tester) async {
      final preferences = InMemoryUiPreferences();

      await pumpApp(
        tester,
        overrides: [uiPreferencesProvider.overrideWithValue(preferences)],
      );
      await tester.tap(findByLabel('Expand menu'));
      await settleApp(tester);

      expect(preferences.railExpanded, isTrue);
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

    testWidgets('the time at its right end, quiet and without AM/PM, on '
        'every destination (ADR-065)', (tester) async {
      final app = await pumpApp(
        tester,
        overrides: [
          appClockProvider.overrideWithValue(
            () => DateTime(2026, 9, 14, 20, 5),
          ),
          ...emptyLibraryOverrides,
        ],
      );

      for (final destination in AppDestination.values) {
        app.router.go(destination.path);
        await settleApp(tester);
        final clock = find.descendant(
          of: find.byType(ShellTopBar),
          matching: find.text('8:05'),
        );
        expect(clock, findsOneWidget, reason: destination.label);
        // The last thing in the bar, at its padding.
        expect(
          tester.getTopRight(clock).dx,
          moreOrLessEquals(
            tester.getTopRight(find.byType(ShellTopBar)).dx - 24,
          ),
          reason: destination.label,
        );
      }
      // A screen reader hears the whole time.
      expect(
        tester.widget<Text>(find.text('8:05')).semanticsLabel,
        'The time: 8:05 PM',
      );
    });

    testWidgets('the clock gives way first in a cramped bar: a 1024 px '
        'window at 115 % text and more', (tester) async {
      tester.view
        ..physicalSize = const Size(1400, 300)
        ..devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      Future<void> bar(double width, double text) => tester.pumpWidget(
        MaterialApp(
          theme: buildAppTheme(),
          home: MediaQuery(
            data: MediaQueryData(textScaler: TextScaler.linear(text)),
            child: Align(
              alignment: Alignment.topLeft,
              child: SizedBox(
                width: width,
                child: ShellTopBar(
                  title: 'Home',
                  onOpenSearch: () {},
                  syncStatus: const ShellSyncStatus(
                    message: 'Syncing channels · 12,340',
                  ),
                  clock: () => DateTime(2026, 9, 14, 20, 5),
                ),
              ),
            ),
          ),
        ),
      );
      Finder clock() => find.byType(ShellClock);

      // The bar beside a 1024 px window's rail.
      await bar(952, 1);
      expect(clock(), findsOneWidget);
      await bar(952, 1.15);
      expect(clock(), findsNothing);
      await bar(952, 1.3);
      expect(clock(), findsNothing);
      // A 1280 px window, and a TV's 1280 canvas, at 130 %.
      await bar(1208, 1.3);
      expect(clock(), findsOneWidget);
    });

    testWidgets('the clock turns with the minute on its own', (tester) async {
      var now = DateTime(2026, 9, 14, 20, 5, 40);
      await tester.pumpWidget(
        MaterialApp(
          theme: buildAppTheme(),
          home: ShellClock(clock: () => now),
        ),
      );
      expect(find.text('8:05'), findsOneWidget);

      now = now.add(const Duration(seconds: 20));
      await tester.pump(const Duration(seconds: 19));
      expect(find.text('8:05'), findsOneWidget);
      await tester.pump(const Duration(seconds: 1));
      expect(find.text('8:06'), findsOneWidget);
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

    testWidgets('background news becomes a toast, and the same news '
        'another day becomes another', (tester) async {
      final notices = AppNotices();
      addTearDown(notices.dispose);
      await pumpApp(
        tester,
        overrides: [appNoticesProvider.overrideWithValue(notices)],
      );
      const message = 'Guide updated · 142 channels matched';

      notices.show(AppNotice(message, tone: NoticeTone.success));
      await settleApp(tester);
      expect(find.text(message), findsOneWidget);

      await tester.pump(AppToast.defaultDuration);
      await settleApp(tester);
      expect(find.byType(AppToast), findsNothing);

      notices.show(AppNotice(message, tone: NoticeTone.success));
      await settleApp(tester);
      expect(find.text(message), findsOneWidget);
      await tester.pump(AppToast.defaultDuration);
      await settleApp(tester);
    });

    testWidgets("Ctrl+Z runs the shown toast's Undo, which ends it; with no "
        'Undo to run, Ctrl+Z goes on its way', (tester) async {
      final notices = AppNotices();
      addTearDown(notices.dispose);
      await pumpApp(
        tester,
        overrides: [appNoticesProvider.overrideWithValue(notices)],
      );
      var undone = 0;
      Future<void> ctrlZ() async {
        await tester.sendKeyDownEvent(LogicalKeyboardKey.controlLeft);
        await tester.sendKeyEvent(LogicalKeyboardKey.keyZ);
        await tester.sendKeyUpEvent(LogicalKeyboardKey.controlLeft);
        await settleApp(tester);
      }

      notices.show(
        AppNotice.undoable('Channel hidden', onUndo: () => undone++),
      );
      await settleApp(tester);
      expect(find.text('Undo'), findsOneWidget);
      await ctrlZ();
      expect(undone, 1);
      expect(find.byType(AppToast), findsNothing, reason: 'the Undo ended it');
      await ctrlZ();
      expect(undone, 1, reason: 'nothing shown to undo');

      notices.show(AppNotice('Guide updated', actionLabel: 'Open'));
      await settleApp(tester);
      await ctrlZ();
      expect(find.text('Guide updated'), findsOneWidget, reason: 'no Undo');
      await tester.pump(AppToast.defaultDuration);
      await settleApp(tester);
    });

    testWidgets('a click on Undo runs it once and ends the toast; a click '
        'beside the toast reaches the screen under it', (tester) async {
      final notices = AppNotices();
      addTearDown(notices.dispose);
      final app = await pumpApp(
        tester,
        initialLocation: AppDestination.favorites.path,
        overrides: [appNoticesProvider.overrideWithValue(notices)],
      );
      var undone = 0;
      notices.show(
        AppNotice.undoable('Channel hidden', onUndo: () => undone++),
      );
      await settleApp(tester);

      await tester.tap(find.text('Add a source'));
      await settleApp(tester);
      expect(app.location, addSourceRoutePath);
      expect(find.text('Channel hidden'), findsOneWidget);

      await tester.tap(find.text('Undo'));
      await settleApp(tester);
      expect(undone, 1);
      expect(find.byType(AppToast), findsNothing);
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
}

class _AlwaysExpanded extends RailExpanded {
  @override
  bool build() => true;
}
