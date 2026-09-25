import 'package:go_router/go_router.dart';
import 'package:iptv_player/app/destinations.dart';
import 'package:iptv_player/features/settings/presentation/settings_section.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'guide_match_request.g.dart';

/// A channel whose Match… picker Settings → Guide opens as soon as it
/// shows: set by the Live TV preview's "Match to a guide channel".
@Riverpod(keepAlive: true)
class GuideMatchRequest extends _$GuideMatchRequest {
  @override
  int? build() => null;

  int? get channelId => state;

  set channelId(int? channelId) => state = channelId;

  /// The pending channel, once: the picker opens for it a single time.
  int? take() {
    final channelId = state;
    if (channelId != null) state = null;
    return channelId;
  }
}

/// Opens Settings → Guide for [sourceId] with the Match… picker for
/// [channelId] on top. Reads nothing from a `ref`: the caller passes the
/// notifiers, read before any await.
void openGuideMatch(
  GoRouter router,
  SettingsLocation location,
  GuideMatchRequest request, {
  required String sourceId,
  required int channelId,
}) {
  location.showGuide(sourceId);
  request.channelId = channelId;
  router.go(AppDestination.settings.path);
}
