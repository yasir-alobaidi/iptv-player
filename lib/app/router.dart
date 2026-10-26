import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:iptv_player/app/destinations.dart';
import 'package:iptv_player/app/shell/desktop_shell.dart';
import 'package:iptv_player/core/core_providers.dart';
import 'package:iptv_player/core/logging/app_log.dart';
import 'package:iptv_player/core/platform/form_factor.dart';
import 'package:iptv_player/design/gallery/gallery_availability.dart';
import 'package:iptv_player/design/gallery/gallery_screen.dart';
import 'package:iptv_player/features/favorites/presentation/favorites_screen.dart';
import 'package:iptv_player/features/guide/data/guide_providers.dart';
import 'package:iptv_player/features/guide/presentation/guide_screen.dart';
import 'package:iptv_player/features/home/presentation/home_screen.dart';
import 'package:iptv_player/features/library/presentation/library_movie_page.dart';
import 'package:iptv_player/features/library/presentation/library_routes.dart';
import 'package:iptv_player/features/library/presentation/library_screen.dart';
import 'package:iptv_player/features/library/presentation/library_show_page.dart';
import 'package:iptv_player/features/live_tv/domain/channels.dart';
import 'package:iptv_player/features/live_tv/presentation/live_tv_screen.dart';
import 'package:iptv_player/features/movies/presentation/movies_screen.dart';
import 'package:iptv_player/features/onboarding/presentation/connect_screen.dart';
import 'package:iptv_player/features/onboarding/presentation/onboarding_state.dart';
import 'package:iptv_player/features/onboarding/presentation/pick_categories_screen.dart';
import 'package:iptv_player/features/onboarding/presentation/sync_screen.dart';
import 'package:iptv_player/features/onboarding/presentation/welcome_screen.dart';
import 'package:iptv_player/features/playback/presentation/player_screen.dart';
import 'package:iptv_player/features/search/presentation/search_overlay.dart';
import 'package:iptv_player/features/series/presentation/series_screen.dart';
import 'package:iptv_player/features/settings/presentation/settings_screen.dart';
import 'package:iptv_player/features/vod/presentation/title_details_screen.dart';
import 'package:iptv_player/features/vod/presentation/title_routes.dart';
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
  if (ref.read(formFactorProvider) == FormFactor.tv) {
    ref.onDispose(logScreens(router, ref.read(appLogProvider)));
  }
  ref.onDispose(router.dispose);
  return router;
}

/// Logs each screen [router] shows, its path and never a query: a TV's
/// own log of a run then says where the run ended (ADR-059). Returns the
/// call that stops it.
VoidCallback logScreens(GoRouter router, AppLog log) {
  String? shown;
  void noteScreen() {
    final path = router.routerDelegate.currentConfiguration.uri.path;
    if (path == shown) return;
    shown = path;
    log.info('screen', path);
  }

  router.routerDelegate.addListener(noteScreen);
  return () => router.routerDelegate.removeListener(noteScreen);
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
          // The canvas draws no top bar on a title's page.
          immersive:
              isTitleDetailsPath(state.uri.path) ||
              isLibraryPagePath(state.uri.path),
        ),
        branches: [
          for (final destination in AppDestination.values)
            StatefulShellBranch(
              routes: [
                GoRoute(
                  path: destination.path,
                  builder: (context, state) =>
                      _OnTopOnly(_screenFor(destination)),
                  redirect: destination == AppDestination.guide
                      ? _guideRedirect
                      : null,
                  routes: _pagesOf(destination),
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
        path: playerRoutePath,
        parentNavigatorKey: rootNavigatorKey,
        pageBuilder: (context, state) => NoTransitionPage(
          key: state.pageKey,
          child: PlayerScreen(
            zapQuery: switch (state.extra) {
              final ChannelQuery query => query,
              _ => null,
            },
          ),
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

/// The Guide's page goes Home while the Guide is switched off (ADR-031):
/// nothing leads there then, and a jump that still does (an old link, a
/// key) lands somewhere useful. Read from the app's providers above the
/// router.
String? _guideRedirect(BuildContext context, GoRouterState state) =>
    ProviderScope.containerOf(
      context,
      listen: false,
    ).read(guideSwitchedOffProvider)
    ? AppDestination.home.path
    : null;

/// A title's page, inside its branch (Phase 5 step 5).
/// The pages inside a destination's branch: a title's page under Movies
/// and Series; under the Library, a movie and a show of its own (Phase 8
/// sketches A and B) and the provider's pages of what was downloaded,
/// which say "‹ Library" there.
List<GoRoute> _pagesOf(AppDestination destination) => switch (destination) {
  AppDestination.movies => [
    GoRoute(
      path: ':sourceId/:remoteKey',
      builder: (context, state) => MovieDetailsScreen(
        sourceId: state.pathParameters['sourceId']!,
        remoteKey: state.pathParameters['remoteKey']!,
      ),
    ),
  ],
  AppDestination.series => [
    GoRoute(
      path: ':sourceId/:remoteKey',
      builder: (context, state) => SeriesDetailsScreen(
        sourceId: state.pathParameters['sourceId']!,
        remoteKey: state.pathParameters['remoteKey']!,
      ),
    ),
  ],
  AppDestination.library => [
    GoRoute(
      path: 'movie/:itemId',
      builder: (context, state) => LibraryMovieScreen(
        itemId: int.tryParse(state.pathParameters['itemId']!),
      ),
    ),
    GoRoute(
      path: 'show/:showKey',
      builder: (context, state) =>
          LibraryShowScreen(showKey: state.pathParameters['showKey']!),
    ),
    GoRoute(
      path: 'movies/:sourceId/:remoteKey',
      builder: (context, state) => MovieDetailsScreen(
        sourceId: state.pathParameters['sourceId']!,
        remoteKey: state.pathParameters['remoteKey']!,
        back: 'Library',
      ),
    ),
    GoRoute(
      path: 'series/:sourceId/:remoteKey',
      builder: (context, state) => SeriesDetailsScreen(
        sourceId: state.pathParameters['sourceId']!,
        remoteKey: state.pathParameters['remoteKey']!,
        back: 'Library',
      ),
    ),
  ],
  _ => const [],
};

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

/// A destination's screen stays out of the focus's search until it has
/// been on top of its branch once. Flutter skips a covered page's own
/// scope, not what is in it, and a screen built beneath a title's page
/// opened straight from elsewhere (Home, Search, a film played to its end)
/// has never been laid out: ↓ in the rail then threw and stayed put (the
/// Bedroom TV). Its controls stay focusable; once shown, it is searched
/// as before, covered or not (a title's page opened from it keeps its
/// first focus as it was).
class _OnTopOnly extends StatefulWidget {
  const new(this.child);

  final Widget child;

  @override
  State<_OnTopOnly> createState() => _OnTopOnlyState();
}

class _OnTopOnlyState extends State<_OnTopOnly> {
  /// On top once, so laid out: a route on top is on stage.
  bool _shown = false;

  @override
  Widget build(BuildContext context) {
    if (ModalRoute.isCurrentOf(context) ?? true) _shown = true;
    return Focus(
      canRequestFocus: false,
      skipTraversal: true,
      includeSemantics: false,
      descendantsAreTraversable: _shown,
      child: widget.child,
    );
  }
}

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
