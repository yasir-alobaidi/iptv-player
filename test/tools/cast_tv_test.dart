// Phase 7 step 2 on a real Cast device (the user's Living Room TV): the
// client's first LAUNCH and LOAD. Only with the user's go-ahead, and with
// them watching — it shows on the TV for about half a minute:
//
//     CAST_HOST=192.168.1.155 flutter test --tags real_cast --run-skipped \
//       test/tools/cast_tv_test.dart
//
// 1. Who is there, asked two ways, nothing on screen: the direct DNS-SD
//    query (step 1) and a Cast connection's GET_STATUS and multizone
//    status (step 2's fallback). Their ids should agree.
// 2. Join: LAUNCH the Default Media Receiver (or join it), timed.
// 3. LOAD the 10-minute MP4 sample, served from this computer with Range
//    requests on the address the Cast connection leaves from; timed to
//    PLAYING.
// 4. PAUSE, SEEK to 1:00, PLAY.
// 5. STOP the receiver: the TV returns to its home screen. This runs
//    whatever failed before it.
//
// The log goes to the console and to build/real_cast_run/tv.log.
@Tags(['real_cast'])
library;

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:iptv_player/core/cast/cast_discovery.dart';
import 'package:iptv_player/core/cast/cast_receiver.dart';
import 'package:iptv_player/core/logging/app_log.dart';
import 'package:iptv_player/core/logging/secret_registry.dart';
import 'package:iptv_player/data/cast/cast_connection_check.dart';
import 'package:iptv_player/data/cast/cast_v2_receivers.dart';
import 'package:iptv_player/data/cast/unicast_address_check.dart';
import 'package:logger/logger.dart';

const _sample = 'tools/media_samples/out/vod_h264_aac_10min.mp4';

void main() {
  final host = Platform.environment['CAST_HOST'] ?? '192.168.1.155';
  final logFile = File('build/real_cast_run/tv.log');
  final clock = Stopwatch()..start();
  void say(String line) {
    final seconds = (clock.elapsedMilliseconds / 1000).toStringAsFixed(1);
    final stamped = '[${seconds.padLeft(6)} s] $line';
    // The run is watched live, from the console.
    // ignore: avoid_print
    print(stamped);
    logFile.writeAsStringSync('$stamped\n', mode: FileMode.append);
  }

  final log = AppLog(
    output: _Lines(say),
    secrets: SecretRegistry(),
    level: Level.debug,
  );

  test('LAUNCH, LOAD the sample, PAUSE, SEEK, PLAY, STOP on $host', () async {
    logFile
      ..createSync(recursive: true)
      ..writeAsStringSync('');
    expect(File(_sample).existsSync(), isTrue, reason: 'generate $_sample');
    final address = CastAddress.tryParse(host)!;

    // 1. Who is there.
    final txt = await UnicastCastAddressCheck(log: log).check(address);
    final cast = await CastConnectionCheck(log: log).check(address);
    String? idOf(CastAddressAnswer answer) =>
        answer is CastDeviceAnswered ? answer.device.id : null;
    say('DNS-SD: ${_describe(txt)}');
    say('Cast:   ${_describe(cast)}');

    // 2. Join.
    final joining = Stopwatch()..start();
    final joined = await CastV2Receivers(log: log).join(address);
    if (joined is CastJoinFailed) {
      fail('join failed: ${joined.reason} ${joined.detail ?? ''}');
    }
    final session = (joined as CastJoined).session;
    say(
      'joined after ${joining.elapsedMilliseconds} ms '
      '(${joined.launched ? 'launched' : 'already running'}); this '
      'computer is ${session.localAddress} on that connection',
    );
    final states = session.states.listen(
      (s) => say(
        'state: ${s.link.name} '
        '${s.media?.playerState.name ?? 'no media'}'
        '${s.media?.idleReason == null ? '' : '/${s.media!.idleReason!.name}'} '
        't=${s.media?.position.inMilliseconds ?? '-'} ms',
      ),
    );
    final server = await _RangeServer.start(session.localAddress, say);
    try {
      // 3. LOAD.
      final loading = Stopwatch()..start();
      final load = await session.load(
        CastLoad(
          url: server.url,
          contentType: 'video/mp4',
          live: false,
          title: 'IPTV Player · casting test',
          subtitle: 'Phase 7 step 2: the MP4 sample, direct with Range',
        ),
      );
      say(
        'LOAD answered ${load.runtimeType} after '
        '${loading.elapsedMilliseconds} ms',
      );
      expect(load, isA<CastDone>());
      await _until(session, (s) => _is(s, CastPlayerState.playing));
      say('PLAYING ${loading.elapsedMilliseconds} ms after LOAD');
      await Future<void>.delayed(const Duration(seconds: 8));

      // 4. PAUSE, SEEK, PLAY.
      say('PAUSE → ${_short(await session.pause())}');
      await Future<void>.delayed(const Duration(seconds: 2));
      final seeking = Stopwatch()..start();
      final seek = await session.seek(const Duration(seconds: 60));
      say('SEEK 60 s → ${_short(seek)}');
      say('PLAY → ${_short(await session.play())}');
      await _until(
        session,
        (s) =>
            _is(s, CastPlayerState.playing) &&
            s.media!.position >= const Duration(seconds: 60),
      );
      say('playing from 1:00 ${seeking.elapsedMilliseconds} ms after SEEK');
      await Future<void>.delayed(const Duration(seconds: 4));
    } finally {
      // 5. STOP, whatever happened.
      await session.stop();
      say('STOP: the receiver closed (${session.state.end?.name})');
      await states.cancel();
      await server.close();
      say('Range requests served: ${server.requests}');
    }
    expect(session.state.end, CastEnd.stopped);
    expect(server.requests, greaterThanOrEqualTo(1));
    if (idOf(txt) != null && idOf(cast) != null) {
      expect(idOf(cast), idOf(txt), reason: 'multizone id vs TXT id');
    }
  }, timeout: const Timeout(Duration(minutes: 2)));
}

Future<void> _until(
  CastReceiverSession session,
  bool Function(CastSessionState state) test,
) async {
  if (test(session.state)) return;
  await session.states.firstWhere(test).timeout(const Duration(seconds: 20));
}

bool _is(CastSessionState state, CastPlayerState player) =>
    state.media?.playerState == player;

String _describe(CastAddressAnswer answer) => switch (answer) {
  CastDeviceAnswered(:final device) =>
    '"${device.name}" (${device.model ?? 'no model'}) id ${device.id} '
        'at ${device.host}:${device.port}'
        '${device.status == null ? '' : ', running ${device.status}'}',
  CastAudioOnlyAnswered(:final name) => 'a speaker, "$name"',
  CastNoAnswer() => 'no answer',
};

String _short(CastCommandResult result) => switch (result) {
  CastDone(:final media) =>
    'done (${media?.playerState.name}, t=${media?.position.inMilliseconds} ms)',
  CastRefused(:final reason, :final detail) => 'refused: $reason $detail',
  CastUnanswered() => 'no answer',
  CastDisconnected() => 'disconnected',
};

/// The sample over HTTP with Range requests, as the relay will serve a
/// file (docs/04 "Direct file"), on a port in 38400–38499.
final class _RangeServer {
  new _(this._server, this._say);

  static Future<_RangeServer> start(
    String address,
    void Function(String) say,
  ) async {
    for (var port = 38400; port < 38500; port++) {
      try {
        final server = await HttpServer.bind(address, port);
        return _RangeServer._(server, say).._listen();
      } on SocketException {
        continue;
      }
    }
    throw StateError('no free port in 38400–38499');
  }

  final HttpServer _server;
  final void Function(String) _say;
  int requests = 0;

  String get url =>
      'http://${_server.address.address}:${_server.port}/f/test/media.mp4';

  void _listen() {
    _server.listen((request) async {
      final response = request.response;
      response.headers
        ..set('Access-Control-Allow-Origin', '*')
        ..set('Access-Control-Allow-Headers', '*')
        ..set('Access-Control-Allow-Methods', 'GET, HEAD, OPTIONS');
      if (request.method == 'OPTIONS') {
        await response.close();
        return;
      }
      if (request.uri.path != '/f/test/media.mp4') {
        response.statusCode = HttpStatus.notFound;
        await response.close();
        return;
      }
      requests++;
      final file = File(_sample);
      final length = file.lengthSync();
      final range = RegExp(r'bytes=(\d*)-(\d*)')
          .firstMatch(request.headers.value('range') ?? '');
      var start = 0;
      var end = length - 1;
      if (range != null) {
        start = int.tryParse(range[1]!) ?? 0;
        end = int.tryParse(range[2]!) ?? end;
        response
          ..statusCode = HttpStatus.partialContent
          ..headers.set('Content-Range', 'bytes $start-$end/$length');
      }
      response.headers
        ..contentType = ContentType('video', 'mp4')
        ..set('Accept-Ranges', 'bytes')
        ..contentLength = end - start + 1;
      _say(
        'HTTP ${request.method} range=${request.headers.value('range')} '
        '→ ${response.statusCode}',
      );
      try {
        if (request.method != 'HEAD') {
          await response.addStream(file.openRead(start, end + 1));
        }
        await response.close();
      } on Object {
        // The TV moved on (a seek opens a new request).
      }
    });
  }

  Future<void> close() => _server.close(force: true);
}

final class _Lines extends LogOutput {
  new(this._say);

  final void Function(String) _say;

  @override
  void output(OutputEvent event) => event.lines.forEach(_say);
}
