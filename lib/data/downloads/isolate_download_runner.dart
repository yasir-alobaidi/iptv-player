import 'dart:async';
import 'dart:io';
import 'dart:isolate';

import 'package:iptv_player/core/downloads/download_runner.dart';
import 'package:iptv_player/core/logging/app_log.dart';
import 'package:iptv_player/core/logging/redact.dart';
import 'package:iptv_player/data/downloads/download_isolate.dart';
import 'package:iptv_player/data/downloads/http_download.dart';

const _tag = 'downloads';

/// [DownloadRunner] in its own long-lived isolate (Phase 8 decision 2):
/// started with the first download, kept until the app quits. The app's
/// side answers the isolate's requests for a download's URL, built
/// afresh each time from the source, and writes its log into the app's.
final class IsolateDownloadRunner implements DownloadRunner {
  new({
    required this._processFolder,
    required this._log,
    this.ffmpeg,
    this.timings = const DownloadTimings(),
  });

  final Directory _processFolder;
  final AppLog _log;

  /// The bundled FFmpeg (a playlist's saver); null when there is none.
  final String? ffmpeg;
  final DownloadTimings timings;

  final _news = StreamController<DownloadNews>.broadcast();
  final _upstreams = <int, Future<DownloadUpstream?> Function()>{};
  final _replies = <int, Completer<void>>{};
  final _ports = <ReceivePort>[];
  Future<SendPort>? _commands;
  Isolate? _isolate;
  var _replyIds = 0;
  var _closed = false;

  @override
  Stream<DownloadNews> get news => _news.stream;

  @override
  Future<void> start(
    DownloadOrder order, {
    required Future<DownloadUpstream?> Function() upstream,
  }) async {
    // The app is quitting: nothing starts, and nothing is said.
    if (_closed) return;
    _upstreams[order.id] = upstream;
    try {
      (await _spawn()).send(DownloadStartCommand(order));
    } on Object catch (error) {
      _upstreams.remove(order.id);
      _news.add(
        DownloadFailedNews(
          order.id,
          DownloadEnd.network,
          bytes: 0,
          detail: redact('the downloads could not start: $error'),
        ),
      );
    }
  }

  @override
  Future<void> stop(int id) async {
    if (_commands == null || !_upstreams.containsKey(id)) return;
    await _call(
      (reply) => DownloadStopCommand(reply, id),
      timeout: const Duration(seconds: 15),
    );
  }

  @override
  Future<void> close() async {
    if (_closed) return;
    _closed = true;
    if (_commands != null) {
      await _call(
        DownloadShutdownCommand.new,
        timeout: const Duration(seconds: 10),
      );
    }
    _isolate?.kill(priority: Isolate.immediate);
    for (final port in _ports) {
      port.close();
    }
    await _news.close();
  }

  Future<void> _call(
    Object Function(int replyId) command, {
    required Duration timeout,
  }) async {
    final SendPort port;
    try {
      port = await _spawn();
    } on Object {
      return;
    }
    final id = _replyIds++;
    final reply = Completer<void>();
    _replies[id] = reply;
    port.send(command(id));
    try {
      await reply.future.timeout(timeout);
    } on TimeoutException {
      _log.warning(_tag, 'The downloads did not answer in $timeout');
    } finally {
      _replies.removeWhere((k, _) => k == id);
    }
  }

  Future<SendPort> _spawn() {
    final running = _commands;
    if (running != null) return running;
    final starting = _startIsolate();
    _commands = starting;
    unawaited(
      starting.then<void>(
        (_) {},
        onError: (Object error) {
          _log.error(_tag, 'The downloads could not start', error: error);
          if (identical(_commands, starting)) _commands = null;
          _isolate?.kill(priority: Isolate.immediate);
          _isolate = null;
        },
      ),
    );
    return starting;
  }

  Future<SendPort> _startIsolate() async {
    final messages = ReceivePort('downloads');
    final errors = ReceivePort('downloads errors');
    final exits = ReceivePort('downloads exit');
    _ports.addAll([messages, errors, exits]);
    final ready = Completer<SendPort>();
    messages.listen((message) {
      if (message case DownloadIsolateReady(:final commands)) {
        if (!ready.isCompleted) ready.complete(commands);
        return;
      }
      _onMessage(message);
    });
    errors.listen((error) {
      final pair = error is List && error.length == 2;
      _log.error(
        _tag,
        'The downloads hit an error',
        error: redact('${pair ? error[0] : error}'),
        stackTrace: pair && error[1] != null
            ? StackTrace.fromString('${error[1]}')
            : null,
      );
    });
    exits.listen((_) => _lost());
    _isolate = await Isolate.spawn(
      downloadIsolateMain,
      DownloadIsolateSetup(
        app: messages.sendPort,
        processFolder: _processFolder.path,
        ffmpeg: ffmpeg,
        timings: timings,
      ),
      debugName: 'downloads',
      errorsAreFatal: false,
      onError: errors.sendPort,
      onExit: exits.sendPort,
    );
    return await ready.future.timeout(const Duration(seconds: 10));
  }

  /// The isolate ended without being asked to: every download with it.
  void _lost() {
    if (_closed) return;
    _log.error(_tag, 'The downloads stopped unexpectedly');
    _commands = null;
    _isolate = null;
    for (final reply in _replies.values) {
      if (!reply.isCompleted) reply.complete();
    }
    for (final id in [..._upstreams.keys]) {
      _upstreams.remove(id);
      _news.add(
        DownloadFailedNews(
          id,
          DownloadEnd.network,
          bytes: 0,
          detail: 'the downloads stopped',
        ),
      );
    }
  }

  void _onMessage(Object? message) {
    switch (message) {
      case DownloadReply(:final replyId):
        final reply = _replies[replyId];
        if (reply != null && !reply.isCompleted) reply.complete();
      case DownloadResolveRequest(:final requestId, :final id):
        unawaited(_resolve(requestId, id));
      case DownloadLogLines(:final level, :final lines):
        _log.forward(level, lines);
      case DownloadNews():
        if (message is DownloadDone ||
            message is DownloadHalted ||
            message is DownloadFailedNews) {
          _upstreams.remove(message.id);
        }
        if (!_news.isClosed) _news.add(message);
    }
  }

  Future<void> _resolve(int requestId, int id) async {
    DownloadUpstream? upstream;
    try {
      upstream = await _upstreams[id]?.call();
    } on Object catch (error) {
      _log.warning(_tag, 'No URL for download $id: ${redact('$error')}');
    }
    final commands = await _commands;
    commands?.send(DownloadResolveAnswer(requestId, upstream));
  }
}
