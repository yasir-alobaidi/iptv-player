import 'package:flutter_test/flutter_test.dart';
import 'package:iptv_player/features/sources/domain/source.dart';
import 'package:iptv_player/features/sources/domain/source_form.dart';

void main() {
  const xtream = SourceDraft(
    type: SourceType.xtream,
    name: 'Northwind',
    url: 'line.northwind.test:8080',
    username: 'living-room',
    password: 'secret',
  );

  group('validateDraft', () {
    test('a complete draft has no problems', () {
      expect(validateDraft(xtream, requirePassword: true), isEmpty);
    });

    test('names every missing Xtream field, in form order', () {
      final problems = validateDraft(
        const SourceDraft(type: SourceType.xtream, name: '', url: ''),
        requirePassword: true,
      );
      expect(problems, {
        DraftField.name: DraftProblem.missing,
        DraftField.url: DraftProblem.missing,
        DraftField.username: DraftProblem.missing,
        DraftField.password: DraftProblem.missing,
      });
    });

    test('an edit may leave the password blank', () {
      expect(
        validateDraft(xtream.copyWith(password: ''), requirePassword: false),
        isEmpty,
      );
    });

    test('a server that is not http(s) is invalid, not missing', () {
      expect(
        validateDraft(
          xtream.copyWith(url: 'ftp://line.test'),
          requirePassword: true,
        ),
        {DraftField.url: DraftProblem.invalid},
      );
    });

    test('a playlist URL needs a scheme and a host', () {
      for (final url in ['lists.test/get.php', 'http://', 'file:///x.m3u']) {
        expect(
          validateDraft(
            SourceDraft(type: SourceType.m3uUrl, name: 'x', url: url),
            requirePassword: true,
          ),
          {DraftField.url: DraftProblem.invalid},
          reason: url,
        );
      }
    });

    test('an EPG link must be a web address', () {
      expect(
        validateDraft(
          xtream.copyWith(epgUrl: 'guide.xml'),
          requirePassword: true,
        ),
        {DraftField.epgUrl: DraftProblem.invalid},
      );
    });

    test('a name over the limit is too long', () {
      expect(
        validateDraft(
          xtream.copyWith(name: 'x' * (maxSourceNameLength + 1)),
          requirePassword: true,
        ),
        {DraftField.name: DraftProblem.tooLong},
      );
    });
  });

  group('normalizeServerUrl', () {
    for (final (input, expected) in [
      ('line.test:8080', 'http://line.test:8080'),
      ('https://line.test/', 'https://line.test'),
      (
        'http://user:pw@line.test:8080/base//?x=1#f',
        'http://line.test:8080/base',
      ),
      ('http://line.test:8080/player_api.php', 'http://line.test:8080'),
      ('http://line.test/get.php?username=a&password=b', 'http://line.test'),
      ('  line.test  ', 'http://line.test'),
    ]) {
      test('$input → $expected', () {
        expect(normalizeServerUrl(input), expected);
      });
    }

    for (final input in ['', 'ftp://line.test', 'http://']) {
      test('"$input" has no server', () {
        expect(normalizeServerUrl(input), isNull);
      });
    }
  });

  test('displayOrigin keeps only the origin', () {
    expect(
      displayOrigin('http://lists.test:81/p/9c2e81d4/list.m3u?t=secret'),
      'http://lists.test:81/…',
    );
    expect(displayOrigin('not a url'), '…');
  });

  group('xtreamLinkLogin', () {
    test('takes a get.php link apart', () {
      final login = xtreamLinkLogin(
        'http://line.test:8080/get.php?username=living&password=s3cret'
        '&type=m3u_plus&output=ts',
      );
      expect(login?.server, 'http://line.test:8080');
      expect(login?.username, 'living');
      expect(login?.password, 's3cret');
    });

    test('works without a scheme', () {
      expect(
        xtreamLinkLogin('line.test/player_api.php?username=a&password=b')
            ?.server,
        'http://line.test',
      );
    });

    test('is null for a plain server or a link missing either half', () {
      expect(xtreamLinkLogin('http://line.test:8080'), isNull);
      expect(xtreamLinkLogin('http://line.test/get.php?username=a'), isNull);
    });
  });

  group('suggestedSourceName', () {
    test('uses the host without www', () {
      expect(
        suggestedSourceName(SourceType.xtream, 'http://www.northwind.tv:80'),
        'northwind.tv',
      );
      expect(
        suggestedSourceName(SourceType.m3uUrl, 'http://lists.test/get.php'),
        'lists.test',
      );
    });

    test("uses the file's name without its extension", () {
      expect(
        suggestedSourceName(SourceType.m3uFile, '/home/me/tv/My List.m3u8'),
        'My List',
      );
      expect(
        suggestedSourceName(SourceType.m3uFile, r'C:\Users\me\list.m3u'),
        'list',
      );
    });

    test('falls back when there is nothing to go on', () {
      expect(suggestedSourceName(SourceType.xtream, ''), 'My provider');
      expect(suggestedSourceName(SourceType.m3uFile, ''), 'Playlist');
    });
  });
}
