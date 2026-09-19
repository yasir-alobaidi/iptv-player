import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:iptv_player/core/logging/app_log.dart';
import 'package:iptv_player/core/logging/redact.dart';
import 'package:iptv_player/core/logging/secret_registry.dart';
import 'package:iptv_player/core/player/player_engine.dart';
import 'package:media_kit/media_kit.dart';
import 'package:media_kit_video/media_kit_video.dart';

const _tag = 'player';

/// docs/03's base options, set once. Every name was checked against the
/// system libmpv 0.34.1 (ADR-003).
const _baseOptions = {
  'cache': 'yes',
  // 0.34.1 logs "Failed to create file cache" on every open otherwise.
  'cache-on-disk': 'no',
  'network-timeout': '10',
  'stream-lavf-o': 'reconnect=1,reconnect_streamed=1,reconnect_delay_max=5',
};

/// docs/03's buffer presets.
const Map<BufferPreset, Map<String, String>> _presetOptions = {
  BufferPreset.lowLatency: {
    'cache-secs': '2',
    'demuxer-max-bytes': '32MiB',
    'demuxer-readahead-secs': '2',
    'demuxer-lavf-probesize': '500000',
    'demuxer-lavf-analyzeduration': '0.5',
  },
  BufferPreset.balanced: {
    'cache-secs': '8',
    'demuxer-max-bytes': '64MiB',
    'demuxer-readahead-secs': '8',
    'demuxer-lavf-probesize': '1000000',
    'demuxer-lavf-analyzeduration': '1',
  },
  BufferPreset.stable: {
    'cache-secs': '20',
    'demuxer-max-bytes': '128MiB',
    'demuxer-readahead-secs': '20',
    'demuxer-lavf-probesize': '2000000',
    'demuxer-lavf-analyzeduration': '2',
  },
};

/// "Bound memory" behind the live edge; VOD keeps more to seek back into.
const _liveBackBytes = '16MiB';
const _vodBackBytes = '64MiB';

/// The mpv options [MediaKitPlayerEngine] sets for [request], in order:
/// the preset, then what varies per stream. Exposed for tests.
Map<String, String> mpvOptionsFor(PlayRequest request) => {
  ..._presetOptions[request.preset]!,
  'demuxer-max-back-bytes': request.live ? _liveBackBytes : _vodBackBytes,
  'user-agent': request.userAgent ?? '',
  'alang': request.audioLanguages.join(','),
  'slang': request.subtitleLanguages.join(','),
  if (request.deinterlace != null)
    'deinterlace': request.deinterlace! ? 'yes' : 'no',
};

/// [PlayerEngine] on media_kit (libmpv) with our patched media_kit_video
/// (ADR-003). One instance for the app's lifetime; every channel is an
/// `open` on it.
final class MediaKitPlayerEngine implements PlayerEngine {
  new _(this._player, this._controller, this._log, this._secrets);

  /// [video] false runs mpv with no video output (`vo=null`): decoding,
  /// network and audio as usual, nothing drawn. For headless runs with
  /// no GPU (ADR-010, step 1).
  static Future<MediaKitPlayerEngine> create({
    required AppLog log,
    required SecretRegistry secrets,
    bool video = true,
  }) async {
    MediaKit.ensureInitialized();
    final player = Player(
      configuration: PlayerConfiguration(
        title: 'IPTV Player',
        logLevel: MPVLogLevel.warn,
        vo: video ? null : 'null',
      ),
    );
    // Our own property calls skip media_kit's wait for the video
    // controller: that waits for the first texture, which needs frames
    // drawn, and mpv doesn't need the controller for options.
    await (player.platform! as NativePlayer).waitForPlayerInitialization;
    final controller = video
        ? VideoController(
            player,
            configuration: const VideoControllerConfiguration(
              hwdec: 'auto-safe',
            ),
          )
        : null;
    final engine = MediaKitPlayerEngine._(player, controller, log, secrets);
    await engine._start();
    return engine;
  }

  final Player _player;
  final VideoController? _controller;
  final AppLog _log;
  final SecretRegistry _secrets;

  final _events = StreamController<PlayerEvent>.broadcast();
  final _subscriptions = <StreamSubscription<Object?>>[];

  NativePlayer get _native => _player.platform! as NativePlayer;

  Future<void> _set(String name, String value) =>
      _native.setProperty(name, value, waitForInitialization: false);

  Future<String> _get(String name) =>
      _native.getProperty(name, waitForInitialization: false);

  /// Counts opens; a poll or event from an older open is dropped.
  int _generation = 0;
  bool _open = false;
  bool _started = false;
  Timer? _firstFramePoll;
  String? _lastError;
  Duration _position = Duration.zero;
  Duration _buffered = Duration.zero;
  DateTime _lastProgress = DateTime.fromMillisecondsSinceEpoch(0);
  bool _disposed = false;

  @override
  Stream<PlayerEvent> get events => _events.stream;

  Future<void> _start() async {
    for (final MapEntry(:key, :value) in _baseOptions.entries) {
      await _set(key, value);
    }
    // media_kit leaves video decoding off until a VideoController turns it
    // on; with no picture wanted, decode anyway, so the watchdog and the
    // stream info see the same stream a window would.
    if (_controller == null) await _set('vid', 'auto');
    _subscriptions
      ..add(_player.stream.position.listen(_onPosition))
      ..add(_player.stream.completed.listen(_onCompleted))
      ..add(_player.stream.error.listen(_onError))
      ..add(_player.stream.videoParams.listen(_onVideoParams))
      ..add(_player.stream.tracks.listen((_) => _emitTracks()))
      ..add(_player.stream.track.listen((_) => _emitTracks()));
    await _native.observeProperty(
      'paused-for-cache',
      waitForInitialization: false,
      (value) async {
        if (_open) _emit(PlayerBuffering(buffering: value == 'yes'));
      },
    );
    await _native.observeProperty(
      'demuxer-cache-duration',
      waitForInitialization: false,
      (value) async {
        final seconds = double.tryParse(value);
        if (seconds != null) {
          _buffered = Duration(milliseconds: (seconds * 1000).round());
        }
      },
    );
    // mpv goes idle when a stream fails to open or its file ends.
    await _native.observeProperty('idle-active', waitForInitialization: false, (
      value,
    ) async {
      if (value != 'yes' || !_open) return;
      if (_started) {
        _open = false;
        _emit(const PlayerEnded());
      } else if (_firstFramePoll != null) {
        _fail(_lastError ?? 'The stream closed before it started.');
      }
    });
  }

  void _emit(PlayerEvent event) {
    if (!_disposed) _events.add(event);
  }

  String _clean(String text) => redact(text, secrets: _secrets.values);

  @override
  Future<void> open(PlayRequest request) async {
    final generation = ++_generation;
    _firstFramePoll?.cancel();
    _open = true;
    _started = false;
    _lastError = null;
    _position = Duration.zero;
    _buffered = Duration.zero;
    _emit(PlayerOpening(generation));
    for (final MapEntry(:key, :value) in mpvOptionsFor(request).entries) {
      await _set(key, value);
    }
    if (request.deinterlace == null) {
      await _set('deinterlace', 'no');
    }
    await _player.open(Media(request.url));
    if (generation != _generation) return;
    _pollFirstFrame(generation, autoDeinterlace: request.deinterlace == null);
  }

  /// The spike's proven test (ADR-003): the new file is playing and its
  /// video size is known, or it has no video at all.
  void _pollFirstFrame(int generation, {required bool autoDeinterlace}) {
    _firstFramePoll = Timer.periodic(const Duration(milliseconds: 40), (
      timer,
    ) async {
      if (generation != _generation || !_open) {
        timer.cancel();
        return;
      }
      final time = await _get('playback-time');
      if (time.isEmpty) return;
      final width = await _get('video-params/w');
      final noVideo = (await _get('vid')) == 'no';
      if (width.isEmpty && !noVideo) return;
      if (generation != _generation || timer != _firstFramePoll) return;
      timer.cancel();
      _firstFramePoll = null;
      _started = true;
      _emit(PlayerFirstFrame(generation));
      if (autoDeinterlace) await _autoDeinterlace(generation);
    });
  }

  /// docs/03 "Auto": 0.34.1's `deinterlace` is only yes/no, so follow the
  /// stream's own interlacing.
  Future<void> _autoDeinterlace(int generation) async {
    final interlaced = await _get('video-frame-info/interlaced');
    if (generation == _generation && interlaced == 'yes') {
      await _set('deinterlace', 'yes');
    }
  }

  void _fail(String message) {
    _firstFramePoll?.cancel();
    _firstFramePoll = null;
    _open = false;
    final text = _clean(message);
    _log.warning(_tag, 'Playback failed: $text');
    _emit(PlayerFailed(text));
  }

  void _onPosition(Duration position) {
    if (!_open) return;
    _position = position;
    final now = DateTime.now();
    // mpv reports every frame; the watchdog needs a few a second.
    if (now.difference(_lastProgress) < const Duration(milliseconds: 250)) {
      return;
    }
    _lastProgress = now;
    _emit(PlayerProgress(position: _position, buffered: _buffered));
  }

  void _onCompleted(bool completed) {
    if (!completed || !_open) return;
    _open = false;
    _emit(const PlayerEnded());
  }

  void _onError(String text) {
    // Kept as the detail for a failure; decoder hiccups and the like are
    // not failures by themselves (the watchdog decides).
    _lastError = text;
    _log.debug(_tag, 'mpv: ${_clean(text)}');
  }

  void _onVideoParams(VideoParams params) {
    final width = params.w;
    final height = params.h;
    if (width == null || height == null || width == 0) return;
    _emit(PlayerVideoChanged(width: width, height: height));
  }

  void _emitTracks() {
    final tracks = _player.state.tracks;
    final current = _player.state.track;
    bool real(String id) => id != 'auto' && id != 'no';
    _emit(
      PlayerTracks(
        audio: [
          for (final t in tracks.audio)
            if (real(t.id))
              MediaTrack(
                id: t.id,
                title: t.title,
                language: t.language,
                codec: t.codec,
                channels: t.channels,
              ),
        ],
        subtitles: [
          for (final t in tracks.subtitle)
            if (real(t.id))
              MediaTrack(
                id: t.id,
                title: t.title,
                language: t.language,
                codec: t.codec,
              ),
        ],
        audioId: real(current.audio.id) ? current.audio.id : null,
        subtitleId: real(current.subtitle.id) ? current.subtitle.id : null,
      ),
    );
  }

  @override
  Future<void> stop() async {
    _generation++;
    _firstFramePoll?.cancel();
    _firstFramePoll = null;
    _open = false;
    _started = false;
    await _player.stop();
    // The connection is closed once mpv is idle again.
    for (var i = 0; i < 50; i++) {
      if ((await _get('idle-active')) == 'yes') return;
      await Future<void>.delayed(const Duration(milliseconds: 20));
    }
  }

  @override
  Future<void> setPaused({required bool paused}) =>
      paused ? _player.pause() : _player.play();

  @override
  Future<void> setVolume(double volume) =>
      _player.setVolume(volume.clamp(0, 100).toDouble());

  @override
  Future<void> setMuted({required bool muted}) =>
      _set('mute', muted ? 'yes' : 'no');

  @override
  Future<void> selectAudio(String? id) => _set('aid', id ?? 'auto');

  @override
  Future<void> selectSubtitle(String? id) => _set('sid', id ?? 'no');

  @override
  Future<void> setAspect(AspectMode mode) async {
    final (keep, override, panscan) = switch (mode) {
      AspectMode.fit => ('yes', '-1', '0'),
      AspectMode.fill => ('yes', '-1', '1'),
      AspectMode.stretch => ('no', '-1', '0'),
      AspectMode.ratio16x9 => ('yes', '16:9', '0'),
      AspectMode.ratio4x3 => ('yes', '4:3', '0'),
    };
    await _set('keepaspect', keep);
    await _set('video-aspect-override', override);
    await _set('panscan', panscan);
  }

  @override
  Future<void> setDeinterlace({required bool on}) =>
      _set('deinterlace', on ? 'yes' : 'no');

  @override
  Future<StreamInfo> streamInfo() async {
    Future<String> read(String name) => _get(name);
    int? integer(String text) => int.tryParse(text);
    double? decimal(String text) => double.tryParse(text);
    final hwdec = await read('hwdec-current');
    final fps =
        decimal(await read('estimated-vf-fps')) ??
        decimal(await read('container-fps'));
    final cache = decimal(await read('demuxer-cache-duration'));
    final interlaced = await read('video-frame-info/interlaced');
    return StreamInfo(
      width: integer(await read('video-params/w')),
      height: integer(await read('video-params/h')),
      fps: fps,
      videoCodec: _nonEmpty(await read('video-codec')),
      hardwareDecoder: hwdec.isEmpty || hwdec == 'no' ? null : hwdec,
      audioCodec: _nonEmpty(await read('audio-codec-name')),
      audioChannels: integer(await read('audio-params/channel-count')),
      videoBitrate: decimal(await read('video-bitrate'))?.round(),
      buffered: cache == null
          ? null
          : Duration(milliseconds: (cache * 1000).round()),
      droppedFrames: integer(await read('frame-drop-count')),
      interlaced: interlaced.isEmpty ? null : interlaced == 'yes',
    );
  }

  static String? _nonEmpty(String text) => text.isEmpty ? null : text;

  @override
  Widget videoView({
    required Color background,
    Key? key,
    BoxFit fit = BoxFit.contain,
  }) {
    final controller = _controller;
    if (controller == null) {
      return ColoredBox(
        key: key,
        color: background,
        child: const SizedBox.expand(),
      );
    }
    return Video(
      key: key,
      controller: controller,
      fit: fit,
      controls: null,
      fill: background,
    );
  }

  @override
  Future<void> dispose() async {
    _disposed = true;
    _firstFramePoll?.cancel();
    for (final subscription in _subscriptions) {
      await subscription.cancel();
    }
    await _events.close();
    await _player.dispose();
  }
}
