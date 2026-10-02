// Not a test: the process `relay_kill_test.dart` starts and then kills
// with SIGKILL while its relay runs FFmpeg, to prove a killed app leaves
// no FFmpeg behind (Phase 7's exit criterion 2). Plain Dart (`dart run`),
// like everything the relay's isolate runs: it starts that isolate as the
// app does, and speaks its messages.
import 'dart:async';
import 'dart:io';
import 'dart:isolate';

import 'package:iptv_player/data/cast/relay/relay_isolate.dart';
import 'package:iptv_player/data/cast/relay/relay_job.dart';
import 'package:iptv_player/data/cast/relay/relay_proxy.dart';
import 'package:iptv_player/data/cast/relay/relay_runtime.dart';

/// `dart run …/relay_victim.dart ffmpeg processes relay-root stream-url
/// hls|continuous`: relays the stream and prints `ready` (and the URL of
/// a continuous stream) once the TV could load it, then waits to be
/// killed.
Future<void> main(List<String> args) async {
  final [ffmpeg, processes, relayRoot, stream, output] = args;
  final messages = ReceivePort();
  final ready = Completer<SendPort>();
  late SendPort commands;
  messages.listen((message) {
    switch (message) {
      case RelayIsolateReady(:final commands):
        ready.complete(commands);
      case RelayResolveRequest(:final requestId):
        commands.send(
          RelayResolveAnswer(
            requestId,
            RelayResolved(
              upstream: RelayUpstream(url: stream, maxConnections: 1),
            ),
          ),
        );
      case RelayReply(value: RelayStartAnswer(:final url?)):
        if (output == 'continuous') stdout.writeln('ready $url');
      case RelaySessionMessage(event: RelayReady()) when output == 'hls':
        stdout.writeln('ready');
      case RelayLogLines(:final lines):
        lines.forEach(stderr.writeln);
    }
  });
  await Isolate.spawn(
    relayIsolateMain,
    RelayIsolateSetup(
      app: messages.sendPort,
      processFolder: processes,
      relayFolder: relayRoot,
    ),
  );
  commands = await ready.future
    ..send(
      RelayStartCommand(
        replyId: 1,
        sessionId: 'victim',
        inputId: 'victim/input',
        sourceId: 'panel',
        localAddress: '127.0.0.1',
        job: RelayJob(
          ffmpeg: ffmpeg,
          output: output == 'hls' ? RelayOutput.hls : RelayOutput.continuous,
          live: true,
          outputArgs: const [
            ...['-map', '0:V:0', '-c:v', 'copy'],
            ...['-map', '0:a:0?', '-c:a', 'aac', '-ac', '2'],
          ],
        ),
      ),
    );
  // Until the test kills it.
  await Completer<void>().future;
}
