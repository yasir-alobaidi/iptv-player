// Phase 7 step 8 on a real Cast device: docs/04's casting matrix through
// the app — the fake panel's channels and movies on one connection, the
// relay with FFmpeg, ffprobe, the encoders this laptop has, our Cast
// client, the coordinators — on the user's Living Room TV. Only with the
// user's go-ahead, and with them watching: each row plays on the TV for
// CAST_HOLD seconds (30), about 20 minutes in all.
//
//     CAST_HOST=192.168.1.155 flutter test --tags real_cast --run-skipped \
//       test/tools/cast_matrix_tv_test.dart
//
// CAST_ROWS=1,4,9 runs those rows only. Two rows ask something of the
// user first and run only when named: 6 (Input Signal Plus off, so the
// TV's HDMI link is 1080p) and 16 (the TV's remote, in hand).
//
// CAST_HOST=fake runs every row against the fake receiver in-process
// (rows 6 and 16 included, with shorter holds): the runner's own check,
// nothing on any screen.
//
// Each row says what to watch for. The summary — how long each cast took
// to play, its plans, what the cast did — goes to the console and to
// build/real_cast_run/matrix.md, the whole log to matrix.log.
@Tags(['real_cast'])
library;

import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:fake_provider/profile.dart';
import 'package:fake_provider/server.dart';
import 'package:fake_provider/server_state.dart';
import 'package:fake_receiver/fake_receiver.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:iptv_player/core/cast/cast_device.dart';
import 'package:iptv_player/core/cast/cast_discovery.dart';
import 'package:iptv_player/core/cast/cast_plan.dart';
import 'package:iptv_player/core/logging/app_log.dart';
import 'package:iptv_player/core/logging/secret_registry.dart';
import 'package:iptv_player/core/player/fake_player_engine.dart';
import 'package:iptv_player/core/player/player_engine.dart';
import 'package:iptv_player/data/cast/cast_connection_check.dart';
import 'package:iptv_player/data/cast/cast_v2_receivers.dart';
import 'package:iptv_player/data/cast/ffmpeg_encoder_detector.dart';
import 'package:iptv_player/data/cast/ffprobe_stream_probe.dart';
import 'package:iptv_player/data/cast/relay/isolate_cast_relay.dart';
import 'package:iptv_player/data/images/artwork_cache.dart';
import 'package:iptv_player/data/process/process_supervisor.dart';
import 'package:iptv_player/features/casting/data/artwork_cast_pictures.dart';
import 'package:iptv_player/features/casting/domain/cast_coordinator.dart';
import 'package:iptv_player/features/casting/domain/cast_items.dart';
import 'package:iptv_player/features/casting/domain/casting_state.dart';
import 'package:iptv_player/features/casting/domain/stream_facts_lookup.dart';
import 'package:iptv_player/features/casting/presentation/cast_shell_slots.dart';
import 'package:iptv_player/features/live_tv/domain/channels.dart';
import 'package:iptv_player/features/playback/data/http_stream_prober.dart';
import 'package:iptv_player/features/playback/domain/playable.dart';
import 'package:iptv_player/features/playback/domain/playback_coordinator.dart';
import 'package:iptv_player/features/vod/domain/titles.dart';
import 'package:logger/logger.dart';
import 'package:path/path.dart' as p;

import '../data/cast/relay/relay_rig.dart';
import '../features/casting/support/cast_e2e_rig.dart';
import '../features/casting/support/cast_fakes.dart';
import '../features/playback/support/playback_fakes.dart';

void main() {
  // flutter_test answers every HTTP request with 400 unless told not to.
  setUpAll(() => HttpOverrides.global = null);

  final host = Platform.environment['CAST_HOST'] ?? '192.168.1.155';
  final fake = host == 'fake';
  final named = {
    for (final row in (Platform.environment['CAST_ROWS'] ?? '').split(','))
      ?int.tryParse(row.trim()),
  };
  final hold = Duration(
    seconds:
        int.tryParse(Platform.environment['CAST_HOLD'] ?? '') ??
        (fake ? 4 : 30),
  );

  test(
    "docs/04's casting matrix on ${fake ? 'the fake TV' : host}",
    () async {
      final matrix = await _Matrix.open(host: host, fake: fake, hold: hold);
      addTearDown(matrix.close);
      final rows = _rows(fake: fake);
      final chosen = [
        for (final row in rows)
          if (named.isEmpty
              ? (fake || row.asks == null)
              : named.contains(row.number))
            row,
      ];
      for (final row in chosen) {
        await matrix.run(row, of: rows.length);
      }
      await matrix.summarize();
      expect(
        [
          for (final result in matrix.results)
            if (result.failure != null) '${result.row.number}',
        ],
        isEmpty,
        reason: 'rows that failed (see the summary)',
      );
    },
    skip: relaySkip([
      'h264_1080p50_aac',
      'h264_1080p25_ac3',
      'hevc_1080p50_aac',
      'h264_1080i50_mp2',
      'mpeg2_576i25_mp2',
      'hevc_2160p25_eac3',
      'h264_2160p25_aac',
    ]),
    timeout: Timeout.none,
  );
}

/// The fake panel's movies: 100000 the MP4 sample, 100001 the H.264 +
/// AC-3 Matroska one.
MovieItem _movie(int id, String ext) => MovieItem(
  id: id,
  sourceId: 'panel',
  remoteKey: '$id',
  name: 'Movie $id',
  ext: ext,
  runtime: const Duration(minutes: 10),
);

ChannelItem _channel(String sample, _Matrix m) => panelChannel(
  channelOf[sample]!,
  logoUrl: '${m.panel.url}/art/live/${channelOf[sample]}.png',
);

/// The matrix: docs/04's rows, then the plan's movies and the remote.
List<_Row> _rows({required bool fake}) {
  // Shorter on the fake TV, which nobody watches.
  final dropEvery = fake ? 10 : 60;
  final switchAfter = fake ? 5 : 20;
  final killAfter = Duration(seconds: fake ? 5 : 20);
  return [
    _Row(
      1,
      'H.264 1080p50 + AAC, and a zap there and back',
      'a smooth picture with sound; the two zaps',
      (m, r) async {
        final first = _channel('h264_1080p50_aac', m);
        await m.castChannel(r, first);
        await m.hold(r);
        final second = _channel('h264_1080p25_ac3', m);
        r.note('zap ${await m.zap(r, second)}');
        r.note('zap back ${await m.zap(r, first)}');
        await m.hold(r, m.holdFor ~/ 2);
      },
    ),
    _Row(
      2,
      'H.264 1080p25 + AC-3 (the sound converted to AAC)',
      'sound, in step with the picture',
      (m, r) async {
        await m.castChannel(r, _channel('h264_1080p25_ac3', m));
        await m.hold(r);
      },
    ),
    _Row(
      3,
      'H.264 1080i50 + MP2 (interlaced, copied; MP2 to AAC)',
      'the picture: combing on motion is the TV deinterlacing, or not',
      (m, r) async {
        await m.castChannel(r, _channel('h264_1080i50_mp2', m));
        await m.hold(r);
      },
    ),
    _Row(
      4,
      'HEVC 2160p25 + E-AC-3 (one continuous fMP4)',
      'a smooth 4K picture with sound, no stutter',
      (m, r) async {
        await m.castChannel(r, _channel('hevc_2160p25_eac3', m));
        await m.hold(r);
      },
    ),
    _Row(
      5,
      'HEVC 1080p50 with the TV set to "HEVC: No" (re-encoded to H.264)',
      'a smooth picture: the laptop re-encodes it',
      (m, r) async {
        m.devices.devices[m.device.id] = m.known(hevc: HevcSupport.no);
        await m.castChannel(r, _channel('hevc_1080p50_aac', m));
        await m.hold(r);
      },
    ),
    _Row(
      6,
      'H.264 2160p25 on a 1080p HDMI link (learned, then re-encoded to '
          '1080p)',
      'a picture within seconds after the refusal; the toast in the log',
      asks:
          "Turn Input Signal Plus off for the TV's HDMI port (Samsung: "
          'Settings → General → External Device Manager), and back on '
          'after this row.',
      fakeDevice: FakeDevice.tvOnHdLink,
      (m, r) async {
        await m.castChannel(r, _channel('h264_2160p25_aac', m));
        await m.hold(r);
      },
    ),
    _Row(
      7,
      'MPEG-2 576i25 + MP2 (re-encoded and deinterlaced)',
      'a smooth picture with sound',
      (m, r) async {
        await m.castChannel(r, _channel('mpeg2_576i25_mp2', m));
        await m.hold(r);
      },
    ),
    _Row(
      8,
      'A codec change mid-stream (planned again, loaded again)',
      'the picture coming back after the change',
      (m, r) async {
        m.resolver.query = 'codec_switch_after_s=$switchAfter';
        await m.castChannel(r, _channel('h264_1080p50_aac', m));
        await m.hold(r, Duration(seconds: switchAfter * 2 + 10));
      },
    ),
    _Row(
      9,
      'A provider drop every ${dropEvery}s, through HLS',
      'the picture through each drop: a short stall at most',
      (m, r) async {
        m.resolver.query = 'drop_after_s=$dropEvery';
        await m.castChannel(r, _channel('h264_1080p50_aac', m));
        await m.hold(r, Duration(seconds: dropEvery * 2 + 15));
      },
    ),
    _Row(
      10,
      'A provider drop every ${dropEvery}s, through one continuous fMP4',
      'the picture through each drop: a short stall at most',
      (m, r) async {
        m.resolver.query = 'drop_after_s=$dropEvery';
        await m.castChannel(r, _channel('hevc_1080p50_aac', m));
        await m.hold(r, Duration(seconds: dropEvery * 2 + 15));
      },
    ),
    _Row(
      11,
      "The relay's FFmpeg killed during a continuous fMP4 (a new LOAD)",
      'the picture coming back within seconds',
      (m, r) async {
        await m.castChannel(r, _channel('hevc_1080p50_aac', m));
        await m.hold(r, killAfter);
        final pid = m.relayPid();
        r.note('killed FFmpeg $pid');
        Process.killPid(pid, ProcessSignal.sigkill);
        final back = Stopwatch()..start();
        await m.playingAgain(r);
        r.note('back in ${_seconds(back.elapsed)}');
        await m.hold(r);
      },
    ),
    _Row(
      12,
      'An 8 s slow start from the provider',
      'a picture about 8 s later than usual',
      (m, r) async {
        m.resolver.query = 'slow_start_ms=8000';
        await m.castChannel(r, _channel('h264_1080p50_aac', m));
        await m.hold(r);
      },
    ),
    _Row(
      13,
      'Cast while the laptop plays it, on a one-connection source',
      'the channel moving to the TV',
      (m, r) async {
        final channel = _channel('h264_1080p50_aac', m);
        unawaited(m.playback.playLive(channel));
        await m.until(
          () => m.engine.reading,
          'the laptop reading the stream',
          within: const Duration(seconds: 20),
        );
        r.note('the laptop played it');
        await m.castChannel(r, channel, moving: true);
        await m.hold(r);
      },
    ),
    _Row(
      14,
      'A movie (MP4), straight to the TV if it can, with seeks',
      'the movie at 0:00, then at 1:00, then at 5:00',
      (m, r) async {
        await m.castFile(r, PlayableMovie(_movie(100000, 'mp4')));
        await m.hold(r, m.holdFor ~/ 3);
        r.note('seek to 1:00 ${await m.seekTo(r, const Duration(minutes: 1))}');
        await m.hold(r, m.holdFor ~/ 3);
        r.note('seek to 5:00 ${await m.seekTo(r, const Duration(minutes: 5))}');
        await m.hold(r, m.holdFor ~/ 3);
      },
    ),
    _Row(
      15,
      'A movie (MKV, AC-3) through the relay from 1:00, a seek, and resume',
      'the movie from 1:00, then 5:00; after the stop, from where it was',
      (m, r) async {
        final movie = PlayableMovie(_movie(100001, 'mkv'));
        await m.castFile(r, movie, from: const Duration(minutes: 1));
        await m.hold(r, m.holdFor ~/ 3);
        r.note('seek to 5:00 ${await m.seekTo(r, const Duration(minutes: 5))}');
        await m.hold(r, m.holdFor ~/ 3);
        await m.coordinator.disconnect();
        final kept = m.progress.lastPosition;
        r.note('stopped; kept ${_clock(kept)}');
        await m.castFile(r, movie, from: kept);
        final at = m.coordinator.timeline.position;
        r.note('resumed at ${_clock(at)}');
        if (kept == null || at < kept - const Duration(seconds: 5)) {
          throw StateError('resumed at ${_clock(at)}, kept ${_clock(kept)}');
        }
        await m.hold(r, m.holdFor ~/ 3);
      },
    ),
    _Row(
      16,
      "The TV's remote: Pause, Play, then Back",
      'the app following the remote',
      asks: "Have the TV's remote at hand: the run says when to press.",
      (m, r) async {
        await m.castChannel(r, _channel('h264_1080p50_aac', m));
        await m.remote(r, 'Pause', (tv) => tv.remotePause(), () {
          return m.state.paused;
        });
        await m.remote(r, 'Play', (tv) => tv.remotePlay(), () {
          return !m.state.paused;
        });
        await m.remote(r, 'Back', (tv) => tv.remoteBack(), () {
          return r.notices.isNotEmpty;
        });
      },
    ),
  ];
}

final class _Row {
  const new(
    this.number,
    this.name,
    this.watch,
    this.run, {
    this.asks,
    this.fakeDevice,
  });

  final int number;
  final String name;

  /// What the user watches the TV for.
  final String watch;
  final Future<void> Function(_Matrix m, _Result r) run;

  /// What the user does first; such a row runs only when named.
  final String? asks;

  /// The fake TV it needs, on the fake run.
  final FakeDevice? fakeDevice;
}

final class _Result {
  new(this.row);

  final _Row row;
  final notes = <String>[];
  final plans = <String>[];
  final notices = <String>[];
  Duration? start;
  String? failure;
  int mostConnections = 0;
  int reloads = 0;
  int restarts = 0;
  int refusals = 0;

  void note(String line) => notes.add(line);
}

/// The app's casting stack on the real TV (or the fake one), with the
/// fake panel on this computer's network address.
final class _Matrix {
  new _({
    required this.temp,
    required this.panel,
    required this.resolver,
    required this.relay,
    required this.coordinator,
    required this.playback,
    required this.engine,
    required this.devices,
    required this.progress,
    required this.device,
    required this.holdFor,
    required this.lines,
    required this.say,
    required this.fakeTvs,
  });

  static Future<_Matrix> open({
    required String host,
    required bool fake,
    required Duration hold,
  }) async {
    final binaries = relayBinaries()!;
    final out = Directory('build/real_cast_run')..createSync(recursive: true);
    final logFile = File(p.join(out.path, 'matrix.log'))..writeAsStringSync('');
    final clock = Stopwatch()..start();
    final lines = <String>[];
    void say(String line) {
      final seconds = (clock.elapsedMilliseconds / 1000).toStringAsFixed(1);
      final stamped = '[${seconds.padLeft(7)} s] $line';
      // The run is watched live, from the console.
      // ignore: avoid_print
      print(stamped);
      logFile.writeAsStringSync('$stamped\n', mode: FileMode.append);
    }

    final log = AppLog(
      output: _Lines((line) {
        lines.add(line);
        if (line.contains('[cast]') || line.contains('[relay]')) {
          say(line);
        } else {
          logFile.writeAsStringSync('$line\n', mode: FileMode.append);
        }
      }),
      secrets: SecretRegistry(),
    );

    // The TV, and the address it reaches this computer on.
    final fakeTvs = <FakeDevice, FakeReceiver>{};
    final CastDevice device;
    final String address;
    if (fake) {
      final tv = await FakeReceiver.start(
        pingEvery: null,
        playback: FakePlayback(ffprobe: binaries.ffprobe),
      );
      fakeTvs[FakeDevice.tv4k] = tv;
      device = _fakeDevice(tv);
      address = '127.0.0.1';
    } else {
      final cast = CastAddress.tryParse(host)!;
      final answer = await CastConnectionCheck(log: log).check(cast);
      if (answer is! CastDeviceAnswered) {
        throw StateError('$host: no Cast device answered ($answer)');
      }
      device = answer.device.copyWith(manual: true);
      final socket = await Socket.connect(
        cast.host,
        cast.port,
        timeout: const Duration(seconds: 5),
      );
      address = socket.address.address;
      socket.destroy();
      say('${device.name} at $host; this computer is $address');
    }

    final temp = await Directory.systemTemp.createTemp('cast_matrix');
    final panel = await FakeProviderServer.start(
      state: FakeServerState(
        profile: fakeProfiles['default']!.copyWith(maxConnections: 1),
        samplesDir: samples.path,
        ffmpegPath: binaries.ffmpeg,
        runDir: p.join(temp.path, 'panel'),
      ),
      port: 0,
      address: address,
    );
    final processes = Directory(p.join(temp.path, 'processes'));
    final supervisor = ProcessSupervisor(folder: processes, log: log);
    final relay = IsolateCastRelay(
      binaries: binaries,
      processFolder: processes,
      relayFolder: Directory(p.join(temp.path, 'relay')),
      log: log,
    );
    final resolver = PanelResolver(panel)..maxConnections = 1;
    final engine = _ReadingEngine();
    final progress = FakeWatchProgress();
    final playback = PlaybackCoordinator(
      engine: engine,
      resolver: resolver,
      prober: FakeProber(),
      history: FakeHistory(),
      channels: FakeChannels(),
      progress: progress,
      log: log,
    );
    final devices = MemoryCastDevices();
    final coordinator = CastCoordinator(
      receivers: CastV2Receivers(log: log),
      relay: relay,
      lookup: StreamFactsLookup(
        probe: FfprobeStreamProbe(
          ffprobe: binaries.ffprobe,
          supervisor: supervisor,
          log: log,
        ),
      ),
      encoderDetection: FfmpegEncoderDetector(
        binaries: binaries,
        folder: Directory(p.join(temp.path, 'cast')),
        supervisor: supervisor,
        log: log,
      ),
      devices: devices,
      items: CastItems(resolver: resolver),
      playback: playback,
      classify: classifyStreamFailure,
      log: log,
      progress: progress,
      pictures: ArtworkCastPictures(
        ArtworkCache(directory: Directory(p.join(temp.path, 'art'))),
      ),
    );
    return _Matrix._(
      temp: temp,
      panel: panel,
      resolver: resolver,
      relay: relay,
      coordinator: coordinator,
      playback: playback,
      engine: engine,
      devices: devices,
      progress: progress,
      device: device,
      holdFor: hold,
      lines: lines,
      say: say,
      fakeTvs: fakeTvs,
    );
  }

  final Directory temp;
  final FakeProviderServer panel;
  final PanelResolver resolver;
  final IsolateCastRelay relay;
  final CastCoordinator coordinator;
  final PlaybackCoordinator playback;
  final _ReadingEngine engine;
  final MemoryCastDevices devices;
  final FakeWatchProgress progress;
  final Duration holdFor;
  final List<String> lines;
  final void Function(String) say;

  /// The fake run's TVs, by the device each plays.
  final Map<FakeDevice, FakeReceiver> fakeTvs;

  /// The TV the row casts to.
  CastDevice device;

  final results = <_Result>[];

  CastingState get state => coordinator.state;

  static CastDevice _fakeDevice(FakeReceiver tv) => CastDevice(
    id: 'fake-${tv.device.id.substring(28)}',
    name: tv.device.name,
    host: tv.host,
    port: tv.port,
    model: 'Chromecast',
    manual: true,
  );

  /// [device]'s profile with [hevc] chosen and nothing learned.
  KnownCastDevice known({HevcSupport hevc = HevcSupport.auto}) =>
      KnownCastDevice(
        id: device.id,
        name: device.name,
        host: device.host,
        port: device.port,
        manual: true,
        model: device.model,
        hevc: hevc,
        learned: const CastLearned(),
      );

  Future<void> run(_Row row, {required int of}) async {
    final r = _Result(row);
    results.add(r);
    say('');
    say('── Row ${row.number} of $of: ${row.name}');
    if (row.asks case final asks?) say('   First: $asks');
    say('   Watch the TV for: ${row.watch}');

    // A fresh start: the device as found, the panel clean, nothing on.
    resolver
      ..query = ''
      ..hls = false
      ..remap.clear();
    devices.devices.clear();
    final fakeTv = row.fakeDevice;
    if (fakeTvs.isNotEmpty) {
      final wanted = fakeTv ?? FakeDevice.tv4k;
      final tv = fakeTvs[wanted] ??= await FakeReceiver.start(
        device: wanted,
        pingEvery: null,
        playback: FakePlayback(ffprobe: relayBinaries()!.ffprobe),
      );
      device = _fakeDevice(tv);
    }
    final from = lines.length;
    final watchPanel = Timer.periodic(const Duration(milliseconds: 50), (_) {
      final open = panel.state.activeStreams;
      if (open > r.mostConnections) r.mostConnections = open;
    });
    final notices = coordinator.notices.listen(
      (notice) => r.notices.add(castNoticeText(notice)),
    );
    final plans = coordinator.states.listen((state) {
      final plan = state.plan;
      if (plan != null && r.plans.lastOrNull != _plan(plan)) {
        r.plans.add(_plan(plan));
      }
    });
    try {
      await row.run(this, r);
    } on Object catch (error) {
      r.failure = '$error';
      say('   FAILED: $error');
    } finally {
      await coordinator.disconnect();
      await playback.stop();
      try {
        await _until(
          () => panel.state.activeStreams == 0 && running.isEmpty,
          within: const Duration(seconds: 15),
          what: () => "the panel's connections and FFmpeg gone",
        );
      } on TimeoutException catch (error) {
        r.failure ??= '$error';
      }
      watchPanel.cancel();
      await notices.cancel();
      await plans.cancel();
    }
    final logged = lines.sublist(from);
    int count(String words) => logged.where((l) => l.contains(words)).length;
    r
      ..reloads = count('loading it again') + count('loading again')
      ..restarts = count('The relay started FFmpeg again')
      ..refusals = count('refused CastPlan');
    if (r.mostConnections > 1) {
      r.failure ??= '${r.mostConnections} provider connections at once';
    }
    say('   ${r.failure == null ? 'done' : 'FAILED'}: ${_describe(r)}');
  }

  /// Connects (the receiver launched or joined) and plays [channel] on
  /// the TV; [moving] when it already plays here and moves with Cast.
  Future<void> castChannel(
    _Result r,
    ChannelItem channel, {
    bool moving = false,
  }) async {
    final clock = Stopwatch()..start();
    final playing = _playingCount;
    await coordinator.connect(device);
    if (!moving) unawaited(playback.playLive(channel));
    await _playing(PlayableChannel(channel), after: playing);
    r.start = clock.elapsed;
    say('   playing ${_seconds(clock.elapsed)} after Cast');
  }

  Future<void> castFile(_Result r, Playable item, {Duration? from}) async {
    final clock = Stopwatch()..start();
    final playing = _playingCount;
    await coordinator.connect(device);
    unawaited(playback.playVod(item, from: from));
    await _playing(item, after: playing);
    r.start ??= clock.elapsed;
    say('   playing ${_seconds(clock.elapsed)} after Cast');
  }

  /// Another channel while casting: how long until it plays.
  Future<String> zap(_Result r, ChannelItem channel) async {
    final clock = Stopwatch()..start();
    final playing = _playingCount;
    unawaited(playback.playLive(channel));
    await _playing(PlayableChannel(channel), after: playing);
    return _seconds(clock.elapsed);
  }

  Future<String> seekTo(_Result r, Duration to) async {
    final clock = Stopwatch()..start();
    await playback.seek(to);
    await _until(
      () =>
          state.phase == CastPhase.playing &&
          coordinator.timeline.position >= to &&
          coordinator.timeline.position < to + const Duration(seconds: 20),
      within: const Duration(seconds: 40),
      what: () => 'playing from ${_clock(to)} (${state.phase.name})',
    );
    return _seconds(clock.elapsed);
  }

  /// After a cut: the cast loads the stream again, then plays. ("Playing
  /// on" is logged once a play, not after a re-LOAD.)
  Future<void> playingAgain(_Result r) async {
    int reloads() => lines.where((l) => l.contains('loading it again')).length;
    final before = reloads();
    await _until(
      () => reloads() > before,
      within: const Duration(seconds: 40),
      what: () => 'a new LOAD ($state)',
    );
    await _until(
      () => state.phase == CastPhase.playing,
      within: const Duration(seconds: 40),
      what: () => 'playing again ($state)',
    );
  }

  /// Holds the cast on the TV for [time], failing the row if it fails.
  Future<void> hold(_Result r, [Duration? time]) async {
    final end = DateTime.now().add(time ?? holdFor);
    while (DateTime.now().isBefore(end)) {
      if (state.phase == CastPhase.failed) {
        throw StateError('the cast failed: ${state.problem}');
      }
      await Future<void>.delayed(const Duration(milliseconds: 200));
    }
  }

  /// One press of the TV's remote: asked of the user, or done by the fake.
  Future<void> remote(
    _Result r,
    String button,
    void Function(FakeReceiver tv) onFake,
    bool Function() seen,
  ) async {
    if (fakeTvs.isNotEmpty) {
      await Future<void>.delayed(const Duration(seconds: 1));
      onFake(fakeTvs[FakeDevice.tv4k]!);
    } else {
      say("   >>> Press $button on the TV's remote now (60 s).");
    }
    final clock = Stopwatch()..start();
    await _until(
      seen,
      within: const Duration(seconds: 60),
      what: () => 'the app seeing $button',
    );
    r.note('$button seen ${_seconds(clock.elapsed)} after asking');
  }

  /// The relay's FFmpeg, from its PID file.
  int relayPid() {
    final pids = [
      for (final file in running)
        (jsonDecode(file.readAsStringSync()) as Map)['pid'] as int,
    ];
    if (pids.length != 1) throw StateError('FFmpegs running: $pids');
    return pids.single;
  }

  List<File> get running {
    final folder = Directory(p.join(temp.path, 'processes'));
    return folder.existsSync()
        ? folder.listSync().whereType<File>().toList()
        : const [];
  }

  Future<void> until(
    bool Function() test,
    String what, {
    Duration within = const Duration(seconds: 30),
  }) => _until(test, within: within, what: () => what);

  int get _playingCount => lines.where((l) => l.contains('Playing on ')).length;

  Future<void> _playing(Playable item, {required int after}) => _until(
    () =>
        _playingCount > after &&
        state.item == item &&
        state.phase == CastPhase.playing,
    within: const Duration(seconds: 60),
    what: () => 'the TV playing $item ($state)',
  );

  Future<void> summarize() async {
    final table = StringBuffer()
      ..writeln('# The casting matrix on ${device.name}')
      ..writeln()
      ..writeln('| Row | What | Result | Cast to playing | Plans | Notes |')
      ..writeln('|---|---|---|---|---|---|');
    for (final r in results) {
      table.writeln(
        '| ${r.row.number} | ${r.row.name} | '
        '${r.failure == null ? 'ok' : 'FAILED: ${r.failure}'} | '
        '${r.start == null ? '—' : _seconds(r.start!)} | '
        '${r.plans.join(' → ')} | ${_describe(r)} |',
      );
    }
    File('build/real_cast_run/matrix.md').writeAsStringSync('$table');
    say('');
    '$table'.split('\n').forEach(say);
  }

  Future<void> close() async {
    await coordinator.dispose();
    await playback.dispose();
    await relay.close();
    for (final tv in fakeTvs.values) {
      await tv.close();
    }
    await panel.close();
    await temp.delete(recursive: true);
  }
}

/// The laptop's player as a provider sees it: it opens the stream and
/// reads it until stopped, so a one-connection panel counts it.
final class _ReadingEngine implements PlayerEngine {
  final _fake = FakePlayerEngine();
  HttpClient? _client;
  bool reading = false;

  @override
  Stream<PlayerEvent> get events => _fake.events;

  @override
  Future<void> open(PlayRequest request) async {
    _close();
    await _fake.open(request);
    final generation = _fake.generation;
    final client = _client = HttpClient()..userAgent = request.userAgent;
    unawaited(() async {
      try {
        final response = await (await client.getUrl(Uri.parse(request.url)))
            .close();
        await for (final _ in response) {
          if (!reading && _fake.generation == generation) {
            reading = true;
            _fake.firstFrame();
          }
        }
      } on Object {
        // Stopped, or the panel let go.
      }
    }());
  }

  void _close() {
    _client?.close(force: true);
    _client = null;
    reading = false;
  }

  @override
  Future<void> stop() async {
    _close();
    await _fake.stop();
  }

  @override
  Future<void> setPaused({required bool paused}) =>
      _fake.setPaused(paused: paused);

  @override
  Future<void> seek(Duration position) => _fake.seek(position);

  @override
  Future<void> setVolume(double volume) => _fake.setVolume(volume);

  @override
  Future<void> setMuted({required bool muted}) => _fake.setMuted(muted: muted);

  @override
  Future<void> selectAudio(String? id) => _fake.selectAudio(id);

  @override
  Future<void> selectSubtitle(String? id) => _fake.selectSubtitle(id);

  @override
  Future<void> setAspect(AspectMode mode) => _fake.setAspect(mode);

  @override
  Future<void> setDeinterlace({required bool on}) =>
      _fake.setDeinterlace(on: on);

  @override
  Future<StreamInfo> streamInfo() => _fake.streamInfo();

  @override
  Widget videoView({
    required Color background,
    Key? key,
    BoxFit fit = BoxFit.contain,
  }) => _fake.videoView(background: background, key: key, fit: fit);

  @override
  Future<void> dispose() async {
    _close();
    await _fake.dispose();
  }
}

String _describe(_Result r) => [
  ...r.notes,
  if (r.reloads > 0) '${r.reloads} new LOAD(s)',
  if (r.restarts > 0) '${r.restarts} relay restart(s)',
  if (r.refusals > 0) '${r.refusals} refusal(s) learned from',
  'at most ${r.mostConnections} provider connection(s)',
  for (final notice in r.notices) 'toast "$notice"',
].join('; ');

String _plan(CastPlan plan) =>
    '$plan'.replaceFirst('CastPlan(', '').replaceFirst(RegExp(r'\)$'), '');

String _seconds(Duration time) =>
    '${(time.inMilliseconds / 1000).toStringAsFixed(1)} s';

String _clock(Object? time) => switch (time) {
  final Duration d =>
    '${d.inMinutes}:${(d.inSeconds % 60).toString().padLeft(2, '0')}',
  null => '—',
  _ => '$time',
};

/// Until [test]; [what] is read when it gives up, so it says the state
/// then.
Future<void> _until(
  bool Function() test, {
  required Duration within,
  required String Function() what,
}) async {
  final deadline = DateTime.now().add(within);
  while (!test()) {
    if (DateTime.now().isAfter(deadline)) {
      throw TimeoutException('waited ${within.inSeconds} s for ${what()}');
    }
    await Future<void>.delayed(const Duration(milliseconds: 50));
  }
}

final class _Lines extends LogOutput {
  new(this._say);

  final void Function(String) _say;

  @override
  void output(OutputEvent event) => event.lines.forEach(_say);
}
