/// Wiring: one shelf pipeline over the API, the streams and the admin stub.
library;

import 'dart:io';

import 'package:fake_provider/admin.dart';
import 'package:fake_provider/get_php.dart';
import 'package:fake_provider/player_api.dart';
import 'package:fake_provider/server_state.dart';
import 'package:fake_provider/streams.dart';
import 'package:shelf/shelf.dart';
import 'package:shelf/shelf_io.dart' as io;
import 'package:shelf_router/shelf_router.dart';

/// A running fake provider. [start] also runs the stream relay's startup
/// cleanup, so a previous run's ffmpeg processes are gone before this one
/// serves anything (hard rule 8).
class FakeProviderServer {
  /// [start] is the way in; this only holds what it built.
  new(this._server, this._relay, this.state);

  static Future<FakeProviderServer> start({
    required FakeServerState state,
    required int port,
    String address = '127.0.0.1',
    bool verbose = false,
  }) async {
    final relay = StreamRelay(state, verbose: verbose);
    await relay.cleanStaleProcesses();

    final router = Router()
      ..all('/player_api.php', playerApiHandler(state))
      ..get('/get.php', getPhpHandler(state))
      ..get('/', (Request request) => Response.ok(_index(state)));

    var handler = const Pipeline().addHandler(
      Cascade()
          .add(relay.handler)
          .add(adminHandler(state))
          .add(router.call)
          .handler,
    );
    if (verbose) {
      handler = const Pipeline()
          .addMiddleware(logRequests(logger: _log))
          .addHandler(handler);
    }

    final server = await io.serve(handler, address, port);
    return FakeProviderServer(server, relay, state);
  }

  final HttpServer _server;
  final StreamRelay _relay;
  final FakeServerState state;

  Uri get url => Uri.parse('http://${_server.address.host}:${_server.port}');

  Future<void> close() async {
    await _relay.close();
    await _server.close(force: true);
  }

  /// Credentials are the profile's own `test`/`test`, but the log still goes
  /// through the same redaction the app uses (hard rule 3): a stream URL
  /// carries them in its path, and these lines get pasted into issues.
  static void _log(String message, bool isError) {
    final line = message.replaceAllMapped(
      RegExp('/(live|movie|series)/[^/]+/[^/]+/'),
      (m) => '/${m[1]}/***/***/',
    );
    if (isError) {
      stderr.writeln(line);
    } else {
      stdout.writeln(line);
    }
  }

  static String _index(FakeServerState state) {
    final p = state.profile;
    return '''
fake IPTV provider — profile "${p.name}"
  ${p.liveCount} channels · ${p.movieCount} movies · ${p.seriesCount} series
  credentials ${p.username} / ${p.password} · max_connections ${state.maxConnections}

  GET /player_api.php?username=&password=[&action=]
  GET /live/{username}/{password}/{stream_id}.ts
  GET|POST|DELETE /admin/faults

docs/06-quality.md describes the endpoints that are still to come.
''';
  }
}
