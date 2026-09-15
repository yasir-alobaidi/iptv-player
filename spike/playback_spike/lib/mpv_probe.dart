import 'dart:async';
import 'dart:io';

import 'package:media_kit/media_kit.dart';

/// Reads and writes libmpv properties through media_kit's NativePlayer.
class MpvProbe {
  MpvProbe(this.native);

  final NativePlayer native;

  /// docs/03 base options + Balanced preset. `hwdec` is set by
  /// VideoControllerConfiguration, so it is only read back.
  static const balancedPreset = <String, String>{
    'cache': 'yes',
    'cache-secs': '8',
    'demuxer-max-bytes': '64MiB',
    'demuxer-readahead-secs': '8',
    'demuxer-max-back-bytes': '16MiB',
    'demuxer-lavf-probesize': '1000000',
    'demuxer-lavf-analyzeduration': '1',
    'network-timeout': '10',
    'user-agent': 'playback_spike/0.1',
    'stream-lavf-o': 'reconnect=1,reconnect_streamed=1,reconnect_delay_max=5',
    'alang': 'en',
    'slang': 'en',
  };

  /// Everything docs/03 names as an option.
  static const docOptions = [
    'hwdec',
    'cache',
    'network-timeout',
    'user-agent',
    'stream-lavf-o',
    'demuxer-max-back-bytes',
    'alang',
    'slang',
    'cache-secs',
    'demuxer-max-bytes',
    'demuxer-readahead-secs',
    'demuxer-lavf-probesize',
    'demuxer-lavf-analyzeduration',
    'deinterlace',
  ];

  /// Properties the watchdog, zapping, and stream info overlay will read.
  static const docProperties = [
    'hwdec-current',
    'hwdec-interop',
    'video-codec',
    'video-format',
    'video-params',
    'estimated-vf-fps',
    'container-fps',
    'frame-drop-count',
    'decoder-frame-drop-count',
    'video-frame-info',
    'audio-codec-name',
    'audio-params',
    'video-bitrate',
    'audio-bitrate',
    'demuxer-cache-duration',
    'cache-buffering-state',
    'paused-for-cache',
    'track-list',
    'current-tracks',
    'path',
    'playback-time',
    'time-pos',
    'core-idle',
    'eof-reached',
    'mpv-version',
    'ffmpeg-version',
    'current-vo',
  ];

  static const statProps = [
    'hwdec-current',
    'hwdec-interop',
    'current-vo',
    'video-codec',
    'video-format',
    'video-params/w',
    'video-params/h',
    'video-params/pixelformat',
    'video-params/hw-pixelformat',
    'container-fps',
    'estimated-vf-fps',
    'frame-drop-count',
    'decoder-frame-drop-count',
    'video-frame-info/interlaced',
    'audio-codec-name',
    'audio-params/channel-count',
    'audio-params/samplerate',
    'demuxer-cache-duration',
    'cache-buffering-state',
    'paused-for-cache',
    'video-bitrate',
    'deinterlace',
  ];

  Future<Map<String, String>> read(List<String> names) async => {
    for (final n in names) n: await native.getProperty(n),
  };

  /// Sets each option, then reads it back (empty read-back = rejected).
  Future<Map<String, String>> applyOptions(Map<String, String> options) async {
    for (final e in options.entries) {
      await native.setProperty(e.key, e.value);
    }
    return read([...options.keys, 'hwdec']);
  }

  /// Checks names against libmpv's own `options` and `property-list`.
  Future<Map<String, Object>> verifyNames() async {
    final props = (await native.getProperty('property-list'))
        .split(',')
        .toSet();
    final opts = (await native.getProperty('options')).split(',').toSet();
    return {
      'property_list_size': props.length,
      'options_size': opts.length,
      'options': {for (final o in docOptions) o: opts.contains(o)},
      'properties': {for (final p in docProperties) p: props.contains(p)},
    };
  }

  /// Milliseconds on [sw] until the file whose path contains [token] shows its
  /// first frame (`playback-time` available and video params known).
  Future<int?> waitForFirstFrame(
    String token,
    Stopwatch sw, {
    Duration timeout = const Duration(seconds: 20),
  }) async {
    while (sw.elapsed < timeout) {
      if ((await native.getProperty('path')).contains(token) &&
          (await native.getProperty('playback-time')).isNotEmpty &&
          (await native.getProperty('video-params/w')).isNotEmpty) {
        return sw.elapsedMilliseconds;
      }
      await Future<void>.delayed(const Duration(milliseconds: 5));
    }
    return null;
  }
}

/// Process CPU time from /proc/self/stat (includes Flutter's raster thread,
/// excludes the ffmpeg stream processes).
class CpuSample {
  CpuSample._(this.ticks, this.at);

  factory CpuSample.now() {
    final s = File('/proc/self/stat').readAsStringSync();
    final f = s.substring(s.lastIndexOf(')') + 2).split(' ');
    return CpuSample._(int.parse(f[11]) + int.parse(f[12]), DateTime.now());
  }

  static const _clkTck = 100;

  final int ticks;
  final DateTime at;

  /// `total` is % of all cores (the docs/06 budget); `oneCore` is % of one.
  ({double total, double oneCore}) since(CpuSample earlier) {
    final wall = at.difference(earlier.at).inMicroseconds / 1e6;
    final oneCore = wall > 0
        ? (ticks - earlier.ticks) / _clkTck / wall * 100
        : 0.0;
    return (total: oneCore / Platform.numberOfProcessors, oneCore: oneCore);
  }
}
