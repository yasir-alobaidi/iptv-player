import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:iptv_player/app/destinations.dart';
import 'package:iptv_player/app/router.dart';
import 'package:iptv_player/app/shell/desktop_shell.dart';
import 'package:iptv_player/design/components.dart';
import 'package:iptv_player/design/gallery/gallery_availability.dart';
import 'package:iptv_player/design/gallery/gallery_screen.dart';
import 'package:iptv_player/features/favorites/presentation/favorites_screen.dart';
import 'package:iptv_player/features/guide/data/guide_providers.dart';
import 'package:iptv_player/features/guide/presentation/guide_screen.dart';
import 'package:iptv_player/features/home/presentation/home_screen.dart';
import 'package:iptv_player/features/library/presentation/library_screen.dart';
import 'package:iptv_player/features/live_tv/presentation/live_tv_screen.dart';
import 'package:iptv_player/features/movies/presentation/movies_screen.dart';
import 'package:iptv_player/features/onboarding/presentation/welcome_screen.dart';
import 'package:iptv_player/features/search/presentation/search_overlay.dart';
import 'package:iptv_player/features/series/presentation/series_screen.dart';
import 'package:iptv_player/features/settings/presentation/settings_screen.dart';

import '../features/guide/guide_switch.dart';
import '../features/guide/presentation/guide_settings_fakes.dart';
import '../features/onboarding/onboarding_fakes.dart';
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
      final app = await pumpApp(
        tester,
        initialLocation: destination.path,
        overrides: [...emptyLibraryOverrides, guideSwitchedOn()],
      );

      expect(app.location, destination.path);
      expect(
        find.byType(switch (destination) {
          AppDestination.home => HomeScreen,
          AppDestination.settings => SettingsScreen,
          AppDestination.liveTv => LiveTvScreen,
          AppDestination.guide => GuideScreen,
          AppDestination.movies => MoviesScreen,
          AppDestination.series => SeriesScreen,
          AppDestination.favorites => FavoritesScreen,
          AppDestination.library => LibraryScreen,
        }),
        findsOneWidget,
        reason: '${destination.label} has no screen',
      );
    }
  });

  group('the Guide switched off (ADR-031)', () {
    testWidgets('its page goes Home; on again, it opens', (tester) async {
      final fakes = GuideFakes(OnboardingFakes()..sources.seed());
      final app = await pumpApp(tester, overrides: fakes.overrides);

      app.router.go(AppDestination.guide.path);
      await settleApp(tester);
      expect(app.location, AppDestination.home.path);
      expect(find.byType(HomeScreen), findsOneWidget);

      final container = ProviderScope.containerOf(
        tester.element(find.byType(HomeScreen)),
      );
      await container
          .read(guideSettingsControllerProvider.notifier)
          .setEnabled(on: true);
      await settleApp(tester);
      app.router.go(AppDestination.guide.path);
      await settleApp(tester);
      expect(app.location, AppDestination.guide.path);
      expect(find.byType(GuideScreen), findsOneWidget);
    });

    testWidgets('a page opened before the choice was read goes Home once it '
        'is, and holds nothing', (tester) async {
      final app = await pumpApp(
        tester,
        initialLocation: AppDestination.guide.path,
        settle: false,
      );
      expect(app.location, AppDestination.guide.path, reason: 'not read yet');

      await settleApp(tester);
      expect(app.location, AppDestination.home.path);
      expect(
        find.descendant(
          of: find.byType(GuideScreen, skipOffstage: false),
          matching: find.byType(FocusPane, skipOffstage: false),
        ),
        findsNothing,
      );
    });
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
