import 'package:flutter_test/flutter_test.dart';
import 'package:iptv_player/features/playback/data/stream_urls.dart';

void main() {
  test('live: TS by default, HLS on request', () {
    expect(
      xtreamLiveUrl(
        server: 'http://line.test:8080',
        username: 'viewer',
        password: 'secret',
        streamId: '201',
      ),
      'http://line.test:8080/live/viewer/secret/201.ts',
    );
    expect(
      xtreamLiveUrl(
        server: 'http://line.test:8080/',
        username: 'viewer',
        password: 'secret',
        streamId: '201',
        hls: true,
      ),
      'http://line.test:8080/live/viewer/secret/201.m3u8',
    );
  });

  test('a server with a base path keeps it', () {
    expect(
      xtreamLiveUrl(
        server: 'https://panel.test/iptv/',
        username: 'u',
        password: 'p',
        streamId: '7',
      ),
      'https://panel.test/iptv/live/u/p/7.ts',
    );
  });

  test('credentials with URL characters are encoded, not broken', () {
    final url = xtreamLiveUrl(
      server: 'http://line.test',
      username: 'a b',
      password: 'p/w?#%',
      streamId: '1',
    );

    expect(url, 'http://line.test/live/a%20b/p%2Fw%3F%23%25/1.ts');
    expect(Uri.parse(url).pathSegments, ['live', 'a b', 'p/w?#%', '1.ts']);
  });

  test('movie and episode paths (Phase 5)', () {
    expect(
      xtreamMovieUrl(
        server: 'http://line.test',
        username: 'u',
        password: 'p',
        streamId: '55',
        extension: 'mkv',
      ),
      'http://line.test/movie/u/p/55.mkv',
    );
    expect(
      xtreamEpisodeUrl(
        server: 'http://line.test',
        username: 'u',
        password: 'p',
        episodeId: '9001',
        extension: 'mp4',
      ),
      'http://line.test/series/u/p/9001.mp4',
    );
  });
}
