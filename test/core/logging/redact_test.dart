import 'package:flutter_test/flutter_test.dart';
import 'package:iptv_player/core/logging/redact.dart';

void main() {
  group('Xtream path credentials', () {
    final cases = {
      'http://provider.example:8080/live/john/s3cret/12345.ts':
          'http://provider.example:8080/live/***/***/12345.ts',
      'https://provider.example/live/john/s3cret/12345.m3u8':
          'https://provider.example/live/***/***/12345.m3u8',
      'http://provider.example/movie/john/s3cret/991.mkv':
          'http://provider.example/movie/***/***/991.mkv',
      'http://provider.example/series/john/s3cret/5501.mp4':
          'http://provider.example/series/***/***/5501.mp4',
      'http://p.example/timeshift/john/s3cret/120/2026-09-15:20-00/42.ts':
          'http://p.example/timeshift/***/***/120/2026-09-15:20-00/42.ts',
      'Open failed: http://p.example/LIVE/John/S3cret/1.ts (403)':
          'Open failed: http://p.example/LIVE/***/***/1.ts (403)',
    };
    for (final MapEntry(key: input, value: expected) in cases.entries) {
      test(input, () => expect(redact(input), expected));
    }
  });

  group('query-string credentials', () {
    final cases = {
      'http://p.example/player_api.php?username=john&password=s3cret'
              '&action=get_live_streams':
          'http://p.example/player_api.php?username=***&password=***'
          '&action=get_live_streams',
      'http://p.example/get.php?username=john&password=p%40ss&type=m3u_plus':
          'http://p.example/get.php?username=***&password=***&type=m3u_plus',
      'http://p.example/xmltv.php?PASSWORD=Secret&USERNAME=John':
          'http://p.example/xmltv.php?PASSWORD=***&USERNAME=***',
      '<a href="x.php?user=john&amp;pass=s3cret">':
          '<a href="x.php?user=***&amp;pass=***">',
      'https://cdn.example/stream.m3u8?token=abc123#t=10':
          'https://cdn.example/stream.m3u8?token=***#t=10',
      'https://api.example/v1?api_key=k1&apikey=k2&key=k3&sig=k4':
          'https://api.example/v1?api_key=***&apikey=***&key=***&sig=***',
    };
    for (final MapEntry(key: input, value: expected) in cases.entries) {
      test(input, () => expect(redact(input), expected));
    }
  });

  group('basic-auth URLs', () {
    final cases = {
      'http://john:s3cret@provider.example:8080/playlist.m3u':
          'http://***@provider.example:8080/playlist.m3u',
      'https://john@provider.example/epg.xml.gz':
          'https://***@provider.example/epg.xml.gz',
      'fetch rtsp://admin:p%40ss@10.0.0.2:554/stream failed':
          'fetch rtsp://***@10.0.0.2:554/stream failed',
    };
    for (final MapEntry(key: input, value: expected) in cases.entries) {
      test(input, () => expect(redact(input), expected));
    }
  });

  group('headers and structured data', () {
    test('Authorization header line', () {
      expect(
        redact('Authorization: Basic am9objpzM2NyZXQ='),
        'Authorization: ***',
      );
    });

    test('printed header map keeps other headers', () {
      expect(
        redact('{Authorization: Bearer abc.def, User-Agent: VLC/3.0}'),
        '{Authorization: ***, User-Agent: VLC/3.0}',
      );
    });

    test('Xtream user_info JSON', () {
      expect(
        redact(
          r'{"user_info":{"username":"john","password":"s3\"cret",'
          '"status":"Active","max_connections":"1"}}',
        ),
        '{"user_info":{"username":"***","password":"***",'
        '"status":"Active","max_connections":"1"}}',
      );
    });

    test('printed Dart map', () {
      expect(
        redact('{username: john, password: s3cret, status: Active}'),
        '{username: ***, password: ***, status: Active}',
      );
    });
  });

  group('registered secrets', () {
    test('masks exact values where no pattern applies', () {
      expect(
        redact(
          'GET http://p.example:8080/john99/s3cretPass/12345 failed',
          secrets: ['john99', 's3cretPass'],
        ),
        'GET http://p.example:8080/***/***/12345 failed',
      );
    });

    test('masks the URL-encoded form', () {
      expect(
        redact('http://p.example/u/p%40ss%20word/1', secrets: ['p@ss word']),
        'http://p.example/u/***/1',
      );
    });

    test('masks the longest secret first', () {
      expect(redact('token abcdef', secrets: ['abc', 'abcdef']), 'token ***');
    });

    test('ignores secrets shorter than minSecretLength', () {
      expect(redact('tv channel list', secrets: ['tv']), 'tv channel list');
    });
  });

  group('leaves ordinary text alone', () {
    const unchanged = [
      'https://image.tmdb.org/t/p/w500/poster.jpg',
      'http://p.example/player_api.php?action=get_vod_info&vod_id=42',
      'http://p.example:8080/movie/42.mkv',
      'Playing Live TV channel 12 · /live/',
      'Contact support@provider.example for help',
      'Sync finished: 12,340 channels, 8,021 movies',
      '',
    ];
    for (final input in unchanged) {
      test('"$input"', () => expect(redact(input), input));
    }
  });

  test('handles several credentials across lines', () {
    expect(
      redact(
        'retry 1: http://p.example/live/john/s3cret/1.ts\n'
        'retry 2: http://john:s3cret@p.example/get.php?password=s3cret',
      ),
      'retry 1: http://p.example/live/***/***/1.ts\n'
      'retry 2: http://***@p.example/get.php?password=***',
    );
  });

  test('is stable when applied twice', () {
    const input =
        'http://john:pw@p.example/live/john/pw/1.ts?token=t '
        'Authorization: Basic x {"password":"pw"}';
    final once = redact(input, secrets: ['john']);
    expect(redact(once, secrets: ['john']), once);
  });
}
