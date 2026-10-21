import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:iptv_player/core/app_identity.dart';
import 'package:iptv_player/core/cast/cast_planner.dart' show sameLanguage;
import 'package:iptv_player/core/logging/app_log.dart';
import 'package:iptv_player/core/logging/redact.dart';
import 'package:iptv_player/core/logging/secret_registry.dart';
import 'package:iptv_player/core/player/player_engine.dart';
import 'package:iptv_player/core/player/player_version.dart';
import 'package:iptv_player/data/library/library_scan.dart' show subtitleBeside;
import 'package:iptv_player/data/player_mediakit/desktop_picture.dart';
import 'package:iptv_player/data/player_mediakit/layer_picture.dart';
import 'package:iptv_player/data/player_mediakit/subtitle_style.dart';
import 'package:iptv_player/data/player_mediakit/video_layer.dart';
import 'package:iptv_player/data/player_mediakit/video_layer_geometry.dart';
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

/// A file reads ahead as far as its bytes allow, whatever the preset: an
/// hour of seconds, so the bytes are what stop it (ADR-046, ADR-048).
/// Balanced's 8 s put every 10 s jump outside what was buffered, and each
/// went back to the provider (0.6 to 0.9 s, its answer and the first
/// data); on a TV's 32 MiB a 1.3 Mb/s film holds about 150 s ahead, and a
/// held key's jump of a minute or two plays again in 0.1 s. A channel
/// keeps the preset's: there, reading ahead only waits behind the live
/// edge.
const _fileAheadSeconds = '3600';

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

/// mpv's audio on Android: AudioTrack, then media_kit's OpenSL ES.
const _androidAudio = 'audiotrack,opensles';

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

/// Whether a seek to [to] has played again at [position] (ADR-048): mpv
/// says the target itself from the moment a seek starts, before it is
/// even seeking, so the clock at the target proves nothing yet. It has to
/// have moved on past it, with mpv done seeking and not waiting for its
/// cache. Exposed for tests.
bool seekPlaysAgain({
  required Duration to,
  required Duration position,
  required bool seeking,
  required bool cacheWait,
}) {
  if (seeking || cacheWait) return false;
  final past = position - to;
  return past >= const Duration(milliseconds: 10) &&
      past <= const Duration(seconds: 2);
}

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
    if (!request.live) ...{
      'cache-secs': _fileAheadSeconds,
      'demuxer-readahead-secs': _fileAheadSeconds,
    },
    // Read when the file's decoder starts, so a change in Settings applies
    // to the next thing played.
    // media_kit keeps the output while nothing plays (`force-window`); the
    // direct output then spun a core of a TV after every film (ADR-032).
    if (direct) 'force-window': 'no',
    // media_kit's OpenSL ES moves mpv's clock in coarse steps, and the
    // frames timed by it came a refresh early or late (a channel's ticker
    // stuttered at 50 Hz); AudioTrack's clock is exact: every frame of a
    // 25 fps channel held two refreshes (ADR-046). OpenSL ES if it fails.
    if (direct) 'ao': _androidAudio,
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
    // Each file starts from Settings: mpv keeps a track picked in the last
    // one (a number this one may not have, or Off) for the next.
    'aid': 'auto',
    // Subtitles start only in a language asked for, none by default
    // (ADR-041): mpv showed a file's default track, or one beside it,
    // with none asked for. media_kit turns on a newer mpv's fallbacks to
    // any track and to the system's language; 0.34 has neither option.
    'sid': request.subtitleLanguages.isEmpty ? 'no' : 'auto',
    'subs-fallback': 'no',
    'subs-match-os-language': 'no',
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

/// The subtitle track a file plays with once it has started, as mpv's
/// `sid`: a track in the first of [languages] that one of [tracks] has;
/// `no` when none is asked for or none has one (ADR-041). mpv's own pick
/// ([current]) stays when it is in that language: its default and forced
/// flags chose among that language's tracks. In its place, a whole track
/// before a forced one (only the lines in another language).
String subtitleChoice(
  List<String> languages,
  List<({String id, String? language, bool forced})> tracks, {
  required String current,
}) {
  for (final wanted in languages) {
    final those = tracks.where((t) => sameLanguage(t.language, wanted));
    if (those.isEmpty) continue;
    if (those.any((t) => t.id == current)) return current;
    return (those.where((t) => !t.forced).firstOrNull ?? those.first).id;
  }
  return 'no';
}

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
    this._layer,
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
      layer: direct && videoLayerBuilt ? VideoLayer() : null,
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

  /// The picture's own layer (T1), in a TV build that has it.
  final VideoLayer? _layer;

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

  /// On the layer: mpv draws into [_layerWid]; the picture widget reports
  /// its place ([_layerBox], physical pixels), and the picture goes in it
  /// as Picture size says ([videoLayerRect]).
  final ValueNotifier<bool> _behind = ValueNotifier(false);
  int? _layerWid;
  bool _layerShown = false;
  Rect? _layerBox;
  Rect? _layerRect;

  /// The picture's display size (its shape, any ratio override applied).
  Size? _displaySize;

  /// The subtitles' configuration for each size asked for (ADR-038).
  final _subtitles = SubtitleStyles();

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

  /// The audio and subtitle tracks mpv plays, as it says (`aid`, `sid`;
  /// null until it has): media_kit's `track` stays "auto" when mpv picks
  /// one itself (a file's default, `alang`/`slang`), and the menus then
  /// ticked Off.
  String? _aid;
  String? _sid;

  /// What the file opened last asked for its subtitles: Settings'
  /// languages, and the video a subtitle file beside it is named after.
  List<String> _subtitleLanguages = const [];
  String _video = '';

  /// Buffering, as the watchdog and the picture's spinner hear it: mpv
  /// waiting for its cache, or a seek still waiting after [_slowSeek].
  bool _cacheWait = false;
  bool _seekWait = false;
  bool _buffering = false;
  Timer? _slowSeekTimer;

  /// mpv's `seeking` and `pause`, as each last said.
  bool _seeking = false;
  bool _paused = false;

  /// The seek asked for last, until it plays again: logged with how long
  /// that took, and how far ahead was buffered when it was asked.
  ({Stopwatch took, Duration from, Duration to, Duration ahead})? _seekAsked;

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
    _layer?.onDestroyed = (wid) {
      if (wid != _layerWid) return;
      _log.info(_tag, 'The video layer went: the picture leaves it');
      unawaited(_leaveLayer());
    };
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
      _paused = value == 'yes';
      // A paused file's clock stands still: a seek's time to play again
      // would be the pause's.
      if (_paused) _seekAsked = null;
      if (_open && _started) _emit(PlayerPaused(paused: value == 'yes'));
      if (_layerShown) unawaited(_layer?.keepAwake(awake: value != 'yes'));
    });
    await _native.observeProperty('aid', waitForInitialization: false, (
      value,
    ) async {
      _aid = value;
      _emitTracks();
    });
    await _native.observeProperty('sid', waitForInitialization: false, (
      value,
    ) async {
      _sid = value;
      _emitTracks();
    });
    await _native.observeProperty(
      'paused-for-cache',
      waitForInitialization: false,
      (value) async {
        _cacheWait = value == 'yes';
        _updateBuffering();
        _seekSettled();
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
      _seeking = value == 'yes';
      if (value != 'yes') {
        _seekWait = false;
        _updateBuffering();
        _seekSettled();
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

  /// A seek playing again ([seekPlaysAgain]): one line, so a slow one
  /// shows in the log of a TV.
  void _seekSettled() {
    final asked = _seekAsked;
    if (asked == null ||
        !seekPlaysAgain(
          to: asked.to,
          position: _position,
          seeking: _seeking,
          cacheWait: _cacheWait,
        )) {
      return;
    }
    _seekAsked = null;
    final jump = asked.to - asked.from;
    final seconds = (jump.inMilliseconds / 1000).round();
    _log.info(
      _tag,
      'Seek ${seconds < 0 ? '−' : '+'}${seconds.abs()} s: playing again '
      'in ${asked.took.elapsedMilliseconds} ms '
      '(${(asked.ahead.inMilliseconds / 1000).toStringAsFixed(1)} s was '
      'buffered ahead)',
    );
  }

  /// A new open, or none: nothing is waited for.
  void _resetBuffering() {
    _slowSeekTimer?.cancel();
    _slowSeekTimer = null;
    _cacheWait = false;
    _seekWait = false;
    _buffering = false;
    _seeking = false;
    _seekAsked = null;
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
    _subtitleLanguages = request.subtitleLanguages;
    _video = request.url;
    _resetBuffering();
    _sinceOpen
      ..reset()
      ..start();
    _emit(PlayerOpening(generation));
    await _chooseOutput(request);
    if (generation != _generation) return;
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

  /// The first frame's line, with what decodes and draws it. A TV's
  /// channel (the texture) has its output, and so its decoder, a moment
  /// after its first frame: the line said "(no, null)" (the Bedroom TV).
  Future<void> _logFirstFrame(int took, int generation) async {
    try {
      for (var i = 0; i < 15 && (await _get('current-vo')).isEmpty; i++) {
        await Future<void>.delayed(const Duration(milliseconds: 100));
        if (generation != _generation) return;
      }
      _log.info(
        _tag,
        'First frame in $took ms '
        '(${await _get('hwdec-current')}, ${await _get('current-vo')}'
        '${_layerWid != null ? ', on its own layer' : ''})',
      );
    } on Object catch (error) {
      _log.debug(_tag, "Couldn't read what decodes the picture: $error");
    }
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
      unawaited(_logFirstFrame(took, generation));
      unawaited(_settleSubtitles(generation));
      if (autoDeinterlace) await _autoDeinterlace(generation);
    });
  }

  /// Settings' subtitles, made sure of once the file plays (ADR-041): a
  /// Linux desktop's mpv (0.34) shows a subtitle file beside the video
  /// whatever its language, knows no language for one, and matches
  /// `slang` by a code's exact spelling ("en" never picked "eng").
  Future<void> _settleSubtitles(int generation) async {
    try {
      final list = jsonDecode(await _get('track-list'));
      final current = await _get('sid');
      if (generation != _generation || list is! List) return;
      final tracks = [
        for (final track in list)
          if (track is Map && track['type'] == 'sub' && track['id'] is int)
            (
              id: '${track['id']}',
              language: switch (track) {
                {'lang': final String lang} => lang,
                {'external-filename': final String file} => subtitleBeside(
                  _video,
                  file,
                )?.language,
                _ => null,
              },
              forced: track['forced'] == true,
            ),
      ];
      final wanted = subtitleChoice(
        _subtitleLanguages,
        tracks,
        current: current,
      );
      if (wanted == current) return;
      _log.info(_tag, 'Subtitles: $wanted, not $current as mpv picked');
      await selectSubtitle(wanted == 'no' ? null : wanted);
    } on Object catch (error) {
      _log.debug(_tag, "Couldn't settle the subtitles: $error");
    }
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
    if (_seekAsked != null) _seekSettled();
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
    final (dw, dh) = switch (params.rotate) {
      90 || 270 => (params.dh, params.dw),
      _ => (params.dw, params.dh),
    };
    if (dw != null && dh != null && dw > 0 && dh > 0) {
      _displaySize = Size(dw.toDouble(), dh.toDouble());
      unawaited(_placeLayer());
      _desktop?.video(dw, dh);
    }
    final width = params.w;
    final height = params.h;
    if (width == null || height == null || width == 0) return;
    _emit(PlayerVideoChanged(width: width, height: height));
  }

  /// On a TV everything goes on the picture's own layer (T1 films, T2
  /// channels); with no surface from the layer within a second, the
  /// texture. Before the stream opens, with nothing playing.
  Future<void> _chooseOutput(PlayRequest request) async {
    final layer = _layer;
    if (layer == null) return;
    _leaveTimer?.cancel();
    _leaveTimer = null;
    if (!playsOnLayer(built: true, direct: _direct)) {
      await _leaveLayer();
      return;
    }
    _layerShown = true;
    final surface = await layer.show();
    final android = await _androidController();
    if (surface == null || android == null) {
      _log.warning(_tag, 'No surface from the video layer: the texture');
      await _leaveLayer();
      return;
    }
    if (surface.wid != _layerWid) {
      await android.setLayer(
        surface.wid,
        width: surface.width,
        height: surface.height,
      );
      _layerWid = surface.wid;
      _log.info(
        _tag,
        'On the video layer (${surface.width}x${surface.height})',
      );
    }
    // The first film after launch: the widget reports its place only once
    // the film plays, and until then the whole window (the surface's size
    // at its first show) places the picture, not stretched to it.
    _layerBox ??= Rect.fromLTWH(
      0,
      0,
      surface.width.toDouble(),
      surface.height.toDouble(),
    );
    _behind.value = true;
    await _placeLayer();
  }

  /// Back to the texture, and the layer hidden.
  Future<void> _leaveLayer() async {
    final layer = _layer;
    if (layer == null) return;
    if (_layerWid != null) {
      _layerWid = null;
      _behind.value = false;
      await (await _androidController())?.setLayer(null);
    }
    if (_layerShown) {
      _layerShown = false;
      _layerRect = null;
      await layer.hide();
    }
  }

  /// Puts the picture where the widget is, as Picture size says.
  Future<void> _placeLayer() async {
    final layer = _layer;
    final box = _layerBox;
    final video = _displaySize;
    if (layer == null || _layerWid == null || box == null || video == null) {
      return;
    }
    final rect = videoLayerRect(box: box, video: video, fit: _directFit.value);
    if (rect == null || rect == _layerRect) return;
    _layerRect = rect;
    await layer.setRect(rect);
  }

  Future<AndroidVideoController?> _androidController() async {
    final controller = _controller;
    if (controller == null) return null;
    final platform = await controller.platform.future;
    return platform is AndroidVideoController ? platform : null;
  }

  void _emitTracks() {
    final tracks = _player.state.tracks;
    final current = _player.state.track;
    bool real(String id) => id != 'auto' && id != 'no';
    final aid = _aid ?? current.audio.id;
    final sid = _sid ?? current.subtitle.id;
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
        audioId: real(aid) ? aid : null,
        subtitleId: real(sid) ? sid : null,
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
      if ((await _get('idle-active')) == 'yes') break;
      await Future<void>.delayed(const Duration(milliseconds: 20));
    }
    _leaveSoon();
  }

  /// A stop leaves the layer only if nothing opens on it soon: a zap on
  /// a one-connection source stops the last channel first, and mpv taken
  /// off the layer and put back on it would remake its output twice
  /// between two channels (T2, ADR-045). The app paints over a stopped
  /// picture meanwhile.
  void _leaveSoon() {
    if (_layer == null) return;
    _leaveTimer?.cancel();
    _leaveTimer = Timer(_leaveAfter, () {
      _leaveTimer = null;
      if (!_open) unawaited(_leaveLayer());
    });
  }

  Timer? _leaveTimer;
  static const _leaveAfter = Duration(milliseconds: 1500);

  // Straight to mpv: media_kit's own play() and pause() wait for the
  // video controller's first texture.
  @override
  Future<void> setPaused({required bool paused}) =>
      _set('pause', paused ? 'yes' : 'no');

  @override
  Future<void> seek(Duration position) async {
    if (!_open) return;
    if (_started && !_paused) {
      _seekAsked = (
        took: Stopwatch()..start(),
        from: _position,
        to: position,
        ahead: _buffered,
      );
    }
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

  // Through media_kit, which clears the line on screen: mpv says nothing
  // more once its subtitles are off, so the last line stayed for good.
  @override
  Future<void> selectSubtitle(String? id) => _player.setSubtitleTrack(
    id == null ? SubtitleTrack.no() : SubtitleTrack(id, null, null),
  );

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
    unawaited(_placeLayer());
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
    final avSync = decimal(await read('avsync'));
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
      transfer: _nonEmpty(await read('video-params/gamma')),
      primaries: _nonEmpty(await read('video-params/primaries')),
      avSync: avSync == null
          ? null
          : Duration(microseconds: (avSync * 1e6).round()),
    );
  }

  static String? _nonEmpty(String text) => text.isEmpty ? null : text;

  @override
  Widget videoView({
    required Color background,
    Key? key,
    BoxFit fit = BoxFit.contain,
    double subtitleScale = 1,
  }) {
    final controller = _controller;
    if (controller == null) {
      return ColoredBox(
        key: key,
        color: background,
        child: const SizedBox.expand(),
      );
    }
    final subtitles = _subtitles.at(subtitleScale);
    if (_direct && _layer != null) {
      return ValueListenableBuilder(
        key: key,
        valueListenable: _behind,
        builder: (context, behind, _) => behind
            ? LayerPicture(
                onPlaced: (box) {
                  _layerBox = box;
                  unawaited(_placeLayer());
                },
                // As the texture's `Video` draws them (ADR-038).
                child: SubtitleView(
                  controller: controller,
                  configuration: subtitles,
                ),
              )
            : _directVideo(
                controller,
                background: background,
                fit: fit,
                subtitles: subtitles,
              ),
      );
    }
    if (_direct) {
      return KeyedSubtree(
        key: key,
        child: _directVideo(
          controller,
          background: background,
          fit: fit,
          subtitles: subtitles,
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
          subtitleViewConfiguration: subtitles,
        ),
      );
    }
    return Video(
      key: key,
      controller: controller,
      fit: fit,
      controls: null,
      fill: background,
      subtitleViewConfiguration: subtitles,
    );
  }

  Widget _directVideo(
    VideoController controller, {
    required Color background,
    required BoxFit fit,
    required SubtitleViewConfiguration subtitles,
  }) => ValueListenableBuilder(
    valueListenable: _directFit,
    builder: (context, directFit, _) => Video(
      controller: controller,
      fit: directFit == BoxFit.contain ? fit : directFit,
      controls: null,
      fill: background,
      subtitleViewConfiguration: subtitles,
    ),
  );

  @override
  ValueListenable<bool> get pictureBehindApp => _behind;

  @override
  Future<void> dispose() async {
    _disposed = true;
    _firstFramePoll?.cancel();
    _slowSeekTimer?.cancel();
    _leaveTimer?.cancel();
    for (final subscription in _subscriptions) {
      await subscription.cancel();
    }
    await _events.close();
    _directFit.dispose();
    await _layer?.hide();
    _behind.dispose();
    _desktop?.dispose();
    await _player.dispose();
  }
}
