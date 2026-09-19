import 'package:go_router/go_router.dart';
import 'package:iptv_player/app/destinations.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'settings_section.g.dart';

/// Settings' sub-navigation, in the canvas's order (docs/05 §12).
enum SettingsSection {
  sources('Sources'),
  playback('Playback', phase: 9),
  casting('Casting', phase: 7),
  downloads('Downloads & library', phase: 8),
  guide('Guide', phase: 4),
  categories('Categories'),
  appearance('Appearance', phase: 9),
  shortcuts('Keyboard shortcuts', phase: 9),
  data('Data', phase: 9),
  about('About & diagnostics', phase: 9);

  new(this.label, {this.phase});

  final String label;

  /// The phase that builds the section; null once it is built.
  final int? phase;
}

/// Which section Settings shows, and which source the Categories section
/// manages. Kept for the session, so leaving Settings and coming back
/// returns to the same place.
@Riverpod(keepAlive: true)
class SettingsLocation extends _$SettingsLocation {
  @override
  ({SettingsSection section, String? categoriesSourceId}) build() =>
      (section: SettingsSection.sources, categoriesSourceId: null);

  void show(SettingsSection section) =>
      state = (section: section, categoriesSourceId: state.categoriesSourceId);

  /// The Categories section for [sourceId].
  void showCategories(String sourceId) => state = (
    section: SettingsSection.categories,
    categoriesSourceId: sourceId,
  );
}

/// Opens Settings at [section] from anywhere: the top bar's "Manage
/// sources…", the expiry banner, a source's "Categories".
void openSettings(
  GoRouter router,
  SettingsLocation location,
  SettingsSection section, {
  String? categoriesSourceId,
}) {
  if (categoriesSourceId != null) {
    location.showCategories(categoriesSourceId);
  } else {
    location.show(section);
  }
  router.go(AppDestination.settings.path);
}
