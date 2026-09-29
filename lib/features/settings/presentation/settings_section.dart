import 'package:go_router/go_router.dart';
import 'package:iptv_player/app/destinations.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'settings_section.g.dart';

/// Settings' sub-navigation, in the canvas's order (docs/05 §12).
enum SettingsSection {
  sources('Sources'),
  playback('Playback'),
  casting('Casting', phase: 7),
  downloads('Downloads & library', phase: 8),
  guide('Guide'),
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

/// Where Settings is: the section it shows, and the source each per-source
/// section manages (Categories, Guide). Kept for the session, so leaving
/// Settings and coming back returns to the same place.
typedef SettingsPlace = ({
  SettingsSection section,
  String? categoriesSourceId,
  String? guideSourceId,
});

/// Which section Settings shows, and which source the Categories and
/// Guide sections manage.
@Riverpod(keepAlive: true)
class SettingsLocation extends _$SettingsLocation {
  @override
  SettingsPlace build() => (
    section: SettingsSection.sources,
    categoriesSourceId: null,
    guideSourceId: null,
  );

  void show(SettingsSection section) => state = (
    section: section,
    categoriesSourceId: state.categoriesSourceId,
    guideSourceId: state.guideSourceId,
  );

  /// The Categories section for [sourceId].
  void showCategories(String sourceId) => state = (
    section: SettingsSection.categories,
    categoriesSourceId: sourceId,
    guideSourceId: state.guideSourceId,
  );

  /// The Guide section for [sourceId].
  void showGuide(String sourceId) => state = (
    section: SettingsSection.guide,
    categoriesSourceId: state.categoriesSourceId,
    guideSourceId: sourceId,
  );
}

/// Settings → Categories opens on its Hidden channels tab, once: asked
/// by Live TV's "Manage" when only channels are hidden, and by search's
/// "Show in Settings" (Phase 6 decision 8).
@Riverpod(keepAlive: true)
class HiddenChannelsRequest extends _$HiddenChannelsRequest {
  @override
  bool build() => false;

  void ask() => state = true;

  /// Whether it was asked for, once.
  bool take() {
    final asked = state;
    if (asked) state = false;
    return asked;
  }
}

/// Opens Settings → Categories for [sourceId] on its Hidden channels
/// tab. Reads nothing from a `ref`: the caller passes the notifiers.
void openHiddenChannels(
  GoRouter router,
  SettingsLocation location,
  HiddenChannelsRequest request, {
  required String sourceId,
}) {
  location.showCategories(sourceId);
  request.ask();
  router.go(AppDestination.settings.path);
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
