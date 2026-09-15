import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:cast_spike/cast_channel.dart';
import 'package:cast_spike/discovery.dart';
import 'package:cast_spike/relay.dart';

const _samples = {
  'h264_1080p50_aac': 'h264_1080p50_aac.ts',
  'h264_1080p25_ac3': 'h264_1080p25_ac3.ts',
  'hevc_2160p25_eac3': 'hevc_2160p25_eac3.ts',
  'hevc_1080p50_aac': 'hevc_1080p50_aac.ts',
  'h264_2160p25_aac': 'h264_2160p25_aac.ts',
  'vod_file': 'vod_h264_aac_10min.mp4',
};

const _usage = '''
Usage (run from spike/cast_spike):
  dart run bin/cast_spike.dart discover [--timeout 5]
  dart run bin/cast_spike.dart cast --case <case> (--host <ip> | --name <device name>)
      [--seg-format fmp4|FMP4|none] [--content-type <mime>] [--hold <s>]
      [--seek 300,60] [--keep-app] [--label <suffix>]
      [--hls-time 2] [--min-segments 2] [--start-offset <s behind live>]
      [--fmp4] [--vtag hvc1|hev1|none]
Cases: h264_1080p50_aac, h264_1080p25_ac3 (HLS/TS relay-copy; --fmp4 for fMP4),
       hevc_2160p25_eac3, hevc_1080p50_aac (HLS/fMP4 relay-copy, -tag:v hvc1),
       vod_file (plain MP4 over Range, BUFFERED, seek + pause test)
Stop early: Ctrl+C, SIGTERM, or `touch results/stop`.
''';

Future<void> main(List<String> argv) async {
  final opts = <String, String>{};
  for (var i = 1; i < argv.length; i++) {
    if (!argv[i].startsWith('--')) continue;
    final key = argv[i].substring(2);
    final hasValue = i + 1 < argv.length && !argv[i + 1].startsWith('--');
    opts[key] = hasValue ? argv[++i] : 'true';
  }
  final code = switch (argv.firstOrNull) {
    'discover' => await _discover(opts),
    'cast' => await _cast(opts),
    _ => _help(),
  };
  exit(code);
}

int _help() {
  stdout.write(_usage);
  return 64;
}

Future<int> _discover(Map<String, String> opts) async {
  final sw = Stopwatch()..start();
  final devices = await discoverCastDevices(
    timeout: Duration(seconds: int.parse(opts['timeout'] ?? '5')),
  );
  stdout.writeln(
    '${devices.length} device(s) after ${sw.elapsedMilliseconds} ms',
  );
  for (final d in devices) {
    stdout
      ..writeln('  $d')
      ..writeln('    txt ${d.txt}');
  }
  return devices.isEmpty ? 1 : 0;
}

class _Fail implements Exception {
  _Fail(this.result, this.code);

  final String result;
  final int code;

  @override
  String toString() => result;
}

Future<Json> _nextMedia(
  CastChannel ch,
  bool Function(Json status) test, [
  Duration? timeout,
]) {
  final f = ch.messages
      .where((m) => m.namespace == nsMedia && m.type == 'MEDIA_STATUS')
      .map((m) => CastSession.mediaStatusFrom(m.json))
      .where((st) => st != null && test(st))
      .map((st) => st!)
      .first;
  return timeout == null ? f : f.timeout(timeout);
}

Future<int> _cast(Map<String, String> opts) async {
  final caseName = opts['case'];
  final sample = _samples[caseName];
  if (caseName == null || sample == null) return _help();
  final root = Directory.current.absolute.parent.parent.path;
  final ffmpeg = '$root/third_party/ffmpeg/linux-x64/ffmpeg';
  final samples = '$root/tools/media_samples/out';
  if (!File(ffmpeg).existsSync() || !File('$samples/$sample').existsSync()) {
    stderr.writeln(
      'Run from spike/cast_spike; needs $ffmpeg and $samples/$sample',
    );
    return 66;
  }
  final results = Directory('${Directory.current.absolute.path}/results')
    ..createSync();
  final runDir = Directory('${results.path}/run')..createSync();
  final sessionsRoot = Directory('${results.path}/sessions')..createSync();
  final stopFile = File('${results.path}/stop');
  if (stopFile.existsSync()) stopFile.deleteSync();
  final label = opts['label'] == null
      ? caseName
      : '${caseName}_${opts['label']}';
  final logSink = File('${results.path}/$label.log').openWrite();
  final events = File('${results.path}/$label.jsonl').openWrite();
  final pidFile = File('${results.path}/cast_spike.pid')
    ..writeAsStringSync('$pid\n');
  final clock = Stopwatch()..start();
  void log(String line) {
    final secs = (clock.elapsedMilliseconds / 1000).toStringAsFixed(1);
    final l = '[${secs.padLeft(6)} s] $line';
    stdout.writeln(l);
    logSink.writeln(l);
  }

  void event(String name, Json data) => events.writeln(
    jsonEncode({'t_ms': clock.elapsedMilliseconds, 'event': name, ...data}),
  );

  sweepLeftovers(runDir, sessionsRoot, log);

  final isFile = caseName == 'vod_file';
  final isHevc = caseName.startsWith('hevc_');
  final fmp4 = isHevc || opts['fmp4'] != null;
  final vtag = opts['vtag'] ?? (isHevc ? 'hvc1' : 'none');
  final segFormat = opts['seg-format'] ?? (fmp4 ? 'fmp4' : 'none');
  final summary = <String, Object?>{
    'case': caseName,
    'label': label,
    if (!isFile) ...{'fmp4': fmp4, 'vtag': vtag, 'seg_format': segFormat},
  };

  final stop = Completer<String>();
  void requestStop(String why) {
    if (!stop.isCompleted) stop.complete(why);
  }

  final signalSubs = [
    ProcessSignal.sigint.watch().listen((_) => requestStop('SIGINT')),
    ProcessSignal.sigterm.watch().listen((_) => requestStop('SIGTERM')),
  ];
  final stopPoll = Timer.periodic(const Duration(seconds: 1), (_) {
    if (stopFile.existsSync()) requestStop('stop file');
  });

  final seen = <String, int>{};
  var httpBytes = 0;
  RelayServer? relay;
  SourceServer? source;
  HlsRelay? hls;
  CastChannel? channel;
  CastSession? session;
  Timer? ticker;
  var code = 0;
  try {
    final CastDevice device;
    final host = opts['host'];
    if (host != null) {
      device = CastDevice(name: host, model: '?', id: '?', host: host);
    } else {
      final all = await discoverCastDevices();
      final match = all.where((d) => d.name == opts['name']).firstOrNull;
      if (match == null) {
        throw _Fail('device "${opts['name']}" not found in $all', 69);
      }
      device = match;
    }
    summary['device'] = '$device';
    final lan = await lanAddressFor(device.host);

    relay = await RelayServer.start(lan, (r) {
      final path = r['path'] as String;
      final kind = path.endsWith('.m3u8')
          ? 'playlist'
          : path.endsWith('.ts') || path.endsWith('.m4s')
          ? 'segment'
          : path.startsWith('f/')
          ? 'file'
          : 'init';
      final key = '$kind ${r['method']} ${r['status']}';
      final n = seen[key] = (seen[key] ?? 0) + 1;
      httpBytes += (r['length'] as int?) ?? 0;
      event('http', r);
      summary['receiver_ua'] ??= r['ua'];
      summary['receiver_origin'] ??= r['origin'];
      if (n == 1 || kind == 'file' || (r['status'] as int) >= 400) {
        final shown = path.replaceFirstMapped(
          RegExp('^(r|f)/[0-9a-f]{32}/'),
          (m) => '${m[1]}/…/',
        );
        log(
          'http ${r['method']} /$shown range=${r['range']} → ${r['status']} '
          '${r['length']} B in ${r['ms']} ms'
          '${n == 1 ? ' ua="${r['ua']}" origin=${r['origin']}' : ''}',
        );
      }
    });
    log('relay server on ${relay.origin}');

    final metadata = {
      'metadataType': 0,
      'title': 'Spike B · $caseName',
      'subtitle': isFile
          ? 'direct file with Range'
          : 'relay-copy HLS/${fmp4 ? 'fMP4' : 'TS'}',
    };
    final Json media;
    if (isFile) {
      media = {
        'contentId': relay.addFile(File('$samples/$sample')),
        'contentType': opts['content-type'] ?? 'video/mp4',
        'streamType': 'BUFFERED',
        'metadata': metadata,
      };
    } else {
      source = await SourceServer.start(ffmpeg, samples, runDir);
      final dir = Directory('${sessionsRoot.path}/${newToken()}');
      hls = await HlsRelay.start(
        ffmpeg: ffmpeg,
        sourceUrl: source.url(sample),
        dir: dir,
        runDir: runDir,
        fmp4: fmp4,
        videoTag: vtag == 'none' ? null : vtag,
        log: log,
        hlsTime: int.parse(opts['hls-time'] ?? '2'),
      );
      final minSegments = int.parse(opts['min-segments'] ?? '2');
      final startOffset = double.tryParse(opts['start-offset'] ?? '');
      summary
        ..['hls_time'] = opts['hls-time'] ?? '2'
        ..['min_segments'] = minSegments
        ..['start_offset'] = startOffset;
      final readyMs = await hls.waitForSegments(
        minSegments,
        const Duration(seconds: 60),
      );
      summary['relay_ready_ms'] = readyMs;
      log('relay: playlist lists $minSegments segments after $readyMs ms');
      media = {
        'contentId': relay.addHls(dir, startOffset: startOffset),
        'contentType': opts['content-type'] ?? 'application/x-mpegurl',
        'streamType': 'LIVE',
        'metadata': metadata,
        if (segFormat != 'none') ...{
          'hlsSegmentFormat': segFormat,
          'hlsVideoSegmentFormat': segFormat,
        },
      };
    }

    final ch = channel = await CastChannel.connect(
      device.host,
      device.port,
      log,
    );
    final s = session = CastSession(ch, log);
    String? lastState;
    ch.messages.listen((m) {
      if (m.namespace == nsMedia && m.type == 'MEDIA_STATUS') {
        final st = CastSession.mediaStatusFrom(m.json);
        if (st == null) {
          log('← MEDIA_STATUS without a media session');
          return;
        }
        event('media_status', st);
        final idle = st['idleReason'];
        final state = '${st['playerState']}${idle == null ? '' : '/$idle'}';
        if (state != lastState) {
          lastState = state;
          log(
            '← MEDIA_STATUS $state t=${st['currentTime']}'
            '${idle == null ? '' : ' ${jsonEncode(st)}'}',
          );
        }
      } else if (m.namespace == nsReceiver) {
        event('receiver', m.json);
        final status = m.json['status'];
        final apps = status is Json && status['applications'] is List
            ? (status['applications'] as List)
                  .map((a) => a is Json ? a['displayName'] : a)
                  .toList()
            : null;
        log(
          status is Json
              ? '← ${m.type} apps=$apps'
              : '← ${m.type} ${jsonEncode(m.json)}',
        );
      } else {
        event('message', {'ns': m.namespace, 'payload': m.json});
        if (m.type != 'CLOSE') log('← ${m.namespace} ${jsonEncode(m.json)}');
      }
    });

    final launch = Stopwatch()..start();
    await s.launch(defaultMediaReceiver);
    summary['launch_ms'] = launch.elapsedMilliseconds;
    log(
      'Default Media Receiver ready after ${launch.elapsedMilliseconds} ms '
      '(transportId ${s.transportId})',
    );

    final load = Stopwatch()..start();
    final started = _nextMedia(
      ch,
      (st) =>
          st['playerState'] == 'PLAYING' ||
          (st['playerState'] == 'IDLE' && st['idleReason'] != null),
      const Duration(seconds: 60),
    );
    final ended = _nextMedia(
      ch,
      (st) => st['playerState'] == 'IDLE' && st['idleReason'] != null,
    );
    final reply = await s.media({
      'type': 'LOAD',
      'media': media,
      'autoplay': true,
      'currentTime': 0,
    }, timeout: const Duration(seconds: 60));
    summary['load_reply'] = reply.type;
    event('load_reply', reply.json);
    if (reply.type != 'MEDIA_STATUS') {
      started.ignore();
      ended.ignore();
      throw _Fail('LOAD answered ${reply.type}: ${jsonEncode(reply.json)}', 2);
    }
    final first = await started;
    if (first['playerState'] != 'PLAYING') {
      ended.ignore();
      throw _Fail('receiver IDLE/${first['idleReason']} before playing', 3);
    }
    summary['load_to_playing_ms'] = load.elapsedMilliseconds;
    log('PLAYING ${load.elapsedMilliseconds} ms after LOAD');

    ticker = Timer.periodic(const Duration(seconds: 5), (_) async {
      try {
        final r = await s.media({
          'type': 'GET_STATUS',
        }, timeout: const Duration(seconds: 5));
        final st = CastSession.mediaStatusFrom(r.json);
        final t = (st?['currentTime'] as num?)?.toStringAsFixed(1);
        log('status ${st?['playerState']} t=$t http=$seen');
      } on Object catch (e) {
        log('GET_STATUS: $e');
      }
    });

    if (isFile) {
      final targets = (opts['seek'] ?? '300,60').split(',').map(double.parse);
      summary['seeks'] = await _seekAndPause(s, ch, targets.toList(), log);
    }

    final hold = int.parse(opts['hold'] ?? '120');
    final why = await Future.any<String>([
      stop.future,
      Future.delayed(Duration(seconds: hold), () => 'hold of $hold s elapsed'),
      ch.closed.then((r) => 'channel closed: $r'),
      ended.then((st) => 'receiver IDLE/${st['idleReason']}'),
    ]);
    summary['end'] = why;
    summary['result'] = why.startsWith('receiver') || why.startsWith('channel')
        ? 'ended early'
        : 'ok';
    if (summary['result'] != 'ok') code = 4;
    log('ending: $why');
  } on _Fail catch (f) {
    log('FAILED: $f');
    summary['result'] = f.result;
    code = f.code;
  } on Object catch (e) {
    log('ERROR: $e');
    summary['result'] = 'error: $e';
    code = 1;
  } finally {
    ticker?.cancel();
    stopPoll.cancel();
    for (final sub in signalSubs) {
      await sub.cancel();
    }
    final s = session;
    if (s != null && s.channel.isOpen) {
      if (s.mediaSessionId != null) {
        try {
          await s.media({'type': 'STOP'}, timeout: const Duration(seconds: 5));
        } on Object catch (e) {
          log('media STOP: $e');
        }
      }
      if (opts['keep-app'] == null) await s.stopApp();
    }
    await channel?.close();
    await hls?.stop();
    await source?.close();
    await relay?.close();
    summary['http'] = seen;
    summary['http_mb'] = (httpBytes / 1e6).toStringAsFixed(1);
    event('summary', summary);
    log('summary ${jsonEncode(summary)}');
    await events.close();
    await logSink.close();
    if (pidFile.existsSync()) pidFile.deleteSync();
  }
  return code;
}

/// Seeks to each target (8 s apart), then pauses 3 s and resumes.
Future<List<Json>> _seekAndPause(
  CastSession s,
  CastChannel ch,
  List<double> targets,
  Log log,
) async {
  final out = <Json>[];
  for (final target in targets) {
    await Future<void>.delayed(const Duration(seconds: 8));
    log('SEEK to $target s');
    final sw = Stopwatch()..start();
    final settled = _nextMedia(ch, (st) {
      final t = (st['currentTime'] as num?) ?? -1;
      return st['playerState'] == 'PLAYING' &&
          t >= target - 1 &&
          t < target + 10;
    }, const Duration(seconds: 30));
    try {
      final reply = await s.media({
        'type': 'SEEK',
        'currentTime': target,
        'resumeState': 'PLAYBACK_START',
      });
      final replyMs = sw.elapsedMilliseconds;
      final st = await settled;
      final playingMs = sw.elapsedMilliseconds;
      await Future<void>.delayed(const Duration(seconds: 4));
      final later = CastSession.mediaStatusFrom(
        (await s.media({'type': 'GET_STATUS'})).json,
      );
      final r = <String, dynamic>{
        'target': target,
        'reply': reply.type,
        'reply_ms': replyMs,
        'playing_ms': playingMs,
        'time_at_playing': st['currentTime'],
        'time_4s_later': later?['currentTime'],
        'state_4s_later': later?['playerState'],
      };
      log('seek ${jsonEncode(r)}');
      out.add(r);
    } on Object catch (e) {
      settled.ignore();
      log('seek to $target failed: $e');
      out.add({'target': target, 'error': '$e'});
    }
  }
  await Future<void>.delayed(const Duration(seconds: 5));
  final pause = <String, dynamic>{'pause': 'PAUSE'};
  try {
    final paused = _nextMedia(
      ch,
      (st) => st['playerState'] == 'PAUSED',
      const Duration(seconds: 10),
    );
    await s.media({'type': 'PAUSE'});
    pause['paused_at'] = (await paused)['currentTime'];
    await Future<void>.delayed(const Duration(seconds: 3));
    final resumed = _nextMedia(
      ch,
      (st) => st['playerState'] == 'PLAYING',
      const Duration(seconds: 10),
    );
    await s.media({'type': 'PLAY'});
    pause['resumed_at'] = (await resumed)['currentTime'];
  } on Object catch (e) {
    pause['error'] = '$e';
  }
  log('pause/resume ${jsonEncode(pause)}');
  out.add(pause);
  return out;
}
