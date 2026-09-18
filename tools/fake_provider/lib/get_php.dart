/// `get.php`: the whole catalogue as an M3U playlist, the way Xtream panels
/// export it (docs/02 "M3U"). `type=m3u_plus` (the default) carries the
/// `tvg-*` and `group-title` attributes; `type=m3u` only titles.
/// `output=ts` (default) or `m3u8` picks the live streams' extension.
///
/// Live channels, then movies, then every series' episodes, written onto
/// the response one entry at a time like the JSON lists, so the `large`
/// profile's playlist never exists whole.
library;

import 'package:fake_provider/player_api.dart';
import 'package:fake_provider/server_state.dart';
import 'package:shelf/shelf.dart';

/// The handler for `/get.php`; the caller owns the route.
Handler getPhpHandler(FakeServerState state) {
  return (Request request) {
    final params = request.url.queryParameters;
    final username = params['username'];
    final password = params['password'];
    // Panels refuse a playlist outright; there is no JSON to put auth 0 in.
    if (!state.authenticates(username, password)) {
      return Response(401, body: 'Unauthorized');
    }
    final plus = (params['type'] ?? 'm3u_plus') != 'm3u';
    final liveExt = params['output'] == 'm3u8' ? 'm3u8' : 'ts';
    return Response.ok(
      _playlist(
        state,
        origin: requestOrigin(request),
        username: username!,
        password: password!,
        plus: plus,
        liveExt: liveExt,
      ),
      headers: const {'content-type': 'audio/x-mpegurl; charset=utf-8'},
    );
  };
}

Stream<List<int>> _playlist(
  FakeServerState state, {
  required String origin,
  required String username,
  required String password,
  required bool plus,
  required String liveExt,
}) async* {
  final quirks = state.profile.quirks;
  final newline = quirks.messyM3u ? '\r\n' : '\n';
  final catalog = state.catalog;
  List<int> encode(String text) =>
      encodeWireText(text, breakUtf8: quirks.invalidUtf8Names);

  final credentials = '$username/$password';
  yield encode(
    '#EXTM3U url-tvg="$origin/xmltv.php?username=$username'
    '&password=$password"$newline',
  );

  final liveGroups = {for (final c in catalog.liveCategories) c.id: c.name};
  var index = 0;
  for (final channel in catalog.channels()) {
    index++;
    final attributes = plus
        ? _attributes({
            'tvg-id': channel.epgChannelId,
            'tvg-name': channel.name,
            'tvg-logo': channel.icon,
            'group-title': liveGroups[channel.categoryId] ?? '',
            if (channel.archiveDays > 0) 'catchup': 'xc',
            if (channel.archiveDays > 0)
              'catchup-days': '${channel.archiveDays}',
          })
        : '';
    yield encode(
      '#EXTINF:-1$attributes,${channel.name}$newline'
      '${_messy(quirks.messyM3u, index, newline)}'
      '$origin/live/$credentials/${channel.streamId}.$liveExt$newline',
    );
  }

  final movieGroups = {for (final c in catalog.movieCategories) c.id: c.name};
  for (final movie in catalog.movies()) {
    index++;
    final attributes = plus
        ? _attributes({
            'tvg-name': movie.name,
            'tvg-logo': movie.icon,
            'group-title': movieGroups[movie.categoryId] ?? '',
          })
        : '';
    yield encode(
      '#EXTINF:-1$attributes,${movie.name}$newline'
      '${_messy(quirks.messyM3u, index, newline)}'
      '$origin/movie/$credentials/${movie.streamId}'
      '.${movie.containerExtension}$newline',
    );
  }

  final seriesGroups = {for (final c in catalog.seriesCategories) c.id: c.name};
  for (final series in catalog.series()) {
    for (final MapEntry(key: season, value: episodes)
        in catalog.episodesOf(series).entries) {
      for (final episode in episodes) {
        index++;
        final name =
            '${series.name} S${_two(season)} E${_two(episode.episode)}';
        final attributes = plus
            ? _attributes({
                'tvg-name': name,
                'tvg-logo': series.cover,
                'group-title': seriesGroups[series.categoryId] ?? '',
              })
            : '';
        yield encode(
          '#EXTINF:-1$attributes,$name$newline'
          '${_messy(quirks.messyM3u, index, newline)}'
          '$origin/series/$credentials/${episode.id}'
          '.${episode.containerExtension}$newline',
        );
      }
    }
  }
}

/// ` key="value"` for each attribute with a value, as panels write them.
String _attributes(Map<String, String?> values) => [
  for (final MapEntry(:key, :value) in values.entries)
    if (value != null) ' $key="$value"',
].join();

/// The lines a messy export puts between an `#EXTINF` and its URL.
String _messy(bool on, int index, String newline) => !on
    ? ''
    : [
        if (index % 7 == 0) '#EXTVLCOPT:http-user-agent=FakePanel/1.0$newline',
        if (index % 9 == 0)
          '#KODIPROP:inputstream.adaptive.manifest_type=mpd$newline',
      ].join();

String _two(int value) => '$value'.padLeft(2, '0');
