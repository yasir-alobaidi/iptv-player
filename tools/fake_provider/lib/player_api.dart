/// `player_api.php`: the Xtream API surface (docs/02 "Xtream Codes API").
///
/// Every action reads from [FakeServerState.catalog] and serializes through
/// the profile's [JsonShape], so a quirky profile changes the wire
/// representation without the generator knowing. Lists are written onto the
/// response stream one item at a time: the `large` profile has 50k channels
/// and 30k movies, and materializing either as a Dart list or as one JSON
/// string would cost far more memory than the server is allowed.
library;

import 'dart:async';
import 'dart:convert';

import 'package:fake_provider/models.dart';
import 'package:fake_provider/profile.dart';
import 'package:fake_provider/server_state.dart';
import 'package:shelf/shelf.dart';

/// The actions this step answers. Anything else gets a 501 naming these, so
/// a later phase that needs `get_simple_data_table` fails loudly.
const supportedActions = <String>[
  'get_live_categories',
  'get_live_streams',
  'get_vod_categories',
  'get_vod_streams',
  'get_series_categories',
  'get_series',
  'get_vod_info',
  'get_series_info',
  'get_short_epg',
];

/// `get_short_epg` without `limit`, as panels default.
const defaultShortEpgLimit = 4;

/// A byte that is not valid UTF-8 in any position, which is what the
/// `invalidUtf8Names` quirk puts on the wire in place of
/// [invalidUtf8Marker] (docs/02: decode with `allowMalformed: true`).
const _invalidUtf8Byte = 0xff;

const _jsonHeaders = {'content-type': 'application/json'};

const _arrayOpen = <int>[0x5b]; // [
const _arrayClose = <int>[0x5d]; // ]

/// The handler for `/player_api.php`; the caller owns the route.
Handler playerApiHandler(FakeServerState state) {
  return (Request request) async {
    final params = await _readParams(request);
    if (!state.authenticates(params['username'], params['password'])) {
      // what a real panel answers: 200 with auth 0 and no hint about which
      // half was wrong. streams answer 401 instead.
      return _object(state, const {
        'user_info': {'auth': 0, 'status': 'Disabled'},
      });
    }

    final catalog = state.catalog;
    final shape = JsonShape(state.profile.quirks);
    final category = _value(params, 'category_id');

    switch (_value(params, 'action')) {
      case null:
        return _object(state, _account(state, request, shape));
      case 'get_live_categories':
        return _array(
          state,
          catalog.liveCategories.map((c) => c.toJson(shape)),
        );
      case 'get_live_streams':
        return _array(
          state,
          catalog.channels(categoryId: category).map((c) => c.toJson(shape)),
        );
      case 'get_vod_categories':
        return _array(
          state,
          catalog.movieCategories.map((c) => c.toJson(shape)),
        );
      case 'get_vod_streams':
        return _array(
          state,
          catalog.movies(categoryId: category).map((m) => m.toJson(shape)),
        );
      case 'get_series_categories':
        return _array(
          state,
          catalog.seriesCategories.map((c) => c.toJson(shape)),
        );
      case 'get_series':
        return _array(
          state,
          catalog.series(categoryId: category).map((s) => s.toJson(shape)),
        );
      case 'get_vod_info':
        return _object(state, _vodInfo(state, shape, _value(params, 'vod_id')));
      case 'get_series_info':
        return _object(
          state,
          _seriesInfo(state, shape, _value(params, 'series_id')),
        );
      case 'get_short_epg':
        return _object(state, _shortEpg(state, shape, params));
      case final action:
        return _object(state, {
          'error': 'unsupported action',
          'action': action,
          'supported_actions': supportedActions,
          'message':
              'tools/fake_provider implements the docs/02 Xtream calls '
              'only; add this action to lib/player_api.dart when a phase '
              'needs it',
        }, status: 501);
    }
  };
}

/// Credentials and arguments, from the query string and — for POST — from a
/// form-encoded body as well, with the query winning. Clients in the wild do
/// both, so the fake takes both.
Future<Map<String, String>> _readParams(Request request) async {
  final query = request.url.queryParameters;
  if (request.method != 'POST') return query;
  final body = await request.readAsString();
  if (body.isEmpty) return query;
  try {
    return {...Uri.splitQueryString(body), ...query};
  } on FormatException {
    // a body we cannot parse is simply no arguments; hard rule 1 applies to
    // the fake too, and a malformed request must not take the server down.
    return query;
  }
}

/// A parameter, with `""` read as absent so `&category_id=` means "all".
String? _value(Map<String, String> params, String key) {
  final value = params[key];
  return (value == null || value.isEmpty) ? null : value;
}

Map<String, Object?> _account(
  FakeServerState state,
  Request request,
  JsonShape shape,
) {
  final profile = state.profile;
  final expiresInDays = profile.expiresInDays;
  final now = DateTime.now();
  final endpoint = _endpoint(request);
  return {
    'user_info': {
      'username': profile.username,
      'password': profile.password,
      'message': 'fake provider, profile ${profile.name}',
      'auth': shape.flag(value: true),
      'status': 'Active',
      // absent means no expiry (docs/02); the quirky profile sends `""`.
      'exp_date': expiresInDays == null
          ? shape.text(null)
          : shape.timestamp(state.startedAt.add(Duration(days: expiresInDays))),
      'is_trial': shape.flag(value: false),
      'active_cons': shape.number(state.activeStreams),
      'created_at': shape.timestamp(
        state.startedAt.subtract(const Duration(days: 90)),
      ),
      'max_connections': shape.number(state.maxConnections),
      'allowed_output_formats': const ['ts', 'm3u8'],
    },
    'server_info': {
      // taken from the request, so a client that rebuilds stream URLs out of
      // server_info lands back on this server whatever host or port it was
      // reached on (docs/02: always rebuild URLs from the original server).
      'url': endpoint.host,
      'port': shape.number(endpoint.port),
      'https_port': shape.number(443),
      'server_protocol': 'http',
      // no rtmp here; panels send 0 when they have none.
      'rtmp_port': shape.number(0),
      'timezone': now.timeZoneName,
      'timestamp_now': shape.number(now.millisecondsSinceEpoch ~/ 1000),
      'time_now': _stamp(now),
    },
  };
}

/// An unknown `vod_id` gets `{}`: a panel answers 200 with an empty body
/// rather than a 404, and the client has to treat "no info" as a state.
Map<String, Object?> _vodInfo(
  FakeServerState state,
  JsonShape shape,
  String? rawId,
) {
  final id = int.tryParse(rawId ?? '');
  final movie = id == null ? null : state.catalog.movieById(id);
  return movie?.toInfoJson(shape) ?? const {};
}

/// Same for an unknown `series_id`: `{}`.
Map<String, Object?> _seriesInfo(
  FakeServerState state,
  JsonShape shape,
  String? rawId,
) {
  final id = int.tryParse(rawId ?? '');
  final series = id == null ? null : state.catalog.seriesById(id);
  if (series == null) return const {};
  final bySeason = state.catalog.episodesOf(series);
  return {
    'seasons': [
      for (final season in bySeason.entries)
        series.seasonJson(shape, season.key, season.value.length),
    ],
    'info': series.toJson(shape),
    // a map keyed by the season number as a string, or one flat list — both
    // are shapes docs/02 says the parser must tolerate.
    'episodes': state.profile.quirks.episodesAsMap
        ? <String, Object?>{
            for (final season in bySeason.entries)
              '${season.key}': [
                for (final episode in season.value) episode.toJson(shape),
              ],
          }
        : <Object?>[
            for (final season in bySeason.entries)
              for (final episode in season.value) episode.toJson(shape),
          ],
  };
}

/// `{"epg_listings": [...]}`, and an empty list for an unknown or EPG-less
/// channel — the envelope stays, so a client never sees a missing key.
Map<String, Object?> _shortEpg(
  FakeServerState state,
  JsonShape shape,
  Map<String, String> params,
) {
  final streamId = int.tryParse(_value(params, 'stream_id') ?? '');
  final limit =
      int.tryParse(_value(params, 'limit') ?? '') ?? defaultShortEpgLimit;
  final channel = streamId == null ? null : state.catalog.channelById(streamId);
  if (channel == null || limit < 1) {
    return const {'epg_listings': <Object?>[]};
  }
  final programmes = state.catalog.shortEpg(channel.streamId, limit: limit);
  return {
    'epg_listings': [
      for (var i = 0; i < programmes.length; i++)
        programmes[i].toShortEpgJson(shape, now: i == 0),
    ],
  };
}

Response _object(
  FakeServerState state,
  Map<String, Object?> body, {
  int status = 200,
}) => Response(
  status,
  body: encodeWireText(
    json.encode(body),
    breakUtf8: state.profile.quirks.invalidUtf8Names,
  ),
  headers: _jsonHeaders,
);

Response _array(FakeServerState state, Iterable<Map<String, Object?>> items) =>
    Response.ok(
      _arrayBytes(items, breakUtf8: state.profile.quirks.invalidUtf8Names),
      headers: _jsonHeaders,
    );

/// The array, encoded as it is walked: `[`, item, `,`, item, …, `]`. The
/// [items] iterable stays lazy, so a 50k-channel response never exists as a
/// whole anywhere.
Stream<List<int>> _arrayBytes(
  Iterable<Map<String, Object?>> items, {
  required bool breakUtf8,
}) async* {
  yield _arrayOpen;
  var first = true;
  for (final item in items) {
    final text = first ? json.encode(item) : ',${json.encode(item)}';
    first = false;
    // one chunk per item is what makes the marker replacement below safe: a
    // marker can never straddle two chunks, so nothing has to be buffered.
    yield encodeWireText(text, breakUtf8: breakUtf8);
  }
  yield _arrayClose;
}

/// UTF-8 bytes, with every [invalidUtf8Marker] replaced by a byte that is
/// not valid UTF-8 when the quirk is on. The break has to happen here: a
/// Dart `String` cannot hold an invalid sequence, so only the encoder can
/// put a genuinely malformed body on the wire.
List<int> encodeWireText(String text, {required bool breakUtf8}) {
  if (!breakUtf8 || !text.contains(invalidUtf8Marker)) {
    return utf8.encode(text);
  }
  final parts = text.split(invalidUtf8Marker);
  final bytes = <int>[];
  for (var i = 0; i < parts.length; i++) {
    if (i > 0) bytes.add(_invalidUtf8Byte);
    bytes.addAll(utf8.encode(parts[i]));
  }
  return bytes;
}

/// `http://host:port` as the client reached this server, for URLs that
/// must lead back here (`get.php` stream lines, `server_info`).
String requestOrigin(Request request) {
  final endpoint = _endpoint(request);
  return 'http://${endpoint.host}:${endpoint.port}';
}

/// The host and port the client used, from the Host header when there is one
/// (proxies and `localhost` vs `127.0.0.1` both matter to a client rebuilding
/// URLs) and from the requested URI otherwise.
_Endpoint _endpoint(Request request) {
  final header = request.headers['host'];
  if (header != null && header.isNotEmpty) {
    final parsed = Uri.tryParse('http://$header/');
    if (parsed != null && parsed.host.isNotEmpty) {
      return _Endpoint(parsed.host, parsed.hasPort ? parsed.port : 80);
    }
  }
  final uri = request.requestedUri;
  return _Endpoint(uri.host, uri.port);
}

class _Endpoint {
  const new(this.host, this.port);

  final String host;
  final int port;
}

/// `server_info.time_now`: local wall clock, as panels send it.
String _stamp(DateTime local) {
  String p(int value) => '$value'.padLeft(2, '0');
  return '${local.year}-${p(local.month)}-${p(local.day)} '
      '${p(local.hour)}:${p(local.minute)}:${p(local.second)}';
}
