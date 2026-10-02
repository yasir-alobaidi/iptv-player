// Plain Dart: runs in the relay's isolate.
import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math';
import 'dart:typed_data';

import 'package:iptv_player/core/logging/app_log.dart';
import 'package:iptv_player/core/logging/redact.dart';
import 'package:iptv_player/data/cast/relay/hls_playlists.dart';
import 'package:iptv_player/data/cast/relay/ts_programs.dart';

const _tag = 'relay';

/// One connection's worth of a provider's stream, built by the app from
/// the source (`StreamResolver`) whenever the proxy asks. It carries
/// credentials: never logged, never on a command line.
final class RelayUpstream {
  const new({
    required this.url,
    required this.maxConnections,
    this.userAgent,
    this.hls = false,
  });

  final String url;
  final String? userAgent;

  /// The provider's own HLS: its playlists are rewritten so the segments
  /// come through the proxy too.
  final bool hls;

  /// Streams the source allows at once.
  final int maxConnections;

  @override
  String toString() =>
      'RelayUpstream(hls: $hls, maxConnections: $maxConnections)';
}

/// The app's answer when the proxy asks for an upstream: one, or why not
/// (already redacted).
final class RelayResolved {
  const new({this.upstream, this.failure});

  final RelayUpstream? upstream;
  final String? failure;
}

/// Asks the app for [inputId]'s upstream, built afresh.
typedef RelayResolver = Future<RelayResolved> Function(String inputId);

/// Why the provider didn't give the proxy its stream.
final class RelayRefusal {
  const new(this.kind, {this.status, this.body = '', this.detail});

  final RelayRefusalKind kind;

  /// The provider's HTTP status; null when nothing answered.
  final int? status;

  /// The first bytes of its answer, redacted: what tells a full account
  /// ("MAX_CONNECTIONS_REACHED") from a refused one (docs/03).
  final String body;

  /// What happened, in the proxy's words.
  final String? detail;

  @override
  String toString() =>
      'RelayRefusal(${kind.name}${status == null ? '' : ', HTTP $status'}'
      '${detail == null ? '' : ', $detail'})';
}

enum RelayRefusalKind {
  /// The provider answered with an error status.
  refused,

  /// Nothing answered: no connection, a timeout, a reset.
  unreachable,

  /// The app couldn't build the stream's URL: the source is gone, or its
  /// keyring is locked.
  unresolved,

  /// The source's connections are all held by the relay's own other
  /// inputs (a probe still reading).
  connectionsInUse,
}

sealed class RelayProxyEvent {
  const new();
}

/// [inputId]'s provider refused it, or couldn't be reached.
final class RelayProxyRefused extends RelayProxyEvent {
  const new(this.inputId, this.refusal);

  final String inputId;
  final RelayRefusal refusal;
}

/// [inputId]'s live MPEG-TS stream changed its streams: a channel that
/// switched codec mid-stream, which FFmpeg, copying, never says.
final class RelayProxyStreamsChanged extends RelayProxyEvent {
  const new(this.inputId);

  final String inputId;
}

/// The provider connections the proxy holds for [sourceId] now (Phase 7
/// decision 3: the app sees exactly when they open and close).
final class RelayProxyConnections extends RelayProxyEvent {
  const new(this.sourceId, this.open);

  final String sourceId;
  final int open;
}

final class RelayProxyTimings {
  const new({
    this.connect = const Duration(seconds: 8),
    this.answer = const Duration(seconds: 15),
    this.idle = const Duration(seconds: 8),
    this.slotWait = const Duration(seconds: 10),
    this.resolve = const Duration(seconds: 10),
    this.limitRetries = const [
      Duration(seconds: 1),
      Duration(seconds: 1),
      Duration(seconds: 2),
    ],
    this.networkRetries = const [
      Duration(milliseconds: 500),
      Duration(seconds: 1),
      Duration(seconds: 2),
    ],
    this.hlsLinger = const Duration(seconds: 3),
  });

  /// For a connection to the provider.
  final Duration connect;

  /// For its answer to begin: a panel can take seconds to start a
  /// channel (docs/04's matrix has an 8 s slow start).
  final Duration answer;

  /// A live stream that sends nothing for this long has stalled: the
  /// proxy cuts FFmpeg's connection, and FFmpeg's reconnect gets a fresh
  /// one.
  final Duration idle;

  /// For one of the source's connections to come free.
  final Duration slotWait;

  /// For the app to build the stream's URL.
  final Duration resolve;

  /// Waits before trying again after a refusal that looks like a full
  /// account: a panel can take a moment to notice the connection the
  /// proxy just closed (ADR-010).
  final List<Duration> limitRetries;

  /// Waits before trying again when nothing answered.
  final List<Duration> networkRetries;

  /// How long a provider's HLS keeps its connection between requests:
  /// its playlist and segments are one stream.
  final Duration hlsLinger;
}

/// The relay's loopback proxy (Phase 7 decision 3). FFmpeg and ffprobe
/// read `http://127.0.0.1:<port>/in/<token>`, never the provider's URL:
/// - no credentials reach a command line or FFmpeg's messages;
/// - every connection asks the app for the stream's URL, built afresh
///   from the source, with the source's User-Agent (an expiring redirect
///   is followed fresh);
/// - the source's connections are counted, and a new one waits for one to
///   come free, up to the source's limit;
/// - the provider's refusals are read and reported.
///
/// A live stream from the provider never ends on its own: when it does
/// (a drop, a cut, a stall), the proxy cuts FFmpeg's connection without a
/// clean end, which FFmpeg's `-reconnect` takes as a cut and answers with
/// a new connection, so a fresh one is made. A provider's HLS has its
/// playlists rewritten so its segments come through here too.
final class RelayProxy {
  new _(this._server, this._resolve, this._log, this.timings, this._onEvent);

  /// On 127.0.0.1, a free port: nothing on the network can reach it.
  static Future<RelayProxy> start({
    required RelayResolver resolve,
    required AppLog log,
    void Function(RelayProxyEvent event)? onEvent,
    RelayProxyTimings timings = const RelayProxyTimings(),
  }) async {
    final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    final proxy = RelayProxy._(server, resolve, log, timings, onEvent);
    server.listen(
      (request) => unawaited(proxy._onRequest(request)),
      onError: (Object _) {},
    );
    return proxy;
  }

  final HttpServer _server;
  final RelayResolver _resolve;
  final AppLog _log;
  final RelayProxyTimings timings;
  final void Function(RelayProxyEvent event)? _onEvent;

  final _inputs = <String, _Input>{};
  final _byToken = <String, _Input>{};
  final _held = <String, int>{};
  var _freed = Completer<void>();
  var _closed = false;

  int get port => _server.port;

  /// The connections the proxy holds for [sourceId] now.
  int openFor(String sourceId) => _held[sourceId] ?? 0;

  /// Opens [inputId] (a relay session's, or a probe's) on [sourceId]:
  /// the URL FFmpeg or ffprobe reads. A [live] stream is reconnected when
  /// it ends; a file is passed as it is, with Range.
  String open(String inputId, {required String sourceId, required bool live}) {
    close(inputId);
    final token = newRelayToken();
    final input = _Input(inputId, token, sourceId, live: live);
    _inputs[inputId] = input;
    _byToken[token] = input;
    return 'http://127.0.0.1:$port/in/$token';
  }

  /// Forgets [inputId], and cuts whatever it has open.
  void close(String inputId) {
    final input = _inputs.remove(inputId);
    if (input == null) return;
    _byToken.remove(input.token);
    input.closed = true;
    for (final exchange in [...input.exchanges]) {
      exchange.abort();
    }
    _letGo(input, now: true);
  }

  Future<void> shutdown() async {
    _closed = true;
    [..._inputs.keys].forEach(close);
    await _server.close(force: true);
  }

  Future<void> _onRequest(HttpRequest request) async {
    final Socket client;
    try {
      client = await request.response.detachSocket(writeHeaders: false);
    } on Object {
      return;
    }
    final path = request.uri.pathSegments;
    final input = path.length >= 2 && path.length <= 3 && path[0] == 'in'
        ? _byToken[path[1]]
        : null;
    // `<n>` or `<n>.<ext>`: FFmpeg's HLS reader takes only segments whose
    // URL ends in an extension it knows (`allowed_segment_extensions`).
    final sub = path.length == 3
        ? int.tryParse(path[2].split('.').first)
        : null;
    if (input == null ||
        input.closed ||
        request.method != 'GET' ||
        (path.length == 3 && sub == null)) {
      _answer(client, 404, 'Not Found', 'not here\n');
      return;
    }
    final exchange = _Exchange(client);
    input.exchanges.add(exchange);
    try {
      await _serve(
        input,
        exchange,
        sub: sub,
        range: request.headers.value(HttpHeaders.rangeHeader),
      );
    } on Object catch (error, stack) {
      _log.warning(
        _tag,
        'The proxy failed on ${input.id}',
        error: _describe(error),
        stackTrace: stack,
      );
      exchange.abort();
    } finally {
      input.exchanges.remove(exchange);
    }
  }

  Future<void> _serve(
    _Input input,
    _Exchange exchange, {
    required int? sub,
    required String? range,
  }) async {
    final main = sub == null;
    Uri? target;
    if (!main) {
      target = input.resources[sub];
      if (target == null) {
        _answer(exchange.client, 404, 'Not Found', 'gone\n');
        return;
      }
    }
    var limitTries = 0;
    var networkTries = 0;
    while (true) {
      if (exchange.gone || input.closed) return exchange.abort();
      // The main stream of a live channel or a file is a new connection
      // every time FFmpeg asks: its URL is built afresh. A provider's HLS
      // keeps its URL between playlist refreshes, until something fails.
      final upstream = await _upstreamFor(input, refresh: main);
      if (upstream == null) {
        _answer(exchange.client, 502, 'Bad Gateway', 'no stream\n');
        return;
      }
      if (exchange.gone || input.closed) return exchange.abort();
      final url = target ?? Uri.parse(upstream.url);
      if (!await _takeSlot(input, upstream)) {
        _refuse(
          input,
          const RelayRefusal(
            RelayRefusalKind.connectionsInUse,
            detail: 'every connection of the source is in use',
          ),
        );
        _answer(exchange.client, 503, 'Service Unavailable', 'busy\n');
        return;
      }
      final opened = await _open(
        input,
        exchange,
        url,
        upstream,
        // A live channel starts at its live edge whatever FFmpeg read
        // before; a file and a segment are read where FFmpeg asks.
        range: main && input.live && !upstream.hls ? null : range,
      );
      switch (opened) {
        case _Opened(:final response, :final client, :final finalUrl):
          final status = response.statusCode;
          if (status >= 200 && status < 300) {
            await _pass(
              input,
              exchange,
              response,
              client,
              finalUrl: finalUrl,
              playlist:
                  (main && upstream.hls) ||
                  _namesPlaylist(finalUrl, response.headers.contentType),
              main: main,
            );
            return;
          }
          final body = await _head(response);
          client.close(force: true);
          _done(input);
          input.stale = true;
          if (_looksFull(status, body) &&
              limitTries < timings.limitRetries.length &&
              !exchange.gone) {
            _log.info(
              _tag,
              '${input.id}: the provider says HTTP $status (full?); '
              'trying again',
            );
            await Future<void>.delayed(timings.limitRetries[limitTries++]);
            continue;
          }
          _refuse(
            input,
            RelayRefusal(
              RelayRefusalKind.refused,
              status: status,
              body: body,
              detail: 'the provider answered HTTP $status',
            ),
          );
          _answer(
            exchange.client,
            status,
            response.reasonPhrase,
            body.isEmpty ? 'refused\n' : body,
          );
          return;
        case _Unreachable(:final detail):
          _done(input);
          input.stale = true;
          if (networkTries < timings.networkRetries.length && !exchange.gone) {
            await Future<void>.delayed(timings.networkRetries[networkTries++]);
            continue;
          }
          _refuse(
            input,
            RelayRefusal(RelayRefusalKind.unreachable, detail: detail),
          );
          _answer(exchange.client, 502, 'Bad Gateway', 'no answer\n');
          return;
        case _Abandoned():
          _done(input);
          return exchange.abort();
      }
    }
  }

  /// The input's upstream: asked of the app when [refresh] says so, or
  /// none is known, or the last one failed. Null after reporting why not.
  Future<RelayUpstream?> _upstreamFor(
    _Input input, {
    required bool refresh,
  }) async {
    final known = input.upstream;
    if (known != null && !input.stale && !(refresh && !known.hls)) {
      return known;
    }
    RelayResolved resolved;
    try {
      resolved = await _resolve(input.id).timeout(timings.resolve);
    } on Object catch (error) {
      resolved = RelayResolved(failure: _describe(error));
    }
    final upstream = resolved.upstream;
    if (upstream == null) {
      _refuse(
        input,
        RelayRefusal(
          RelayRefusalKind.unresolved,
          detail: redact(resolved.failure ?? 'no stream URL'),
        ),
      );
      return null;
    }
    input
      ..upstream = upstream
      ..stale = false;
    return upstream;
  }

  /// One of the source's connections for [input], waiting for one to
  /// come free; false when none did in time.
  Future<bool> _takeSlot(_Input input, RelayUpstream upstream) async {
    input.linger?.cancel();
    input.linger = null;
    if (input.active > 0 || input.holdsSlot) {
      input.active++;
      return true;
    }
    final limit = max(1, upstream.maxConnections);
    final deadline = DateTime.now().add(timings.slotWait);
    while ((_held[input.sourceId] ?? 0) >= limit) {
      final left = deadline.difference(DateTime.now());
      if (left <= Duration.zero || input.closed || _closed) return false;
      try {
        await _freed.future.timeout(left);
      } on TimeoutException {
        return false;
      }
    }
    _held[input.sourceId] = (_held[input.sourceId] ?? 0) + 1;
    input
      ..holdsSlot = true
      ..active = 1;
    _onEvent?.call(
      RelayProxyConnections(input.sourceId, _held[input.sourceId]!),
    );
    return true;
  }

  /// One of [input]'s upstream requests ended.
  void _done(_Input input) {
    if (input.active > 0) input.active--;
    if (input.active > 0) return;
    // A provider's HLS is one stream across its requests: its connection
    // is let go only once FFmpeg stops asking.
    final hls = input.upstream?.hls ?? false;
    if (hls && !input.closed) {
      input.linger?.cancel();
      input.linger = Timer(timings.hlsLinger, () => _letGo(input));
    } else {
      _letGo(input);
    }
  }

  void _letGo(_Input input, {bool now = false}) {
    input.linger?.cancel();
    input.linger = null;
    if (!input.holdsSlot || (input.active > 0 && !now)) return;
    input
      ..holdsSlot = false
      ..active = 0;
    final open = max(0, (_held[input.sourceId] ?? 1) - 1);
    if (open == 0) {
      _held.remove(input.sourceId);
    } else {
      _held[input.sourceId] = open;
    }
    _onEvent?.call(RelayProxyConnections(input.sourceId, open));
    final freed = _freed;
    _freed = Completer<void>();
    freed.complete();
  }

  Future<_Attempt> _open(
    _Input input,
    _Exchange exchange,
    Uri url,
    RelayUpstream upstream, {
    String? range,
  }) async {
    final client = HttpClient()
      ..connectionTimeout = timings.connect
      ..autoUncompress = false
      ..userAgent = null;
    exchange.upstreamClient = client;
    try {
      final request = await client.getUrl(url).timeout(timings.connect);
      request
        ..followRedirects = true
        ..maxRedirects = 5
        ..persistentConnection = false;
      if (upstream.userAgent case final agent?) {
        request.headers.set(HttpHeaders.userAgentHeader, agent);
      }
      if (range != null) request.headers.set(HttpHeaders.rangeHeader, range);
      final response = await request.close().timeout(timings.answer);
      if (exchange.gone || input.closed) {
        client.close(force: true);
        return const _Abandoned();
      }
      var finalUrl = url;
      for (final hop in response.redirects) {
        finalUrl = finalUrl.resolveUri(hop.location);
      }
      return _Opened(response, client, finalUrl);
    } on Object catch (error) {
      client.close(force: true);
      if (exchange.gone || input.closed) return const _Abandoned();
      return _Unreachable(_describe(error));
    }
  }

  /// Passes a 2xx answer on: a playlist rewritten whole, anything else as
  /// it comes, with FFmpeg's pace (the socket's back-pressure) as the
  /// provider's.
  Future<void> _pass(
    _Input input,
    _Exchange exchange,
    HttpClientResponse response,
    HttpClient upstreamClient, {
    required Uri finalUrl,
    required bool playlist,
    required bool main,
  }) async {
    final client = exchange.client;
    if (playlist) {
      final List<int> bytes;
      try {
        bytes = await _readAll(response, 4 << 20).timeout(timings.idle);
      } on Object catch (error) {
        upstreamClient.close(force: true);
        _done(input);
        input.stale = true;
        _log.info(_tag, '${input.id}: a playlist broke: ${_describe(error)}');
        return exchange.abort();
      }
      upstreamClient.close(force: true);
      _done(input);
      final text = utf8.decode(bytes, allowMalformed: true);
      final body = looksLikePlaylist(text)
          ? rewritePlaylist(text, finalUrl, (uri) => input.proxied(uri, port))
          : text;
      _answer(
        client,
        response.statusCode,
        response.reasonPhrase,
        body,
        type: 'application/vnd.apple.mpegurl',
      );
      return;
    }

    final length = response.contentLength;
    final chunked = length < 0;
    final type = response.headers.contentType ?? 'video/mp2t';
    final head = StringBuffer(
      'HTTP/1.1 ${response.statusCode} ${response.reasonPhrase}\r\n',
    )..write('Content-Type: $type\r\n');
    if (chunked) {
      head.write('Transfer-Encoding: chunked\r\n');
    } else {
      head.write('Content-Length: $length\r\n');
    }
    for (final name in const ['content-range', 'accept-ranges']) {
      if (response.headers.value(name) case final value?) {
        head.write('$name: $value\r\n');
      }
    }
    head.write('Connection: close\r\n\r\n');
    client.add(utf8.encode('$head'));

    // A live channel's program map is watched for a change of codec.
    final programs = main && input.live && !(input.upstream?.hls ?? false)
        ? (input.programs ??= TsProgramWatch(
            (before, after) => _programsChanged(input, before, after),
          ))
        : null;
    programs?.restart();

    // Ends: the provider's body ends (finished), breaks, or goes quiet,
    // or FFmpeg leaves.
    var ending = _Ending.finished;
    var sent = 0;
    late StreamSubscription<List<int>> upstream;
    final body = StreamController<List<int>>(sync: true);
    Timer? idle;
    void stop(_Ending why) {
      if (body.isClosed) return;
      ending = why;
      idle?.cancel();
      unawaited(upstream.cancel());
      unawaited(body.close());
    }

    void watch() {
      idle?.cancel();
      idle = Timer(timings.idle, () => stop(_Ending.quiet));
    }

    body
      ..onListen = () {
        upstream = response.listen(
          (chunk) {
            if (chunk.isEmpty || body.isClosed) return;
            watch();
            programs?.add(chunk);
            sent += chunk.length;
            if (chunked) {
              // The chunk's frame around its bytes, never a copy of them.
              body
                ..add(ascii.encode('${chunk.length.toRadixString(16)}\r\n'))
                ..add(chunk)
                ..add(_lineEnd);
            } else {
              body.add(chunk);
            }
          },
          onError: (Object _) => stop(_Ending.broken),
          onDone: () => stop(_Ending.finished),
          cancelOnError: true,
        );
        watch();
      }
      ..onPause = (() => upstream.pause())
      ..onResume = (() => upstream.resume())
      ..onCancel = () {
        if (!body.isClosed) stop(_Ending.left);
      };
    exchange.onGone = () => stop(_Ending.left);
    try {
      await client.addStream(body.stream);
    } on Object {
      ending = _Ending.left;
    }
    idle?.cancel();
    upstreamClient.close(force: true);
    _done(input);

    final complete = chunked || sent >= length;
    final reconnect = main && input.live && !(input.upstream?.hls ?? false);
    final cut = ending != _Ending.finished || !complete || reconnect;
    if (cut) input.stale = true;
    if (ending == _Ending.left || exchange.gone) return exchange.abort();
    if (main && input.live) {
      _log.info(
        _tag,
        '${input.id}: the provider stream ${ending.words} after '
        '${(sent / 1e6).toStringAsFixed(1)} MB; FFmpeg reconnects',
      );
    }
    // A cut, not an end, unless it really is one: FFmpeg reconnects after
    // a cut (a live stream, a body cut short) and finishes after an end.
    if (cut) return exchange.abort();
    if (chunked) client.add(_lastChunk);
    await exchange.finish();
  }

  void _programsChanged(
    _Input input,
    List<TsStream> before,
    List<TsStream> after,
  ) {
    String types(List<TsStream> streams) =>
        [for (final s in streams) '0x${s.type.toRadixString(16)}'].join(' ');
    _log.warning(
      _tag,
      "${input.id}: the stream's programs changed: ${types(before)} → "
      '${types(after)}',
    );
    _onEvent?.call(RelayProxyStreamsChanged(input.id));
  }

  void _refuse(_Input input, RelayRefusal refusal) {
    _log.warning(_tag, '${input.id}: $refusal');
    _onEvent?.call(RelayProxyRefused(input.id, refusal));
  }

  static bool _namesPlaylist(Uri url, ContentType? type) {
    final path = url.path.toLowerCase();
    return path.endsWith('.m3u8') ||
        path.endsWith('.m3u') ||
        (type?.subType.contains('mpegurl') ?? false);
  }

  /// docs/03's hint that an account is full: a 429, or an answer that
  /// says so (the fake panel's MAX_CONNECTIONS_REACHED).
  static bool _looksFull(int status, String body) {
    if (status == 429) return true;
    if (status < 400 || status >= 500) return false;
    final text = body.toLowerCase();
    return text.contains('max_connections') ||
        text.contains('max connections') ||
        text.contains('connection limit') ||
        text.contains('too many');
  }

  static Future<String> _head(HttpClientResponse response) async {
    final bytes = BytesBuilder(copy: false);
    try {
      await for (final chunk in response.timeout(const Duration(seconds: 2))) {
        bytes.add(chunk);
        if (bytes.length >= 512) break;
      }
    } on Object {
      // What came is enough.
    }
    final all = bytes.takeBytes();
    return redact(
      utf8.decode(all.sublist(0, min(all.length, 512)), allowMalformed: true),
    ).trim();
  }

  static Future<List<int>> _readAll(Stream<List<int>> body, int cap) async {
    final bytes = BytesBuilder(copy: false);
    await for (final chunk in body) {
      bytes.add(chunk);
      if (bytes.length > cap) throw const FormatException('too large');
    }
    return bytes.takeBytes();
  }

  static void _answer(
    Socket client,
    int status,
    String reason,
    String text, {
    String type = 'text/plain; charset=utf-8',
  }) {
    final body = utf8.encode(text);
    try {
      client
        ..add(
          utf8.encode(
            'HTTP/1.1 $status ${reason.isEmpty ? 'Error' : reason}\r\n'
            'Content-Type: $type\r\n'
            'Content-Length: ${body.length}\r\n'
            'Connection: close\r\n\r\n',
          ),
        )
        ..add(body);
      unawaited(client.close().catchError((Object _) => null));
    } on Object {
      client.destroy();
    }
  }

  /// An error in words that never carry a URL.
  static String _describe(Object error) => switch (error) {
    TimeoutException() => 'timed out',
    SocketException(:final osError) =>
      'no connection${osError == null ? '' : ' (${osError.message})'}',
    TlsException() => 'TLS failed',
    HttpException() => 'a broken answer',
    _ => redact('$error'),
  };

  static final List<int> _lastChunk = ascii.encode('0\r\n\r\n');
  static final List<int> _lineEnd = ascii.encode('\r\n');
}

/// A session token: 128 random bits (docs/04).
String newRelayToken() {
  final random = Random.secure();
  return [
    for (var i = 0; i < 16; i++)
      random.nextInt(256).toRadixString(16).padLeft(2, '0'),
  ].join();
}

final class _Input {
  new(this.id, this.token, this.sourceId, {required this.live});

  final String id;
  final String token;
  final String sourceId;
  final bool live;

  RelayUpstream? upstream;

  /// Ask the app again before the next request: the last one failed.
  bool stale = true;

  /// Upstream requests in flight.
  int active = 0;
  bool holdsSlot = false;
  Timer? linger;
  bool closed = false;

  /// A live MPEG-TS stream's program map, across reconnects.
  TsProgramWatch? programs;
  final exchanges = <_Exchange>{};

  /// A provider's HLS: the URIs its playlists named, by number.
  final resources = <int, Uri>{};
  final _numbers = <String, int>{};
  var _next = 0;

  String proxied(Uri absolute, int port) {
    final key = '$absolute';
    var number = _numbers[key];
    if (number == null) {
      number = _next++;
      _numbers[key] = number;
      resources[number] = absolute;
      // A live playlist names new segments forever; the old ones go.
      if (resources.length > 2048) {
        final oldest = resources.keys.first;
        _numbers.remove('${resources.remove(oldest)}');
      }
    }
    final extension = RegExp(r'\.[A-Za-z0-9]{1,5}$')
        .firstMatch(absolute.pathSegments.lastOrNull ?? '');
    return 'http://127.0.0.1:$port/in/$token/$number'
        '${extension?[0]?.toLowerCase() ?? ''}';
  }
}

/// One request from FFmpeg, on its own socket.
final class _Exchange {
  new(this.client) {
    client.listen(
      (_) {},
      onDone: _leave,
      onError: (Object _) => _leave(),
      cancelOnError: true,
    );
  }

  final Socket client;
  HttpClient? upstreamClient;
  void Function()? onGone;
  bool gone = false;
  var _ended = false;

  void _leave() {
    if (gone) return;
    gone = true;
    onGone?.call();
    upstreamClient?.close(force: true);
  }

  /// A cut: no clean end, so FFmpeg reconnects.
  void abort() {
    if (_ended) return;
    _ended = true;
    gone = true;
    upstreamClient?.close(force: true);
    client.destroy();
  }

  Future<void> finish() async {
    if (_ended) return;
    _ended = true;
    try {
      await client.close();
    } on Object {
      client.destroy();
    }
  }
}

sealed class _Attempt {
  const new();
}

final class _Opened extends _Attempt {
  const new(this.response, this.client, this.finalUrl);

  final HttpClientResponse response;
  final HttpClient client;
  final Uri finalUrl;
}

final class _Unreachable extends _Attempt {
  const new(this.detail);

  final String detail;
}

final class _Abandoned extends _Attempt {
  const new();
}

enum _Ending {
  finished('ended'),
  broken('broke'),
  quiet('went quiet'),
  left('was left');

  new(this.words);

  final String words;
}
