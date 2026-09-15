import 'dart:async';
import 'dart:convert';
import 'dart:io';

/// Loopback HTTP server that plays each sample as an endless live MPEG-TS
/// stream: bundled ffmpeg `-re -stream_loop -1 … -c copy -f mpegts pipe:1`,
/// one process per request, killed when the client disconnects.
class StreamServer {
  StreamServer._(this._server, this._ffmpeg, this._samplesDir);

  static Future<StreamServer> start({
    required String ffmpeg,
    required String samplesDir,
  }) async {
    final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    final s = StreamServer._(server, ffmpeg, samplesDir);
    server.listen(s._handle);
    return s;
  }

  final HttpServer _server;
  final String _ffmpeg;
  final String _samplesDir;
  final Set<Process> _procs = {};

  /// [token] makes every URL unique so the player's `path` identifies the
  /// open request. [burst] sends that many seconds at full speed first, like
  /// many real providers do (`-readrate_initial_burst`).
  String url(String sample, {required String token, int burst = 0}) =>
      'http://127.0.0.1:${_server.port}/live/$sample?burst=$burst&$token';

  Future<void> _handle(HttpRequest req) async {
    final segs = req.uri.pathSegments;
    final file =
        segs.length == 2 && segs[0] == 'live' && !segs[1].contains('..')
        ? File('$_samplesDir/${segs[1]}')
        : null;
    if (file == null || !file.existsSync()) {
      req.response.statusCode = HttpStatus.notFound;
      await req.response.close();
      return;
    }
    final burst = int.tryParse(req.uri.queryParameters['burst'] ?? '') ?? 0;
    final p = await Process.start(_ffmpeg, [
      '-hide_banner',
      '-loglevel',
      'error',
      '-nostdin',
      if (burst > 0) ...['-readrate_initial_burst', '$burst'],
      '-re',
      '-stream_loop',
      '-1',
      '-i',
      file.path,
      '-map',
      '0:v:0',
      '-map',
      '0:a:0?',
      '-c',
      'copy',
      '-f',
      'mpegts',
      'pipe:1',
    ]);
    _procs.add(p);
    p.stderr
        .transform(utf8.decoder)
        .listen((l) => stderr.write('[ffmpeg ${segs[1]}] $l'));
    void kill() {
      p.kill(ProcessSignal.sigkill);
      _procs.remove(p);
    }

    unawaited(req.response.done.then((_) => kill(), onError: (_) => kill()));
    req.response
      ..bufferOutput = false
      ..headers.contentType = ContentType('video', 'mp2t');
    try {
      await req.response.addStream(p.stdout);
    } catch (_) {
      // Client went away mid-stream: expected on every zap.
    } finally {
      kill();
      try {
        await req.response.close();
      } catch (_) {}
    }
  }

  Future<void> close() async {
    for (final p in _procs.toList()) {
      p.kill(ProcessSignal.sigkill);
    }
    _procs.clear();
    await _server.close(force: true);
  }
}
