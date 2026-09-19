/// `/admin/faults`: read, replace, and clear the fault set at runtime, so an
/// integration test can change the provider's behaviour between steps
/// (docs/06 "Admin endpoint to change faults at runtime").
///
/// This endpoint only stores and reports the set; each fault is honoured
/// where it is served. The live-stream faults (drop, stall, slow start,
/// HTTP status, max connections, expiring redirect, codec switch) act in
/// `streams.dart` since Phase 3; the Range and ETag faults arrive with
/// downloads (Phase 8).
library;

import 'dart:convert';

import 'package:fake_provider/profile.dart';
import 'package:fake_provider/server_state.dart';
import 'package:shelf/shelf.dart';
import 'package:shelf_router/shelf_router.dart';

Handler adminHandler(FakeServerState state) =>
    (Router(notFoundHandler: _unknownPath)
          ..get('/admin/faults', (Request request) => _faults(state))
          ..post('/admin/faults', (Request request) => _replace(state, request))
          ..delete('/admin/faults', (Request request) => _clear(state)))
        .call;

Response _unknownPath(Request request) =>
    Response.notFound('no admin endpoint at /${request.url.path}\n');

/// The fault set plus enough context to tell which server answered: a test
/// that gets a surprise can print this and see the profile and the live
/// connection count in one place.
Response _faults(FakeServerState state) {
  final profile = state.profile;
  return _json({
    'faults': state.faults.toJson(),
    'profile': profile.name,
    'counts': {
      'live': profile.liveCount,
      'movies': profile.movieCount,
      'series': profile.seriesCount,
      'live_categories': profile.liveCategoryCount,
      'movie_categories': profile.movieCategoryCount,
      'series_categories': profile.seriesCategoryCount,
    },
    'quirks': profile.quirks.toJson(),
    'max_connections': state.maxConnections,
    'active_streams': state.activeStreams,
    'uptime_s': DateTime.now().difference(state.startedAt).inSeconds,
  });
}

/// Replaces the set wholesale: a POST is the complete new state, so a key it
/// leaves out is off. Unknown keys and wrong types are ignored by
/// [FakeFaults.fromJson] rather than failing the request.
Future<Response> _replace(FakeServerState state, Request request) async {
  final body = await request.readAsString();
  Object? decoded;
  try {
    decoded = jsonDecode(body);
  } on FormatException catch (error) {
    return Response.badRequest(
      body: 'POST /admin/faults expects a JSON object body: ${error.message}\n',
    );
  }
  if (decoded is! Map<String, Object?>) {
    return Response.badRequest(
      body:
          'POST /admin/faults expects a JSON object body, '
          'got ${decoded.runtimeType}\n',
    );
  }
  state.faults = FakeFaults.fromJson(decoded);
  return _json(state.faults.toJson());
}

Response _clear(FakeServerState state) {
  state.faults = const FakeFaults();
  return _json(state.faults.toJson());
}

Response _json(Map<String, Object?> body) => Response.ok(
  jsonEncode(body),
  headers: {'content-type': 'application/json; charset=utf-8'},
);
