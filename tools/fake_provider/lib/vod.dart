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
/// starting past it gets through) and `throttle_kbps`; for downloads
/// (Phase 8) `change_etag` (new validators on every answer, so `If-Range`
/// never matches), `wrong_content_length` (a Content-Length 4 KiB past the
/// body), `size_mb` (the file padded to that many MiB with
/// [fakePaddingByte]s, made as they are sent) and `vod_as_hls` (an HLS VOD
/// playlist of TS segments under `/vodhls/`, made once with ffmpeg).
library;

import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math' as math;
import 'dart:typed_data';

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

  /// Bumped by every answer under `change_etag`.
  var _validatorTurn = 0;

  /// `vod_as_hls`: each sample's segments, made once (by its name).
  final _segmented = <String, Future<Directory?>>{};

  Handler get handler => (_router ??= _buildRouter()).call;

  /// Bodies being written right now.
  int get openCount => _open.length;

  // HEAD first: shelf_router answers HEAD from a GET route by dropping the
  // body, which a hijacked connection has no way to do.
  Router _buildRouter() => Router(notFoundHandler: _unknownPath)
    ..add('HEAD', '/movie/<username>/<password>/<file>', _movie)
    ..get('/movie/<username>/<password>/<file>', _movie)
    ..add('HEAD', '/series/<username>/<password>/<file>', _episode)
    ..get('/series/<username>/<password>/<file>', _episode)
    ..get('/vodhls/<name>/<file>', _segment);

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

    if (faults.vodAsHls) return await _playlist(request, sample);

    final stat = sample.statSync();
    final sampleSize = stat.size;
    final size = switch (faults.sizeMb) {
      final mb? when mb * _mib > sampleSize => mb * _mib,
      _ => sampleSize,
    };
    var modified = stat.modified.toUtc();
    var etag =
        '"${size.toRadixString(16)}-'
        '${(modified.millisecondsSinceEpoch ~/ 1000).toRadixString(16)}"';
    if (faults.changeEtag) {
      final turn = ++_validatorTurn;
      modified = modified.add(Duration(seconds: turn));
      etag = '${etag.substring(0, etag.length - 1)}-$turn"';
    }
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
    final length = size == 0 ? 0 : end - start + 1;
    // `wrong_content_length`: more than the body holds.
    final claimed = length + (faults.wrongContentLength ? 4096 : 0);
    final headers = [
      if (range == null) 'HTTP/1.1 200 OK' else 'HTTP/1.1 206 Partial Content',
      'content-type: ${_contentType(extension)}',
      'content-length: $claimed',
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
          sampleSize: sampleSize,
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
    required int sampleSize,
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
        connection.body(
          _bytes(sample, sampleSize, start, endExclusive, faults),
        ),
      );
    } on Object {
      // A failed write: the client is gone.
    }
    _open.remove(connection);
    await connection.stop();
    await hangUp();
  }

  /// The file from [start] to [endExclusive] — past [sampleSize], the
  /// padding — paced by `throttle_kbps` and ending early where
  /// `drop_after_bytes` says.
  Stream<List<int>> _bytes(
    File file,
    int sampleSize,
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
    final content = _content(file, sampleSize, start, stopAt);
    if (bytesPerSecond == null) {
      yield* content;
      return;
    }
    final clock = Stopwatch()..start();
    final piece = math.max(512, bytesPerSecond ~/ 20);
    var sent = 0;
    await for (final chunk in content) {
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

  /// The sample's bytes up to [sampleSize], then the padding, from
  /// [start] to [end].
  Stream<List<int>> _content(
    File file,
    int sampleSize,
    int start,
    int end,
  ) async* {
    if (start < sampleSize) {
      yield* file.openRead(start, math.min(end, sampleSize));
    }
    var at = math.max(start, sampleSize);
    while (at < end) {
      final offset = at % _padding.length;
      final take = math.min(end - at, _padding.length - offset);
      yield Uint8List.sublistView(_padding, offset, offset + take);
      at += take;
    }
  }

  /// `vod_as_hls`: the item as an HLS VOD playlist; its segments come from
  /// `/vodhls/<name>/`.
  Future<Response> _playlist(Request request, File sample) async {
    final name = _segmentsName(sample);
    final directory = await (_segmented[name] ??= _makeSegments(sample, name));
    final index = directory == null
        ? null
        : File('${directory.path}/index.m3u8');
    if (index == null || !index.existsSync()) {
      _segmented.removeWhere((key, _) => key == name);
      return Response.internalServerError(body: 'no segments for $name\n');
    }
    final lines = [
      for (final line in index.readAsLinesSync())
        if (line.startsWith('#') || line.trim().isEmpty)
          line
        else
          '/vodhls/$name/${line.trim()}',
    ];
    return Response.ok(
      request.method == 'HEAD' ? null : '${lines.join('\n')}\n',
      headers: {'content-type': 'application/vnd.apple.mpegurl'},
    );
  }

  /// A segment of `vod_as_hls`, holding a connection slot while it is
  /// sent.
  Future<Response> _segment(Request request, String name, String file) async {
    final directory = await _segmented[name];
    final segment =
        directory == null || !RegExp(r'^seg_\d+\.ts$').hasMatch(file)
        ? null
        : File('${directory.path}/$file');
    if (segment == null || !segment.existsSync()) {
      return Response.notFound('no segment $file\n');
    }
    final faults = _state.faults.overriddenBy(request.url.queryParameters);
    final limit = faults.maxConnections ?? _state.profile.maxConnections;
    if (_state.activeStreams >= limit) {
      return Response.forbidden('$maxConnectionsBody\n');
    }
    _state.activeStreams++;
    var held = true;
    void free() {
      if (!held) return;
      held = false;
      _state.activeStreams--;
    }

    final body = StreamController<List<int>>();
    final reading = segment.openRead().listen(
      body.add,
      onError: body.addError,
      onDone: () {
        free();
        unawaited(body.close());
      },
    );
    body
      ..onPause = reading.pause
      ..onResume = reading.resume
      ..onCancel = () async {
        free();
        await reading.cancel();
      };
    return Response.ok(
      body.stream,
      headers: {
        'content-type': 'video/mp2t',
        'content-length': '${segment.lengthSync()}',
      },
    );
  }

  static String _segmentsName(File sample) =>
      sample.uri.pathSegments.last.replaceAll(RegExp('[^A-Za-z0-9_-]'), '_');

  /// Cuts [sample] into 4 s TS segments with a VOD playlist, once; null
  /// when ffmpeg can't.
  Future<Directory?> _makeSegments(File sample, String name) async {
    final directory = Directory('${_state.runDir}/vodhls/$name');
    if (directory.existsSync()) directory.deleteSync(recursive: true);
    directory.createSync(recursive: true);
    try {
      final result = await Process.run(_state.ffmpegPath, [
        ...['-hide_banner', '-loglevel', 'error', '-nostdin'],
        ...['-i', sample.path],
        ...['-map', '0:v:0', '-map', '0:a:0?', '-c', 'copy'],
        ...['-f', 'hls', '-hls_time', '4', '-hls_playlist_type', 'vod'],
        ...['-hls_segment_filename', '${directory.path}/seg_%05d.ts'],
        '${directory.path}/index.m3u8',
      ]);
      if (result.exitCode != 0) {
        _log('segmenting $name failed: ${result.stderr}');
        return null;
      }
      return directory;
    } on ProcessException catch (error) {
      _log('segmenting $name failed: $error');
      return null;
    }
  }

  void _log(String message) {
    if (verbose) stderr.writeln('[vod] $message');
  }
}

const int _mib = 1024 * 1024;

/// The byte at [offset] of a file's padding (`size_mb`), as a test checks
/// a padded download: offsets count from the start of the file.
int fakePaddingByte(int offset) => _padding[offset % _padding.length];

/// 64 KiB of filler, repeated past the sample's end.
final Uint8List _padding = Uint8List.fromList(
  List<int>.generate(64 * 1024, (i) => (i * 131 + 17) & 0xff),
);

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
/// with another validator than the file's means the whole file, before
/// the range is looked at.
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
  // Before the range itself, as HTTP has it: a validator that doesn't
  // match means the whole file, even for a range past the end.
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
  return range;
}

String _contentType(String extension) => switch (extension) {
  'mp4' || 'm4v' => 'video/mp4',
  'mkv' => 'video/x-matroska',
  'ts' => 'video/mp2t',
  _ => 'application/octet-stream',
};
