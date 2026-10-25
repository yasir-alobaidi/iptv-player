import 'dart:async';
import 'dart:collection';
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
    this.flushEvery = 64 << 20,
    this.paceWindow = const Duration(seconds: 4),
    this.paceSettle = const Duration(seconds: 6),
    this.freshPause = const Duration(seconds: 1),
  });

  final Duration connect;

  /// From the request to the answer's headers.
  final Duration answer;

  /// With no bytes coming: the connection is taken for broken.
  final Duration idle;

  /// How often progress is reported.
  final Duration report;

  /// How often the file is forced to the disk (`fsync`), and on pause.
  /// docs/09 says 8 MB; at 8 MB the syncs halved the speed on this
  /// laptop's SSD, and a crash of the app loses nothing written anyway
  /// (only a power cut does), so 64 MB (ADR-015 step 3).
  final int flushEvery;

  /// [ConnectionPace]'s window and the age a connection has before it is
  /// judged slowed.
  final Duration paceWindow;
  final Duration paceSettle;

  /// Between a slowed connection's close and the fresh one: a panel that
  /// allows one connection counts the old one until it has gone.
  final Duration freshPause;
}

/// Whether the provider has slowed a connection it started fast (ADR-054).
/// The user's panel sends each new connection at ~3 MB/s for its first
/// seconds, then holds it to about twice the video's bitrate: 0.28 MB/s,
/// flat, at a 10 ms round trip with the window wide open. A fresh
/// connection from the same byte is fast again. Fed the connection's
/// bytes as they come; [slowed] once the last [window] went at under a
/// quarter of the best one, on a connection [settle] old. Exposed for
/// tests.
final class ConnectionPace {
  new({required this.window, required this.settle});

  final Duration window;
  final Duration settle;
  final _samples = Queue<(Duration, int)>();

  /// Bytes a second over the best and the last whole window.
  double best = 0;
  double recent = 0;

  /// [bytes] had come on the connection [at] after it opened.
  void add(Duration at, int bytes) {
    if (_samples.isNotEmpty && at - _samples.last.$1 < window ~/ 10) return;
    _samples.addLast((at, bytes));
    while (_samples.length > 2 && at - _samples.elementAt(1).$1 >= window) {
      _samples.removeFirst();
    }
    final (from, fromBytes) = _samples.first;
    final span = at - from;
    if (span < window * 3 ~/ 4) return;
    recent = (bytes - fromBytes) * 1e6 / span.inMicroseconds;
    if (recent > best) best = recent;
  }

  bool slowed(Duration at) => at >= settle && best > 0 && recent < best / 4;
}

/// How an attempt went: the file is whole, the attempt ended (said in
/// its news), or the provider answered with a playlist, which FFmpeg
/// saves instead (Phase 8 decision 4).
enum HttpDownloadOutcome { ended, playlist }

/// One attempt at a download over HTTP (docs/09 "Resume", "Writing"):
/// the `.part` file's size on disk is where it starts; `Range` +
/// `If-Range` ask for the rest; a 200 empties the `.part` and starts
/// over; a 416 is the end when the size matches. Chunks go straight to
/// disk, flushed every 8 MB. A connection the provider slows down after
/// its first seconds ends, and a fresh one carries on from the same byte
/// ([ConnectionPace]). Runs in the downloads isolate: plain Dart.
final class HttpDownload {
  new(
    this.order,
    this._upstream,
    this._emit, {
    this.timings = const DownloadTimings(),
    void Function(String line)? note,
  }) : _note = note ?? _quiet;

  final DownloadOrder order;
  final UpstreamFor _upstream;
  final void Function(DownloadNews news) _emit;
  final DownloadTimings timings;

  /// A line for the app's log.
  final void Function(String line) _note;
  static void _quiet(String _) {}

  /// Fresh connections so far, and those in a row that came no faster:
  /// at two, this download stops opening them (a panel slow from the
  /// first byte, or one that keeps a connection's pace across them).
  int _fresh = 0;
  int _freshInVain = 0;

  /// The pace that made the last fresh connection, to tell whether it
  /// helped.
  double? _slowedAt;

  bool get _freshAllowed =>
      order.bytesPerSecond == null && _freshInVain < _freshTries;
  static const _freshTries = 2;

  /// A fresh connection the provider refuses (its old one not yet gone)
  /// is asked again this many times before the refusal stands.
  static const _freshRefusals = 3;

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
    // Asked again after a refusal or a failure of a fresh connection.
    var refusedFresh = 0;
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
          if (_slowedAt != null && refusedFresh < _freshRefusals) {
            await _drain(response);
            await _sleep(timings.freshPause * (1 << refusedFresh++));
            continue;
          }
          return await _refused(response);
        }
        refusedFresh = 0;

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
        if (restarted) {
          await _truncate(part);
          // A panel that answered a fresh connection's range with the
          // whole file would take every one back to the start.
          if (_slowedAt != null) _freshInVain = _freshTries;
        }
        if (status == HttpStatus.ok && _isPlaylistType(response.headers)) {
          await _drain(response);
          return HttpDownloadOutcome.playlist;
        }
        final ranged =
            status == HttpStatus.partialContent ||
            response.headers.value(HttpHeaders.acceptRangesHeader) == 'bytes';
        final wrote = await _write(
          part,
          response,
          total: total,
          restarted: restarted,
          fresh: ranged && _freshAllowed,
        );
        if (wrote != null) return wrote;
        // Slowed: the same file from the same byte, on a fresh connection,
        // once the old one has gone.
        client.close(force: true);
        await _sleep(timings.freshPause);
        continue;
      } on FileSystemException catch (error) {
        return _fail(DownloadEnd.diskWrite, detail: error.message);
      } on Object catch (error) {
        if (_stopping) return _halt();
        if (_slowedAt != null && refusedFresh < _freshRefusals) {
          await _sleep(timings.freshPause * (1 << refusedFresh++));
          continue;
        }
        return _fail(DownloadEnd.network, detail: '$error');
      } finally {
        client.close(force: true);
        if (identical(_client, client)) _client = null;
      }
    }
  }

  /// The body into the `.part`: how the attempt ended, or null when the
  /// provider slowed this connection and a fresh one should go on.
  Future<HttpDownloadOutcome?> _write(
    File part,
    HttpClientResponse response, {
    required int? total,
    required bool restarted,
    required bool fresh,
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
    // From the answer's headers: a burst that comes in one read still
    // counts as fast.
    final pace = ConnectionPace(
      window: timings.paceWindow,
      settle: timings.paceSettle,
    )..add(Duration.zero, 0);
    var slowed = false;
    // No bytes for [DownloadTimings.idle]: the connection is broken. A
    // check now and then, not a timeout wrapped round every chunk: that
    // cost a fifth of the speed at a gigabyte a second.
    final quiet = Stopwatch()..start();
    var wentQuiet = false;
    final checkEvery = timings.idle ~/ 4 < const Duration(seconds: 1)
        ? timings.idle ~/ 4
        : const Duration(seconds: 1);
    final watchdog = Timer.periodic(checkEvery, (_) {
      if (quiet.elapsed >= timings.idle && !wentQuiet) {
        wentQuiet = true;
        _client?.close(force: true);
      }
    });
    Object? broke;
    try {
      try {
        await for (final chunk in response) {
          quiet.reset();
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
            quiet.reset();
          }
          if (_stopping) break;
          if (fresh) {
            final at = paced.elapsed;
            pace.add(at, received);
            if (pace.slowed(at) && _worthFresh(pace, total)) {
              slowed = true;
              break;
            }
          }
        }
      } on FileSystemException {
        rethrow;
      } on Object catch (error) {
        broke = error;
      }
      await file.flush();
    } finally {
      watchdog.cancel();
      await file.close();
    }
    if (wentQuiet && !_stopping) {
      broke = 'no bytes came for ${timings.idle.inSeconds} s';
    }
    if (playlist) return HttpDownloadOutcome.playlist;
    open();
    if (_stopping) return _halt();
    _judgeFresh(pace);
    if (slowed && broke == null) {
      _emit(DownloadMoved(order.id, bytes: _size, durable: _size));
      _openFresh(pace);
      return null;
    }
    if (broke != null) {
      return _fail(DownloadEnd.network, detail: '$broke');
    }
    if (expected >= 0 && received < expected) {
      return _fail(
        DownloadEnd.network,
        detail: 'the body ended at $received of $expected bytes',
      );
    }
    if (_fresh > 0) {
      _note('Download ${order.id} done after $_fresh fresh connections');
    }
    _emit(DownloadDone(order.id, bytes: _size, total: total));
    return HttpDownloadOutcome.ended;
  }

  /// Worth a fresh connection: the rest at the slowed pace would take
  /// longer than a few of the pauses one costs.
  bool _worthFresh(ConnectionPace pace, int? total) {
    if (total == null) return true;
    final left = total - _size;
    final pause = timings.freshPause.inMicroseconds / 1e6;
    return pace.recent <= 0 || left / pace.recent > 5 * pause;
  }

  /// Whether the last fresh connection came faster than the pace that
  /// made it: two in a row that didn't and no more are opened.
  void _judgeFresh(ConnectionPace pace) {
    final slowedAt = _slowedAt;
    if (slowedAt == null) return;
    if (pace.best >= slowedAt * 2) {
      _freshInVain = 0;
    } else if (++_freshInVain == _freshTries) {
      _note(
        'Download ${order.id}: fresh connections come no faster '
        '(${_mbps(pace.best)} MB/s): it keeps the one it has',
      );
    }
  }

  void _openFresh(ConnectionPace pace) {
    if (_fresh++ == 0) {
      _note(
        'Download ${order.id}: the provider slowed it to '
        '${_mbps(pace.recent)} MB/s (from ${_mbps(pace.best)}): a fresh '
        'connection from byte $_size',
      );
    }
    _slowedAt = pace.recent;
  }

  static String _mbps(double bytesPerSecond) =>
      (bytesPerSecond / 1e6).toStringAsFixed(2);

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
