import 'dart:async';
import 'dart:io';

import 'package:iptv_player/core/logging/redact.dart';
import 'package:iptv_player/core/result.dart';
import 'package:iptv_player/core/streams/idle_timeout.dart';
import 'package:iptv_player/data/providers/provider_http.dart';
import 'package:iptv_player/features/sources/domain/source_form.dart';

/// Where a guide comes from. Plain values, so an input can be sent to the
/// import isolate: the bytes never cross isolates.
sealed class XmltvInput {
  const new();
}

final class XmltvFileInput extends XmltvInput {
  const new(this.path);

  final String path;

  @override
  String toString() => 'XmltvFileInput($path)';
}

final class XmltvUrlInput extends XmltvInput {
  const new(this.url, {this.userAgent});

  /// The real guide URL, credentials and all (an Xtream `xmltv.php` with
  /// the password in its query, a playlist's `url-tvg` with a token in
  /// its path). Never logged: see [hideUrl].
  final String url;
  final String? userAgent;

  @override
  String toString() => 'XmltvUrlInput(${displayOrigin(url)})';
}

/// A guide's body, open and not yet read.
final class XmltvBody {
  new _(
    Stream<List<int>> raw, {
    this.length,
    Stream<List<int>> Function(Stream<List<int>>)? decode,
    this._client,
  }) {
    final counted = raw.map((chunk) {
      _bytesRead += chunk.length;
      return chunk;
    });
    bytes = _releasing(decode == null ? counted : decode(counted));
  }

  final HttpClient? _client;
  var _bytesRead = 0;

  /// The body, with a `Content-Encoding: gzip` already undone. A `.xml.gz`
  /// served as plain bytes is still gzip here: the parser finds it by its
  /// magic number, so nothing is decoded twice. Single subscription;
  /// pausing it pauses the connection, which is how the import holds one
  /// batch in memory rather than the guide.
  late final Stream<List<int>> bytes;

  /// The body's length as it travels (compressed when it is), when the
  /// server or the file system said it.
  final int? length;

  /// Bytes of the body read so far, counted as they arrive — before any
  /// decoding, so they compare with [length].
  int get bytesRead => _bytesRead;

  /// Lets the connection go. [bytes] does this itself when it ends or is
  /// cancelled; this is for a body that is never read to the end.
  void close() => _client?.close(force: true);

  Stream<List<int>> _releasing(Stream<List<int>> body) async* {
    try {
      yield* body;
    } finally {
      close();
    }
  }
}

/// Opens [input] in the calling isolate: the guide import calls this
/// inside its own isolate (`runEpgImportWork`).
///
/// Never throws. A file that doesn't exist is `NotFoundFailure`; over
/// HTTP, 401/403 is `AuthFailure`, 404 `NotFoundFailure`, any other
/// non-2xx a `NetworkFailure` with the status, and a server that doesn't
/// answer within [idleTimeout] a `TimeoutFailure`. The body itself ends
/// with a `TimeoutException` when it goes quiet for [idleTimeout] between
/// bytes (not in total: a 300 MB guide on a slow line is fine).
///
/// No failure carries the URL or any part of it that could be a secret
/// ([failureWithoutUrl]).
Future<Result<XmltvBody>> openXmltv(
  XmltvInput input, {
  Duration idleTimeout = const Duration(seconds: 60),
  Duration connectionTimeout = const Duration(seconds: 15),
}) async {
  switch (input) {
    case XmltvFileInput(:final path):
      return _openFile(path);
    case XmltvUrlInput(:final url, :final userAgent):
      final result = await _openUrl(
        url,
        userAgent: userAgent,
        idleTimeout: idleTimeout,
        connectionTimeout: connectionTimeout,
      );
      return switch (result) {
        Ok() => result,
        Err(:final failure) => Err(failureWithoutUrl(failure, url)),
      };
  }
}

Result<XmltvBody> _openFile(String path) {
  try {
    final file = File(path);
    if (!file.existsSync()) {
      return Err(NotFoundFailure('guide file does not exist'));
    }
    return Ok(XmltvBody._(file.openRead(), length: file.lengthSync()));
  } on Object catch (error) {
    return Err(AppFailure.fromError(error));
  }
}

Future<Result<XmltvBody>> _openUrl(
  String url, {
  required String? userAgent,
  required Duration idleTimeout,
  required Duration connectionTimeout,
}) async {
  final uri = Uri.tryParse(url.trim());
  if (uri == null ||
      uri.host.isEmpty ||
      (uri.scheme != 'http' && uri.scheme != 'https')) {
    // Not the URL in the detail: a parse error quotes all of it.
    return Err(InvalidInputFailure('guide URL is not an http(s) URL'));
  }
  // The body is decoded here rather than by the client, so what arrives
  // can be counted against the length the server sent.
  final client = HttpClient()
    ..connectionTimeout = connectionTimeout
    ..autoUncompress = false
    ..userAgent = userAgent ?? defaultUserAgent;
  try {
    final request = await client.getUrl(uri);
    request.headers.set(HttpHeaders.acceptEncodingHeader, 'gzip');
    // A server that accepts the connection and then says nothing is as
    // stalled as one that stops mid-body.
    final response = await request.close().timeout(idleTimeout);
    final status = response.statusCode;
    if (status < 200 || status >= 300) {
      client.close(force: true);
      return Err(switch (status) {
        401 || 403 => AuthFailure('guide: HTTP $status', status),
        404 => NotFoundFailure('guide: HTTP 404', status),
        _ => NetworkFailure('guide: HTTP $status', status),
      });
    }
    final encoding = response.headers
        .value(HttpHeaders.contentEncodingHeader)
        ?.trim()
        .toLowerCase();
    final gzipped = encoding == 'gzip' || encoding == 'x-gzip';
    final length = response.contentLength;
    return Ok(
      XmltvBody._(
        response.idleTimeout(idleTimeout),
        length: length < 0 ? null : length,
        decode: gzipped ? gzip.decoder.bind : null,
        client: client,
      ),
    );
  } on Object catch (error) {
    client.close(force: true);
    // Socket, TLS and HTTP errors quote the URL; AppFailure masks what its
    // patterns know, and openXmltv the rest.
    return Err(AppFailure.fromError(error));
  }
}

/// [text] with [url] in every form it is printed in replaced by its
/// origin (`http://host:port/…`), and every part of it that can be a
/// secret masked wherever else it turns up.
///
/// `redact()` alone is not enough for a guide URL: its patterns know a
/// `password=` in a query, not a token in a path
/// (`/epg/9c2e81d4f0/guide.xml`), and the import isolate has no
/// `SecretRegistry` to catch the rest — the registry lives with the log
/// on the app's side. So the isolate masks what it knows is secret: the
/// URL it was given.
String hideUrl(String text, String url) {
  if (text.isEmpty || url.isEmpty) return text;
  final uri = Uri.tryParse(url.trim());
  final origin = displayOrigin(url);

  // Whole URLs first, longest first, so the origin that replaces one
  // isn't then cut into by a shorter form. `AppFailure` has already
  // pattern-masked its detail, so the masked forms are looked for too.
  final forms = <String>{
    url,
    url.trim(),
    if (uri != null) ...[uri.toString(), uri.removeFragment().toString()],
  };
  final wholes =
      {
          for (final form in forms) ...[form, redact(form)],
        }.where((form) => form.length > origin.length).toList()
        ..sort((a, b) => b.length.compareTo(a.length));
  var out = text;
  for (final form in wholes) {
    out = out.replaceAll(form, origin);
  }
  if (uri == null) return redact(out);

  // Then the pieces, wherever else they turn up: user-info, every query
  // value, the path, and any path segment long enough to be a token (a
  // word like `epg` is left alone; masking it would garble the text).
  final pieces = <String>{
    ...uri.userInfo.split(':'),
    for (final part in uri.query.split('&'))
      if (part.contains('=')) ...[
        part.substring(part.indexOf('=') + 1),
        _decoded(part.substring(part.indexOf('=') + 1), query: true),
      ],
    if (uri.path.length > 1) ...[uri.path, _decoded(uri.path)],
    for (final segment in uri.pathSegments)
      if (segment.length >= _tokenLength) segment,
    for (final segment in uri.path.split('/'))
      if (segment.length >= _tokenLength) segment,
  }..removeWhere((piece) => piece.isEmpty);
  return redact(out, secrets: pieces);
}

/// Path segments this long are masked as possible tokens. Real tokens are
/// longer; the file names beside them (`epg.xml`, `guide.xml`) mostly
/// shorter, and masking one of those does no harm.
const _tokenLength = 8;

/// [text] percent-decoded (and `+` as a space in a query), or as it is
/// when its encoding is broken.
String _decoded(String text, {bool query = false}) {
  try {
    return query ? Uri.decodeQueryComponent(text) : Uri.decodeComponent(text);
  } on Object {
    return text;
  }
}

/// [failure] with [hideUrl] applied to its detail: the same type and
/// status, so the UI's message and the stored code don't change.
AppFailure failureWithoutUrl(AppFailure failure, String url) {
  final detail = failure.detail;
  if (detail == null) return failure;
  final clean = hideUrl(detail, url);
  if (clean == detail) return failure;
  return switch (failure) {
    NetworkFailure(:final statusCode) => NetworkFailure(clean, statusCode),
    AuthFailure(:final statusCode) => AuthFailure(clean, statusCode),
    NotFoundFailure(:final statusCode) => NotFoundFailure(clean, statusCode),
    ParseFailure() => ParseFailure(clean),
    StorageFailure() => StorageFailure(clean),
    SecureStorageFailure() => SecureStorageFailure(clean),
    InvalidInputFailure() => InvalidInputFailure(clean),
    TimeoutFailure() => TimeoutFailure(clean),
    CancelledFailure() => CancelledFailure(clean),
    UnexpectedFailure() => UnexpectedFailure(clean),
  };
}
