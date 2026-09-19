// The fake provider (docs/06) in its own `dart` process, started and
// stopped by the test that uses it: in-process, its JSON encoding and its
// ffmpeg supervision would count against the app being measured.

import 'dart:async';
import 'dart:convert';
import 'dart:io';

/// The media samples live streams loop (tools/media_samples/generate.sh);
/// not committed, so CI has none.
final samplesDirectory = Directory('tools/media_samples/out');

/// Live streams need the samples and an ffmpeg; the API needs neither.
bool get streamsAvailable =>
    samplesDirectory.existsSync() &&
    File('${samplesDirectory.path}/h264_1080p50_aac.ts').existsSync();

final class FakePanel {
  new _(this._process, this.port, this._scratch);

  /// [streams] points the server at the real samples, so `/live/…` plays;
  /// without it an empty folder satisfies its start-up check.
  static Future<FakePanel> start({
    String profile = 'default',
    bool streams = false,
    List<String> extra = const [],
  }) async {
    final port = await _freePort();
    final scratch = await Directory.systemTemp.createTemp('iptv_panel');
    final process = await Process.start('dart', [
      'run',
      'tools/fake_provider/bin/server.dart',
      ...['--profile', profile, '--port', '$port'],
      ...['--samples', if (streams) samplesDirectory.path else scratch.path],
      ...['--run-dir', scratch.path],
      ...extra,
    ]);
    unawaited(process.stdout.drain<void>());
    final errors = StringBuffer();
    process.stderr.transform(utf8.decoder).listen(errors.write);
    final panel = FakePanel._(process, port, scratch);
    final client = HttpClient();
    try {
      for (var attempt = 0; attempt < 240; attempt++) {
        try {
          final request = await client.get('127.0.0.1', port, '/');
          await (await request.close()).drain<void>();
          return panel;
        } on SocketException {
          await Future<void>.delayed(const Duration(milliseconds: 250));
        }
      }
    } finally {
      client.close(force: true);
    }
    await panel.stop();
    throw StateError('the fake provider did not start: $errors');
  }

  final Process _process;
  final int port;
  final Directory _scratch;

  String get url => 'http://127.0.0.1:$port';

  /// A live channel's stream URL with the fake's credentials.
  String live(int id, {String extension = 'ts'}) =>
      '$url/live/test/test/$id.$extension';

  /// `user_info.active_cons`: the streams the panel has open right now.
  Future<int> activeConnections() async {
    final client = HttpClient();
    try {
      final request = await client.getUrl(
        Uri.parse('$url/player_api.php?username=test&password=test'),
      );
      final body = await (await request.close()).transform(utf8.decoder).join();
      final info =
          (jsonDecode(body) as Map<String, dynamic>)['user_info']
              as Map<String, dynamic>;
      return int.parse('${info['active_cons']}');
    } finally {
      client.close(force: true);
    }
  }

  /// Sets faults through `/admin/faults` (docs/06).
  Future<void> setFaults(Map<String, Object?> faults) async {
    final client = HttpClient();
    try {
      final request = await client.postUrl(Uri.parse('$url/admin/faults'));
      request.headers.contentType = ContentType.json;
      request.write(jsonEncode(faults));
      await (await request.close()).drain<void>();
    } finally {
      client.close(force: true);
    }
  }

  Future<void> stop() async {
    // SIGINT lets the server reap its ffmpeg children (hard rule 8).
    _process.kill(ProcessSignal.sigint);
    await _process.exitCode.timeout(
      const Duration(seconds: 5),
      onTimeout: () {
        _process.kill(ProcessSignal.sigkill);
        return -1;
      },
    );
    if (_scratch.existsSync()) await _scratch.delete(recursive: true);
  }
}

Future<int> _freePort() async {
  final socket = await ServerSocket.bind(InternetAddress.loopbackIPv4, 0);
  final port = socket.port;
  await socket.close();
  return port;
}
