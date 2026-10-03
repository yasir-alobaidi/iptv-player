import 'package:iptv_player/core/cast/cast_device.dart';
import 'package:iptv_player/features/casting/data/casting_providers.dart';
import 'package:iptv_player/features/casting/domain/casting_state.dart';
import 'package:iptv_player/features/playback/domain/playback_state.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'casting_view_state.g.dart';

/// The cast as it changes, for the screens.
@Riverpod(keepAlive: true)
Stream<CastingState> castingState(Ref ref) async* {
  final coordinator = ref.watch(castCoordinatorProvider);
  yield coordinator.state;
  yield* coordinator.states;
}

/// Where a movie or an episode is on the TV.
@Riverpod(keepAlive: true)
Stream<VodTimeline> castTimeline(Ref ref) async* {
  final coordinator = ref.watch(castCoordinatorProvider);
  yield coordinator.timeline;
  yield* coordinator.timelines;
}

/// Whether the casting view shows in place of the screen (the canvas
/// draws it inside the shell). It closes by itself when the session ends.
@Riverpod(keepAlive: true)
class CastingViewOpen extends _$CastingViewOpen {
  @override
  bool build() {
    ref.listen(castingStateProvider, (_, next) {
      if (next.value?.active == false && state) state = false;
    });
    return false;
  }

  void open() => state = true;

  void close() => state = false;
}

/// The devices the app keeps, with their settings and what they taught.
@riverpod
Stream<List<KnownCastDevice>> knownCastDevices(Ref ref) =>
    ref.watch(castDeviceStoreProvider).watchAll();
