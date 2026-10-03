// Plain Dart: runs in the relay's isolate.
import 'dart:async';
import 'dart:io';
import 'dart:math';

import 'package:iptv_player/core/cast/cast_relay_ports.dart';
import 'package:iptv_player/core/logging/app_log.dart';
import 'package:iptv_player/data/cast/relay/relay_proxy.dart';
import 'package:path/path.dart' as p;

const _tag = 'relay';

/// docs/04's ports: the firewall help names them.
const int relayFirstPort = castRelayFirstPort;
const int relayLastPort = castRelayLastPort;

/// Serves a continuous stream's request: the server has set the CORS
/// headers; the handler answers.
typedef RelayStreamHandler = Future<void> Function(HttpRequest request);

/// The server the TV fetches from (docs/04 "Relay HTTP server"), on this
/// computer's address on the TV's network: the local address of the Cast
/// connection's own socket, which is the route the system uses to reach
/// the TV. Each session has a random 128-bit token in its path:
/// - `/r/<token>/index.m3u8` and `/r/<token>/<segment>.ts`: HLS from a
///   session's folder;
/// - `/p/<token>/stream.mp4`: one continuous fragmented MP4, made for the
///   request;
/// - `/f/<token>/media.<ext>`: a file, with Range.
///
/// Every answer carries the CORS headers the receiver needs (its requests
/// come from `https://www.gstatic.com`); playlists and continuous streams
/// are `no-cache`; anything else is a 404.
final class RelayServer {
  new _(this._server, this.address, this._log, this._onFetched);

  /// The first free port in [first]–[last] on [address].
  static Future<RelayServer> bind(
    String address, {
    required AppLog log,
    void Function(String token)? onFetched,
    int first = relayFirstPort,
    int last = relayLastPort,
  }) async {
    final host = InternetAddress(address);
    for (var port = first; port <= last; port++) {
      final HttpServer server;
      try {
        server = await HttpServer.bind(host, port);
      } on SocketException catch (error) {
        // An address that isn't this computer's any more won't change
        // with the port; anything else (in use here or by another
        // program) may.
        if (_notHere(error)) rethrow;
        continue;
      }
      server
        ..autoCompress = false
        ..defaultResponseHeaders.clear();
      final relay = RelayServer._(server, address, log, onFetched);
      server.listen(
        (request) => unawaited(relay._onRequest(request)),
        onError: (Object _) {},
      );
      return relay;
    }
    throw SocketException('every port in $first–$last is in use on $address');
  }

  final HttpServer _server;
  final AppLog _log;
  final void Function(String token)? _onFetched;

  /// This computer's address on the TV's network.
  final String address;

  final _routes = <String, _Route>{};
  final _fetched = <String>{};

  int get port => _server.port;

  /// `http://192.168.1.20:38400`, brackets and all for IPv6.
  String get origin => Uri(scheme: 'http', host: address, port: port).origin;

  bool get isEmpty => _routes.isEmpty;

  /// Serves the HLS FFmpeg writes in [folder].
  String serveHls(Directory folder) {
    final token = _add(_HlsRoute(folder));
    return '$origin/r/$token/index.m3u8';
  }

  /// Serves a continuous stream: [handler] answers each request.
  String serveStream(RelayStreamHandler handler) {
    final token = _add(_StreamRoute(handler));
    return '$origin/p/$token/stream.mp4';
  }

  /// Serves [file] with Range requests (docs/04 "Direct file"; the
  /// casting view's picture), typed by [extension] (`.png`) or else its
  /// own.
  String serveFile(File file, {String? extension}) {
    final type = extension ?? p.extension(file.path).toLowerCase();
    final token = _add(_FileRoute(file, 'media$type'));
    return '$origin/f/$token/media$type';
  }

  /// The token in [url], one of this server's.
  static String? tokenOf(String url) {
    final path = Uri.tryParse(url)?.pathSegments ?? const [];
    return path.length == 3 ? path[1] : null;
  }

  /// Stops serving [token]: its URL answers 404 from now on.
  void remove(String token) {
    _routes.remove(token);
    _fetched.remove(token);
  }

  Future<void> close() => _server.close(force: true);

  String _add(_Route route) {
    final token = newRelayToken();
    _routes[token] = route;
    return token;
  }

  Future<void> _onRequest(HttpRequest request) async {
    final response = request.response;
    relayCorsHeaders.forEach(response.headers.set);
    try {
      if (request.method == 'OPTIONS') {
        response.statusCode = HttpStatus.noContent;
        await response.close();
        return;
      }
      final path = request.uri.pathSegments;
      final route = path.length == 3 ? _routes[path[1]] : null;
      final head = request.method == 'HEAD';
      if (route == null ||
          route.prefix != path[0] ||
          (request.method != 'GET' && !head)) {
        return await _notFound(response);
      }
      final token = path[1];
      if (_fetched.add(token)) _onFetched?.call(token);
      switch (route) {
        case _HlsRoute(:final folder):
          await _hls(request, folder, path[2], head: head);
        case _StreamRoute(:final handler):
          if (path[2] != 'stream.mp4') return await _notFound(response);
          await handler(request);
        case _FileRoute(:final file, :final name):
          if (path[2] != name) return await _notFound(response);
          await _file(request, file, name, head: head);
      }
    } on Object catch (error) {
      _log.info(
        _tag,
        'A request to the relay ended early: ${error.runtimeType}',
      );
      try {
        response.statusCode = HttpStatus.internalServerError;
        await response.close();
      } on Object {
        // The answer had begun, or the TV left.
      }
    }
  }

  static Future<void> _notFound(HttpResponse response) async {
    response
      ..statusCode = HttpStatus.notFound
      ..headers.contentType = ContentType.text
      ..write('not here\n');
    await response.close();
  }

  static final _segmentName = RegExp(r'^[A-Za-z0-9_-]{1,64}\.(m3u8|ts|m4s)$');

  Future<void> _hls(
    HttpRequest request,
    Directory folder,
    String name, {
    required bool head,
  }) async {
    final response = request.response;
    if (!_segmentName.hasMatch(name)) return await _notFound(response);
    final file = File(p.join(folder.path, name));
    final int length;
    try {
      length = await file.length();
    } on FileSystemException {
      // Not written yet, or gone with an old segment.
      return await _notFound(response);
    }
    response.headers
      ..set(HttpHeaders.contentTypeHeader, relayMimeType(name))
      ..contentLength = length;
    if (name.endsWith('.m3u8')) {
      response.headers.set(HttpHeaders.cacheControlHeader, 'no-cache');
    }
    if (!head) {
      try {
        await response.addStream(file.openRead());
      } on FileSystemException {
        // Deleted under us (Windows); the TV asks the next one.
      }
    }
    await response.close();
  }

  /// [name] is what it is served as (`media.png`): its type, whatever
  /// the file is called on disk (the artwork cache's have no extension).
  static Future<void> _file(
    HttpRequest request,
    File file,
    String name, {
    required bool head,
  }) async {
    final response = request.response;
    final int size;
    try {
      size = await file.length();
    } on FileSystemException {
      return await _notFound(response);
    }
    response.headers
      ..set(HttpHeaders.contentTypeHeader, relayMimeType(name))
      ..set(HttpHeaders.acceptRangesHeader, 'bytes');
    final range = request.headers.value(HttpHeaders.rangeHeader);
    final (start, end) = range == null ? (0, size - 1) : _range(range, size);
    if (start == null || end == null) {
      response
        ..statusCode = HttpStatus.requestedRangeNotSatisfiable
        ..headers.set(HttpHeaders.contentRangeHeader, 'bytes */$size');
      await response.close();
      return;
    }
    if (range != null) {
      response
        ..statusCode = HttpStatus.partialContent
        ..headers.set(
          HttpHeaders.contentRangeHeader,
          'bytes $start-$end/$size',
        );
    }
    response.headers.contentLength = size == 0 ? 0 : end - start + 1;
    if (!head && size > 0) {
      await response.addStream(file.openRead(start, end + 1));
    }
    await response.close();
  }

  /// `bytes=a-b`, `bytes=a-`, `bytes=-n`; (null, null) when it can't be
  /// satisfied.
  static (int?, int?) _range(String header, int size) {
    final match = RegExp(r'^bytes=(\d*)-(\d*)$').firstMatch(header.trim());
    if (match == null || size == 0) return (null, null);
    final from = match[1]!;
    final to = match[2]!;
    int start;
    int end;
    if (from.isNotEmpty) {
      start = int.parse(from);
      end = to.isEmpty ? size - 1 : min(int.parse(to), size - 1);
    } else if (to.isNotEmpty) {
      start = max(0, size - int.parse(to));
      end = size - 1;
    } else {
      return (null, null);
    }
    if (start > end || start >= size) return (null, null);
    return (start, end);
  }

  static bool _notHere(SocketException error) {
    final code = error.osError?.errorCode;
    // EADDRNOTAVAIL: 99 on Linux, 49 on macOS, 10049 (WSAEADDRNOTAVAIL)
    // on Windows.
    return code == 99 || code == 49 || code == 10049;
  }
}

/// Every answer's: the receiver's requests come from
/// `https://www.gstatic.com` (docs/04).
const relayCorsHeaders = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Headers': '*',
  'Access-Control-Allow-Methods': 'GET, HEAD, OPTIONS',
};

/// docs/04's MIME types, by extension.
String relayMimeType(String name) => switch (p.extension(name).toLowerCase()) {
  '.m3u8' => 'application/vnd.apple.mpegurl',
  '.ts' => 'video/mp2t',
  '.m4s' => 'video/iso.segment',
  '.mp4' || '.m4v' || '.mov' => 'video/mp4',
  '.webm' => 'video/webm',
  '.vtt' => 'text/vtt',
  '.jpg' || '.jpeg' => 'image/jpeg',
  '.png' => 'image/png',
  '.webp' => 'image/webp',
  _ => 'application/octet-stream',
};

sealed class _Route {
  const new(this.prefix);

  final String prefix;
}

final class _HlsRoute extends _Route {
  const new(this.folder) : super('r');

  final Directory folder;
}

final class _StreamRoute extends _Route {
  const new(this.handler) : super('p');

  final RelayStreamHandler handler;
}

final class _FileRoute extends _Route {
  const new(this.file, this.name) : super('f');

  final File file;
  final String name;
}

/// A picture's extension from its first bytes (the artwork cache's files
/// have none): `.jpg`, `.png` or `.webp`, the types the TV shows; null
/// for anything else.
String? pictureExtension(List<int> head) {
  bool starts(List<int> magic, [int at = 0]) {
    if (head.length < at + magic.length) return false;
    for (var i = 0; i < magic.length; i++) {
      if (head[at + i] != magic[i]) return false;
    }
    return true;
  }

  if (starts(const [0xff, 0xd8, 0xff])) return '.jpg';
  if (starts(const [0x89, 0x50, 0x4e, 0x47, 0x0d, 0x0a, 0x1a, 0x0a])) {
    return '.png';
  }
  // RIFF, a size, WEBP.
  if (starts(const [0x52, 0x49, 0x46, 0x46]) &&
      starts(const [0x57, 0x45, 0x42, 0x50], 8)) {
    return '.webp';
  }
  return null;
}
