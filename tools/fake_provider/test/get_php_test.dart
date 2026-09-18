import 'dart:convert';

import 'package:fake_provider/get_php.dart';
import 'package:fake_provider/profile.dart';
import 'package:fake_provider/server_state.dart';
import 'package:shelf/shelf.dart';
import 'package:test/test.dart';

const small = FakeProfile(
  name: 'small',
  seed: 5,
  liveCount: 6,
  movieCount: 4,
  seriesCount: 2,
  liveCategoryCount: 2,
  movieCategoryCount: 2,
  seriesCategoryCount: 1,
);

FakeServerState stateOf(FakeProfile profile) => FakeServerState(
  profile: profile,
  samplesDir: '.',
  ffmpegPath: 'ffmpeg',
  runDir: '.',
);

Future<Response> call(FakeServerState state, String query) => Future.value(
  getPhpHandler(state)(
    Request('GET', Uri.parse('http://localhost:8899/get.php$query')),
  ),
);

Future<List<int>> bytesOf(Response response) async =>
    (await response.read().toList()).expand((chunk) => chunk).toList();

Future<List<String>> linesOf(Response response) async => const LineSplitter()
    .convert(utf8.decode(await bytesOf(response), allowMalformed: true));

int episodeCount(FakeServerState state) => state.catalog
    .series()
    .map((s) => state.catalog.episodesOf(s).values.expand((e) => e).length)
    .fold(0, (a, b) => a + b);

void main() {
  test('wrong credentials: 401, no playlist', () async {
    final response = await call(
      stateOf(small),
      '?username=test&password=wrong',
    );

    expect(response.statusCode, 401);
  });

  test('every channel, movie and episode, each an #EXTINF and a URL', () async {
    final state = stateOf(small);
    final lines = await linesOf(
      await call(state, '?username=test&password=test'),
    );

    expect(lines.first, startsWith('#EXTM3U url-tvg="http://localhost:8899/'));
    final infos = lines.where((l) => l.startsWith('#EXTINF:')).length;
    final urls = lines.where((l) => l.startsWith('http://')).toList();
    final expected = 6 + 4 + episodeCount(state);
    expect(infos, expected);
    expect(urls, hasLength(expected));
    expect(urls.where((u) => u.contains('/live/test/test/')), hasLength(6));
    expect(urls.where((u) => u.contains('/movie/test/test/')), hasLength(4));
    expect(
      urls.where((u) => u.contains('/series/test/test/')),
      hasLength(episodeCount(state)),
    );
  });

  test('m3u_plus carries the tvg attributes; m3u only titles', () async {
    final state = stateOf(small);
    final plus = await linesOf(
      await call(state, '?username=test&password=test'),
    );
    final plain = await linesOf(
      await call(state, '?username=test&password=test&type=m3u'),
    );

    expect(plus[1], contains('group-title="'));
    expect(plain[1], matches(RegExp(r'^#EXTINF:-1,[^"]+$')));
  });

  test('output=m3u8 changes the live extension only', () async {
    final lines = await linesOf(
      await call(stateOf(small), '?username=test&password=test&output=m3u8'),
    );

    expect(lines[2], endsWith('.m3u8'));
  });

  test('episodes are named with their season and episode', () async {
    final lines = await linesOf(
      await call(stateOf(small), '?username=test&password=test'),
    );

    expect(
      lines.where((l) => l.startsWith('#EXTINF:')).last,
      matches(RegExp(r',.+ S\d\d E\d\d$')),
    );
  });

  test('the quirky profile: CRLF, #EXTVLCOPT and #KODIPROP, and invalid '
      'UTF-8 bytes', () async {
    final bytes = await bytesOf(
      await call(
        stateOf(fakeProfiles['quirky']!),
        '?username=test&password=test',
      ),
    );
    final text = utf8.decode(bytes, allowMalformed: true);

    expect(text, contains('\r\n'));
    expect(text, contains('#EXTVLCOPT:http-user-agent='));
    expect(text, contains('#KODIPROP:'));
    expect(bytes, contains(0xff));
  });
}
