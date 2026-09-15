import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'package:shelf/shelf.dart';
import 'package:shelf/shelf_io.dart' as shelf_io;
import 'package:shelf_router/shelf_router.dart';

import 'cast_channel.dart' show Json, Log;

String newToken() {
  final r = Random.secure();
  return List.generate(
    16,
    (_) => r.nextInt(256).toRadixString(16).padLeft(2, '0'),
  ).join();
}

/// PID files: `<runDir>/<name>_<pid>.pid` with the pid and, optionally, a
/// session dir to delete. A later start sweeps what a crash left behind.
File _writePid(Directory runDir, String name, int pid, [String dir = '']) =>
    File('${runDir.path}/${name}_$pid.pid')..writeAsStringSync('$pid\n$dir\n');

void sweepLeftovers(Directory runDir, Directory sessionsRoot, Log log) {
  if (!runDir.existsSync()) return;
  for (final f in runDir.listSync().whereType<File>()) {
    if (!f.path.endsWith('.pid')) continue;
    final lines = f.readAsLinesSync();
    final pid = int.tryParse(lines.firstOrNull ?? '');
    final cmdline = File('/proc/$pid/cmdline');
    if (pid != null &&
        cmdline.existsSync() &&
        cmdline.readAsStringSync().contains('ffmpeg')) {
      Process.killPid(pid, ProcessSignal.sigkill);
      log('sweep: killed leftover ffmpeg $pid');
    }
    final dir = lines.length > 1 ? lines[1] : '';
    if (dir.startsWith('${sessionsRoot.path}/') &&
        Directory(dir).existsSync()) {
      Directory(dir).deleteSync(recursive: true);
      log('sweep: deleted $dir');
    }
    f.deleteSync();
  }
}

Future<void> _terminate(Process p) async {
  p.kill();
  await p.exitCode.timeout(
    const Duration(seconds: 3),
    onTimeout: () {
      p.kill(ProcessSignal.sigkill);
      return p.exitCode;
    },
  );
}

/// Loopback stand-in for a provider: a sample as an endless real-time MPEG-TS
/// stream (`-re -stream_loop -1 -c copy`), one ffmpeg per request.
class SourceServer {
  SourceServer._(this._server, this._ffmpeg, this._samplesDir, this._runDir);

  static Future<SourceServer> start(
    String ffmpeg,
    String samplesDir,
    Directory runDir,
  ) async {
    final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    final s = SourceServer._(server, ffmpeg, samplesDir, runDir);
    server.listen((req) => unawaited(s._handle(req)));
    return s;
  }

  final HttpServer _server;
  final String _ffmpeg;
  final String _samplesDir;
  final Directory _runDir;
  final _procs = <Process>{};

  String url(String sample) => 'http://127.0.0.1:${_server.port}/live/$sample';

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
    final p = await Process.start(_ffmpeg, [
      ...['-hide_banner', '-loglevel', 'error', '-nostdin'],
      ...['-re', '-stream_loop', '-1', '-i', file.path],
      ...['-map', '0:v:0', '-map', '0:a:0?', '-c', 'copy', '-f', 'mpegts'],
      'pipe:1',
    ]);
    _procs.add(p);
    final pidFile = _writePid(_runDir, 'source', p.pid);
    p.stderr.drain<void>();
    req.response
      ..bufferOutput = false
      ..headers.contentType = ContentType('video', 'mp2t');
    try {
      await req.response.addStream(p.stdout);
    } on Object {
      // The relay closed the connection.
    } finally {
      p.kill(ProcessSignal.sigkill);
      _procs.remove(p);
      if (pidFile.existsSync()) pidFile.deleteSync();
      try {
        await req.response.close();
      } on Object {
        // Already closed.
      }
    }
  }

  Future<void> close() async {
    for (final p in _procs) {
      p.kill(ProcessSignal.sigkill);
    }
    await _server.close(force: true);
  }
}

/// docs/04 relay-copy: video copied, audio to AAC stereo, HLS in [dir].
class HlsRelay {
  HlsRelay._(this.process, this.dir, this._pidFile);

  static Future<HlsRelay> start({
    required String ffmpeg,
    required String sourceUrl,
    required Directory dir,
    required Directory runDir,
    required bool fmp4,
    String? videoTag,
    required Log log,
    int hlsTime = 2,
  }) async {
    dir.createSync(recursive: true);
    final args = [
      ...['-hide_banner', '-loglevel', 'warning', '-nostdin'],
      ...['-user_agent', 'iptv-player cast_spike'],
      ...['-reconnect', '1', '-reconnect_streamed', '1'],
      ...['-reconnect_on_network_error', '1', '-reconnect_delay_max', '5'],
      ...['-fflags', '+genpts+discardcorrupt'],
      ...['-i', sourceUrl],
      ...['-map', '0:v:0', '-map', '0:a:0?', '-c:v', 'copy'],
      ...['-c:a', 'aac', '-b:a', '192k', '-ac', '2'],
      if (videoTag != null) ...['-tag:v', videoTag],
      ...['-f', 'hls', '-hls_time', '$hlsTime', '-hls_list_size', '6'],
      ...['-hls_flags', 'delete_segments+independent_segments+omit_endlist'],
      ...['-hls_segment_type', if (fmp4) 'fmp4' else 'mpegts'],
      '${dir.path}/index.m3u8',
    ];
    log('relay: ffmpeg ${args.join(' ')}');
    final p = await Process.start(ffmpeg, args, workingDirectory: dir.path);
    final pidFile = _writePid(runDir, 'relay', p.pid, dir.path);
    p.stderr
        .transform(utf8.decoder)
        .transform(const LineSplitter())
        .listen((l) => log('[relay ffmpeg] $l'));
    p.stdout.drain<void>();
    return HlsRelay._(p, dir, pidFile);
  }

  final Process process;
  final Directory dir;
  final File _pidFile;

  /// Milliseconds until the playlist lists [count] segments.
  Future<int> waitForSegments(int count, Duration timeout) async {
    final sw = Stopwatch()..start();
    final playlist = File('${dir.path}/index.m3u8');
    while (sw.elapsed < timeout) {
      if (playlist.existsSync() &&
          '#EXTINF'.allMatches(playlist.readAsStringSync()).length >= count) {
        return sw.elapsedMilliseconds;
      }
      await Future<void>.delayed(const Duration(milliseconds: 100));
    }
    throw TimeoutException('playlist has fewer than $count segments');
  }

  Future<void> stop() async {
    await _terminate(process);
    if (_pidFile.existsSync()) _pidFile.deleteSync();
    if (dir.existsSync()) dir.deleteSync(recursive: true);
  }
}

String mimeFor(String name) =>
    switch (name.substring(name.lastIndexOf('.') + 1).toLowerCase()) {
      'm3u8' => 'application/vnd.apple.mpegurl',
      'ts' => 'video/mp2t',
      'm4s' => 'video/iso.segment',
      'mp4' || 'm4v' || 'mov' => 'video/mp4',
      'webm' => 'video/webm',
      'vtt' => 'text/vtt',
      _ => 'application/octet-stream',
    };

const _corsHeaders = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Headers': '*',
  'Access-Control-Allow-Methods': 'GET, HEAD, OPTIONS',
};

/// docs/04 relay server: `/r/<token>/<file>` (HLS session dir) and
/// `/f/<token>/media.<ext>` (plain file with Range), CORS on everything.
class RelayServer {
  RelayServer._(this._server, this.host);

  static Future<RelayServer> start(
    InternetAddress address,
    void Function(Json request) onRequest,
  ) async {
    late final RelayServer relay;
    final router = Router()
      ..get('/r/<token>/<name>', (Request r, String t, String n) {
        return relay._hlsFile(t, n);
      })
      ..get('/f/<token>/<name>', (Request r, String t, String n) {
        return relay._file(r, t, n);
      });
    Handler handler(Handler inner) => (req) async {
      final sw = Stopwatch()..start();
      final res = req.method == 'OPTIONS' ? Response(204) : await inner(req);
      onRequest({
        'method': req.method,
        'path': req.url.path,
        'range': req.headers['range'],
        'status': res.statusCode,
        'length': res.contentLength,
        'ms': sw.elapsedMilliseconds,
        'ua': req.headers['user-agent'],
        'origin': req.headers['origin'],
      });
      return res.change(headers: _corsHeaders);
    };
    for (var port = 38400; port < 38500; port++) {
      try {
        final server = await shelf_io.serve(
          handler(router.call),
          address,
          port,
        );
        return relay = RelayServer._(server, address.address);
      } on SocketException {
        continue;
      }
    }
    throw StateError('no free port in 38400–38499 on ${address.address}');
  }

  final HttpServer _server;
  final String host;
  final _hls = <String, Directory>{};
  final _files = <String, File>{};
  final _startOffsets = <String, double>{};

  String get origin => 'http://$host:${_server.port}';

  /// [startOffset] adds `#EXT-X-START:TIME-OFFSET=-<s>` to served playlists.
  String addHls(Directory dir, {double? startOffset}) {
    final token = newToken();
    _hls[token] = dir;
    if (startOffset != null) _startOffsets[token] = startOffset;
    return '$origin/r/$token/index.m3u8';
  }

  String addFile(File file) {
    final token = newToken();
    _files[token] = file;
    return '$origin/f/$token/media${_ext(file.path)}';
  }

  Response _hlsFile(String token, String name) {
    final dir = _hls[token];
    if (dir == null || name.contains('..')) return Response.notFound(null);
    try {
      var bytes = File('${dir.path}/$name').readAsBytesSync();
      final offset = _startOffsets[token];
      if (offset != null && name.endsWith('.m3u8')) {
        bytes = utf8.encode(
          utf8
              .decode(bytes)
              .replaceFirst(
                '#EXTM3U\n',
                '#EXTM3U\n#EXT-X-START:TIME-OFFSET=-$offset,PRECISE=NO\n',
              ),
        );
      }
      return Response.ok(
        bytes,
        headers: {
          'Content-Type': mimeFor(name),
          if (name.endsWith('.m3u8')) 'Cache-Control': 'no-cache',
        },
      );
    } on FileSystemException {
      return Response.notFound(null);
    }
  }

  Response _file(Request r, String token, String name) {
    final file = _files[token];
    if (file == null || name != 'media${_ext(file.path)}') {
      return Response.notFound(null);
    }
    final size = file.lengthSync();
    final headers = {
      'Content-Type': mimeFor(file.path),
      'Accept-Ranges': 'bytes',
    };
    final range = r.headers['range'];
    if (range == null) {
      return Response.ok(
        file.openRead(),
        headers: {...headers, 'Content-Length': '$size'},
      );
    }
    final m = RegExp(r'^bytes=(\d*)-(\d*)$').firstMatch(range.trim());
    int? start;
    int? end;
    if (m != null && m[1]!.isNotEmpty) {
      start = int.parse(m[1]!);
      end = m[2]!.isEmpty ? size - 1 : min(int.parse(m[2]!), size - 1);
    } else if (m != null && m[2]!.isNotEmpty) {
      start = max(0, size - int.parse(m[2]!));
      end = size - 1;
    }
    if (start == null || end == null || start > end || start >= size) {
      return Response(
        HttpStatus.requestedRangeNotSatisfiable,
        headers: {...headers, 'Content-Range': 'bytes */$size'},
      );
    }
    return Response(
      HttpStatus.partialContent,
      body: file.openRead(start, end + 1),
      headers: {
        ...headers,
        'Content-Range': 'bytes $start-$end/$size',
        'Content-Length': '${end - start + 1}',
      },
    );
  }

  Future<void> close() => _server.close(force: true);
}

String _ext(String path) => path.substring(path.lastIndexOf('.'));

/// The laptop's IPv4 address on the device's /24 (a home LAN).
Future<InternetAddress> lanAddressFor(String deviceHost) async {
  final prefix = deviceHost.substring(0, deviceHost.lastIndexOf('.') + 1);
  for (final ni in await NetworkInterface.list(
    type: InternetAddressType.IPv4,
  )) {
    for (final a in ni.addresses) {
      if (a.address.startsWith(prefix)) return a;
    }
  }
  throw StateError(
    'no local IPv4 address on $prefix* (same network as the device?)',
  );
}
