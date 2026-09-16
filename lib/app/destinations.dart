import 'package:iptv_player/design/app_icon.dart';

/// The shell's navigation destinations, in nav-rail order (docs/05).
///
/// Each one is a branch of the router's stateful shell route, so its
/// screen keeps its scroll position and state while the user is somewhere
/// else. Search is deliberately not here: it is an overlay opened with
/// Ctrl+K or `/`, and the canvas has no Search item in the rail (ADR-008).
enum AppDestination {
  home(path: '/', label: 'Home', icon: AppIcons.home, shortcut: 'Ctrl 1'),
  liveTv(
    path: '/live',
    label: 'Live TV',
    icon: AppIcons.liveTv,
    shortcut: 'Ctrl 2',
  ),
  guide(
    path: '/guide',
    label: 'Guide',
    icon: AppIcons.guide,
    shortcut: 'Ctrl 3',
  ),
  movies(
    path: '/movies',
    label: 'Movies',
    icon: AppIcons.movies,
    shortcut: 'Ctrl 4',
  ),
  series(
    path: '/series',
    label: 'Series',
    icon: AppIcons.series,
    shortcut: 'Ctrl 5',
  ),
  favorites(
    path: '/favorites',
    label: 'Favorites',
    icon: AppIcons.star,
    shortcut: 'Ctrl 6',
  ),
  library(
    path: '/library',
    label: 'Library',
    icon: AppIcons.library,
    shortcut: 'Ctrl 7',
  ),
  settings(
    path: '/settings',
    label: 'Settings',
    icon: AppIcons.settings,
    shortcut: 'Ctrl ,',
  );

  new({
    required this.path,
    required this.label,
    required this.icon,
    required this.shortcut,
  });

  final String path;
  final String label;
  final AppIcons icon;

  /// Shown in the rail item's tooltip (docs/05: tooltips show shortcuts).
  final String shortcut;

  // `index` comes from Enum: declaration order is the rail's order and
  // the router's branch order.

  /// The destinations above the rail's spacer; Settings sits below it, as
  /// on the canvas.
  static List<AppDestination> get primary =>
      values.where((d) => d != AppDestination.settings).toList();

  /// Ctrl+1 … Ctrl+7 (docs/05). Ctrl+, opens Settings and is handled
  /// separately.
  static AppDestination? forNumberKey(int number) =>
      number >= 1 && number <= 7 ? values[number - 1] : null;
}
