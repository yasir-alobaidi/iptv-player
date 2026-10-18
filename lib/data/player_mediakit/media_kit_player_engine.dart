import 'dart:async';
import 'dart:io';

import 'package:flutter/widgets.dart';
import 'package:iptv_player/core/app_identity.dart';
import 'package:iptv_player/core/logging/app_log.dart';
import 'package:iptv_player/core/logging/redact.dart';
import 'package:iptv_player/core/logging/secret_registry.dart';
import 'package:iptv_player/core/player/player_engine.dart';
import 'package:iptv_player/core/player/player_version.dart';
import 'package:iptv_player/data/player_mediakit/desktop_picture.dart';
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

/// A TV's caps (docs/07: a 2 GB device; the Chromecast with Google TV had
/// about 200 MB free with a film playing): at most this much read ahead,
/// whatever the preset, and this much kept behind, a film's too. The
/// preset's seconds still apply below the cap; a seek further back than
/// [_lowMemoryBackBytes] asks the server again.
const _lowMemoryAheadBytes = '32MiB';
const _lowMemoryBackBytes = '16MiB';

/// mpv's `hwdec` for Settings → Playback → Hardware decoding: Automatic
/// (ADR-003: only the decoders mpv lists as safe) and Off.
const hwdecAutomatic = 'auto-safe';
const hwdecOff = 'no';

/// On Android, MediaCodec decoding straight into the picture's surface
/// (`vo=mediacodec_embed`), the only decoder that output takes. mpv's own
/// `gpu` output copies every decoded frame back (`mediacodec-copy`) and
/// dropped about 65% of a 720p50 channel's frames on a Chromecast with
/// Google TV; this output dropped none (ADR-025).
const hwdecDirect = 'mediacodec';
const _directOutput = 'mediacodec_embed';

/// Diagnostics for a TV, where mpv's log is otherwise out of reach: a
/// build with `--dart-define=BIJOU_MPV_LOG=ao,ad,cplayer` writes mpv's
/// verbose lines from those modules to the app's log, and so to logcat
/// (docs/setup.md §7).
const _mpvLog = String.fromEnvironment('BIJOU_MPV_LOG');

/// The picture widget's fit on Android's direct output, which draws whole
/// frames and skips mpv's scaler: `keepaspect` and `panscan` do nothing
/// there, so Fill and Stretch are the widget's (a 4:3 channel kept its
/// bars on the Bedroom TV). The ratios are mpv's `video-aspect-override`,
/// which the widget follows. The desktop's too, whose texture has the
/// video's own shape unless High sizes it ([DesktopPicture]). Exposed for
/// tests.
BoxFit directOutputFit(AspectMode mode) => switch (mode) {
  AspectMode.fill => BoxFit.cover,
  AspectMode.stretch => BoxFit.fill,
  AspectMode.fit ||
  AspectMode.ratio16x9 ||
  AspectMode.ratio4x3 => BoxFit.contain,
};

/// Settings → Playback → Picture quality's High, on the desktop: mpv
/// 0.34's `gpu-hq` profile, option by option (the profile's name and what
/// it holds differ between mpv versions, and Windows ships another mpv).
/// Standard puts back what the running mpv had for each when the engine
/// started.
const highQualityPicture = {
  'scale': 'spline36',
  'cscale': 'spline36',
  'dscale': 'mitchell',
  'dither-depth': 'auto',
  'correct-downscaling': 'yes',
  'linear-downscaling': 'yes',
  'sigmoid-upscaling': 'yes',
  'deband': 'yes',
};

/// The mpv options [MediaKitPlayerEngine] sets for [request], in order:
/// the preset, then what varies per stream. Exposed for tests.
///
/// [picture] false is a player with no video output: there Automatic
/// leaves `hwdec` alone (nothing for a graphics card to draw to), and Off
/// still says no. [direct] is Android's direct output, which shows only
/// what MediaCodec decodes: Off there waits for the next launch.
/// [lowMemory] is a TV's smaller buffers.
///
/// [scaling] is the desktop's picture, which mpv scales itself for High:
/// the quality mpv's filters are set for now, and the running mpv's own
/// value of each of [highQualityPicture]'s options (Standard's). Another
/// quality asked for sets High's, or puts those back. An option the
/// running mpv had no value for is left alone: it couldn't be put back.
/// Null where mpv never scales the picture (Android, no video output).
Map<String, String> mpvOptionsFor(
  PlayRequest request, {
  bool picture = true,
  bool direct = false,
  bool lowMemory = false,
  ({PictureQuality now, Map<String, String> standard})? scaling,
}) {
  // mpv's list option parts paths at ':' (';' on Windows), so a path
  // holding one is left out.
  final subtitleFiles = request.subtitleFiles.where(
    (path) => !path.contains(_listSeparator),
  );
  return {
    ..._presetOptions[request.preset]!,
    // Read when the file's decoder starts, so a change in Settings applies
    // to the next thing played.
    // media_kit keeps the output while nothing plays (`force-window`); the
    // direct output then spun a core of a TV after every film (ADR-032).
    if (direct) 'force-window': 'no',
    if (direct)
      'hwdec': hwdecDirect
    else if (!request.hardwareDecoding)
      'hwdec': hwdecOff
    else if (picture)
      'hwdec': hwdecAutomatic,
    if (lowMemory) 'demuxer-max-bytes': _lowMemoryAheadBytes,
    'demuxer-max-back-bytes': lowMemory
        ? _lowMemoryBackBytes
        : request.live
        ? _liveBackBytes
        : _vodBackBytes,
    'user-agent': request.userAgent ?? '',
    'alang': request.audioLanguages.join(','),
    'slang': request.subtitleLanguages.join(','),
    if (request.deinterlace != null)
      'deinterlace': request.deinterlace! ? 'yes' : 'no',
    // A library file's subtitle files (docs/09), as tracks. With none the
    // option is left out and `open` clears the last file's: the libmpv
    // media_kit ships for Android and Windows reads an empty string as
    // one file named "", and every play then fails (0.34.1 cleared).
    if (subtitleFiles.isNotEmpty)
      'sub-files': subtitleFiles.join(_listSeparator),
    if (scaling != null &&
        picture &&
        !direct &&
        request.pictureQuality != scaling.now)
      for (final MapEntry(:key, :value) in scaling.standard.entries)
        key: switch (request.pictureQuality) {
          PictureQuality.high => highQualityPicture[key] ?? value,
          PictureQuality.standard => value,
        },
  };
}

final _listSeparator = Platform.isWindows ? ';' : ':';

/// [PlayerEngine] on media_kit (libmpv) with our patched media_kit_video
/// (ADR-003). One instance for the app's lifetime; every channel is an
/// `open` on it.
final class MediaKitPlayerEngine implements PlayerEngine, PlayerVersion {
  new _(
    this._player,
    this._controller,
    this._log,
    this._secrets, {
    required this._direct,
    required this._desktop,
  });

  /// [video] false runs mpv with no video output (`vo=null`): decoding,
  /// network and audio as usual, nothing drawn. For headless runs with
  /// no GPU (ADR-010, step 1).
  ///
  /// [hardwareDecoding] is the stored choice at launch: the video
  /// controller sets `hwdec` once by itself, some time after this
  /// returns, and must not undo an Off chosen before the first play.
  static Future<MediaKitPlayerEngine> create({
    required AppLog log,
    required SecretRegistry secrets,
    bool video = true,
    bool hardwareDecoding = true,
  }) async {
    MediaKit.ensureInitialized();
    final player = Player(
      configuration: PlayerConfiguration(
        title: appName,
        logLevel: _mpvLog.isEmpty ? MPVLogLevel.warn : MPVLogLevel.v,
        vo: video ? null : 'null',
      ),
    );
    // Our own property calls skip media_kit's wait for the video
    // controller: that waits for the first texture, which needs frames
    // drawn, and mpv doesn't need the controller for options.
    await (player.platform! as NativePlayer).waitForPlayerInitialization;
    final direct = video && hardwareDecoding && Platform.isAndroid;
    final controller = video
        ? VideoController(
            player,
            configuration: VideoControllerConfiguration(
              vo: direct ? _directOutput : null,
              hwdec: direct
                  ? hwdecDirect
                  : hardwareDecoding
                  ? hwdecAutomatic
                  : hwdecOff,
            ),
          )
        : null;
    final engine = MediaKitPlayerEngine._(
      player,
      controller,
      log,
      secrets,
      direct: direct,
      // media_kit's Android controller can't be sized (its setSize
      // throws), and the direct output skips mpv's scaler.
      desktop: controller == null || Platform.isAndroid
          ? null
          : DesktopPicture(
              setSize: controller.setSize,
              texture: controller.rect,
              warn: (message) => log.warning(_tag, message),
            ),
    );
    await engine._start();
    return engine;
  }

  final Player _player;
  final VideoController? _controller;
  final AppLog _log;
  final SecretRegistry _secrets;
  final bool _direct;

  /// The desktop's picture: its fit, and its size for High picture
  /// quality. Null on Android and with no video output.
  final DesktopPicture? _desktop;

  /// What the running mpv had for each of [highQualityPicture]'s options
  /// at the start (Standard's), the quality its filters are set for now,
  /// and the options it didn't take.
  final _standardPicture = <String, String>{};
  PictureQuality _pictureNow = PictureQuality.standard;
  final _refused = <String>{};
  bool _pictureChecked = false;

  final _events = StreamController<PlayerEvent>.broadcast();
  final _subscriptions = <StreamSubscription<Object?>>[];

  /// Picture size on the direct output ([directOutputFit]).
  final ValueNotifier<BoxFit> _directFit = ValueNotifier(BoxFit.contain);

  NativePlayer get _native => _player.platform! as NativePlayer;

  Future<void> _set(String name, String value) =>
      _native.setProperty(name, value, waitForInitialization: false);

  Future<String> _get(String name) =>
      _native.getProperty(name, waitForInitialization: false);

  @override
  Future<String?> playerVersion() async {
    try {
      // "mpv 0.34.1", or "mpv v0.38.0-…" from a development build.
      final version = (await _get('mpv-version')).trim();
      return version.isEmpty ? null : version;
    } on Object {
      return null;
    }
  }

  /// What mpv has for [name] now (`hwdec`, `hwdec-current`): for tests of
  /// the options this engine sets.
  @visibleForTesting
  Future<String> mpvProperty(String name) => _get(name);

  /// Counts opens; a poll or event from an older open is dropped.
  int _generation = 0;
  bool _open = false;
  bool _started = false;
  Timer? _firstFramePoll;
  final _sinceOpen = Stopwatch();
  String? _lastError;
  Duration _position = Duration.zero;
  Duration _buffered = Duration.zero;
  DateTime _lastProgress = DateTime.fromMillisecondsSinceEpoch(0);
  bool _disposed = false;

  /// Buffering, as the watchdog and the picture's spinner hear it: mpv
  /// waiting for its cache, or a seek still waiting after [_slowSeek].
  bool _cacheWait = false;
  bool _seekWait = false;
  bool _buffering = false;
  Timer? _slowSeekTimer;

  /// A seek into what is buffered lands within a few frames; one still
  /// waiting after this is waiting on the network (a panel can take
  /// seconds to answer a range, ADR-027), so it is buffering, not a stall.
  static const _slowSeek = Duration(milliseconds: 500);

  @override
  Stream<PlayerEvent> get events => _events.stream;

  Future<void> _start() async {
    for (final MapEntry(:key, :value) in _baseOptions.entries) {
      await _set(key, value);
    }
    // The running mpv's own, whatever its version: Standard's. One it
    // doesn't have reads as "" and is left alone both ways.
    if (_desktop != null) {
      for (final name in highQualityPicture.keys) {
        try {
          final value = await _get(name);
          if (value.isNotEmpty) {
            _standardPicture[name] = value;
          } else {
            _log.info(
              _tag,
              'mpv has no $name: High picture quality goes without it',
            );
          }
        } on Object catch (error) {
          _log.debug(_tag, "Couldn't read mpv's $name: $error");
        }
      }
    }
    // media_kit leaves video decoding off until a VideoController turns it
    // on; with no picture wanted, decode anyway, so the watchdog and the
    // stream info see the same stream a window would.
    if (_controller == null) await _set('vid', 'auto');
    if (_mpvLog.isNotEmpty) {
      final modules = _mpvLog.split(',');
      _subscriptions.add(
        _player.stream.log.listen((line) {
          if (modules.any(line.prefix.startsWith)) {
            _log.info('mpv', '${line.prefix}: ${_clean(line.text.trim())}');
          }
        }),
      );
    }
    _subscriptions
      ..add(_player.stream.position.listen(_onPosition))
      ..add(_player.stream.completed.listen(_onCompleted))
      ..add(_player.stream.error.listen(_onError))
      ..add(_player.stream.videoParams.listen(_onVideoParams))
      ..add(_player.stream.tracks.listen((_) => _emitTracks()))
      ..add(_player.stream.track.listen((_) => _emitTracks()))
      ..add(_player.stream.duration.listen(_onDuration));
    // Once a file plays: media_kit pauses and resumes on its own while it
    // opens one, which is nobody's pause.
    await _native.observeProperty('pause', waitForInitialization: false, (
      value,
    ) async {
      if (_open && _started) _emit(PlayerPaused(paused: value == 'yes'));
    });
    await _native.observeProperty(
      'paused-for-cache',
      waitForInitialization: false,
      (value) async {
        _cacheWait = value == 'yes';
        _updateBuffering();
      },
    );
    // mpv's `seeking` is yes until playback has restarted where a seek
    // (or a resume's start) asked; before the first frame the open's own
    // wait covers it.
    await _native.observeProperty('seeking', waitForInitialization: false, (
      value,
    ) async {
      _slowSeekTimer?.cancel();
      _slowSeekTimer = null;
      if (value != 'yes') {
        _seekWait = false;
        _updateBuffering();
        return;
      }
      if (!_open || !_started) return;
      final generation = _generation;
      _slowSeekTimer = Timer(_slowSeek, () {
        if (generation != _generation || !_open) return;
        _seekWait = true;
        _updateBuffering();
      });
    });
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

  void _updateBuffering() {
    final buffering = _cacheWait || _seekWait;
    if (buffering == _buffering) return;
    _buffering = buffering;
    if (_open) _emit(PlayerBuffering(buffering: buffering));
  }

  /// A new open, or none: nothing is waited for.
  void _resetBuffering() {
    _slowSeekTimer?.cancel();
    _slowSeekTimer = null;
    _cacheWait = false;
    _seekWait = false;
    _buffering = false;
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
    _resetBuffering();
    _sinceOpen
      ..reset()
      ..start();
    _emit(PlayerOpening(generation));
    final options = mpvOptionsFor(
      request,
      picture: _controller != null,
      direct: _direct,
      lowMemory: Platform.isAndroid,
      scaling: _desktop == null
          ? null
          : (now: _pictureNow, standard: _standardPicture),
    );
    for (final MapEntry(:key, :value) in options.entries) {
      if (highQualityPicture.containsKey(key)) {
        await _setPicture(key, value);
      } else {
        await _set(key, value);
      }
    }
    if (_desktop case final desktop?) {
      if (request.pictureQuality != _pictureNow) {
        _pictureNow = request.pictureQuality;
        if (_pictureNow == PictureQuality.high) await _checkPicture();
      }
      desktop.quality = request.pictureQuality;
    }
    if (!options.containsKey('sub-files')) {
      await _native.command([
        'change-list',
        'sub-files',
        'clr',
        '',
      ], waitForInitialization: false);
    }
    if (request.deinterlace == null) {
      await _set('deinterlace', 'no');
    }
    final start = request.start;
    final resume = start != null && start > Duration.zero;
    await _player.open(Media(request.url, start: resume ? start : null));
    if (generation != _generation) return;
    _pollFirstFrame(
      generation,
      autoDeinterlace: request.deinterlace == null,
      resume: resume,
    );
  }

  /// One of High's filters, or Standard's back: one mpv didn't take is
  /// left alone from then on, with a line in the log, and the picture
  /// plays on without it.
  Future<void> _setPicture(String name, String value) async {
    if (_refused.contains(name)) return;
    try {
      await _set(name, value);
    } on Object catch (error) {
      _refuse(name, '$error');
    }
  }

  /// media_kit drops mpv's answer to a property set: High's are read back
  /// the first time, to know which this mpv didn't take.
  Future<void> _checkPicture() async {
    if (_pictureChecked) return;
    _pictureChecked = true;
    try {
      for (final MapEntry(:key, :value) in highQualityPicture.entries) {
        if (_refused.contains(key) || !_standardPicture.containsKey(key)) {
          continue;
        }
        final now = await _get(key);
        if (now != value) _refuse(key, 'it kept "$now"');
      }
    } on Object catch (error) {
      _log.debug(_tag, "Couldn't read back the picture's filters: $error");
    }
  }

  void _refuse(String name, String why) {
    if (!_refused.add(name)) return;
    _log.warning(
      _tag,
      "mpv didn't take $name=${highQualityPicture[name]} for High picture "
      'quality ($why); playing on without it',
    );
  }

  /// The spike's proven test (ADR-003): the new file is playing and its
  /// video size is known, or it has no video at all.
  ///
  /// A [resume] also waits for mpv to have got to its place (`seeking`
  /// no): the first frame mpv decodes comes before it, and the panel may
  /// take seconds to answer the range there (ADR-027). Until then the
  /// open's own time runs, not the stall's, and nothing is shown as the
  /// picture: the surface may still hold the last stream's.
  void _pollFirstFrame(
    int generation, {
    required bool autoDeinterlace,
    required bool resume,
  }) {
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
      if (resume && (await _get('seeking')) != 'no') return;
      if (generation != _generation || timer != _firstFramePoll) return;
      timer.cancel();
      _firstFramePoll = null;
      _started = true;
      final took = _sinceOpen.elapsedMilliseconds;
      _emit(PlayerFirstFrame(generation));
      _log.info(
        _tag,
        'First frame in $took ms '
        '(${await _get('hwdec-current')}, ${await _get('current-vo')})',
      );
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

  void _onDuration(Duration duration) {
    // Zero between files, and for a live stream.
    if (_open && duration > Duration.zero) _emit(PlayerDuration(duration));
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
    // The size the picture is shown at, as media_kit's controller turns
    // it for a rotation.
    if ((params.dw, params.dh) case (final int dw, final int dh)) {
      final turned = params.rotate == 90 || params.rotate == 270;
      _desktop?.video(turned ? dh : dw, turned ? dw : dh);
    }
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
    _resetBuffering();
    await _player.stop();
    // The connection is closed once mpv is idle again.
    for (var i = 0; i < 50; i++) {
      if ((await _get('idle-active')) == 'yes') return;
      await Future<void>.delayed(const Duration(milliseconds: 20));
    }
  }

  // Straight to mpv: media_kit's own play() and pause() wait for the
  // video controller's first texture.
  @override
  Future<void> setPaused({required bool paused}) =>
      _set('pause', paused ? 'yes' : 'no');

  @override
  Future<void> seek(Duration position) async {
    if (!_open) return;
    final seconds = (position.inMilliseconds / 1000).toStringAsFixed(3);
    await _native.command([
      'seek',
      seconds,
      'absolute',
    ], waitForInitialization: false);
  }

  @override
  Future<void> setVolume(double volume) =>
      _player.setVolume(volume.clamp(0, 100).toDouble());

  @override
  Future<void> setMuted({required bool muted}) =>
      _set('mute', muted ? 'yes' : 'no');

  // mpv keeps the pitch by itself (`audio-pitch-correction` is on).
  @override
  Future<void> setSpeed(double speed) =>
      _set('speed', speed.clamp(0.25, 4).toStringAsFixed(2));

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
    if (_direct) _directFit.value = directOutputFit(mode);
    // The desktop's texture has the video's own shape (Standard), so Fill
    // and Stretch are the widget's there too; for High it has the shape
    // of where it goes, mpv crops or stretches into it, and the widget's
    // fit keeps the picture right while a new size is on its way.
    _desktop?.pictureFit = directOutputFit(mode);
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
    final estimated = decimal(await read('estimated-vf-fps'));
    final container = decimal(await read('container-fps'));
    // The direct output's estimate follows the display (60 for a 50 fps
    // channel on a Chromecast); the stream's own rate is the truth there.
    final fps = _direct ? container ?? estimated : estimated ?? container;
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
    if (_direct) {
      return ValueListenableBuilder(
        key: key,
        valueListenable: _directFit,
        builder: (context, directFit, _) => Video(
          controller: controller,
          fit: directFit == BoxFit.contain ? fit : directFit,
          controls: null,
          fill: background,
        ),
      );
    }
    if (_desktop case final desktop?) {
      return desktop.view(
        key: key,
        fit: fit,
        picture: (pictureFit) => Video(
          controller: controller,
          fit: pictureFit,
          controls: null,
          fill: background,
        ),
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
    _slowSeekTimer?.cancel();
    for (final subscription in _subscriptions) {
      await subscription.cancel();
    }
    await _events.close();
    _directFit.dispose();
    _desktop?.dispose();
    await _player.dispose();
  }
}
