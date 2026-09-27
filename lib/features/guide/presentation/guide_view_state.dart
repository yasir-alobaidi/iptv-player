import 'package:iptv_player/features/live_tv/domain/channels.dart';
import 'package:iptv_player/features/sources/presentation/current_source.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'guide_view_state.g.dart';

/// Which channels the Guide lists: the current source's, all of them or
/// one category's, in number order as Live TV sorts them. Its own, not
/// Live TV's: choosing a category in one screen leaves the other alone.
/// Starts over when the source changes.
@riverpod
class GuideChannels extends _$GuideChannels {
  @override
  ChannelQuery? build() {
    final source = ref.watch(currentSourceProvider);
    if (source == null) return null;
    return ChannelQuery(sourceId: source.id);
  }

  void showFilter(ChannelFilter filter) {
    final query = state;
    if (query == null || query.filter == filter) return;
    state = query.copyWith(filter: filter);
  }
}
