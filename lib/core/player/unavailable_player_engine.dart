import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:iptv_player/core/player/player_engine.dart';

/// The engine when the real one couldn't start (libmpv missing or
/// broken): the app still opens (hard rule 1), and every play fails with
/// [reason] behind Details.
final class UnavailablePlayerEngine implements PlayerEngine {
  new(this.reason);

  final String reason;
  final _events = StreamController<PlayerEvent>.broadcast();
  int _generation = 0;

  @override
  Stream<PlayerEvent> get events => _events.stream;

  @override
  Future<void> open(PlayRequest request) async {
    _events
      ..add(PlayerOpening(++_generation))
      ..add(PlayerFailed('The video player could not start: $reason'));
  }

  @override
  Future<void> stop() async {}

  @override
  Future<void> setPaused({required bool paused}) async {}

  @override
  Future<void> setVolume(double volume) async {}

  @override
  Future<void> setMuted({required bool muted}) async {}

  @override
  Future<void> selectAudio(String? id) async {}

  @override
  Future<void> selectSubtitle(String? id) async {}

  @override
  Future<void> setAspect(AspectMode mode) async {}

  @override
  Future<void> setDeinterlace({required bool on}) async {}

  @override
  Future<StreamInfo> streamInfo() async => const StreamInfo();

  @override
  Widget videoView({
    required Color background,
    Key? key,
    BoxFit fit = BoxFit.contain,
  }) => ColoredBox(key: key, color: background, child: const SizedBox.expand());

  @override
  Future<void> dispose() => _events.close();
}
