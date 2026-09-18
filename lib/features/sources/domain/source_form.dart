import 'package:iptv_player/features/sources/domain/source.dart';

/// The fields of a [SourceDraft] a form shows and validation names.
enum DraftField {
  name,

  /// The Xtream server, the playlist URL, or the file path.
  url,
  username,
  password,
  epgUrl,
  userAgent,
  refreshHours,
  epgOffset,
  connectionLimit,
}

/// What is wrong with a field.
enum DraftProblem { missing, invalid, tooLong }

/// The longest name a source may have.
const maxSourceNameLength = 200;

/// Every problem with [draft], in [DraftField] order; empty when it can
/// be saved. The add form checks this inline, and the repository again
/// as the backstop. [requirePassword] is false for an edit, where a blank
/// password keeps the stored one.
Map<DraftField, DraftProblem> validateDraft(
  SourceDraft draft, {
  required bool requirePassword,
}) {
  final problems = <DraftField, DraftProblem>{};
  final name = draft.name.trim();
  if (name.isEmpty) {
    problems[DraftField.name] = DraftProblem.missing;
  } else if (name.length > maxSourceNameLength) {
    problems[DraftField.name] = DraftProblem.tooLong;
  }

  final url = draft.url.trim();
  switch (draft.type) {
    case SourceType.xtream:
      if (url.isEmpty) {
        problems[DraftField.url] = DraftProblem.missing;
      } else if (normalizeServerUrl(url) == null) {
        problems[DraftField.url] = DraftProblem.invalid;
      }
      if (_blank(draft.username)) {
        problems[DraftField.username] = DraftProblem.missing;
      }
      if (requirePassword && _blank(draft.password)) {
        problems[DraftField.password] = DraftProblem.missing;
      }
    case SourceType.m3uUrl:
      if (url.isEmpty) {
        problems[DraftField.url] = DraftProblem.missing;
      } else if (!isWebUrl(url)) {
        problems[DraftField.url] = DraftProblem.invalid;
      }
    case SourceType.m3uFile:
      if (url.isEmpty) problems[DraftField.url] = DraftProblem.missing;
  }

  final epg = draft.epgUrl?.trim() ?? '';
  if (epg.isNotEmpty && !isWebUrl(epg)) {
    problems[DraftField.epgUrl] = DraftProblem.invalid;
  }
  if (draft.refreshHours < 1) {
    problems[DraftField.refreshHours] = DraftProblem.invalid;
  }
  if (draft.epgOffsetMinutes.abs() > 24 * 60) {
    problems[DraftField.epgOffset] = DraftProblem.invalid;
  }
  if ((draft.maxConnectionsOverride ?? 1) < 1) {
    problems[DraftField.connectionLimit] = DraftProblem.invalid;
  }
  return problems;
}

/// An absolute http(s) URL with a host.
bool isWebUrl(String text) {
  final uri = Uri.tryParse(text.trim());
  return uri != null &&
      uri.host.isNotEmpty &&
      (uri.scheme == 'http' || uri.scheme == 'https');
}

/// The server part of an Xtream URL: scheme, host, port and any base path,
/// without user-info, query or fragment, and without a trailing slash.
/// `http://` is assumed when no scheme is given, and a pasted
/// `player_api.php` or `get.php` link is cut back to its server. Null
/// when there is no usable host, or the scheme is not http(s).
String? normalizeServerUrl(String input) {
  var text = input.trim();
  if (text.isEmpty) return null;
  if (!text.contains('://')) text = 'http://$text';
  final uri = Uri.tryParse(text);
  if (uri == null || uri.host.isEmpty) return null;
  if (uri.scheme != 'http' && uri.scheme != 'https') return null;
  final path = uri.path
      .replaceAll(_panelScript, '')
      .replaceAll(RegExp(r'/+$'), '');
  return Uri(
    scheme: uri.scheme,
    host: uri.host,
    port: uri.hasPort ? uri.port : null,
    path: path,
  ).toString();
}

final _panelScript = RegExp(
  r'/(player_api|get|xmltv|panel_api)\.php$',
  caseSensitive: false,
);

/// The display form of a playlist or EPG URL: its origin and an
/// ellipsis, `http://lists.example/…`. Not `redact()`: a token in a path
/// (`/p/9c2e81d4/list.m3u`) matches no pattern, so a masked URL can still
/// carry the secret, and only dropping everything after the host is sure.
String displayOrigin(String url) {
  final uri = Uri.tryParse(url.trim());
  if (uri == null || uri.host.isEmpty) return '…';
  final port = uri.hasPort ? ':${uri.port}' : '';
  return '${uri.scheme}://${uri.host}$port/…';
}

/// The sign-in a pasted Xtream link carries: providers usually send a
/// `get.php?username=…&password=…` link, and pasting it into the server
/// field should fill in all three. Null when [text] has no username and
/// password in its query.
({String server, String username, String password})? xtreamLinkLogin(
  String text,
) {
  final trimmed = text.trim();
  final uri = Uri.tryParse(
    trimmed.contains('://') ? trimmed : 'http://$trimmed',
  );
  if (uri == null) return null;
  final username = uri.queryParameters['username']?.trim() ?? '';
  final password = uri.queryParameters['password']?.trim() ?? '';
  final server = normalizeServerUrl(trimmed);
  if (username.isEmpty || password.isEmpty || server == null) return null;
  return (server: server, username: username, password: password);
}

/// A name for a source the user didn't name: the server's host without
/// `www.`, or the playlist file's name without its extension.
String suggestedSourceName(SourceType type, String url) {
  final text = url.trim();
  if (type == SourceType.m3uFile) {
    final file = text.split(RegExp(r'[/\\]')).last;
    final dot = file.lastIndexOf('.');
    final stem = dot > 0 ? file.substring(0, dot) : file;
    return stem.isEmpty ? 'Playlist' : _clip(stem);
  }
  final uri = Uri.tryParse(text.contains('://') ? text : 'http://$text');
  final host = uri?.host ?? '';
  if (host.isEmpty) {
    return type == SourceType.xtream ? 'My provider' : 'Playlist';
  }
  return _clip(host.startsWith('www.') ? host.substring(4) : host);
}

String _clip(String name) => name.length <= maxSourceNameLength
    ? name
    : name.substring(0, maxSourceNameLength);

bool _blank(String? value) => value == null || value.trim().isEmpty;
