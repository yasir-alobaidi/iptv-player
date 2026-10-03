// Plain Dart: the relay's isolate, and the messages it trades with the
// app (Phase 7 decision 5). Everything here crosses between isolates of
// one group, so it is plain data.
import 'dart:async';
import 'dart:io';
import 'dart:isolate';

import 'package:iptv_player/core/logging/app_log.dart';
import 'package:iptv_player/core/logging/secret_registry.dart';
import 'package:iptv_player/data/cast/relay/relay_job.dart';
import 'package:iptv_player/data/cast/relay/relay_proxy.dart';
import 'package:iptv_player/data/cast/relay/relay_runtime.dart';
import 'package:iptv_player/data/process/process_supervisor.dart';
import 'package:logger/logger.dart';
import 'package:path/path.dart' as p;

/// What the relay's isolate starts with.
final class RelayIsolateSetup {
  const new({
    required this.app,
    required this.processFolder,
    required this.relayFolder,
    this.timings = const RelayTimings(),
    this.proxyTimings = const RelayProxyTimings(),
    this.logLevel = Level.info,
  });

  /// Where its messages go.
  final SendPort app;

  /// The PID files (hard rule 8): the app's own folder for them.
  final String processFolder;

  /// The relay's sessions' folders: `<relay root>`; this run's go in
  /// `<relay root>/<pid>`.
  final String relayFolder;
  final RelayTimings timings;
  final RelayProxyTimings proxyTimings;
  final Level logLevel;
}

// The app → the relay.

final class RelayStartCommand {
  const new({
    required this.replyId,
    required this.sessionId,
    required this.inputId,
    required this.sourceId,
    required this.job,
    required this.localAddress,
  });

  final int replyId;
  final String sessionId;
  final String inputId;
  final String sourceId;
  final RelayJob job;
  final String localAddress;
}

final class RelayRenewCommand {
  const new({required this.replyId, required this.sessionId, this.job});

  final int replyId;
  final String sessionId;
  final RelayJob? job;
}

final class RelayStopCommand {
  const new({required this.replyId, required this.sessionId});

  final int replyId;
  final String sessionId;
}

final class RelayOpenInputCommand {
  const new({
    required this.replyId,
    required this.inputId,
    required this.sourceId,
    required this.live,
  });

  final int replyId;
  final String inputId;
  final String sourceId;
  final bool live;
}

final class RelayCloseInputCommand {
  const new(this.inputId);

  final String inputId;
}

/// Serve the picture at [path] to the TV at [localAddress]; the reply is
/// its URL, or null.
final class RelayServePictureCommand {
  const new({
    required this.replyId,
    required this.path,
    required this.localAddress,
  });

  final int replyId;
  final String path;
  final String localAddress;
}

final class RelayUnserveCommand {
  const new(this.url);

  final String url;
}

/// The app's answer to a [RelayResolveRequest].
final class RelayResolveAnswer {
  const new(this.requestId, this.resolved);

  final int requestId;
  final RelayResolved resolved;
}

final class RelayShutdownCommand {
  const new(this.replyId);

  final int replyId;
}

// The relay → the app.

/// The relay's isolate is up: its commands go to [commands].
final class RelayIsolateReady {
  const new(this.commands);

  final SendPort commands;
}

/// The answer to a command with [replyId]: a [RelayStartAnswer], the
/// input's URL, or null.
final class RelayReply {
  const new(this.replyId, this.value);

  final int replyId;
  final Object? value;
}

/// The proxy asks for [inputId]'s upstream, built afresh.
final class RelayResolveRequest {
  const new(this.requestId, this.inputId);

  final int requestId;
  final String inputId;
}

/// Lines the relay's log made, for the app's log.
final class RelayLogLines {
  const new(this.level, this.lines);

  final Level level;
  final List<String> lines;
}

final class RelaySessionMessage {
  const new(this.sessionId, this.event);

  final String sessionId;
  final RelaySessionEvent event;
}

/// The relay's isolate: the proxy, the server, the sessions and their
/// FFmpegs, away from the UI's event loop (hard rule 2: a 4K stream is
/// tens of megabits a second through the proxy and to the TV).
Future<void> relayIsolateMain(RelayIsolateSetup setup) async {
  final app = setup.app;
  final commands = ReceivePort();
  final log = AppLog(
    output: _ToApp(app),
    secrets: SecretRegistry(),
    level: setup.logLevel,
  );
  final supervisor = ProcessSupervisor(
    folder: Directory(setup.processFolder),
    log: log,
  );
  final asked = <int, Completer<RelayResolved>>{};
  var nextAsk = 0;
  final runtime = await RelayRuntime.open(
    supervisor: supervisor,
    folder: Directory(p.join(setup.relayFolder, '$pid')),
    log: log,
    timings: setup.timings,
    proxyTimings: setup.proxyTimings,
    resolve: (inputId) {
      final id = nextAsk++;
      final answer = Completer<RelayResolved>();
      asked[id] = answer;
      app.send(RelayResolveRequest(id, inputId));
      return answer.future.whenComplete(
        () => asked.removeWhere((k, _) => k == id),
      );
    },
    emit: (sessionId, event) => app.send(RelaySessionMessage(sessionId, event)),
    onProxyEvent: app.send,
  );
  app.send(RelayIsolateReady(commands.sendPort));

  await for (final message in commands) {
    switch (message) {
      case RelayStartCommand():
        unawaited(
          runtime
              .start(
                sessionId: message.sessionId,
                inputId: message.inputId,
                sourceId: message.sourceId,
                job: message.job,
                localAddress: message.localAddress,
              )
              .then((answer) => app.send(RelayReply(message.replyId, answer))),
        );
      case RelayRenewCommand(:final replyId, :final sessionId, :final job):
        unawaited(
          runtime
              .renew(sessionId, job: job)
              .then((answer) => app.send(RelayReply(replyId, answer))),
        );
      case RelayStopCommand(:final replyId, :final sessionId):
        unawaited(
          runtime
              .stop(sessionId)
              .then((_) => app.send(RelayReply(replyId, null))),
        );
      case RelayOpenInputCommand():
        final url = runtime.openInput(
          message.inputId,
          sourceId: message.sourceId,
          live: message.live,
        );
        app.send(RelayReply(message.replyId, url));
      case RelayCloseInputCommand(:final inputId):
        runtime.closeInput(inputId);
      case RelayServePictureCommand(
        :final replyId,
        :final path,
        :final localAddress,
      ):
        unawaited(
          runtime
              .servePicture(path, localAddress: localAddress)
              .then((url) => app.send(RelayReply(replyId, url))),
        );
      case RelayUnserveCommand(:final url):
        unawaited(runtime.unserve(url));
      case RelayResolveAnswer(:final requestId, :final resolved):
        final answer = asked[requestId];
        if (answer != null && !answer.isCompleted) answer.complete(resolved);
      case RelayShutdownCommand(:final replyId):
        for (final answer in asked.values) {
          if (answer.isCompleted) continue;
          answer.complete(const RelayResolved(failure: 'the app is quitting'));
        }
        await runtime.shutdown();
        await log.close();
        app.send(RelayReply(replyId, null));
        commands.close();
    }
  }
}

/// The relay's log lines go to the app, which writes them to its own log
/// (redacted again, with the secrets it knows).
final class _ToApp extends LogOutput {
  new(this._app);

  final SendPort _app;

  @override
  void output(OutputEvent event) =>
      _app.send(RelayLogLines(event.level, event.lines));
}
