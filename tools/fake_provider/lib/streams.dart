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
import 'package:fake_provider/server_state.dart';
import 'package:shelf/shelf.dart';
import 'package:shelf_router/shelf_router.dart';

/// Body of the 403 a request over `max_connections` gets. A real panel just
/// refuses the connection, which leaves a test nothing to check, so we answer
/// with a status and this marker instead.
const maxConnectionsBody = 'MAX_CONNECTIONS_REACHED';

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
  new(this._state, {this.verbose = false});

  final FakeServerState _state;

  /// ffmpeg's stderr is always drained — an undrained pipe fills and stalls
  /// the process — but only printed when this is on.
  final bool verbose;

  final _children = <_Child>{};

  /// Remux in flight per sample name, so two concurrent requests for the same
  /// sample never write the same `.part` file at once.
  final _remuxes = <String, Future<File>>{};

  Router? _router;

  Handler get handler => (_router ??= _buildRouter()).call;

  Router _buildRouter() => Router(notFoundHandler: _unknownPath)
    ..get('/live/<username>/<password>/<file>', _serveLive)
    ..all('/movie/<rest|.*>', _vodNotImplemented)
    ..all('/series/<rest|.*>', _vodNotImplemented);

  /// Kills every child and removes its PID file.
  Future<void> close() async {
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

    final dot = file.lastIndexOf('.');
    final id = dot < 0 ? file : file.substring(0, dot);
    final extension = dot < 0 ? '' : file.substring(dot + 1).toLowerCase();
    if (extension != 'ts') {
      return Response(
        HttpStatus.notImplemented,
        body:
            'only .ts live streams are served; .m3u8 arrives with the phase '
            'that needs it (docs/06 "pre-segmented HLS").\n',
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

    // Before any work, like a panel at its connection limit. activeStreams is
    // `user_info.active_cons`, so it is incremented here and decremented in
    // [_reap] whatever ends the request.
    if (_state.activeStreams >= _state.maxConnections) {
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

    _state.activeStreams++;
    final _Child child;
    try {
      final loop = await _loopable(sample);
      final process = await Process.start(_state.ffmpegPath, [
        ...['-hide_banner', '-loglevel', 'error', '-nostdin'],
        ...['-re', '-stream_loop', '-1', '-i', loop.path],
        // One video and at most one audio track: a live mux carries no
        // subtitle or extra streams.
        ...['-map', '0:v:0', '-map', '0:a:0?', '-c', 'copy', '-f', 'mpegts'],
        'pipe:1',
      ]);
      child = _Child(process, _writePid(process.pid, loop.path));
      _children.add(child);
    } on Object catch (error) {
      _state.activeStreams--;
      return Response.internalServerError(
        body: 'ffmpeg failed for ${channel.sample}: $error\n',
      );
    }

    if (verbose) {
      child.process.stderr
          .transform(utf8.decoder)
          .transform(const LineSplitter())
          .listen((line) => stderr.writeln('[ffmpeg live ${child.pid}] $line'));
    } else {
      unawaited(child.process.stderr.drain<void>());
    }

    // The body is the process's stdout, unbuffered and with pause/resume
    // passed through so a slow client throttles ffmpeg instead of filling
    // memory. Cancelling the subscription is how shelf tells us the client
    // disconnected, and that is where the process dies.
    final body = StreamController<List<int>>();
    late final StreamSubscription<List<int>> out;
    out = child.process.stdout.listen(
      body.add,
      onError: body.addError,
      onDone: () => unawaited(_endBody(body, child)),
      cancelOnError: true,
    );
    body
      ..onPause = out.pause
      ..onResume = out.resume
      ..onCancel = () async {
        await out.cancel();
        await _reap(child);
      };

    return Response.ok(
      body.stream,
      headers: {'content-type': 'video/mp2t', 'cache-control': 'no-store'},
      context: {'shelf.io.buffer_output': false},
    );
  }

  /// ffmpeg ended on its own (a bad sample, or [close] killed it).
  Future<void> _endBody(StreamController<List<int>> body, _Child child) async {
    if (!body.isClosed) await body.close();
    await _reap(child);
  }

  /// Idempotent: kill, drop the PID file, release the connection slot.
  Future<void> _reap(_Child child) async {
    if (child.stopped) return;
    child.stopped = true;
    _children.remove(child);
    child.process.kill(ProcessSignal.sigkill);
    await child.process.exitCode.timeout(
      const Duration(seconds: 3),
      onTimeout: () => -1,
    );
    _delete(child.pidFile);
    _state.activeStreams--;
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
