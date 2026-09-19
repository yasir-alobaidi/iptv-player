import 'package:flutter/foundation.dart';
import 'package:iptv_player/features/live_tv/domain/channels.dart';
import 'package:iptv_player/features/sources/presentation/current_source.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'live_tv_state.g.dart';

/// What the Live TV screen shows: the list's query and the channel the
/// preview is on. Starts over when the source changes.
@immutable
final class LiveTvView {
  const new({required this.query, this.selected});

  final ChannelQuery query;

  /// The channel the preview pane shows (and, after a moment, plays).
  final ChannelItem? selected;

  LiveTvView copyWith({ChannelQuery? query, ChannelItem? selected}) =>
      LiveTvView(
        query: query ?? this.query,
        selected: selected ?? this.selected,
      );

  @override
  bool operator ==(Object other) =>
      other is LiveTvView && other.query == query && other.selected == selected;

  @override
  int get hashCode => Object.hash(query, selected);
}

@riverpod
class LiveTvController extends _$LiveTvController {
  @override
  LiveTvView? build() {
    final source = ref.watch(currentSourceProvider);
    if (source == null) return null;
    return LiveTvView(query: ChannelQuery(sourceId: source.id));
  }

  /// Shows [filter]'s channels; the filter text and "show hidden" reset.
  void showFilter(ChannelFilter filter) {
    final view = state;
    if (view == null || view.query.filter == filter) return;
    state = LiveTvView(
      query: view.query.copyWith(filter: filter, text: '', showHidden: false),
      selected: view.selected,
    );
  }

  void setText(String text) {
    final view = state;
    if (view == null) return;
    state = view.copyWith(query: view.query.copyWith(text: text));
  }

  void setSort(ChannelSort sort) {
    final view = state;
    if (view == null) return;
    state = view.copyWith(query: view.query.copyWith(sort: sort));
  }

  void setShowHidden({required bool show}) {
    final view = state;
    if (view == null) return;
    state = view.copyWith(query: view.query.copyWith(showHidden: show));
  }

  void select(ChannelItem channel) {
    final view = state;
    if (view == null || view.selected == channel) return;
    state = view.copyWith(selected: channel);
  }
}
