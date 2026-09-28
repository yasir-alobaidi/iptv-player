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

  /// Opens (`open`) and every other call, in the order they came.
  final List<String> sequence = [];

  int _generation = 0;
  bool _playing = false;
  bool disposed = false;
  StreamInfo info = const StreamInfo();

  void _call(String call) {
    calls.add(call);
    sequence.add(call);
  }

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

  /// The file's length, as the player learns it.
  void duration(Duration duration) => emit(PlayerDuration(duration));

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
    sequence.add('open');
    emit(PlayerOpening(_generation));
  }

  @override
  Future<void> stop() async {
    _generation++;
    _playing = false;
    _call('stop');
    if (stopDelay > Duration.zero) await Future<void>.delayed(stopDelay);
  }

  /// Reported back at once, as mpv does.
  @override
  Future<void> setPaused({required bool paused}) async {
    _call('paused:$paused');
    if (_playing) emit(PlayerPaused(paused: paused));
  }

  /// Recorded as `seek:<ms>`; the test reports the new position.
  @override
  Future<void> seek(Duration position) async =>
      _call('seek:${position.inMilliseconds}');

  @override
  Future<void> setVolume(double volume) async => _call('volume:$volume');

  @override
  Future<void> setMuted({required bool muted}) async => _call('muted:$muted');

  @override
  Future<void> selectAudio(String? id) async => _call('audio:$id');

  @override
  Future<void> selectSubtitle(String? id) async => _call('subtitle:$id');

  @override
  Future<void> setAspect(AspectMode mode) async => _call('aspect:${mode.name}');

  @override
  Future<void> setDeinterlace({required bool on}) async =>
      _call('deinterlace:$on');

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
