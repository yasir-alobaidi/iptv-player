import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:isolate';
import 'dart:math';

import 'package:iptv_player/core/app_identity.dart';
import 'package:iptv_player/core/logging/app_log.dart';
import 'package:iptv_player/core/result.dart';
import 'package:iptv_player/features/diagnostics/domain/report_share.dart';
import 'package:shelf/shelf.dart';
import 'package:shelf/shelf_io.dart' as shelf_io;

const _tag = 'report';

/// This device's address on the network a phone could be on; null when
/// it has none.
typedef LanAddressFinder = Future<InternetAddress?> Function();

/// Serves the report over HTTP on this device's network address, under a
/// random path, for a phone on the same Wi-Fi (ADR-059):
/// - `/<token>/`: a page with a Download link and the text itself;
/// - `/<token>/<file name>`: the text as a file.
///
/// Anything else is a 404 that says nothing of the token. An offer
/// closes itself after [lifetime].
final class LanReportSharer implements ReportSharer {
  new({
    required this._log,
    LanAddressFinder? findAddress,
    this.lifetime = const Duration(minutes: 30),
  }) : _findAddress = findAddress ?? findLanAddress;

  final AppLog _log;
  final LanAddressFinder _findAddress;

  /// How long an offer nobody closes lasts.
  final Duration lifetime;

  @override
  Future<Result<ReportOffer>> offer(
    String text, {
    required String fileName,
  }) async {
    final InternetAddress? host;
    try {
      host = await _findAddress();
    } on Object catch (error) {
      _log.warning(_tag, "Couldn't list the network interfaces: $error");
      return Err(NetworkFailure('no network interfaces: $error'));
    }
    if (host == null) {
      _log.info(_tag, 'No network address a phone could reach');
      return Err(NetworkFailure('no network address a phone could reach'));
    }

    final token = newReportToken();
    final name = reportFileName(fileName);
    final _Encoded encoded;
    try {
      encoded = await _encode(token, name, text);
    } on Object catch (error) {
      _log.warning(_tag, "Couldn't make the report's page: $error");
      return Err(UnexpectedFailure("couldn't make the report's page: $error"));
    }
    final fetched = StreamController<void>.broadcast();
    final routes = _ReportRoutes(
      token: token,
      fileName: name,
      file: encoded.file,
      page: encoded.page,
      onFetched: () {
        _log.info(_tag, 'A phone downloaded the report');
        if (!fetched.isClosed) fetched.add(null);
      },
      log: _log,
    );
    final HttpServer server;
    try {
      server = await shelf_io.serve(
        routes.handle,
        host,
        0,
        poweredByHeader: null,
      );
    } on Object catch (error) {
      unawaited(fetched.close());
      _log.warning(_tag, "Couldn't serve the report: $error");
      return Err(NetworkFailure("couldn't serve the report: $error"));
    }
    server.autoCompress = false;
    _log.info(
      _tag,
      'Offering the report on port ${server.port} '
      '(${reportKilobytes(encoded.file.length)} KB) '
      'for ${lifetime.inMinutes} min',
    );
    return Ok(
      _LanReportOffer(
        server: server,
        address: Uri(
          scheme: 'http',
          host: host.address,
          port: server.port,
          path: '/${routes.token}/',
        ),
        fetched: fetched,
        log: _log,
        lifetime: lifetime,
      ),
    );
  }
}

final class _LanReportOffer implements ReportOffer {
  new({
    required this._server,
    required this.address,
    required this._fetched,
    required this._log,
    required Duration lifetime,
  }) {
    _timer = Timer(lifetime, () => unawaited(_end(expired: true)));
  }

  final HttpServer _server;
  final StreamController<void> _fetched;
  final AppLog _log;
  late final Timer _timer;
  Future<void>? _closing;

  @override
  final Uri address;

  @override
  Stream<void> get fetched => _fetched.stream;

  @override
  Future<void> close() => _end(expired: false);

  Future<void> _end({required bool expired}) =>
      _closing ??= _shutDown(expired: expired);

  Future<void> _shutDown({required bool expired}) async {
    _timer.cancel();
    try {
      await _server.close(force: true);
    } on Object catch (error) {
      _log.info(_tag, 'Closing the report server: $error');
    }
    // Not awaited: a listener that paused would hold it open.
    unawaited(_fetched.close());
    _log.info(
      _tag,
      expired
          ? 'Stopped offering the report: nobody closed it in time'
          : 'Stopped offering the report',
    );
  }
}

/// The page and the file of one offer.
final class _ReportRoutes {
  new({
    required this.token,
    required this.fileName,
    required this._file,
    required this._page,
    required this._onFetched,
    required this._log,
  });

  final String token;
  final String fileName;
  final List<int> _file;
  final List<int> _page;
  final void Function() _onFetched;
  final AppLog _log;

  Response handle(Request request) {
    try {
      return _answer(request);
    } on Object catch (error) {
      _log.warning(_tag, 'A request for the report failed: $error');
      return Response.internalServerError();
    }
  }

  Response _answer(Request request) {
    final head = request.method == 'HEAD';
    if (request.method != 'GET' && !head) return _notFound();
    final path = request.url.pathSegments;
    if (path.isEmpty || path.first != token) return _notFound();
    return switch (path) {
      // The address without its slash: the page's own.
      [_] => Response.found('/$token/'),
      [_, ''] => Response.ok(
        _page,
        headers: {
          HttpHeaders.contentTypeHeader: 'text/html; charset=utf-8',
          HttpHeaders.cacheControlHeader: 'no-store',
        },
      ),
      [_, final name] when name == fileName => _download(head: head),
      _ => _notFound(),
    };
  }

  Response _download({required bool head}) {
    if (!head) _onFetched();
    return Response.ok(
      _file,
      headers: {
        HttpHeaders.contentTypeHeader: 'text/plain; charset=utf-8',
        'content-disposition': 'attachment; filename="$fileName"',
        HttpHeaders.cacheControlHeader: 'no-store',
      },
    );
  }

  static Response _notFound() => Response.notFound(
    'not here\n',
    headers: {HttpHeaders.contentTypeHeader: 'text/plain; charset=utf-8'},
  );
}

/// A report longer than this is encoded away from the UI isolate (hard
/// rule 2): a TV's logcat makes it long.
const _muchText = 200000;

/// An offer's file and page, as served.
typedef _Encoded = ({List<int> file, List<int> page});

Future<_Encoded> _encode(String token, String fileName, String text) =>
    text.length > _muchText
    ? Isolate.run(() => _encoded(token, fileName, text))
    : Future.value(_encoded(token, fileName, text));

_Encoded _encoded(String token, String fileName, String text) {
  final file = utf8.encode(text);
  return (
    file: file,
    page: utf8.encode(_pageHtml(token, fileName, text, file.length)),
  );
}

/// A phone's page: the Download link first, big enough for a thumb, then
/// the text. The browser's own colors (hard rule 9).
String _pageHtml(String token, String fileName, String text, int bytes) {
  const attribute = HtmlEscape(HtmlEscapeMode.attribute);
  const element = HtmlEscape(HtmlEscapeMode.element);
  final link = attribute.convert('/$token/${Uri.encodeComponent(fileName)}');
  final name = attribute.convert(fileName);
  final title = element.convert('$appName report');
  return '<!doctype html>\n'
      '<html lang="en">\n'
      '<head>\n'
      '<meta charset="utf-8">\n'
      '<meta name="viewport" content="width=device-width, '
      'initial-scale=1">\n'
      '<title>$title</title>\n'
      '<style>\n'
      'body { font-family: system-ui, sans-serif; margin: 1rem; '
      'line-height: 1.4; }\n'
      'a.download { display: block; margin: 1.5rem 0; padding: 1rem; '
      'border: 2px solid; border-radius: 0.75rem; text-align: center; '
      'font-size: 1.25rem; font-weight: bold; text-decoration: none; }\n'
      'pre { white-space: pre-wrap; word-break: break-word; '
      'font-size: 0.8rem; }\n'
      '</style>\n'
      '</head>\n'
      '<body>\n'
      '<h1>$title</h1>\n'
      '<a class="download" href="$link" download="$name">Download the '
      'report (${reportKilobytes(bytes)} KB)</a>\n'
      '<pre>${element.convert(text)}</pre>\n'
      '</body>\n'
      '</html>\n';
}

/// [bytes] in whole kilobytes, at least 1.
int reportKilobytes(int bytes) => max(1, (bytes / 1024).round());

/// [name] with anything but letters, digits, `.`, `_` and `-` replaced,
/// so it is safe in a path and a header; `report.txt` when nothing is
/// left.
String reportFileName(String name) {
  final safe = name.trim().replaceAll(RegExp('[^A-Za-z0-9._-]'), '-');
  return safe.isEmpty || safe.startsWith('.') ? 'report.txt' : safe;
}

/// Letters and digits a person can type from the screen: no 0/o, 1/l/i.
const _tokenAlphabet = 'abcdefghjkmnpqrstuvwxyz23456789';

/// An offer's path: 10 characters from [Random.secure], about 50 bits,
/// for half an hour on a home network.
String newReportToken() {
  final random = Random.secure();
  return String.fromCharCodes([
    for (var i = 0; i < 10; i++)
      _tokenAlphabet.codeUnitAt(random.nextInt(_tokenAlphabet.length)),
  ]);
}

/// This device's address a phone on the same network could reach
/// ([chooseLanAddress] over the system's interfaces).
Future<InternetAddress?> findLanAddress() async {
  final interfaces = await NetworkInterface.list(
    type: InternetAddressType.IPv4,
  );
  return chooseLanAddress([
    for (final interface in interfaces)
      for (final address in interface.addresses) (interface.name, address),
  ]);
}

/// The best of [candidates] (interface name, address) for a phone on the
/// same Wi-Fi: a private IPv4 (10/8, 172.16/12, 192.168/16) before any
/// other, and among those Wi-Fi or Ethernet (`wlan0`, `eth0` on Android;
/// `wlp2s0`, `enp3s0` on Linux) before the rest (a VPN, Docker's bridge).
/// Loopback, link-local (169.254/16) and IPv6 never; null when nothing
/// is left. The first wins a tie.
InternetAddress? chooseLanAddress(List<(String, InternetAddress)> candidates) {
  InternetAddress? best;
  var bestScore = -1;
  for (final (name, address) in candidates) {
    if (address.type != InternetAddressType.IPv4 || address.isLoopback) {
      continue;
    }
    final [a, b, ...] = address.rawAddress;
    if (a == 169 && b == 254) continue;
    final private =
        a == 10 || (a == 172 && b >= 16 && b <= 31) || (a == 192 && b == 168);
    final lower = name.toLowerCase();
    final wifiOrEthernet =
        lower.startsWith('wl') ||
        lower.startsWith('eth') ||
        lower.startsWith('en') ||
        lower.startsWith('wi-fi');
    final score = (private ? 2 : 0) + (wifiOrEthernet ? 1 : 0);
    if (score > bestScore) {
      best = address;
      bestScore = score;
    }
  }
  return best;
}
