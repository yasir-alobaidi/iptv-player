import 'dart:convert';

import 'package:fake_provider/player_api.dart';
import 'package:fake_provider/profile.dart';
import 'package:fake_provider/server_state.dart';
import 'package:shelf/shelf.dart';
import 'package:test/test.dart';

/// docs/02 base: credentials ride in the query string.
const creds = 'username=test&password=test';

/// A profile with no expiry and no quirks, so `exp_date: null` can be seen
/// on its own (the `quirky` profile has both).
const neverExpires = FakeProfile(
  name: 'never-expires',
  seed: 3,
  liveCount: 8,
  movieCount: 4,
  seriesCount: 2,
  liveCategoryCount: 2,
  movieCategoryCount: 2,
  seriesCategoryCount: 1,
  expiresInDays: null,
);

FakeServerState stateOf(FakeProfile profile) => FakeServerState(
  profile: profile,
  samplesDir: '.',
  ffmpegPath: 'ffmpeg',
  runDir: '.',
);

Future<Response> call(
  FakeServerState state,
  String query, {
  Map<String, String>? headers,
  String? formBody,
}) => Future.value(
  playerApiHandler(state)(
    Request(
      formBody == null ? 'GET' : 'POST',
      Uri.parse('http://localhost:8899/player_api.php$query'),
      headers: headers,
      body: formBody,
    ),
  ),
);

Future<List<int>> bytesOf(Response response) async =>
    (await response.read().toList()).expand((chunk) => chunk).toList();

/// The body as the app decodes it: `allowMalformed: true` (docs/02).
Future<Object?> jsonOf(
  FakeServerState state,
  String query, {
  Map<String, String>? headers,
  String? formBody,
}) async {
  final response = await call(
    state,
    query,
    headers: headers,
    formBody: formBody,
  );
  final bytes = await bytesOf(response);
  return jsonDecode(utf8.decode(bytes, allowMalformed: true));
}

Future<Map<String, Object?>> mapOf(
  FakeServerState state,
  String query, {
  Map<String, String>? headers,
  String? formBody,
}) async =>
    (await jsonOf(state, query, headers: headers, formBody: formBody))!
        as Map<String, Object?>;

Future<List<Map<String, Object?>>> listOf(
  FakeServerState state,
  String query,
) async => ((await jsonOf(state, query))! as List<Object?>)
    .cast<Map<String, Object?>>();

void main() {
  group('account', () {
    test('reports an active account, and its expiry', () async {
      final state = stateOf(fakeProfiles['default']!);
      final body = await mapOf(state, '?$creds');
      final user = body['user_info']! as Map<String, Object?>;

      expect(user['auth'], 1);
      expect(user['status'], 'Active');
      expect(user['username'], 'test');
      expect(user['is_trial'], 0);
      expect(user['active_cons'], 0);
      expect(user['max_connections'], 2);
      expect(user['allowed_output_formats'], ['ts', 'm3u8']);
      expect(int.parse(user['created_at']! as String), isPositive);
      final expDate = int.parse(user['exp_date']! as String);
      final now = DateTime.now().millisecondsSinceEpoch ~/ 1000;
      expect(expDate, greaterThan(now));
    });

    test('active_cons follows the stream handler', () async {
      final state = stateOf(fakeProfiles['default']!)..activeStreams = 2;
      final body = await mapOf(state, '?$creds');
      expect((body['user_info']! as Map<String, Object?>)['active_cons'], 2);
    });

    test('max_connections follows the fault override', () async {
      final state = stateOf(fakeProfiles['default']!)
        ..faults = const FakeFaults(maxConnections: 7);
      final body = await mapOf(state, '?$creds');
      expect(
        (body['user_info']! as Map<String, Object?>)['max_connections'],
        7,
      );
    });

    test('exp_date is null when the account never expires', () async {
      final body = await mapOf(stateOf(neverExpires), '?$creds');
      expect((body['user_info']! as Map<String, Object?>)['exp_date'], isNull);
    });

    test('exp_date is "" with the emptyStringForNull quirk', () async {
      final body = await mapOf(stateOf(fakeProfiles['quirky']!), '?$creds');
      expect((body['user_info']! as Map<String, Object?>)['exp_date'], '');
    });

    test('server_info carries the docs/02 fields', () async {
      final body = await mapOf(stateOf(fakeProfiles['default']!), '?$creds');
      final server = body['server_info']! as Map<String, Object?>;
      expect(server.keys, {
        'url',
        'port',
        'https_port',
        'server_protocol',
        'rtmp_port',
        'timezone',
        'timestamp_now',
        'time_now',
      });
      expect(server['server_protocol'], 'http');
      expect(
        server['time_now'],
        matches(r'^\d{4}-\d{2}-\d{2} \d{2}:\d{2}:\d{2}$'),
      );
    });

    test('server_info url and port follow the Host header', () async {
      final body = await mapOf(
        stateOf(fakeProfiles['default']!),
        '?$creds',
        headers: {'host': 'iptv.example:9911'},
      );
      final server = body['server_info']! as Map<String, Object?>;
      expect(server['url'], 'iptv.example');
      expect(server['port'], 9911);
    });

    test('a Host header without a port means 80', () async {
      final body = await mapOf(
        stateOf(fakeProfiles['default']!),
        '?$creds',
        headers: {'host': 'iptv.example'},
      );
      final server = body['server_info']! as Map<String, Object?>;
      expect(server['url'], 'iptv.example');
      expect(server['port'], 80);
    });

    test('without a Host header it falls back to the requested URI', () async {
      final body = await mapOf(stateOf(fakeProfiles['default']!), '?$creds');
      final server = body['server_info']! as Map<String, Object?>;
      expect(server['url'], 'localhost');
      expect(server['port'], 8899);
    });
  });

  group('credentials', () {
    test('wrong password is auth 0 with HTTP 200', () async {
      final state = stateOf(fakeProfiles['default']!);
      final response = await call(state, '?username=test&password=nope');
      expect(response.statusCode, 200);
      final body = jsonDecode(
        utf8.decode(await bytesOf(response)),
      ) as Map<String, Object?>;
      expect(body['user_info'], {'auth': 0, 'status': 'Disabled'});
      expect(body.containsKey('server_info'), isFalse);
    });

    test('missing credentials are auth 0, whatever the action', () async {
      final body = await mapOf(
        stateOf(fakeProfiles['default']!),
        '?action=get_live_streams',
      );
      expect((body['user_info']! as Map<String, Object?>)['auth'], 0);
    });

    test('POST reads credentials from a form body', () async {
      final body = await mapOf(
        stateOf(fakeProfiles['default']!),
        '',
        formBody: creds,
      );
      expect((body['user_info']! as Map<String, Object?>)['auth'], 1);
    });

    test('query parameters win over the POST body', () async {
      final body = await mapOf(
        stateOf(fakeProfiles['default']!),
        '?$creds',
        formBody: 'username=wrong&password=wrong',
      );
      expect((body['user_info']! as Map<String, Object?>)['auth'], 1);
    });
  });

  group('lists', () {
    final state = stateOf(fakeProfiles['default']!);

    test('get_live_categories', () async {
      final items = await listOf(state, '?$creds&action=get_live_categories');
      expect(items, hasLength(state.profile.liveCategoryCount));
      expect(items.first.keys, {'category_id', 'category_name', 'parent_id'});
      expect(items.first['category_id'], isA<String>());
      expect(items.first['parent_id'], 0);
    });

    test('get_live_streams has the docs/02 fields', () async {
      final items = await listOf(state, '?$creds&action=get_live_streams');
      expect(items, hasLength(state.profile.liveCount));
      expect(
        items.first.keys,
        containsAll([
          'num',
          'name',
          'stream_type',
          'stream_id',
          'stream_icon',
          'epg_channel_id',
          'category_id',
          'added',
          'tv_archive',
          'tv_archive_duration',
        ]),
      );
      expect(items.first['stream_type'], 'live');
      expect(items.first['stream_id'], isA<int>());
      expect(items.first['added'], isA<String>());
    });

    test('get_live_streams filters on category_id', () async {
      final categories = await listOf(
        state,
        '?$creds&action=get_live_categories',
      );
      final id = categories[1]['category_id']! as String;
      final filtered = await listOf(
        state,
        '?$creds&action=get_live_streams&category_id=$id',
      );
      expect(filtered, isNotEmpty);
      expect(filtered.length, lessThan(state.profile.liveCount));
      expect(
        filtered.every((item) => item['category_id'] == id),
        isTrue,
        reason: 'the filter must not leak other categories',
      );
    });

    test('an empty category_id means all of them', () async {
      final items = await listOf(
        state,
        '?$creds&action=get_live_streams&category_id=',
      );
      expect(items, hasLength(state.profile.liveCount));
    });

    test('get_vod_categories and get_vod_streams', () async {
      final categories = await listOf(
        state,
        '?$creds&action=get_vod_categories',
      );
      expect(categories, hasLength(state.profile.movieCategoryCount));

      final movies = await listOf(state, '?$creds&action=get_vod_streams');
      expect(movies, hasLength(state.profile.movieCount));
      expect(
        movies.first.keys,
        containsAll([
          'num',
          'name',
          'stream_type',
          'stream_id',
          'stream_icon',
          'rating',
          'added',
          'category_id',
          'container_extension',
        ]),
      );
      expect(movies.first['stream_type'], 'movie');

      final id = categories.first['category_id']! as String;
      final filtered = await listOf(
        state,
        '?$creds&action=get_vod_streams&category_id=$id',
      );
      expect(filtered, isNotEmpty);
      expect(filtered.every((item) => item['category_id'] == id), isTrue);
    });

    test('get_series_categories and get_series', () async {
      final categories = await listOf(
        state,
        '?$creds&action=get_series_categories',
      );
      expect(categories, hasLength(state.profile.seriesCategoryCount));

      final series = await listOf(state, '?$creds&action=get_series');
      expect(series, hasLength(state.profile.seriesCount));
      expect(
        series.first.keys,
        containsAll([
          'num',
          'name',
          'series_id',
          'cover',
          'plot',
          'genre',
          'releaseDate',
          'last_modified',
          'rating',
          'category_id',
        ]),
      );

      final id = categories.first['category_id']! as String;
      final filtered = await listOf(
        state,
        '?$creds&action=get_series&category_id=$id',
      );
      expect(filtered, isNotEmpty);
      expect(filtered.every((item) => item['category_id'] == id), isTrue);
    });

    test('lists are written one item per chunk, never as one string', () async {
      final response = await call(state, '?$creds&action=get_live_streams');
      final chunks = await response.read().toList();
      // `[`, 240 items, `]`
      expect(chunks, hasLength(state.profile.liveCount + 2));
      expect(response.headers['content-type'], 'application/json');
    });
  });

  group('details', () {
    final state = stateOf(fakeProfiles['default']!);

    test('get_vod_info returns info and movie_data', () async {
      final movies = await listOf(state, '?$creds&action=get_vod_streams');
      final id = movies.first['stream_id']! as int;
      final body = await mapOf(state, '?$creds&action=get_vod_info&vod_id=$id');

      expect(body.keys, {'info', 'movie_data'});
      final info = body['info']! as Map<String, Object?>;
      expect(
        info.keys,
        containsAll([
          'movie_image',
          'plot',
          'cast',
          'director',
          'genre',
          'releasedate',
          'rating',
          'duration_secs',
          'duration',
        ]),
      );
      expect(info['duration'], matches(r'^\d+:\d{2}:\d{2}$'));
      expect((body['movie_data']! as Map<String, Object?>)['stream_id'], id);
    });

    test('get_series_info has seasons, info, and episodes as a list', () async {
      final series = await listOf(state, '?$creds&action=get_series');
      final id = series.first['series_id']! as int;
      final body = await mapOf(
        state,
        '?$creds&action=get_series_info&series_id=$id',
      );

      expect(body.keys, {'seasons', 'info', 'episodes'});
      final seasons = (body['seasons']! as List<Object?>)
          .cast<Map<String, Object?>>();
      expect(seasons, isNotEmpty);
      expect(
        seasons.first.keys,
        containsAll([
          'air_date',
          'episode_count',
          'id',
          'name',
          'season_number',
          'cover',
        ]),
      );
      expect((body['info']! as Map<String, Object?>)['series_id'], id);

      final episodes = (body['episodes']! as List<Object?>)
          .cast<Map<String, Object?>>();
      expect(episodes, isNotEmpty);
      expect(
        episodes.first.keys,
        containsAll([
          'id',
          'episode_num',
          'title',
          'container_extension',
          'info',
          'added',
          'season',
        ]),
      );
      expect(episodes.first['id'], isA<String>());
      final counted = seasons.fold<int>(
        0,
        (sum, season) => sum + (season['episode_count']! as int),
      );
      expect(
        episodes,
        hasLength(counted),
        reason: 'the flat list holds every season',
      );
    });

    test('episodes are a map keyed by season with the quirk on', () async {
      final quirky = stateOf(fakeProfiles['quirky']!);
      final series = await listOf(quirky, '?$creds&action=get_series');
      final id = int.parse(series.first['series_id']! as String);
      final body = await mapOf(
        quirky,
        '?$creds&action=get_series_info&series_id=$id',
      );

      final episodes = body['episodes']! as Map<String, Object?>;
      expect(episodes.keys, isNotEmpty);
      expect(episodes.keys.first, '1');
      expect(
        episodes.keys.every((key) => int.tryParse(key) != null),
        isTrue,
        reason: 'keys are season numbers as strings',
      );
      expect(episodes.values.first, isA<List<Object?>>());
    });

    test('unknown ids answer empty, never an error', () async {
      expect(
        await mapOf(state, '?$creds&action=get_vod_info&vod_id=999999999'),
        isEmpty,
      );
      expect(await mapOf(state, '?$creds&action=get_vod_info'), isEmpty);
      expect(
        await mapOf(
          state,
          '?$creds&action=get_series_info&series_id=999999999',
        ),
        isEmpty,
      );
      expect(
        await mapOf(state, '?$creds&action=get_series_info&series_id=abc'),
        isEmpty,
      );
      expect(
        await mapOf(state, '?$creds&action=get_short_epg&stream_id=999999999'),
        {'epg_listings': <Object?>[]},
      );
    });
  });

  group('get_short_epg', () {
    final state = stateOf(fakeProfiles['default']!);

    test('titles and descriptions are base64 (docs/02)', () async {
      final channels = await listOf(state, '?$creds&action=get_live_streams');
      final withEpg = channels.firstWhere(
        (channel) => channel['epg_channel_id'] != null,
      );
      final id = withEpg['stream_id']! as int;
      final body = await mapOf(
        state,
        '?$creds&action=get_short_epg&stream_id=$id',
      );

      final listings = (body['epg_listings']! as List<Object?>)
          .cast<Map<String, Object?>>();
      expect(listings, isNotEmpty);
      expect(listings, hasLength(lessThanOrEqualTo(defaultShortEpgLimit)));
      final first = listings.first;
      expect(
        first.keys,
        containsAll([
          'id',
          'title',
          'lang',
          'start',
          'end',
          'description',
          'channel_id',
          'start_timestamp',
          'stop_timestamp',
          'now_playing',
        ]),
      );
      expect(utf8.decode(base64.decode(first['title']! as String)), isNotEmpty);
      expect(
        utf8.decode(base64.decode(first['description']! as String)),
        isNotEmpty,
      );
      expect(first['now_playing'], 1, reason: 'the first entry is now');
      expect(listings.last['now_playing'], 0);
    });

    test('limit caps the listings', () async {
      final channels = await listOf(state, '?$creds&action=get_live_streams');
      final withEpg = channels.firstWhere(
        (channel) => channel['epg_channel_id'] != null,
      );
      final id = withEpg['stream_id']! as int;

      final one = await mapOf(
        state,
        '?$creds&action=get_short_epg&stream_id=$id&limit=1',
      );
      expect(one['epg_listings'], hasLength(1));

      final six = await mapOf(
        state,
        '?$creds&action=get_short_epg&stream_id=$id&limit=6',
      );
      expect(six['epg_listings'], hasLength(6));
    });

    test('a channel without EPG answers an empty list', () async {
      final channels = await listOf(state, '?$creds&action=get_live_streams');
      final withoutEpg = channels.where(
        (channel) => channel['epg_channel_id'] == null,
      );
      if (withoutEpg.isEmpty) return;
      final id = withoutEpg.first['stream_id']! as int;
      final body = await mapOf(
        state,
        '?$creds&action=get_short_epg&stream_id=$id',
      );
      expect(body['epg_listings'], isEmpty);
    });
  });

  group('unknown action', () {
    test('is a documented 501', () async {
      final state = stateOf(fakeProfiles['default']!);
      final response = await call(
        state,
        '?$creds&action=get_simple_data_table',
      );
      expect(response.statusCode, 501);
      final body = jsonDecode(
        utf8.decode(await bytesOf(response)),
      ) as Map<String, Object?>;
      expect(body['action'], 'get_simple_data_table');
      expect(body['supported_actions'], supportedActions);
      expect(body['message'], contains('lib/player_api.dart'));
    });
  });

  group('quirks', () {
    test('numbersAsStrings turns every number into a string', () async {
      final quirky = stateOf(fakeProfiles['quirky']!);
      final account = await mapOf(quirky, '?$creds');
      final user = account['user_info']! as Map<String, Object?>;
      expect(user['auth'], '1');
      expect(user['active_cons'], '0');
      expect(user['max_connections'], '2');
      expect(
        (account['server_info']! as Map<String, Object?>)['port'],
        isA<String>(),
      );

      final channels = await listOf(quirky, '?$creds&action=get_live_streams');
      expect(channels.first['num'], isA<String>());
      expect(channels.first['stream_id'], isA<String>());
      expect(channels.first['tv_archive'], anyOf('0', '1'));
    });

    test('invalidUtf8Names puts malformed bytes on the wire', () async {
      final quirky = stateOf(fakeProfiles['quirky']!);
      final response = await call(quirky, '?$creds&action=get_live_streams');
      final bytes = await bytesOf(response);

      expect(
        () => utf8.decode(bytes),
        throwsA(isA<FormatException>()),
        reason: 'the body really is malformed, not just odd-looking',
      );
      final decoded = utf8.decode(bytes, allowMalformed: true);
      expect(decoded, contains('\u{FFFD}'));
      expect(decoded, isNot(contains(invalidUtf8Marker)));
      // and it is still JSON once decoded the way the app decodes it
      final items = (jsonDecode(decoded) as List<Object?>)
          .cast<Map<String, Object?>>();
      expect(items, hasLength(quirky.profile.liveCount));
      expect(
        items.where((item) => (item['name']! as String).contains('\u{FFFD}')),
        isNotEmpty,
      );
    });

    test('a clean profile stays valid UTF-8', () async {
      final state = stateOf(fakeProfiles['default']!);
      final bytes = await bytesOf(
        await call(state, '?$creds&action=get_live_streams'),
      );
      expect(utf8.decode(bytes), isNotEmpty);
    });
  });
}
