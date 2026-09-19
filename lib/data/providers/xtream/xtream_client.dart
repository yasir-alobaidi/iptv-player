import 'dart:async';
import 'dart:io';
import 'dart:math';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:iptv_player/core/isolates/background.dart';
import 'package:iptv_player/core/result.dart';
import 'package:iptv_player/core/streams/idle_timeout.dart';
import 'package:iptv_player/data/providers/provider_http.dart';
import 'package:iptv_player/data/providers/xtream/xtream_models.dart';
import 'package:iptv_player/data/providers/xtream/xtream_parse.dart';

export 'package:iptv_player/data/providers/provider_http.dart'
    show defaultUserAgent;

/// Bodies bigger than this are decoded and parsed in a background isolate
/// (hard rule 2). A 50k-channel list is ~20 MB; categories and the account
/// are a few KB and not worth an isolate.
const int backgroundDecodeThreshold = 256 * 1024;

/// One Xtream Codes panel, for one source (docs/02 "Xtream Codes API").
///
/// - **Every request is built from `server`**, never from a redirect or
///   from `server_info`: a load balancer's redirect can carry a token that
///   expires, so the next request starts from the original again.
/// - **One request at a time.** Calls queue behind each other, because
///   panels block clients that fire in parallel (hard rule 7).
/// - **429 and 5xx back off and retry** — honouring `Retry-After` — up to
///   [maxAttempts] in all; so does a connection that drops mid-body.
/// - **Nothing throws.** Every call returns a [Result]; failures carry
///   redacted detail only (`AppFailure` masks the query's credentials).
final class XtreamClient {
  new({
    required String server,
    required this._username,
    required this._password,
    String? userAgent,
    this.maxAttempts = 3,
    this.idleTimeout = const Duration(seconds: 30),
    Dio? dio,
    Future<void> Function(Duration)? delay,
  }) : _server = Uri.parse(server),
       _delay = delay ?? Future<void>.delayed,
       _dio =
           dio ??
           Dio(
             BaseOptions(
               connectTimeout: const Duration(seconds: 15),
               // No receiveTimeout: dio implements it by replacing a Timer
               // on every chunk, which blocked the UI isolate for ~1 s on a
               // 50k-row list. The body is read as a stream with our own
               // idle watchdog instead (_readBody).
               responseType: ResponseType.stream,
               validateStatus: (_) => true,
               headers: {
                 HttpHeaders.userAgentHeader: userAgent ?? defaultUserAgent,
                 HttpHeaders.acceptEncodingHeader: 'gzip',
               },
             ),
           );

  final Uri _server;
  final String _username;
  final String _password;
  final Dio _dio;
  final Future<void> Function(Duration) _delay;

  /// Attempts per request, the first included.
  final int maxAttempts;

  /// How long a response may go without a byte before it counts as
  /// dropped. Between chunks, not in total: a 20 MB list may take minutes
  /// on a slow line, but a panel silent for 30 s is gone.
  final Duration idleTimeout;

  Future<void> _tail = Future.value();
  CancelToken _cancel = CancelToken();

  /// Signs in: the account, or an `AuthFailure` for a wrong username or
  /// password. [retry] false fails fast, for the onboarding form's "Test
  /// connection", where the user is waiting.
  Future<Result<XtreamAccount>> account({bool retry = true}) async {
    final fetched = await _fetch(const {}, attempts: retry ? null : 1);
    return switch (fetched) {
      Ok(:final value) => switch (_parseInline(value, parseAccount)) {
        Ok(value: final account) => account,
        Err(:final failure) => Err(failure),
      },
      Err(:final failure) => Err(failure),
    };
  }

  Future<Result<XtreamRows<XtreamCategory>>> liveCategories() =>
      _list('get_live_categories', parseCategories);

  Future<Result<XtreamRows<XtreamCategory>>> movieCategories() =>
      _list('get_vod_categories', parseCategories);

  Future<Result<XtreamRows<XtreamCategory>>> seriesCategories() =>
      _list('get_series_categories', parseCategories);

  Future<Result<XtreamRows<XtreamChannel>>> liveStreams({String? categoryId}) =>
      _list('get_live_streams', parseChannels, categoryId: categoryId);

  Future<Result<XtreamRows<XtreamMovie>>> movies({String? categoryId}) =>
      _list('get_vod_streams', parseMovies, categoryId: categoryId);

  Future<Result<XtreamRows<XtreamSeries>>> series({String? categoryId}) =>
      _list('get_series', parseSeries, categoryId: categoryId);

  Future<Result<XtreamMovieInfo>> movieInfo(String vodId) =>
      _call({'action': 'get_vod_info', 'vod_id': vodId}, parseMovieInfo);

  Future<Result<XtreamSeriesInfo>> seriesInfo(String seriesId) => _call({
    'action': 'get_series_info',
    'series_id': seriesId,
  }, parseSeriesInfo);

  Future<Result<XtreamRows<XtreamEpgEntry>>> shortEpg(
    String streamId, {
    int limit = 4,
  }) => _call({
    'action': 'get_short_epg',
    'stream_id': streamId,
    'limit': '$limit',
  }, parseShortEpg);

  /// Cancels the request in flight and everything queued behind it; each
  /// completes with a `CancelledFailure`. Later calls run normally.
  void cancelAll() {
    _cancel.cancel();
    _cancel = CancelToken();
  }

  void close() {
    cancelAll();
    _dio.close(force: true);
  }

  Future<Result<XtreamRows<T>>> _list<T>(
    String action,
    XtreamRows<T> Function(Object? json) parse, {
    String? categoryId,
  }) => _call({'action': action, 'category_id': ?categoryId}, parse);

  Future<Result<T>> _call<T>(
    Map<String, String> params,
    T Function(Object? json) parse,
  ) async {
    final fetched = await _fetch(params);
    final Uint8List bytes;
    switch (fetched) {
      case Ok(:final value):
        bytes = value;
      case Err(:final failure):
        return Err(failure);
    }
    if (bytes.length < backgroundDecodeThreshold) {
      return _parseInline(bytes, parse);
    }
    return await _parseInBackground(
      bytes,
      parse,
      params['action'] ?? 'account',
    );
  }

  /// Static on purpose: a closure sent to an isolate carries its whole
  /// scope, and here that scope holds only sendable values — never `this`,
  /// whose Dio can't cross.
  static Future<Result<T>> _parseInBackground<T>(
    Uint8List bytes,
    T Function(Object? json) parse,
    String action,
  ) async {
    final parsed = await runInBackground(
      () => parse(decodeJsonBytes(bytes)),
      timeout: const Duration(minutes: 2),
      debugName: 'xtream-$action',
    );
    return switch (parsed) {
      Ok() => parsed,
      Err(failure: UnexpectedFailure(:final detail)) ||
      Err(
        failure: ParseFailure(:final detail),
      ) => Err(ParseFailure('$action: $detail')),
      Err() => parsed,
    };
  }

  static Result<T> _parseInline<T>(
    Uint8List bytes,
    T Function(Object? json) parse,
  ) {
    try {
      return Ok(parse(decodeJsonBytes(bytes)));
    } on FormatException catch (error) {
      return Err(ParseFailure('not JSON: ${error.message}'));
    }
  }

  /// Queues the request behind any in flight, then runs it with retries.
  Future<Result<Uint8List>> _fetch(
    Map<String, String> params, {
    int? attempts,
  }) {
    final token = _cancel;
    final run = _tail.then(
      (_) => token.isCancelled
          ? Future.value(
              Err<Uint8List>(CancelledFailure('${params['action']}')),
            )
          : _withRetries(params, token, attempts ?? maxAttempts),
    );
    _tail = run.then((_) {});
    return run;
  }

  Future<Result<Uint8List>> _withRetries(
    Map<String, String> params,
    CancelToken token,
    int attempts,
  ) async {
    final action = params['action'] ?? 'account';
    for (var attempt = 1; ; attempt++) {
      final outcome = await _once(params, token, action);
      final retryAfter = outcome.retryAfter;
      if (retryAfter == null || attempt >= attempts || token.isCancelled) {
        return outcome.result;
      }
      await _delay(_backoff(attempt, retryAfter));
      if (token.isCancelled) return Err(CancelledFailure(action));
    }
  }

  Future<_Outcome> _once(
    Map<String, String> params,
    CancelToken token,
    String action,
  ) async {
    try {
      final response = await _dio.getUri<ResponseBody>(
        _url(params),
        cancelToken: token,
      );
      final status = response.statusCode ?? 0;
      final stream = response.data?.stream ?? const Stream<Uint8List>.empty();
      if (status >= 200 && status < 300) {
        final body = await _readBody(stream, action);
        return switch (body) {
          Ok() => _Outcome(body),
          // A stall mid-body is a dropped connection: worth another go.
          Err() => _Outcome(body, retryAfter: Duration.zero),
        };
      }
      // An error page is read only to tell two 404s apart, and drained
      // either way so the connection can be reused.
      final visible = await _visibleBytes(stream);
      final failure = switch (status) {
        401 || 403 => AuthFailure('$action: HTTP $status', status),
        // Some panels refuse a sign-in with an empty 404 from
        // player_api.php; a page that isn't there has the web server's
        // error page as its body (docs/02). A real 404 stays one.
        404 when visible == 0 => AuthFailure(
          '$action: HTTP 404 with an empty body',
          status,
        ),
        404 => NotFoundFailure('$action: HTTP 404', status),
        _ => NetworkFailure('$action: HTTP $status', status),
      };
      final retryable = status == 429 || (status >= 500 && status < 600);
      return _Outcome(
        Err(failure),
        retryAfter: retryable
            ? _retryAfter(response.headers.value(HttpHeaders.retryAfterHeader))
            : null,
      );
    } on DioException catch (error) {
      final failure = switch (error.type) {
        DioExceptionType.cancel => CancelledFailure(action),
        DioExceptionType.connectionTimeout ||
        DioExceptionType.sendTimeout ||
        DioExceptionType.receiveTimeout => TimeoutFailure(
          '$action: ${error.type.name}',
        ),
        DioExceptionType.badCertificate || DioExceptionType.connectionError =>
          NetworkFailure('$action: ${error.error ?? error.type.name}'),
        _ => AppFailure.fromError(error.error ?? error),
      };
      // A body cut off mid-transfer is worth another go; a server that
      // refuses the connection or times out connecting is not — the user
      // may be waiting on "Test connection".
      final dropped =
          error.type == DioExceptionType.receiveTimeout ||
          (error.type == DioExceptionType.unknown &&
              error.error is HttpException);
      return _Outcome(Err(failure), retryAfter: dropped ? Duration.zero : null);
    }
  }

  /// Drains an error body, counting its bytes that aren't whitespace.
  static Future<int> _visibleBytes(Stream<Uint8List> stream) async {
    var count = 0;
    try {
      await for (final chunk in stream) {
        for (final byte in chunk) {
          if (byte > 0x20) count++;
        }
      }
    } on Object {
      // A broken error page is still an error page.
    }
    return count;
  }

  /// Collects the body, failing with a `TimeoutFailure` when no byte
  /// arrives for [idleTimeout] (see `IdleTimeout`: one watchdog per
  /// request, not a timer per chunk).
  Future<Result<Uint8List>> _readBody(
    Stream<Uint8List> stream,
    String action,
  ) async {
    final bytes = BytesBuilder(copy: false);
    try {
      await stream.idleTimeout(idleTimeout).forEach(bytes.add);
      return Ok(bytes.takeBytes());
    } on DioException catch (error) {
      return Err(
        error.type == DioExceptionType.cancel
            ? CancelledFailure(action)
            : AppFailure.fromError(error.error ?? error),
      );
    } on Object catch (error) {
      // TimeoutException → TimeoutFailure; a body cut off mid-transfer
      // (HttpException) → NetworkFailure, its URL redacted.
      return Err(AppFailure.fromError(error));
    }
  }

  Uri _url(Map<String, String> params) {
    final base = _server.path.replaceAll(RegExp(r'/+$'), '');
    return _server.replace(
      path: '$base/player_api.php',
      queryParameters: {
        'username': _username,
        'password': _password,
        ...params,
      },
    );
  }

  /// 1 s, 2 s, 4 s … with ±20 % jitter, or what the server asked for,
  /// capped at 30 s either way.
  Duration _backoff(int attempt, Duration asked) {
    if (asked > Duration.zero) {
      return asked > _maxBackoff ? _maxBackoff : asked;
    }
    final base = 1000 * pow(2, attempt - 1);
    final jitter = 0.8 + _random.nextDouble() * 0.4;
    final ms = min((base * jitter).round(), _maxBackoff.inMilliseconds);
    return Duration(milliseconds: ms);
  }

  static const _maxBackoff = Duration(seconds: 30);
  static final _random = Random();

  /// `Retry-After` in seconds; zero (our own backoff) when absent or in the
  /// HTTP-date form, which panels don't send.
  static Duration _retryAfter(String? header) {
    final seconds = int.tryParse(header?.trim() ?? '');
    return seconds == null || seconds < 0
        ? Duration.zero
        : Duration(seconds: seconds);
  }
}

/// One attempt: its result, and when it may be retried (null: it may not).
final class _Outcome {
  const new(this.result, {this.retryAfter});

  final Result<Uint8List> result;
  final Duration? retryAfter;
}
