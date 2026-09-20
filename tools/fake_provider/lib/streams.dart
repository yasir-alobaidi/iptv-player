/// Live streams: one supervised ffmpeg per request, looping an MKV remux of
/// a media sample (docs/06 "Fake provider", plan step 6).
///
/// The MKV matters: looping the `.ts` sample itself breaks video timestamps
/// at every wrap (about 100 decode errors and a multi-second freeze on HEVC
/// 4K — ADR-004 Finding 8), so each sample is remuxed once, cached, and the
/// cache is what `-stream_loop -1` reads.
library;

import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:fake_provider/generator.dart';
import 'package:fake_provider/profile.dart';
import 'package:fake_provider/server_state.dart';
import 'package:shelf/shelf.dart';
import 'package:shelf_router/shelf_router.dart';

/// Body of the 403 a request over `max_connections` gets. A real panel just
/// refuses the connection, which leaves a test nothing to check, so we answer
/// with a status and this marker instead.
const maxConnectionsBody = 'MAX_CONNECTIONS_REACHED';

/// An MPEG-TS null packet (PID 0x1FFF): demuxers skip it.
final tsNullPacket = List<int>.unmodifiable([
  0x47, 0x1F, 0xFF, 0x10, //
  ...List.filled(184, 0xFF),
]);

/// Body of the 403 an expired redirect token gets.
const tokenExpiredBody = 'TOKEN_EXPIRED';

/// How long a `redirect_with_expiring_token` token works.
const tokenLifetime = Duration(seconds: 10);

/// An HLS session ends this long after its playlist was last asked for.
const hlsIdleTimeout = Duration(seconds: 20);

/// What `/movie/...` and `/series/...` answer for now.
const vodNotImplementedBody =
    'VOD serving (Range, ETag, Last-Modified, size_mb padding — docs/06) '
    'arrives with the phase that needs it; step 6 is live only.';

/// Serves `/live/{u}/{p}/{id}.ts` and owns every ffmpeg it starts.
///
/// Hard rule 8: each process has an owner (this relay), a PID file under
/// `<runDir>/pids/`, is killed when the client goes away or on [close], and
/// leftovers from a previous run are swept by [cleanStaleProcesses].
class StreamRelay {
  new(this._state, {this.verbose = false, this.hlsIdle = hlsIdleTimeout});

  /// How long an HLS session outlives its last playlist request.
  final Duration hlsIdle;

  final FakeServerState _state;

  /// ffmpeg's stderr is always drained — an undrained pipe fills and stalls
  /// the process — but only printed when this is on.
  final bool verbose;

  final _children = <_Child>{};

  /// Remux in flight per sample name, so two concurrent requests for the same
  /// sample never write the same `.part` file at once.
  final _remuxes = <String, Future<File>>{};

  Router? _router;

  /// HLS sessions by channel id.
  final _hls = <int, _HlsSession>{};
  Timer? _hlsReaper;

  Handler get handler => (_router ??= _buildRouter()).call;

  Router _buildRouter() => Router(notFoundHandler: _unknownPath)
    ..get('/live/<username>/<password>/<file>', _serveLive)
    ..get('/hls/<id>/<file>', _serveSegment)
    ..all('/movie/<rest|.*>', _vodNotImplemented)
    ..all('/series/<rest|.*>', _vodNotImplemented);

  /// Kills every child and removes its PID file.
  Future<void> close() async {
    _hlsReaper?.cancel();
    _hlsReaper = null;
    for (final session in _hls.values.toList()) {
      await _stopHls(session);
    }
    for (final child in _children.toList()) {
      await _reap(child);
    }
    _remuxes.clear();
  }

  /// Startup cleanup: the PID files a crashed run left behind. A pid is only
  /// signalled when `/proc` still shows it as the ffmpeg we started; see
  /// [_isOurFfmpeg]. Call this before serving — our own children's PID files
  /// look exactly like stale ones.
  Future<void> cleanStaleProcesses() async {
    final dir = Directory(_pidDirPath);
    if (!dir.existsSync()) return;
    for (final file in dir.listSync().whereType<File>()) {
      if (!file.path.endsWith('.pid')) continue;
      List<String> lines;
      try {
        lines = file.readAsLinesSync();
      } on Object {
        // A truncated or unreadable record tells us nothing; drop it.
        _delete(file);
        continue;
      }
      final pid = int.tryParse(lines.isEmpty ? '' : lines.first.trim());
      final ffmpeg = lines.length > 1 ? lines[1].trim() : '';
      final loop = lines.length > 2 ? lines[2].trim() : '';
      if (pid != null && _isOurFfmpeg(pid, ffmpeg, loop)) {
        Process.killPid(pid, ProcessSignal.sigkill);
        _log('swept stale ffmpeg $pid');
      }
      _delete(file);
    }
  }

  Response _unknownPath(Request request) =>
      Response.notFound('no stream at /${request.url.path}\n');

  Response _vodNotImplemented(Request request, String rest) =>
      Response(HttpStatus.notImplemented, body: '$vodNotImplementedBody\n');

  Future<Response> _serveLive(
    Request request,
    String username,
    String password,
    String file,
  ) async {
    // The plan is explicit: bad credentials are a 401 here, not the 200 with
    // an empty user_info that player_api.php sends.
    if (!_state.authenticates(username, password)) {
      return Response.unauthorized('BAD_CREDENTIALS\n');
    }
    final faults = _state.faults.overriddenBy(request.url.queryParameters);

    // A load balancer's redirect to a tokened URL that stops working after
    // [tokenLifetime]: a player that reconnects to the redirected URL
    // instead of the original one gets a 403 (docs/02).
    if (faults.redirectWithExpiringToken) {
      final token = request.url.queryParameters['token'];
      if (token == null) {
        final expires = DateTime.now()
            .add(tokenLifetime)
            .millisecondsSinceEpoch;
        return Response.found(
          request.requestedUri.replace(
            queryParameters: {
              ...request.url.queryParameters,
              'token': '$expires',
            },
          ),
        );
      }
      final expires = int.tryParse(token) ?? 0;
      if (DateTime.now().millisecondsSinceEpoch > expires) {
        return Response.forbidden('$tokenExpiredBody\n');
      }
    }

    if (faults.httpStatus case final status?) {
      return _faultStatus(status);
    }
    if (faults.slowStartMs case final ms? when ms > 0) {
      await Future<void>.delayed(Duration(milliseconds: ms));
    }

    final dot = file.lastIndexOf('.');
    final id = dot < 0 ? file : file.substring(0, dot);
    final extension = dot < 0 ? '' : file.substring(dot + 1).toLowerCase();
    if (extension != 'ts' && extension != 'm3u8') {
      return Response(
        HttpStatus.notImplemented,
        body: 'live streams are .ts or .m3u8\n',
      );
    }

    // The range check keeps a wrong id off the generator entirely, which is
    // also why an id from the movie or series range is a plain 404.
    final streamId = int.tryParse(id);
    if (streamId == null ||
        streamId < liveIdBase ||
        streamId >= liveIdBase + _state.profile.liveCount) {
      return Response.notFound('no live stream $id\n');
    }
    // Before any work, like a panel at its connection limit (an HLS session
    // already running for this channel is shared, so it is checked there).
    // activeStreams is `user_info.active_cons`: incremented once a stream
    // starts, decremented in [_reap] whatever ends it.
    final limit = faults.maxConnections ?? _state.profile.maxConnections;
    if (extension == 'ts' && _state.activeStreams >= limit) {
      return Response.forbidden('$maxConnectionsBody\n');
    }

    final channel = _state.catalog.channelById(streamId);
    if (channel == null) return Response.notFound('no live stream $id\n');

    final sample = File('${_state.samplesDir}/${channel.sample}');
    if (!sample.existsSync()) {
      // A wrong --samples is the common mistake; say which file is missing
      // rather than hanging or serving an empty body.
      return Response.notFound(
        'missing sample ${sample.path} — is --samples right? '
        '(tools/media_samples/generate.sh builds them)\n',
      );
    }

    if (extension == 'm3u8') {
      return await _servePlaylist(streamId, sample, limit);
    }

    // Nothing is taken until the connection is ours: if the client is gone
    // by then, shelf never calls back.
    request.hijack(
      (connection) => unawaited(
        _relayLive(
          connection.stream,
          connection.sink,
          sample,
          limit,
          faults,
          switchTo: _switchSample(channel.sample),
        ),
      ),
    );
  }

  /// A live `.ts` stream, written on the hijacked connection itself.
  ///
  /// Not a shelf [Response]: when a client resets the connection before the
  /// response headers go out (a player abandoning an attempt mid-reconnect),
  /// dart:io takes the body, drops every chunk and never cancels it, so the
  /// ffmpeg and the slot stay taken for good (the 2026-09-19 soak). Owning
  /// the socket, the relay sees the client leave on its read side, as a
  /// panel does, whenever that happens.
  Future<void> _relayLive(
    Stream<List<int>> incoming,
    StreamSink<List<int>> outgoing,
    File sample,
    int limit,
    FakeFaults faults, {
    required String switchTo,
  }) async {
    unawaited(outgoing.done.then((_) {}, onError: (Object _) {}));
    var gone = false;
    Future<void> Function()? stop;
    final reading = incoming.listen(
      null,
      onDone: () {
        gone = true;
        unawaited(stop?.call());
      },
      onError: (Object _) {
        gone = true;
        unawaited(stop?.call());
      },
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

    // Again, now that the connection is ours: the check in [_serveLive]
    // came before the hijack's wait, so another stream may have started.
    if (_state.activeStreams >= limit) {
      outgoing.add(_plainAnswer(403, 'Forbidden', '$maxConnectionsBody\n'));
      await hangUp();
      return;
    }
    _state.activeStreams++;
    final _Child child;
    try {
      child = await _startLoop(sample);
    } on Object catch (error) {
      _state.activeStreams--;
      final name = sample.uri.pathSegments.last;
      outgoing.add(
        _plainAnswer(
          500,
          'Internal Server Error',
          'ffmpeg failed for $name: $error\n',
        ),
      );
      await hangUp();
      return;
    }
    final body = _relayBody(child, faults, switchTo: switchTo);
    stop = body.stop;
    if (gone) {
      await body.stop();
      await hangUp();
      return;
    }
    // `cut_after_s`: the body stops with no last chunk and the connection
    // closes, as a panel or a network drop does. Unlike `drop_after_s`,
    // lavf reads that as a cut and reconnects by itself (ADR-010).
    var cut = false;
    Timer? cutTimer;
    if (faults.cutAfterS case final s?) {
      cutTimer = Timer(Duration(seconds: s), () {
        cut = true;
        unawaited(body.stop());
      });
    }
    // Chunked, as shelf sent it: a body that ends (drop_after_s) ends with
    // the last chunk, which lavf takes as the end of the stream. Without a
    // length or chunks, lavf takes the close for a cut and reconnects by
    // itself (reconnect_streamed), so the player never sees the drop.
    outgoing.add(
      utf8.encode(
        'HTTP/1.1 200 OK\r\n'
        'content-type: video/mp2t\r\n'
        'cache-control: no-store\r\n'
        'transfer-encoding: chunked\r\n'
        'connection: close\r\n\r\n',
      ),
    );
    try {
      await outgoing.addStream(
        body.stream.where((data) => data.isNotEmpty).map(_chunk),
      );
      if (!cut) outgoing.add(_lastChunk);
    } on Object {
      // A failed write: the client is gone.
    }
    cutTimer?.cancel();
    // Idempotent: the body ended (a drop, ffmpeg exited) or the write failed.
    await body.stop();
    await hangUp();
  }

  /// One chunk of a chunked body: size in hex, the bytes, CRLF.
  static List<int> _chunk(List<int> data) => [
    ...ascii.encode('${data.length.toRadixString(16)}\r\n'),
    ...data,
    13, 10, //
  ];

  static final List<int> _lastChunk = ascii.encode('0\r\n\r\n');

  /// A whole HTTP answer with a text body, for the hijacked connection.
  List<int> _plainAnswer(int status, String reason, String text) {
    final body = utf8.encode(text);
    return [
      ...utf8.encode(
        'HTTP/1.1 $status $reason\r\n'
        'content-type: text/plain; charset=utf-8\r\n'
        'content-length: ${body.length}\r\n'
        'connection: close\r\n\r\n',
      ),
      ...body,
    ];
  }

  /// A fault's status, with the body a panel would plausibly send.
  Response _faultStatus(int status) => switch (status) {
    401 => Response.unauthorized('BAD_CREDENTIALS\n'),
    403 => Response.forbidden('$maxConnectionsBody\n'),
    404 => Response.notFound('no live stream\n'),
    429 => Response(
      429,
      body: 'TOO_MANY_REQUESTS\n',
      headers: {'retry-after': '1'},
    ),
    _ => Response(status, body: 'FAULT $status\n'),
  };

  /// The sample a `codec_switch_after_s` fault switches to: a different
  /// codec from [current], so the player's decoder really changes.
  String _switchSample(String current) => current.startsWith('hevc')
      ? 'h264_1080p50_aac.ts'
      : 'hevc_1080p50_aac.ts';

  Future<_Child> _startLoop(File sample) async {
    final loop = await _loopable(sample);
    final process = await Process.start(_state.ffmpegPath, [
      ...['-hide_banner', '-loglevel', 'error', '-nostdin'],
      ...['-re', '-stream_loop', '-1', '-i', loop.path],
      // One video and at most one audio track: a live mux carries no
      // subtitle or extra streams.
      ...['-map', '0:v:0', '-map', '0:a:0?', '-c', 'copy', '-f', 'mpegts'],
      'pipe:1',
    ]);
    final child = _Child(process, _writePid(process.pid, loop.path));
    _children.add(child);
    if (verbose) {
      child.process.stderr
          .transform(utf8.decoder)
          .transform(const LineSplitter())
          .listen((line) => stderr.writeln('[ffmpeg live ${child.pid}] $line'));
    } else {
      unawaited(child.process.stderr.drain<void>());
    }
    return child;
  }

  /// The body is the process's stdout, unbuffered and with pause/resume
  /// passed through so a slow client throttles ffmpeg instead of filling
  /// memory. `stop` (the client left) or cancelling the body kills the
  /// process and frees the slot.
  ///
  /// The stream faults act here: `drop_after_s` ends the body (a dropped
  /// connection), `stall_after_s` stops sending but keeps it open, and
  /// `codec_switch_after_s` carries on with [switchTo] in the same body.
  ({Stream<List<int>> stream, Future<void> Function() stop}) _relayBody(
    _Child first,
    FakeFaults faults, {
    required String switchTo,
  }) {
    final body = StreamController<List<int>>();
    var child = first;
    var stalled = false;
    final timers = <Timer>[];
    late StreamSubscription<List<int>> out;

    var ended = false;

    Future<void> stop() async {
      ended = true;
      for (final timer in timers) {
        timer.cancel();
      }
      if (!body.isClosed) unawaited(body.close());
      await out.cancel();
      await _reap(child);
    }

    void finish() => unawaited(stop());

    void pipe(_Child source) {
      out = source.process.stdout.listen(
        (data) {
          if (!stalled && !body.isClosed) body.add(data);
        },
        onError: (Object error) {
          if (!body.isClosed) body.addError(error);
        },
        onDone: () {
          // Only the current child ends the body; a switched-out one is
          // killed on purpose.
          if (identical(source, child)) finish();
        },
        cancelOnError: true,
      );
    }

    pipe(child);
    if (faults.dropAfterS case final s?) {
      timers.add(Timer(Duration(seconds: s), finish));
    }
    if (faults.stallAfterS case final s?) {
      timers.add(
        Timer(Duration(seconds: s), () {
          stalled = true;
          out.pause();
          // Nothing a player can play, but the connection is visibly alive.
          timers.add(
            Timer.periodic(const Duration(seconds: 1), (_) {
              if (!body.isClosed) body.add(tsNullPacket);
            }),
          );
        }),
      );
    }
    if (faults.codecSwitchAfterS case final s?) {
      timers.add(
        Timer(Duration(seconds: s), () async {
          final sample = File('${_state.samplesDir}/$switchTo');
          // `ended`, not `body.isClosed`: a client that left cancels the
          // body without closing it.
          if (ended || !sample.existsSync()) return;
          final next = await _startLoop(sample);
          if (ended) {
            await _reap(next, releaseSlot: false);
            return;
          }
          final previous = child;
          child = next;
          await out.cancel();
          await _reap(previous, releaseSlot: false);
          pipe(next);
        }),
      );
    }
    body
      ..onPause = () {
        out.pause();
      }
      ..onResume = () {
        if (!stalled) out.resume();
      }
      ..onCancel = stop;

    return (stream: body.stream, stop: stop);
  }

  /// `.m3u8`: live HLS from one ffmpeg per channel writing 2 s segments,
  /// shared by every client of that channel, and stopped once nobody has
  /// asked for its playlist for [hlsIdleTimeout]. A session holds one
  /// connection slot while it runs, as a panel counts an HLS viewer.
  Future<Response> _servePlaylist(int id, File sample, int limit) async {
    var session = _hls[id];
    if (session == null) {
      if (_state.activeStreams >= limit) {
        return Response.forbidden('$maxConnectionsBody\n');
      }
      _state.activeStreams++;
      try {
        session = await _startHls(id, sample);
      } on Object catch (error) {
        _state.activeStreams--;
        return Response.internalServerError(body: 'ffmpeg failed: $error\n');
      }
    }
    session.lastRequest = DateTime.now();
    final playlist = File('${session.directory.path}/index.m3u8');
    for (var i = 0; i < 200 && !playlist.existsSync(); i++) {
      await Future<void>.delayed(const Duration(milliseconds: 50));
    }
    if (!playlist.existsSync()) {
      return Response.internalServerError(body: 'no playlist yet\n');
    }
    // Segments are served from /hls/<id>/, not next to the playlist URL.
    final text = playlist.readAsStringSync().replaceAllMapped(
      RegExp(r'^(seg_\d+\.ts)$', multiLine: true),
      (m) => '/hls/$id/${m[1]}',
    );
    return Response.ok(
      text,
      headers: {
        'content-type': 'application/vnd.apple.mpegurl',
        'cache-control': 'no-store',
      },
    );
  }

  Future<_HlsSession> _startHls(int id, File sample) async {
    final loop = await _loopable(sample);
    final directory = Directory('${_state.runDir}/hls/$id');
    if (directory.existsSync()) directory.deleteSync(recursive: true);
    directory.createSync(recursive: true);
    final process = await Process.start(_state.ffmpegPath, [
      ...['-hide_banner', '-loglevel', 'error', '-nostdin'],
      ...['-re', '-stream_loop', '-1', '-i', loop.path],
      ...['-map', '0:v:0', '-map', '0:a:0?', '-c', 'copy'],
      ...['-f', 'hls', '-hls_time', '2', '-hls_list_size', '6'],
      ...['-hls_flags', 'delete_segments+omit_endlist'],
      ...['-hls_segment_filename', '${directory.path}/seg_%05d.ts'],
      '${directory.path}/index.m3u8',
    ]);
    unawaited(process.stdout.drain<void>());
    unawaited(process.stderr.drain<void>());
    final session = _HlsSession(
      id,
      _Child(process, _writePid(process.pid, loop.path)),
      directory,
    );
    _children.add(session.child);
    _hls[id] = session;
    _hlsReaper ??= Timer.periodic(const Duration(milliseconds: 500), (_) {
      final now = DateTime.now();
      for (final idle in _hls.values.toList()) {
        if (now.difference(idle.lastRequest) > hlsIdle) {
          unawaited(_stopHls(idle));
        }
      }
    });
    return session;
  }

  Future<void> _stopHls(_HlsSession session) async {
    _hls.remove(session.id);
    await _reap(session.child);
    if (session.directory.existsSync()) {
      session.directory.deleteSync(recursive: true);
    }
  }

  Future<Response> _serveSegment(
    Request request,
    String id,
    String file,
  ) async {
    final session = _hls[int.tryParse(id)];
    if (session == null || !RegExp(r'^seg_\d+\.ts$').hasMatch(file)) {
      return Response.notFound('no segment $file\n');
    }
    final segment = File('${session.directory.path}/$file');
    if (!segment.existsSync()) return Response.notFound('no segment $file\n');
    return Response.ok(
      segment.openRead(),
      headers: {'content-type': 'video/mp2t'},
    );
  }

  /// Idempotent: kill, drop the PID file, release the connection slot
  /// (unless the process is being swapped for another in the same slot).
  Future<void> _reap(_Child child, {bool releaseSlot = true}) async {
    if (child.stopped) return;
    child.stopped = true;
    _children.remove(child);
    child.process.kill(ProcessSignal.sigkill);
    await child.process.exitCode.timeout(
      const Duration(seconds: 3),
      onTimeout: () => -1,
    );
    _delete(child.pidFile);
    if (releaseSlot) _state.activeStreams--;
  }

  /// The cached MKV for [sample], remuxed once. `.part` + rename means a
  /// killed remux never leaves a truncated file that looks cached (hard
  /// rule 11).
  Future<File> _loopable(File sample) async {
    final name = sample.uri.pathSegments.last;
    final pending = _remuxes[name];
    if (pending != null) return await pending;
    final remux = _remux(sample, name);
    _remuxes[name] = remux;
    try {
      return await remux;
    } on Object {
      // Drop the failure so the next request retries instead of inheriting it.
      _remuxes.removeWhere((key, value) => key == name && value == remux);
      rethrow;
    }
  }

  Future<File> _remux(File sample, String name) async {
    final base = name.contains('.')
        ? name.substring(0, name.lastIndexOf('.'))
        : name;
    final mkv = File('${_state.runDir}/loop_cache/$base.mkv');
    if (mkv.existsSync()) return mkv;
    mkv.parent.createSync(recursive: true);
    final part = File('${mkv.path}.part');
    final result = await Process.run(_state.ffmpegPath, [
      ...['-hide_banner', '-loglevel', 'error', '-nostdin', '-y'],
      ...['-i', sample.path, '-map', '0:v:0', '-map', '0:a:0?', '-c', 'copy'],
      ...['-f', 'matroska', part.path],
    ]);
    if (result.exitCode != 0) {
      _delete(part);
      throw StateError(
        'remuxing $name for looping failed (${result.exitCode}): '
        '${result.stderr}',
      );
    }
    part.renameSync(mkv.path);
    return mkv;
  }

  String get _pidDirPath => '${_state.runDir}/pids';

  /// `<pid>\n<ffmpeg path>\n<loop file>\n` — the last two are what a later
  /// run compares against `/proc/<pid>/cmdline`.
  File _writePid(int pid, String loopPath) {
    final dir = Directory(_pidDirPath)..createSync(recursive: true);
    return File('${dir.path}/live_$pid.pid')
      ..writeAsStringSync('$pid\n${_state.ffmpegPath}\n$loopPath\n');
  }

  /// Whether [pid] is still the ffmpeg this record was written for.
  ///
  /// Pids are reused, so a bare "is it alive?" would eventually kill a
  /// stranger's process. `/proc/<pid>/cmdline` has to name both our ffmpeg
  /// binary and the loop file from the record; anything less, including every
  /// platform without `/proc`, means we cannot tell and do not signal.
  bool _isOurFfmpeg(int pid, String ffmpeg, String loop) {
    if (!Platform.isLinux) return false;
    if (ffmpeg.isEmpty || loop.isEmpty) return false;
    final cmdline = File('/proc/$pid/cmdline');
    if (!cmdline.existsSync()) return false;
    String args;
    try {
      // NUL-separated argv; substring matching is enough here.
      args = cmdline.readAsStringSync();
    } on Object {
      // It exited between the two calls, or is not ours to read.
      return false;
    }
    return args.contains(ffmpeg) && args.contains(loop);
  }

  void _delete(File file) {
    try {
      if (file.existsSync()) file.deleteSync();
    } on Object {
      // Another sweep or run got there first.
    }
  }

  void _log(String message) {
    if (verbose) stderr.writeln('[streams] $message');
  }
}

class _Child {
  new(this.process, this.pidFile);

  final Process process;
  final File pidFile;
  bool stopped = false;

  int get pid => process.pid;
}

class _HlsSession {
  new(this.id, this.child, this.directory);

  final int id;
  final _Child child;
  final Directory directory;
  DateTime lastRequest = DateTime.now();
}
