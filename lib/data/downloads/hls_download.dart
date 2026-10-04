import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:iptv_player/core/downloads/download_runner.dart';
import 'package:iptv_player/core/logging/app_log.dart';
import 'package:iptv_player/core/logging/redact.dart';
import 'package:iptv_player/data/cast/relay/relay_proxy.dart';
import 'package:iptv_player/data/process/process_supervisor.dart';

const _tag = 'download';

/// A provider's playlist saved as one file (Phase 8 decision 4): FFmpeg
/// copies its streams into Matroska, reading through the relay's
/// loopback proxy — no credentials in its arguments, the URL built
/// afresh for every request, each segment's connection counted. No
/// resume: a failure starts over (docs/09). Runs in the downloads
/// isolate: plain Dart.
final class HlsDownload {
  new(
    this.order,
    this._emit, {
    required this._proxy,
    required this._supervisor,
    required this.ffmpeg,
    required this._log,
    this.quietFor = const Duration(seconds: 60),
  });

  final DownloadOrder order;
  final void Function(DownloadNews news) _emit;
  final RelayProxy _proxy;
  final ProcessSupervisor _supervisor;
  final String ffmpeg;
  final AppLog _log;

  /// FFmpeg writing nothing for this long is taken for stuck.
  final Duration quietFor;

  /// The proxy's input for this download: its refusals are told by it.
  String get inputId => 'download-${order.id}';

  RelayRefusal? _refusal;
  SupervisedProcess? _process;
  bool _stopping = false;
  final _finished = Completer<void>();

  /// What the proxy said of this input (its refusals).
  void onProxy(RelayProxyEvent event) {
    if (event case RelayProxyRefused(:final inputId, :final refusal)
        when inputId == this.inputId) {
      _refusal = refusal;
    }
  }

  Future<void> stop() async {
    _stopping = true;
    await _process?.stop();
    await _finished.future;
  }

  Future<void> run() async {
    try {
      await _run();
    } on Object catch (error) {
      _emit(
        DownloadFailedNews(
          order.id,
          DownloadEnd.network,
          bytes: _bytes(),
          detail: redact('$error'),
        ),
      );
    } finally {
      _proxy.close(inputId);
      if (!_finished.isCompleted) _finished.complete();
    }
  }

  int _bytes() {
    try {
      return File(order.partPath).lengthSync();
    } on FileSystemException {
      return 0;
    }
  }

  Future<void> _run() async {
    final part = File(order.partPath);
    try {
      await part.parent.create(recursive: true);
      // No resume: whatever an earlier attempt left goes.
      if (part.existsSync()) await part.delete();
    } on FileSystemException catch (error) {
      _emit(
        DownloadFailedNews(
          order.id,
          DownloadEnd.diskWrite,
          bytes: 0,
          detail: redact(error.message),
        ),
      );
      return;
    }
    if (_stopping) {
      _emit(DownloadHalted(order.id, bytes: 0));
      return;
    }
    final input = _proxy.open(inputId, sourceId: order.sourceId, live: false);
    final SupervisedProcess process;
    try {
      process = await _supervisor.start(ffmpeg, [
        ...['-hide_banner', '-nostdin', '-loglevel', 'error', '-nostats'],
        ...['-progress', 'pipe:1'],
        ...['-i', input],
        ...['-map', '0:v?', '-map', '0:a?', '-c', 'copy'],
        ...['-f', 'matroska', '-y', order.partPath],
      ], owner: 'download');
    } on Object catch (error) {
      _emit(
        DownloadFailedNews(
          order.id,
          DownloadEnd.diskWrite,
          bytes: 0,
          detail: redact('FFmpeg could not start: $error'),
        ),
      );
      return;
    }
    _process = process;
    _emit(DownloadOpened(order.id, bytes: 0, hls: true));

    var bytes = 0;
    var lastMove = DateTime.now();
    final errors = StringBuffer();
    final reading = process.stdout
        .transform(utf8.decoder)
        .transform(const LineSplitter())
        .listen((line) {
          final size = line.startsWith('total_size=')
              ? int.tryParse(line.substring('total_size='.length))
              : null;
          if (size != null && size > bytes) {
            bytes = size;
            lastMove = DateTime.now();
            _emit(DownloadMoved(order.id, bytes: bytes, durable: bytes));
          }
        });
    final errorsRead = process.stderr.transform(utf8.decoder).listen((text) {
      if (errors.length < 4096) errors.write(text);
    });
    final watchdog = Timer.periodic(const Duration(seconds: 1), (_) {
      if (DateTime.now().difference(lastMove) > quietFor) {
        _log.warning(_tag, '${order.id}: FFmpeg wrote nothing for $quietFor');
        unawaited(process.kill());
      }
    });
    final code = await process.exitCode;
    watchdog.cancel();
    await Future.wait([
      reading.asFuture<void>().catchError((Object _) {}),
      errorsRead.asFuture<void>().catchError((Object _) {}),
    ]).timeout(const Duration(seconds: 2), onTimeout: () => const []);
    await reading.cancel();
    await errorsRead.cancel();
    final written = _bytes();
    if (_stopping) {
      _emit(DownloadHalted(order.id, bytes: written));
      return;
    }
    if (code == 0) {
      _emit(DownloadDone(order.id, bytes: written));
      return;
    }
    final refusal = _refusal;
    final detail = redact(
      [
        if (refusal != null) '$refusal',
        errors.toString().trim(),
      ].where((s) => s.isNotEmpty).join(' · '),
    );
    _emit(
      DownloadFailedNews(
        order.id,
        _endOf(refusal),
        bytes: written,
        status: refusal?.status,
        detail: detail.isEmpty ? 'FFmpeg ended with $code' : detail,
      ),
    );
  }

  static DownloadEnd _endOf(RelayRefusal? refusal) => switch (refusal) {
    null => DownloadEnd.network,
    RelayRefusal(kind: RelayRefusalKind.unresolved) => DownloadEnd.unresolved,
    RelayRefusal(kind: RelayRefusalKind.unreachable) => DownloadEnd.network,
    RelayRefusal(kind: RelayRefusalKind.connectionsInUse) =>
      DownloadEnd.connectionLimit,
    RelayRefusal(:final status) => switch (status) {
      401 => DownloadEnd.auth,
      403 when _aboutConnections(refusal.body) => DownloadEnd.connectionLimit,
      403 => DownloadEnd.auth,
      404 || 410 => DownloadEnd.notFound,
      429 => DownloadEnd.connectionLimit,
      _ => DownloadEnd.server,
    },
  };

  static bool _aboutConnections(String body) => RegExp(
    r'max[\s_]*connection|connections?[\s_]*(limit|reached|in use)|too many',
    caseSensitive: false,
  ).hasMatch(body);
}
