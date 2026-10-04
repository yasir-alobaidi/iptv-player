import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:iptv_player/core/downloads/download_runner.dart';
import 'package:iptv_player/core/logging/redact.dart';

/// The download's URL, asked for on every connection; null when the app
/// has none (the title or its source is gone).
typedef UpstreamFor = Future<DownloadUpstream?> Function();

/// How long a download waits, and how often it writes and reports.
final class DownloadTimings {
  const new({
    this.connect = const Duration(seconds: 15),
    this.answer = const Duration(seconds: 30),
    this.idle = const Duration(seconds: 30),
    this.report = const Duration(milliseconds: 250),
    this.flushEvery = 8 << 20,
  });

  final Duration connect;

  /// From the request to the answer's headers.
  final Duration answer;

  /// With no bytes coming: the connection is taken for broken.
  final Duration idle;

  /// How often progress is reported.
  final Duration report;

  /// docs/09: flush every 8 MB (and on pause).
  final int flushEvery;
}

/// How an attempt went: the file is whole, the attempt ended (said in
/// its news), or the provider answered with a playlist, which FFmpeg
/// saves instead (Phase 8 decision 4).
enum HttpDownloadOutcome { ended, playlist }

/// One attempt at a download over HTTP (docs/09 "Resume", "Writing"):
/// the `.part` file's size on disk is where it starts; `Range` +
/// `If-Range` ask for the rest; a 200 empties the `.part` and starts
/// over; a 416 is the end when the size matches. Chunks go straight to
/// disk, flushed every 8 MB. Runs in the downloads isolate: plain Dart.
final class HttpDownload {
  new(
    this.order,
    this._upstream,
    this._emit, {
    this.timings = const DownloadTimings(),
  });

  final DownloadOrder order;
  final UpstreamFor _upstream;
  final void Function(DownloadNews news) _emit;
  final DownloadTimings timings;

  HttpClient? _client;
  bool _stopping = false;
  Completer<void>? _pace;
  final _finished = Completer<HttpDownloadOutcome>();

  /// Asks it to stop: it flushes, closes the file and says
  /// [DownloadHalted]. Completes when it has.
  Future<void> stop() async {
    _stopping = true;
    _client?.close(force: true);
    final pace = _pace;
    if (pace != null && !pace.isCompleted) pace.complete();
    await _finished.future;
  }

  Future<HttpDownloadOutcome> run() async {
    try {
      final outcome = await _attempts();
      if (!_finished.isCompleted) _finished.complete(outcome);
      return outcome;
    } on Object catch (error) {
      // Nothing may escape the isolate's loop.
      _emit(
        DownloadFailedNews(
          order.id,
          DownloadEnd.network,
          bytes: _size,
          detail: redact('$error'),
        ),
      );
      if (!_finished.isCompleted) _finished.complete(HttpDownloadOutcome.ended);
      return HttpDownloadOutcome.ended;
    }
  }

  int _size = 0;

  Future<HttpDownloadOutcome> _attempts() async {
    final part = File(order.partPath);
    try {
      await part.parent.create(recursive: true);
      _size = part.existsSync() ? await part.length() : 0;
    } on FileSystemException catch (error) {
      return _fail(DownloadEnd.diskWrite, detail: error.message);
    }
    final upstream = await _upstream();
    if (_stopping) return _halt();
    if (upstream == null) return _fail(DownloadEnd.unresolved);
    if (upstream.hls) return HttpDownloadOutcome.playlist;

    // A resume the server can't place starts over, at most twice.
    var startsOver = 0;
    var useRange = true;
    var total = order.total;
    while (true) {
      if (_stopping) return _halt();
      final client = HttpClient()
        ..connectionTimeout = timings.connect
        ..autoUncompress = false;
      _client = client;
      try {
        final request = await client
            .getUrl(Uri.parse(upstream.url))
            .timeout(timings.answer);
        request.headers.removeAll(HttpHeaders.acceptEncodingHeader);
        if (upstream.userAgent case final agent?) {
          request.headers.set(HttpHeaders.userAgentHeader, agent);
        }
        final resuming = useRange && _size > 0;
        if (resuming) {
          request.headers.set(HttpHeaders.rangeHeader, 'bytes=$_size-');
          if (order.etag ?? order.lastModified case final validator?) {
            request.headers.set(HttpHeaders.ifRangeHeader, validator);
          }
        }
        final response = await request.close().timeout(timings.answer);
        final status = response.statusCode;

        if (status == HttpStatus.requestedRangeNotSatisfiable) {
          await _drain(response);
          final said = _rangeTotal(response.headers.value('content-range'));
          final whole = said ?? total;
          if (whole != null && _size == whole) {
            _emit(DownloadDone(order.id, bytes: _size, total: whole));
            return HttpDownloadOutcome.ended;
          }
          if (++startsOver > 2) {
            return _fail(DownloadEnd.server, status: status);
          }
          await _truncate(part);
          useRange = false;
          continue;
        }
        if (status != HttpStatus.ok && status != HttpStatus.partialContent) {
          return await _refused(response);
        }

        final restarted = status == HttpStatus.ok && _size > 0;
        if (status == HttpStatus.partialContent) {
          final range = _contentRange(response.headers.value('content-range'));
          if (range == null || range.start != _size) {
            await _drain(response);
            if (++startsOver > 2) {
              return _fail(DownloadEnd.server, status: status);
            }
            await _truncate(part);
            useRange = false;
            continue;
          }
          total = range.total ?? total;
        } else {
          total = response.contentLength >= 0 ? response.contentLength : null;
        }
        if (restarted) await _truncate(part);
        if (status == HttpStatus.ok && _isPlaylistType(response.headers)) {
          await _drain(response);
          return HttpDownloadOutcome.playlist;
        }
        return await _write(part, response, total: total, restarted: restarted);
      } on FileSystemException catch (error) {
        return _fail(DownloadEnd.diskWrite, detail: error.message);
      } on Object catch (error) {
        if (_stopping) return _halt();
        return _fail(DownloadEnd.network, detail: '$error');
      } finally {
        client.close(force: true);
        if (identical(_client, client)) _client = null;
      }
    }
  }

  /// The body into the `.part`.
  Future<HttpDownloadOutcome> _write(
    File part,
    HttpClientResponse response, {
    required int? total,
    required bool restarted,
  }) async {
    final expected = response.contentLength;
    final file = await part.open(mode: FileMode.append);
    var received = 0;
    var durable = _size;
    var first = true;
    var playlist = false;
    var opened = false;
    void open() {
      if (opened) return;
      opened = true;
      _emit(
        DownloadOpened(
          order.id,
          bytes: _size,
          total: total,
          etag: response.headers.value(HttpHeaders.etagHeader),
          lastModified: response.headers.value(HttpHeaders.lastModifiedHeader),
          restarted: restarted,
        ),
      );
    }

    final reported = Stopwatch()..start();
    final paced = Stopwatch()..start();
    Object? broke;
    try {
      try {
        await for (final chunk in response.timeout(timings.idle)) {
          if (first) {
            first = false;
            // A playlist under another content type (docs/09: a body
            // starting with #EXTM3U).
            if (_size == 0 && _startsPlaylist(chunk)) {
              playlist = true;
              break;
            }
            open();
          }
          await file.writeFrom(chunk);
          _size += chunk.length;
          received += chunk.length;
          if (_size - durable >= timings.flushEvery) {
            await file.flush();
            durable = _size;
          }
          if (reported.elapsed >= timings.report) {
            reported.reset();
            _emit(DownloadMoved(order.id, bytes: _size, durable: durable));
          }
          if (order.bytesPerSecond case final limit?) {
            final due = Duration(microseconds: received * 1000000 ~/ limit);
            final wait = due - paced.elapsed;
            if (wait > Duration.zero) await _sleep(wait);
          }
          if (_stopping) break;
        }
      } on FileSystemException {
        rethrow;
      } on Object catch (error) {
        broke = error;
      }
      await file.flush();
    } finally {
      await file.close();
    }
    if (playlist) return HttpDownloadOutcome.playlist;
    open();
    if (_stopping) return _halt();
    if (broke != null) {
      return _fail(DownloadEnd.network, detail: '$broke');
    }
    if (expected >= 0 && received < expected) {
      return _fail(
        DownloadEnd.network,
        detail: 'the body ended at $received of $expected bytes',
      );
    }
    _emit(DownloadDone(order.id, bytes: _size, total: total));
    return HttpDownloadOutcome.ended;
  }

  Future<HttpDownloadOutcome> _refused(HttpClientResponse response) async {
    final status = response.statusCode;
    final body = await _head(response);
    final end = switch (status) {
      HttpStatus.unauthorized => DownloadEnd.auth,
      HttpStatus.forbidden when _aboutConnections(body) =>
        DownloadEnd.connectionLimit,
      HttpStatus.forbidden => DownloadEnd.auth,
      HttpStatus.notFound || HttpStatus.gone => DownloadEnd.notFound,
      HttpStatus.tooManyRequests => DownloadEnd.connectionLimit,
      _ => DownloadEnd.server,
    };
    return _fail(end, status: status, detail: body.isEmpty ? null : body);
  }

  HttpDownloadOutcome _fail(DownloadEnd end, {int? status, String? detail}) {
    _emit(
      DownloadFailedNews(
        order.id,
        end,
        bytes: _size,
        status: status,
        detail: detail == null ? null : redact(detail),
      ),
    );
    return HttpDownloadOutcome.ended;
  }

  HttpDownloadOutcome _halt() {
    _emit(DownloadHalted(order.id, bytes: _size));
    return HttpDownloadOutcome.ended;
  }

  Future<void> _truncate(File part) async {
    final file = await part.open(mode: FileMode.write);
    await file.close();
    _size = 0;
  }

  /// A wait the speed limit asks for, cut short by [stop].
  Future<void> _sleep(Duration wait) async {
    final pace = Completer<void>();
    _pace = pace;
    final timer = Timer(wait, () {
      if (!pace.isCompleted) pace.complete();
    });
    await pace.future;
    timer.cancel();
  }

  static Future<void> _drain(HttpClientResponse response) async {
    try {
      await response.drain<void>().timeout(const Duration(seconds: 2));
    } on Object {
      // Only the status mattered.
    }
  }

  /// The first KB of a refusal's body, as text.
  static Future<String> _head(HttpClientResponse response) async {
    final bytes = <int>[];
    try {
      await for (final chunk in response.timeout(const Duration(seconds: 3))) {
        bytes.addAll(chunk);
        if (bytes.length >= 1024) break;
      }
    } on Object {
      // What came is enough.
    }
    final text = utf8.decode(
      bytes.length > 1024 ? bytes.sublist(0, 1024) : bytes,
      allowMalformed: true,
    );
    return text.trim();
  }

  /// A panel's way of saying its connections are in use (docs/03's
  /// connection-limit class).
  static bool _aboutConnections(String body) => RegExp(
    r'max[\s_]*connection|connections?[\s_]*(limit|reached|in use)|too many',
    caseSensitive: false,
  ).hasMatch(body);

  static bool _isPlaylistType(HttpHeaders headers) {
    final type = headers.contentType?.mimeType.toLowerCase() ?? '';
    return type.contains('mpegurl');
  }

  static bool _startsPlaylist(List<int> chunk) {
    const marker = '#EXTM3U';
    var start = 0;
    // A byte-order mark or white space before it.
    if (chunk.length >= 3 &&
        chunk[0] == 0xef &&
        chunk[1] == 0xbb &&
        chunk[2] == 0xbf) {
      start = 3;
    }
    while (start < chunk.length &&
        (chunk[start] == 0x20 || chunk[start] < 14)) {
      start++;
    }
    if (chunk.length - start < marker.length) return false;
    return ascii.decode(
          chunk.sublist(start, start + marker.length),
          allowInvalid: true,
        ) ==
        marker;
  }

  /// `bytes 100-199/1000` → (100, 1000); the total is null for `*`.
  static ({int start, int? total})? _contentRange(String? header) {
    final match = RegExp(r'^\s*bytes\s+(\d+)-\d+/(\d+|\*)\s*$')
        .firstMatch(header ?? '');
    if (match == null) return null;
    return (start: int.parse(match[1]!), total: int.tryParse(match[2]!));
  }

  /// `bytes */1000` (a 416's) → 1000.
  static int? _rangeTotal(String? header) {
    final match = RegExp(r'/(\d+)\s*$').firstMatch(header ?? '');
    return match == null ? null : int.parse(match[1]!);
  }
}
