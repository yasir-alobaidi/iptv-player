import 'dart:async';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:iptv_player/app/destinations.dart';
import 'package:iptv_player/app/shell/desktop_shell.dart';
import 'package:iptv_player/design/gallery/gallery_availability.dart';
import 'package:iptv_player/design/gallery/gallery_screen.dart';
import 'package:iptv_player/features/favorites/presentation/favorites_screen.dart';
import 'package:iptv_player/features/guide/presentation/guide_screen.dart';
import 'package:iptv_player/features/home/presentation/home_screen.dart';
import 'package:iptv_player/features/library/presentation/library_screen.dart';
import 'package:iptv_player/features/live_tv/presentation/live_tv_screen.dart';
import 'package:iptv_player/features/movies/presentation/movies_screen.dart';
import 'package:iptv_player/features/onboarding/presentation/connect_screen.dart';
import 'package:iptv_player/features/onboarding/presentation/onboarding_state.dart';
import 'package:iptv_player/features/onboarding/presentation/pick_categories_screen.dart';
import 'package:iptv_player/features/onboarding/presentation/sync_screen.dart';
import 'package:iptv_player/features/onboarding/presentation/welcome_screen.dart';
import 'package:iptv_player/features/search/presentation/search_overlay.dart';
import 'package:iptv_player/features/series/presentation/series_screen.dart';
import 'package:iptv_player/features/settings/presentation/settings_screen.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'router.g.dart';

/// The search overlay's path. It is a route rather than a dialog so
/// Ctrl+K, `/`, Esc and the back gesture all behave the same way.
const searchRoutePath = '/search';

/// The Component Gallery's path; only routed in debug builds or with
/// `--dart-define=GALLERY=true`.
const galleryRoutePath = '/dev/gallery';

/// Onboarding (docs/05): Welcome, then Connect pushed on top of it, so
/// Back and Esc return to Welcome.
const welcomeRoutePath = '/welcome';
const addSourceRoutePath = '/add-source';

/// The first sync of a source just added. Reached with `go`, so there is
/// nothing to pop back to: Esc can't leave a sync half-way, only Cancel.
String sourceSyncPath(String sourceId) => '/source-setup/$sourceId';

/// Pick categories, on top of the finished sync.
String pickCategoriesPath(String sourceId) =>
    '/source-setup/$sourceId/categories';

/// Editing a configured source: Connect's form, filled in.
String editSourcePath(String sourceId) => '/sources/$sourceId/edit';

/// Where the app opens: Home, or Welcome when no source is configured yet.
/// `bootstrap()` decides before the first frame.
@Riverpod(keepAlive: true)
String startLocation(Ref ref) => '/';

@Riverpod(keepAlive: true)
GoRouter router(Ref ref) {
  final router = buildRouter(initialLocation: ref.read(startLocationProvider));
  ref.onDispose(router.dispose);
  return router;
}

/// Builds the app's router. Tests pass [initialLocation] to start on a
/// particular screen.
///
/// The navigator keys are created here rather than kept as globals, so a
/// test can build more than one router without two navigators sharing a
/// key.
GoRouter buildRouter({String initialLocation = '/'}) {
  final rootNavigatorKey = GlobalKey<NavigatorState>(debugLabel: 'root');

  return GoRouter(
    navigatorKey: rootNavigatorKey,
    initialLocation: initialLocation,
    routes: [
      StatefulShellRoute.indexedStack(
        builder: (context, state, navigationShell) => DesktopShell(
          navigationShell: navigationShell,
          onOpenSearch: () => openSearch(context),
        ),
        branches: [
          for (final destination in AppDestination.values)
            StatefulShellBranch(
              routes: [
                GoRoute(
                  path: destination.path,
                  builder: (context, state) => _screenFor(destination),
                ),
              ],
            ),
        ],
      ),
      GoRoute(
        path: searchRoutePath,
        parentNavigatorKey: rootNavigatorKey,
        pageBuilder: (context, state) => _overlayPage(
          SearchOverlay(onClose: () => closeSearch(context)),
          key: state.pageKey,
        ),
      ),
      GoRoute(
        path: welcomeRoutePath,
        parentNavigatorKey: rootNavigatorKey,
        builder: (context, state) => const WelcomeScreen(),
      ),
      GoRoute(
        path: addSourceRoutePath,
        parentNavigatorKey: rootNavigatorKey,
        builder: (context, state) =>
            ConnectScreen(preset: state.extra as ConnectPreset?),
      ),
      GoRoute(
        path: '/sources/:sourceId/edit',
        parentNavigatorKey: rootNavigatorKey,
        builder: (context, state) =>
            ConnectScreen(editSourceId: state.pathParameters['sourceId']),
      ),
      GoRoute(
        path: '/source-setup/:sourceId',
        parentNavigatorKey: rootNavigatorKey,
        builder: (context, state) =>
            SyncScreen(sourceId: state.pathParameters['sourceId']!),
        routes: [
          GoRoute(
            path: 'categories',
            builder: (context, state) => PickCategoriesScreen(
              sourceId: state.pathParameters['sourceId']!,
            ),
          ),
        ],
      ),
      if (galleryEnabled)
        GoRoute(
          path: galleryRoutePath,
          parentNavigatorKey: rootNavigatorKey,
          builder: (context, state) => const GalleryScreen(),
        ),
    ],
  );
}

Widget _screenFor(AppDestination destination) => switch (destination) {
  AppDestination.home => const HomeScreen(),
  AppDestination.liveTv => const LiveTvScreen(),
  AppDestination.guide => const GuideScreen(),
  AppDestination.movies => const MoviesScreen(),
  AppDestination.series => const SeriesScreen(),
  AppDestination.favorites => const FavoritesScreen(),
  AppDestination.library => const LibraryScreen(),
  AppDestination.settings => const SettingsScreen(),
};

/// The overlay keeps the shell visible behind its scrim, so it fades in
/// rather than replacing the screen.
Page<void> _overlayPage(Widget child, {required LocalKey key}) =>
    CustomTransitionPage<void>(
      key: key,
      opaque: false,
      transitionDuration: const Duration(milliseconds: 120),
      reverseTransitionDuration: const Duration(milliseconds: 100),
      transitionsBuilder: (context, animation, secondary, child) =>
          FadeTransition(opacity: animation, child: child),
      child: child,
    );

/// Opens the search overlay unless it is already open.
void openSearch(BuildContext context) {
  final router = GoRouter.of(context);
  if (isSearchOpen(router)) return;
  unawaited(router.push<void>(searchRoutePath));
}

/// Closes the search overlay, if it is what is on top.
void closeSearch(BuildContext context) {
  final router = GoRouter.of(context);
  if (router.canPop()) router.pop();
}

/// True when the search overlay is the topmost route.
bool isSearchOpen(GoRouter router) => router.state.uri.path == searchRoutePath;
