import 'dart:async';
import 'dart:io';
import 'dart:isolate';

import 'package:iptv_player/core/downloads/download_runner.dart';
import 'package:iptv_player/core/logging/app_log.dart';
import 'package:iptv_player/core/logging/redact.dart';
import 'package:iptv_player/core/logging/secret_registry.dart';
import 'package:iptv_player/data/cast/relay/relay_proxy.dart';
import 'package:iptv_player/data/downloads/hls_download.dart';
import 'package:iptv_player/data/downloads/http_download.dart';
import 'package:iptv_player/data/process/process_supervisor.dart';
import 'package:logger/logger.dart';

/// What the downloads isolate starts with.
final class DownloadIsolateSetup {
  const new({
    required this.app,
    required this.processFolder,
    this.ffmpeg,
    this.timings = const DownloadTimings(),
    this.logLevel = Level.info,
  });

  final SendPort app;

  /// The PID files (hard rule 8).
  final String processFolder;

  /// The bundled FFmpeg, for a playlist; null when the build has none.
  final String? ffmpeg;
  final DownloadTimings timings;
  final Level logLevel;
}

final class DownloadIsolateReady {
  const new(this.commands);

  final SendPort commands;
}

final class DownloadStartCommand {
  const new(this.order);

  final DownloadOrder order;
}

final class DownloadStopCommand {
  const new(this.replyId, this.id);

  final int replyId;
  final int id;
}

final class DownloadShutdownCommand {
  const new(this.replyId);

  final int replyId;
}

final class DownloadReply {
  const new(this.replyId);

  final int replyId;
}

/// The isolate asks the app for [id]'s URL (Phase 8 decision 2: built in
/// the app, afresh for every connection).
final class DownloadResolveRequest {
  const new(this.requestId, this.id);

  final int requestId;
  final int id;
}

final class DownloadResolveAnswer {
  const new(this.requestId, this.upstream);

  final int requestId;

  /// Null: no URL (the title or its source is gone).
  final DownloadUpstream? upstream;
}

final class DownloadLogLines {
  const new(this.level, this.lines);

  final Level level;
  final List<String> lines;
}

/// The downloads isolate (Phase 8 decision 2): every download's bytes go
/// from the socket to the disk here, away from the UI's event loop (hard
/// rule 2). One attempt per start command; a provider that answers with
/// a playlist is handed to FFmpeg through a loopback proxy (decision 4).
Future<void> downloadIsolateMain(DownloadIsolateSetup setup) async {
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
  final asked = <int, Completer<DownloadUpstream?>>{};
  final orders = <int, DownloadOrder>{};
  final running = <int, _Attempt>{};
  final hls = <String, HlsDownload>{};
  var nextAsk = 0;
  RelayProxy? proxy;

  Future<DownloadUpstream?> upstreamOf(int id) {
    final requestId = nextAsk++;
    final answer = Completer<DownloadUpstream?>();
    asked[requestId] = answer;
    app.send(DownloadResolveRequest(requestId, id));
    return answer.future
        .timeout(const Duration(seconds: 30), onTimeout: () => null)
        .whenComplete(() => asked.removeWhere((k, _) => k == requestId));
  }

  Future<RelayProxy> proxyNow() async => proxy ??= await RelayProxy.start(
    log: log,
    resolve: (inputId) async {
      final id = int.tryParse(inputId.replaceFirst('download-', ''));
      final order = id == null ? null : orders[id];
      final upstream = id == null ? null : await upstreamOf(id);
      if (order == null || upstream == null) {
        return const RelayResolved(failure: 'no URL for the download');
      }
      return RelayResolved(
        upstream: RelayUpstream(
          url: upstream.url,
          userAgent: upstream.userAgent,
          hls: true,
          maxConnections: order.maxConnections,
        ),
      );
    },
    onEvent: (event) {
      for (final download in hls.values) {
        download.onProxy(event);
      }
    },
  );

  Future<void> run(DownloadOrder order) async {
    final attempt = _Attempt();
    running[order.id] = attempt;
    orders[order.id] = order;
    try {
      final http = HttpDownload(
        order,
        () => upstreamOf(order.id),
        app.send,
        timings: setup.timings,
      );
      attempt.current = http.stop;
      final outcome = await http.run();
      if (outcome == HttpDownloadOutcome.ended) return;
      if (attempt.stopping) {
        app.send(DownloadHalted(order.id, bytes: 0));
        return;
      }
      final ffmpeg = setup.ffmpeg;
      if (ffmpeg == null) {
        app.send(
          DownloadFailedNews(
            order.id,
            DownloadEnd.server,
            bytes: 0,
            detail:
                'The provider sends this as a playlist, and this build '
                'has no FFmpeg to save it with.',
          ),
        );
        return;
      }
      final saving = HlsDownload(
        order,
        app.send,
        proxy: await proxyNow(),
        supervisor: supervisor,
        ffmpeg: ffmpeg,
        log: log,
      );
      hls[saving.inputId] = saving;
      attempt.current = saving.stop;
      if (attempt.stopping) {
        app.send(DownloadHalted(order.id, bytes: 0));
        return;
      }
      await saving.run();
      hls.remove(saving.inputId);
    } on Object catch (error) {
      app.send(
        DownloadFailedNews(
          order.id,
          DownloadEnd.network,
          bytes: 0,
          detail: redact('$error'),
        ),
      );
    } finally {
      running.remove(order.id);
      orders.remove(order.id);
      attempt.ended.complete();
    }
  }

  app.send(DownloadIsolateReady(commands.sendPort));
  await for (final message in commands) {
    switch (message) {
      case DownloadStartCommand(:final order):
        unawaited(run(order));
      case DownloadStopCommand(:final replyId, :final id):
        final attempt = running[id];
        unawaited(
          (attempt == null ? Future<void>.value() : attempt.stop()).then(
            (_) => app.send(DownloadReply(replyId)),
          ),
        );
      case DownloadResolveAnswer(:final requestId, :final upstream):
        final answer = asked[requestId];
        if (answer != null && !answer.isCompleted) answer.complete(upstream);
      case DownloadShutdownCommand(:final replyId):
        await Future.wait([
          for (final a in [...running.values]) a.stop(),
        ]);
        await proxy?.shutdown();
        await supervisor.stopAll();
        app.send(DownloadReply(replyId));
        commands.close();
    }
  }
}

/// One start: what stops it now, and when it has ended.
final class _Attempt {
  Future<void> Function()? current;
  bool stopping = false;
  final ended = Completer<void>();

  Future<void> stop() async {
    stopping = true;
    await current?.call();
    await ended.future;
  }
}

final class _ToApp extends LogOutput {
  new(this._app);

  final SendPort _app;

  @override
  void output(OutputEvent event) =>
      _app.send(DownloadLogLines(event.level, event.lines));
}
