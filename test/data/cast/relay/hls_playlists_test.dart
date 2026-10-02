import 'package:flutter_test/flutter_test.dart';
import 'package:iptv_player/data/cast/relay/hls_playlists.dart';

/// The proxy rewrites a provider's playlists so their segments come
/// through it too (Phase 7 decision 3); the supervisor reads the playlist
/// FFmpeg writes.
void main() {
  group('rewritePlaylist', () {
    final base = Uri.parse(
      'http://panel.test:8080/live/user/pass/1.m3u8?token=abc',
    );
    String proxied(Uri uri) => 'P<$uri>';

    test('every URI, relative or absolute, resolved against the playlist', () {
      const text =
          '#EXTM3U\n'
          '#EXT-X-TARGETDURATION:2\n'
          '#EXTINF:2.0,\n'
          'seg1.ts\n'
          '#EXTINF:2.0,\n'
          '/hls/1/seg2.ts?t=9\n'
          '#EXTINF:2.0,\n'
          '../other/seg3.ts\n'
          '#EXTINF:2.0,\n'
          'https://cdn.test/seg4.ts\n';
      expect(
        rewritePlaylist(text, base, proxied),
        '#EXTM3U\n'
        '#EXT-X-TARGETDURATION:2\n'
        '#EXTINF:2.0,\n'
        'P<http://panel.test:8080/live/user/pass/seg1.ts>\n'
        '#EXTINF:2.0,\n'
        'P<http://panel.test:8080/hls/1/seg2.ts?t=9>\n'
        '#EXTINF:2.0,\n'
        'P<http://panel.test:8080/live/user/other/seg3.ts>\n'
        '#EXTINF:2.0,\n'
        'P<https://cdn.test/seg4.ts>\n',
      );
    });

    test('the URIs tags carry, and the variants of a master playlist', () {
      const text =
          '#EXTM3U\n'
          '#EXT-X-MEDIA:TYPE=AUDIO,GROUP-ID="a",NAME="en",URI="audio/en.m3u8"\n'
          '#EXT-X-STREAM-INF:BANDWIDTH=5000000,AUDIO="a"\n'
          'video/hd.m3u8\n'
          '#EXT-X-KEY:METHOD=AES-128,URI="https://keys.test/k?id=1",IV=0x1\n'
          '#EXT-X-MAP:URI="init.mp4"\n';
      expect(
        rewritePlaylist(text, base, proxied),
        '#EXTM3U\n'
        '#EXT-X-MEDIA:TYPE=AUDIO,GROUP-ID="a",NAME="en",'
        'URI="P<http://panel.test:8080/live/user/pass/audio/en.m3u8>"\n'
        '#EXT-X-STREAM-INF:BANDWIDTH=5000000,AUDIO="a"\n'
        'P<http://panel.test:8080/live/user/pass/video/hd.m3u8>\n'
        '#EXT-X-KEY:METHOD=AES-128,URI="P<https://keys.test/k?id=1>",IV=0x1\n'
        '#EXT-X-MAP:URI="P<http://panel.test:8080/live/user/pass/init.mp4>"\n',
      );
    });

    test('keeps line ends, blank lines and comments as they are', () {
      const text = '#EXTM3U\r\n\r\n## a comment\r\n#EXTINF:2,\r\n  a.ts  \r\n';
      expect(
        rewritePlaylist(text, base, proxied),
        '#EXTM3U\r\n\r\n## a comment\r\n#EXTINF:2,\r\n'
        'P<http://panel.test:8080/live/user/pass/a.ts>\r\n',
      );
    });

    test('a URI that cannot be read stays as it was', () {
      const text = '#EXTM3U\n#EXTINF:2,\nhttp://[bad\n';
      expect(rewritePlaylist(text, base, proxied), text);
    });
  });

  test('looksLikePlaylist', () {
    expect(looksLikePlaylist('#EXTM3U\n'), isTrue);
    expect(looksLikePlaylist('\ufeff  #EXTM3U\n'), isTrue);
    expect(looksLikePlaylist('<html>'), isFalse);
    expect(looksLikePlaylist(''), isFalse);
  });

  group('readHlsProgress', () {
    test('counts segments and names the newest', () {
      final progress = readHlsProgress(
        '#EXTM3U\n#EXT-X-MEDIA-SEQUENCE:4\n'
        '#EXTINF:2.0,\nseg00004.ts\n#EXTINF:2.0,\nseg00005.ts\n',
      );
      expect(progress.segments, 2);
      expect(progress.newest, 'seg00005.ts');
      expect(progress.mediaSequence, 4);
    });

    test("tolerates FFmpeg 4.4's date lines after an append", () {
      final progress = readHlsProgress(
        '#EXTM3U\n#EXT-X-MEDIA-SEQUENCE:0\n'
        '#EXTINF:2.000000,\nseg00000.ts\n'
        '#EXTINF:2.000000,\n'
        '#EXT-X-PROGRAM-DATE-TIME:1969-12-31T19:00:02.000-0500\n'
        'seg00001.ts\n'
        '#EXT-X-DISCONTINUITY\n'
        '#EXTINF:2.000000,\nseg00002.ts\n',
      );
      expect(progress.segments, 3);
      expect(progress.newest, 'seg00002.ts');
    });

    test('an empty or broken playlist has nothing', () {
      expect(readHlsProgress('').segments, 0);
      expect(readHlsProgress('#EXTM3U\nseg.ts\n').segments, 0);
      expect(readHlsProgress('#EXT-X-MEDIA-SEQUENCE:x\n').mediaSequence, 0);
    });

    test('moves on with a new newest segment, or a new sequence', () {
      const a = HlsProgress(segments: 6, newest: 'seg6.ts', mediaSequence: 1);
      expect(
        const HlsProgress(
          segments: 6,
          newest: 'seg7.ts',
          mediaSequence: 2,
        ).movedOn(a),
        isTrue,
      );
      expect(a.movedOn(a), isFalse);
      expect(HlsProgress.empty.movedOn(HlsProgress.empty), isFalse);
      expect(a.movedOn(HlsProgress.empty), isTrue);
    });
  });
}
