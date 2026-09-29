import 'package:iptv_player/features/guide/domain/epg.dart';
import 'package:iptv_player/features/live_tv/domain/channels.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'guide_programme_request.g.dart';

/// A programme the Guide shows as soon as it can, cursor on it and its
/// sheet open: set by search for an upcoming programme (Phase 6 decision
/// 4), read once by the Guide.
@Riverpod(keepAlive: true)
class GuideProgrammeRequest extends _$GuideProgrammeRequest {
  @override
  ({ChannelItem channel, EpgProgramme programme})? build() => null;

  void show(ChannelItem channel, EpgProgramme programme) =>
      state = (channel: channel, programme: programme);

  /// The pending programme, once.
  ({ChannelItem channel, EpgProgramme programme})? take() {
    final request = state;
    if (request != null) state = null;
    return request;
  }
}
