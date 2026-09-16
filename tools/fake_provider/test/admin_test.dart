import 'dart:convert';
import 'dart:io';

import 'package:fake_provider/admin.dart';
import 'package:fake_provider/profile.dart';
import 'package:fake_provider/server_state.dart';
import 'package:shelf/shelf.dart';
import 'package:test/test.dart';

/// `/admin/faults` is how an integration test changes the provider between
/// steps, so the contract checked here is the one those tests will lean on:
/// a POST is the complete new state, junk is refused, and nothing a test
/// sends can take the server down.
void main() {
  late FakeServerState state;
  late Handler admin;

  setUp(() {
    state = FakeServerState(
      profile: fakeProfiles['default']!,
      samplesDir: '.',
      ffmpegPath: 'ffmpeg',
      runDir: '.',
    );
    admin = adminHandler(state);
  });

  Future<Map<String, Object?>> json(Response response) async =>
      jsonDecode(await response.readAsString()) as Map<String, Object?>;

  Future<Response> get(String path) =>
      Future.value(admin(Request('GET', Uri.parse('http://x$path'))));

  Future<Response> post(String body) => Future.value(
    admin(Request('POST', Uri.parse('http://x/admin/faults'), body: body)),
  );

  test('GET reports the fault set and which server answered', () async {
    final response = await get('/admin/faults');
    expect(response.statusCode, HttpStatus.ok);
    final body = await json(response);

    expect(body['profile'], 'default');
    expect(body['max_connections'], fakeProfiles['default']!.maxConnections);
    expect(body['active_streams'], 0);
    expect(body['uptime_s'], isA<int>());
    expect(
      (body['counts']! as Map<String, Object?>)['live'],
      fakeProfiles['default']!.liveCount,
    );
    // Quirks come along because a surprising list is usually the wrong
    // profile, and this is the one place that says which one is running.
    expect(
      (body['quirks']! as Map<String, Object?>)['numbers_as_strings'],
      false,
    );
    final faults = body['faults']! as Map<String, Object?>;
    expect(faults['drop_after_s'], isNull);
    expect(faults['ignore_range'], false);
  });

  test('POST replaces the set wholesale', () async {
    final first = await post(
      jsonEncode({'drop_after_s': 12, 'throttle_kbps': 800}),
    );
    expect(first.statusCode, HttpStatus.ok);
    expect((await json(first))['drop_after_s'], 12);
    expect(state.faults.dropAfterS, 12);
    expect(state.faults.throttleKbps, 800);

    // A key the second POST leaves out is off again: the body is the state,
    // not a patch.
    final second = await post(jsonEncode({'stall_after_s': 3}));
    expect((await json(second))['drop_after_s'], isNull);
    expect(state.faults.dropAfterS, isNull);
    expect(state.faults.stallAfterS, 3);
  });

  test('a POSTed max_connections wins over the profile', () async {
    expect(state.maxConnections, 2);
    await post(jsonEncode({'max_connections': 5}));
    expect(state.maxConnections, 5);
    expect((await json(await get('/admin/faults')))['max_connections'], 5);
  });

  test('values arriving as strings are accepted', () async {
    // A shell test posting '{"http_status":"429"}' should work; docs/02's
    // "numbers as strings" world does not stop at the provider's own API.
    final response = await post(
      jsonEncode({'http_status': '429', 'ignore_range': '1'}),
    );
    expect((await json(response))['http_status'], 429);
    expect(state.faults.ignoreRange, isTrue);
  });

  test('unknown keys and wrong types are ignored, not refused', () async {
    final response = await post(
      jsonEncode({
        'not_a_fault': 1,
        'drop_after_s': <String>['nonsense'],
      }),
    );
    expect(response.statusCode, HttpStatus.ok);
    expect(state.faults.dropAfterS, isNull);
  });

  test('junk and a non-object body are 400', () async {
    final junk = await post('{not json');
    expect(junk.statusCode, HttpStatus.badRequest);
    final list = await post(jsonEncode([1, 2, 3]));
    expect(list.statusCode, HttpStatus.badRequest);
    // A refused POST leaves the set alone.
    expect(state.faults.toJson(), const FakeFaults().toJson());
  });

  test('DELETE clears the set', () async {
    await post(jsonEncode({'drop_after_s': 9, 'change_etag': true}));
    final response = await admin(
      Request('DELETE', Uri.parse('http://x/admin/faults')),
    );
    expect(response.statusCode, HttpStatus.ok);
    expect(state.faults.toJson(), const FakeFaults().toJson());
  });

  test('another path is a 404 so the server can cascade past it', () async {
    expect((await get('/admin/nope')).statusCode, HttpStatus.notFound);
    expect((await get('/player_api.php')).statusCode, HttpStatus.notFound);
  });
}
