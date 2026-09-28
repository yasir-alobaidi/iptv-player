/// Movie and episode files: `/movie/{u}/{p}/{id}.{ext}` and
/// `/series/{u}/{p}/{id}.{ext}` serve the item's VOD sample as a panel
/// serves a file — Range (206, open ends, suffixes, 416), `ETag`,
/// `Last-Modified`, `If-Range` and `HEAD` (docs/06 "VOD files", Phase 5
/// step 1).
///
/// Like a live stream, a body is written on the hijacked connection, so a
/// client that goes away — a player seeking abandons a connection on every
/// seek — frees its slot whenever it happens (the soak's lesson, ADR-010).
/// A body counts against `max_connections` while it is open, except that a
/// new request for the same file takes over an open one, as a player's seek
/// on a one-connection panel needs: the old connection is closed.
///
/// Faults (`/admin/faults` or the query): `http_status`, `slow_start_ms`,
/// `ignore_range` (every answer is the whole file), `drop_after_bytes` (the
/// connection closes once a body passes that byte of the file, so a request
/// starting past it gets through) and `throttle_kbps`. `change_etag`,
/// `wrong_content_length`, `size_mb` and `vod_as_hls` are the downloads'
/// (Phase 8).
library;

import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math' as math;

import 'package:fake_provider/profile.dart';
import 'package:fake_provider/server_state.dart';
import 'package:fake_provider/streams.dart';
import 'package:shelf/shelf.dart';
import 'package:shelf_router/shelf_router.dart';

class VodRelay {
  new(this._state, {this.verbose = false});

  final FakeServerState _state;
  final bool verbose;

  final _open = <_VodConnection>{};
  Router? _router;

  Handler get handler => (_router ??= _buildRouter()).call;

  /// Bodies being written right now.
  int get openCount => _open.length;

  // HEAD first: shelf_router answers HEAD from a GET route by dropping the
  // body, which a hijacked connection has no way to do.
  Router _buildRouter() => Router(notFoundHandler: _unknownPath)
    ..add('HEAD', '/movie/<username>/<password>/<file>', _movie)
    ..get('/movie/<username>/<password>/<file>', _movie)
    ..add('HEAD', '/series/<username>/<password>/<file>', _episode)
    ..get('/series/<username>/<password>/<file>', _episode);

  /// Closes every open body and frees its slot.
  Future<void> close() async {
    for (final connection in _open.toList()) {
      await connection.kill();
    }
  }

  Response _unknownPath(Request request) =>
      Response.notFound('no file at /${request.url.path}\n');

  Future<Response> _movie(
    Request request,
    String username,
    String password,
    String file,
  ) => _serve(request, username, password, file, movie: true);

  Future<Response> _episode(
    Request request,
    String username,
    String password,
    String file,
  ) => _serve(request, username, password, file, movie: false);

  Future<Response> _serve(
    Request request,
    String username,
    String password,
    String file, {
    required bool movie,
  }) async {
    final what = movie ? 'movie' : 'episode';
    if (!_state.authenticates(username, password)) {
      return Response.unauthorized('BAD_CREDENTIALS\n');
    }
    final faults = _state.faults.overriddenBy(request.url.queryParameters);
    if (faults.httpStatus case final status?) {
      return faultResponse(status, what: what);
    }
    if (faults.slowStartMs case final ms? when ms > 0) {
      await Future<void>.delayed(Duration(milliseconds: ms));
    }

    // The extension has to be the item's own, as the app builds it from
    // `container_extension`: a wrong one is a 404, not a lucky guess.
    final dot = file.lastIndexOf('.');
    final id = int.tryParse(dot < 0 ? file : file.substring(0, dot));
    final extension = dot < 0 ? '' : file.substring(dot + 1).toLowerCase();
    final item = id == null ? null : _item(id, movie: movie);
    if (item == null || item.extension != extension) {
      return Response.notFound('no $what $file\n');
    }
    final sample = File('${_state.samplesDir}/${item.sample}');
    if (!sample.existsSync()) {
      return Response.notFound(
        'missing sample ${sample.path} — is --samples right? '
        '(tools/media_samples/generate.sh builds them)\n',
      );
    }

    final stat = sample.statSync();
    final size = stat.size;
    final modified = stat.modified.toUtc();
    final etag =
        '"${size.toRadixString(16)}-'
        '${(modified.millisecondsSinceEpoch ~/ 1000).toRadixString(16)}"';
    final range = faults.ignoreRange
        ? null
        : _rangeFor(
            request.headers,
            size: size,
            etag: etag,
            modified: modified,
          );
    if (range == _unsatisfiable) {
      return Response(
        HttpStatus.requestedRangeNotSatisfiable,
        body: 'range not satisfiable\n',
        headers: {'content-range': 'bytes */$size'},
      );
    }

    final head = request.method == 'HEAD';
    final key = '$what/$id';
    final limit = faults.maxConnections ?? _state.profile.maxConnections;
    // Before the hijack's wait, like a panel at its limit; checked again
    // once the connection is ours.
    if (!head && !_wouldAdmit(key, limit)) {
      return Response.forbidden('$maxConnectionsBody\n');
    }

    final start = range?.start ?? 0;
    final end = range?.end ?? size - 1;
    final headers = [
      if (range == null) 'HTTP/1.1 200 OK' else 'HTTP/1.1 206 Partial Content',
      'content-type: ${_contentType(extension)}',
      'content-length: ${size == 0 ? 0 : end - start + 1}',
      if (!faults.ignoreRange) 'accept-ranges: bytes',
      if (range != null) 'content-range: bytes $start-$end/$size',
      'etag: $etag',
      'last-modified: ${HttpDate.format(modified)}',
      'connection: close',
    ];
    request.hijack(
      (connection) => unawaited(
        _write(
          connection.stream,
          connection.sink,
          header: utf8.encode('${headers.join('\r\n')}\r\n\r\n'),
          sample: sample,
          start: start,
          endExclusive: size == 0 ? 0 : end + 1,
          key: key,
          limit: limit,
          head: head,
          faults: faults,
        ),
      ),
    );
  }

  ({String sample, String extension})? _item(int id, {required bool movie}) {
    if (movie) {
      final found = _state.catalog.movieById(id);
      return found == null
          ? null
          : (sample: found.sample, extension: found.containerExtension);
    }
    final found = _state.catalog.episodeById(id);
    return found == null
        ? null
        : (sample: found.sample, extension: found.containerExtension);
  }

  bool _wouldAdmit(String key, int limit) =>
      _state.activeStreams < limit || _open.any((c) => c.key == key);

  /// Takes a slot, or the slot of an open body of the same file (which is
  /// closed): false when neither is free.
  bool _admit(String key, int limit) {
    if (_state.activeStreams >= limit) {
      final same = _open.where((c) => c.key == key).firstOrNull;
      if (same == null) return false;
      same.release();
      unawaited(same.kill());
      _log('a new request for $key takes over an open one');
    }
    _state.activeStreams++;
    return true;
  }

  Future<void> _write(
    Stream<List<int>> incoming,
    StreamSink<List<int>> outgoing, {
    required List<int> header,
    required File sample,
    required int start,
    required int endExclusive,
    required String key,
    required int limit,
    required bool head,
    required FakeFaults faults,
  }) async {
    unawaited(outgoing.done.then((_) {}, onError: (Object _) {}));
    final connection = _VodConnection(key, outgoing, () {
      _state.activeStreams--;
    });
    final reading = incoming.listen(
      null,
      onDone: () => unawaited(connection.stop()),
      onError: (Object _) => unawaited(connection.stop()),
      cancelOnError: true,
    );
    Future<void> hangUp() async {
      await reading.cancel();
      try {
        await outgoing.close();
      } on Object {
        // The client is already gone.
      }
    }

    if (head) {
      outgoing.add(header);
      await hangUp();
      return;
    }
    if (!_admit(key, limit)) {
      outgoing.add(
        utf8.encode(
          'HTTP/1.1 403 Forbidden\r\n'
          'content-type: text/plain; charset=utf-8\r\n'
          'content-length: ${maxConnectionsBody.length + 1}\r\n'
          'connection: close\r\n\r\n'
          '$maxConnectionsBody\n',
        ),
      );
      await hangUp();
      return;
    }
    connection.admitted();
    _open.add(connection);
    outgoing.add(header);
    try {
      await outgoing.addStream(
        connection.body(_bytes(sample, start, endExclusive, faults)),
      );
    } on Object {
      // A failed write: the client is gone.
    }
    _open.remove(connection);
    await connection.stop();
    await hangUp();
  }

  /// The file from [start] to [endExclusive], paced by `throttle_kbps` and
  /// ending early where `drop_after_bytes` says.
  Stream<List<int>> _bytes(
    File file,
    int start,
    int endExclusive,
    FakeFaults faults,
  ) async* {
    final dropAt = faults.dropAfterBytes;
    final stopAt = dropAt != null && dropAt > start && dropAt < endExclusive
        ? dropAt
        : endExclusive;
    // Kilobits per second, as the fault's name says.
    final bytesPerSecond = switch (faults.throttleKbps) {
      final kbps? when kbps > 0 => kbps * 1000 ~/ 8,
      _ => null,
    };
    if (stopAt <= start) return;
    if (bytesPerSecond == null) {
      yield* file.openRead(start, stopAt);
      return;
    }
    final clock = Stopwatch()..start();
    final piece = math.max(512, bytesPerSecond ~/ 20);
    var sent = 0;
    await for (final chunk in file.openRead(start, stopAt)) {
      for (var at = 0; at < chunk.length; at += piece) {
        final part = chunk.sublist(at, math.min(chunk.length, at + piece));
        sent += part.length;
        final due = Duration(microseconds: sent * 1000000 ~/ bytesPerSecond);
        final wait = due - clock.elapsed;
        if (wait > Duration.zero) await Future<void>.delayed(wait);
        yield part;
      }
    }
  }

  void _log(String message) {
    if (verbose) stderr.writeln('[vod] $message');
  }
}

/// One body being written, and the slot it holds.
class _VodConnection {
  new(this.key, this._sink, this._free);

  /// `movie/<id>` or `episode/<id>`.
  final String key;
  final StreamSink<List<int>> _sink;
  final void Function() _free;

  bool _holds = false;
  StreamController<List<int>>? _body;
  StreamSubscription<List<int>>? _source;

  void admitted() => _holds = true;

  /// Gives the slot back once, whoever calls it first.
  void release() {
    if (!_holds) return;
    _holds = false;
    _free();
  }

  /// [source] behind a controller, so [stop] can end the body even while
  /// the write is waiting on it.
  Stream<List<int>> body(Stream<List<int>> source) {
    final body = StreamController<List<int>>();
    final subscription = source.listen(
      body.add,
      onError: body.addError,
      onDone: () {
        if (!body.isClosed) unawaited(body.close());
      },
    );
    body
      ..onPause = subscription.pause
      ..onResume = subscription.resume
      ..onCancel = subscription.cancel;
    _body = body;
    _source = subscription;
    return body.stream;
  }

  Future<void> stop() async {
    release();
    await _source?.cancel();
    final body = _body;
    if (body != null && !body.isClosed) unawaited(body.close());
  }

  /// Closes the connection outright, as a panel drops a superseded one.
  Future<void> kill() async {
    await stop();
    final sink = _sink;
    if (sink is Socket) {
      sink.destroy();
    } else {
      try {
        await sink.close();
      } on Object {
        // Already closed.
      }
    }
  }
}

/// A Range header this server can't satisfy: the 416 case.
const ({int start, int end}) _unsatisfiable = (start: -1, end: -1);

/// The byte range to serve, `null` for the whole file. A header this server
/// doesn't take (another unit, several ranges, garbage) is ignored, as HTTP
/// allows; a range that starts past the end is [_unsatisfiable]. `If-Range`
/// with another validator than the file's means the whole file.
({int start, int end})? _rangeFor(
  Map<String, String> headers, {
  required int size,
  required String etag,
  required DateTime modified,
}) {
  final header = headers['range']?.trim();
  if (header == null || !header.startsWith('bytes=') || size == 0) {
    return null;
  }
  final spec = header.substring('bytes='.length).trim();
  if (spec.contains(',')) return null;
  final dash = spec.indexOf('-');
  if (dash < 0) return null;
  final from = spec.substring(0, dash).trim();
  final to = spec.substring(dash + 1).trim();

  ({int start, int end})? range;
  if (from.isEmpty) {
    final suffix = int.tryParse(to);
    if (suffix == null) return null;
    if (suffix == 0) return _unsatisfiable;
    range = (start: math.max(0, size - suffix), end: size - 1);
  } else {
    final start = int.tryParse(from);
    final end = to.isEmpty ? size - 1 : int.tryParse(to);
    if (start == null || end == null) return null;
    if (start >= size) return _unsatisfiable;
    if (end < start) return null;
    range = (start: start, end: math.min(end, size - 1));
  }

  final ifRange = headers['if-range']?.trim();
  if (ifRange != null && ifRange != etag) {
    DateTime? date;
    try {
      date = HttpDate.parse(ifRange);
    } on HttpException {
      date = null;
    }
    final sameSecond =
        date != null &&
        date.millisecondsSinceEpoch ~/ 1000 ==
            modified.millisecondsSinceEpoch ~/ 1000;
    if (!sameSecond) return null;
  }
  return range;
}

String _contentType(String extension) => switch (extension) {
  'mp4' || 'm4v' => 'video/mp4',
  'mkv' => 'video/x-matroska',
  'ts' => 'video/mp2t',
  _ => 'application/octet-stream',
};
