/// Xtream stream URLs (docs/02): `{server}/live/{u}/{p}/{id}.{ts|m3u8}`,
/// `/movie/…/{id}.{ext}` and `/series/…/{id}.{ext}`, kept under any base
/// path the server has. Credentials go in as path segments, encoded.
library;

String xtreamLiveUrl({
  required String server,
  required String username,
  required String password,
  required String streamId,
  bool hls = false,
}) => _xtream(
  server,
  'live',
  username,
  password,
  '$streamId.${hls ? 'm3u8' : 'ts'}',
);

String xtreamMovieUrl({
  required String server,
  required String username,
  required String password,
  required String streamId,
  required String extension,
}) => _xtream(server, 'movie', username, password, '$streamId.$extension');

String xtreamEpisodeUrl({
  required String server,
  required String username,
  required String password,
  required String episodeId,
  required String extension,
}) => _xtream(server, 'series', username, password, '$episodeId.$extension');

String _xtream(
  String server,
  String kind,
  String username,
  String password,
  String file,
) {
  final base = Uri.parse(server.trim());
  return base
      .replace(
        pathSegments: [
          ...base.pathSegments.where((s) => s.isNotEmpty),
          kind,
          username,
          password,
          file,
        ],
      )
      .toString()
      // Uri.replace keeps an empty query as "?"; a stream URL has none.
      .replaceFirst(RegExp(r'\?$'), '');
}
