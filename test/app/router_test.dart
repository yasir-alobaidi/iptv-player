import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:iptv_player/app/destinations.dart';
import 'package:iptv_player/app/placeholder_screen.dart';
import 'package:iptv_player/app/router.dart';
import 'package:iptv_player/app/shell/desktop_shell.dart';
import 'package:iptv_player/design/gallery/gallery_availability.dart';
import 'package:iptv_player/design/gallery/gallery_screen.dart';
import 'package:iptv_player/features/home/presentation/home_screen.dart';
import 'package:iptv_player/features/live_tv/presentation/live_tv_screen.dart';
import 'package:iptv_player/features/onboarding/presentation/welcome_screen.dart';
import 'package:iptv_player/features/search/presentation/search_overlay.dart';
import 'package:iptv_player/features/settings/presentation/settings_screen.dart';

import 'app_harness.dart';

void main() {
  test('the router opens where bootstrap says', () {
    final container = ProviderContainer(
      overrides: [startLocationProvider.overrideWithValue(welcomeRoutePath)],
    );
    addTearDown(container.dispose);

    // The state resolves once the router is in a widget tree; its
    // route information is set from the start.
    expect(
      container.read(routerProvider).routeInformationProvider.value.uri.path,
      welcomeRoutePath,
    );
  });

  testWidgets('Welcome is a page of its own, outside the shell', (
    tester,
  ) async {
    await pumpApp(tester, initialLocation: welcomeRoutePath);

    expect(find.byType(WelcomeScreen), findsOneWidget);
    expect(find.byType(DesktopShell), findsNothing);
  });

  testWidgets('starts on Home inside the shell', (tester) async {
    final app = await pumpApp(tester);

    expect(app.location, AppDestination.home.path);
    expect(find.byType(DesktopShell), findsOneWidget);
    expect(find.byType(HomeScreen), findsOneWidget);
  });

  testWidgets('every destination has a screen', (tester) async {
    for (final destination in AppDestination.values) {
      final app = await pumpApp(tester, initialLocation: destination.path);

      expect(app.location, destination.path);
      // Settings is the first destination with a real screen (Phase 2).
      expect(
        find.byType(
          destination == AppDestination.settings
              ? SettingsScreen
              : PlaceholderScreen,
        ),
        findsOneWidget,
        reason: '${destination.label} has no screen',
      );
    }
  });

  testWidgets('switching branches keeps the shell', (tester) async {
    final app = await pumpApp(tester);

    app.router.go(AppDestination.liveTv.path);
    await settleApp(tester);

    expect(find.byType(LiveTvScreen), findsOneWidget);
    expect(find.byType(DesktopShell), findsOneWidget);
    // The indexed stack keeps the other branches alive but hidden.
    expect(find.byType(HomeScreen, skipOffstage: false), findsOneWidget);
  });

  testWidgets('the search overlay sits over the shell', (tester) async {
    final app = await pumpApp(tester);

    unawaited(app.router.push<void>(searchRoutePath));
    await settleApp(tester);

    expect(find.byType(SearchOverlay), findsOneWidget);
    expect(isSearchOpen(app.router), isTrue);
    // The overlay is not opaque, so the shell stays behind its scrim.
    expect(find.byType(DesktopShell), findsOneWidget);

    app.router.pop();
    await settleApp(tester);

    expect(find.byType(SearchOverlay), findsNothing);
    expect(app.location, AppDestination.home.path);
  });

  testWidgets('the gallery is routed in debug builds', (tester) async {
    expect(galleryEnabled, isTrue, reason: 'tests run in debug mode');

    await pumpApp(tester, initialLocation: galleryRoutePath);

    expect(find.byType(GalleryScreen), findsOneWidget);
  });
}
