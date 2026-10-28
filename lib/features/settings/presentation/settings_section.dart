import 'package:go_router/go_router.dart';
import 'package:iptv_player/app/destinations.dart';
import 'package:iptv_player/core/platform/form_factor.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'settings_section.g.dart';

/// Settings' sub-navigation, in the canvas's order (docs/05 §12).
enum SettingsSection {
  sources('Sources'),
  playback('Playback'),
  casting('Casting'),
  downloads('Downloads & library'),
  guide('Guide'),
  categories('Categories'),
  appearance('Appearance'),
  shortcuts('Keyboard shortcuts'),
  data('Data'),
  about('About & diagnostics');

  new(this.label);

  final String label;

  /// The sections on [formFactor]: a TV has no casting (it is the
  /// player), no downloads or library, and no keyboard (docs/07); a phone
  /// or tablet neither (ADR-068).
  static List<SettingsSection> on(FormFactor formFactor) =>
      !formFactor.isDesktop
      ? values
            .where((s) => s != casting && s != downloads && s != shortcuts)
            .toList()
      : values;
}

/// Where Settings is: the section it shows, and the source each per-source
/// section manages (Categories, Guide). Kept for the session, so leaving
/// Settings and coming back returns to the same place.
///
/// [opened]: the section is open rather than the list of sections, where
/// Settings shows one pane at a time (a phone's width, ADR-068). Two
/// panes show both and ignore it.
typedef SettingsPlace = ({
  SettingsSection section,
  String? categoriesSourceId,
  String? guideSourceId,
  bool opened,
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
    opened: false,
  );

  /// Opens [section] (on a phone's width, in place of the list).
  void show(SettingsSection section) => state = (
    section: section,
    categoriesSourceId: state.categoriesSourceId,
    guideSourceId: state.guideSourceId,
    opened: true,
  );

  /// Back to the list of sections, on a phone's width; the section shown
  /// last stays the one the list returns to.
  void showList() => state = (
    section: state.section,
    categoriesSourceId: state.categoriesSourceId,
    guideSourceId: state.guideSourceId,
    opened: false,
  );

  /// The Categories section for [sourceId].
  void showCategories(String sourceId) => state = (
    section: SettingsSection.categories,
    categoriesSourceId: sourceId,
    guideSourceId: state.guideSourceId,
    opened: true,
  );

  /// The Guide section for [sourceId].
  void showGuide(String sourceId) => state = (
    section: SettingsSection.guide,
    categoriesSourceId: state.categoriesSourceId,
    guideSourceId: sourceId,
    opened: true,
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
