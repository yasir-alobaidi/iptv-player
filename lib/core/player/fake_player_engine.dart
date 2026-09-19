import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:iptv_player/core/player/player_engine.dart';

/// A [PlayerEngine] for tests: it records what it was asked to do, and the
/// test says what the "stream" does next ([firstFrame], [fail], [end], …).
final class FakePlayerEngine implements PlayerEngine {
  new({this.stopDelay = Duration.zero});

  /// How long [stop] takes to "close the connection".
  Duration stopDelay;

  final _events = StreamController<PlayerEvent>.broadcast(sync: true);

  /// Every [open], oldest first.
  final List<PlayRequest> opened = [];

  /// Calls other than [open], as short strings (`stop`, `mute:true`, …).
  final List<String> calls = [];

  int _generation = 0;
  bool _playing = false;
  bool disposed = false;
  StreamInfo info = const StreamInfo();

  PlayRequest? get current => _playing ? opened.lastOrNull : null;
  int get generation => _generation;
  bool get playing => _playing;

  @override
  Stream<PlayerEvent> get events => _events.stream;

  void emit(PlayerEvent event) {
    if (!_events.isClosed) _events.add(event);
  }

  void firstFrame() => emit(PlayerFirstFrame(_generation));

  void progress(Duration position, {Duration buffered = Duration.zero}) =>
      emit(PlayerProgress(position: position, buffered: buffered));

  void buffering({required bool on}) => emit(PlayerBuffering(buffering: on));

  void fail([String message = 'Failed to open']) {
    _playing = false;
    emit(PlayerFailed(message));
  }

  void end() {
    _playing = false;
    emit(const PlayerEnded());
  }

  @override
  Future<void> open(PlayRequest request) async {
    _generation++;
    _playing = true;
    opened.add(request);
    emit(PlayerOpening(_generation));
  }

  @override
  Future<void> stop() async {
    _generation++;
    _playing = false;
    calls.add('stop');
    if (stopDelay > Duration.zero) await Future<void>.delayed(stopDelay);
  }

  @override
  Future<void> setPaused({required bool paused}) async =>
      calls.add('paused:$paused');

  @override
  Future<void> setVolume(double volume) async => calls.add('volume:$volume');

  @override
  Future<void> setMuted({required bool muted}) async =>
      calls.add('muted:$muted');

  @override
  Future<void> selectAudio(String? id) async => calls.add('audio:$id');

  @override
  Future<void> selectSubtitle(String? id) async => calls.add('subtitle:$id');

  @override
  Future<void> setAspect(AspectMode mode) async =>
      calls.add('aspect:${mode.name}');

  @override
  Future<void> setDeinterlace({required bool on}) async =>
      calls.add('deinterlace:$on');

  @override
  Future<StreamInfo> streamInfo() async => info;

  @override
  Widget videoView({
    required Color background,
    Key? key,
    BoxFit fit = BoxFit.contain,
  }) => ColoredBox(
    key: key ?? const ValueKey('fake-video'),
    color: background,
    child: const SizedBox.expand(),
  );

  @override
  Future<void> dispose() async {
    disposed = true;
    await _events.close();
  }
}
