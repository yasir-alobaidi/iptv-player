import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:iptv_player/data/providers/m3u/m3u_credentials.dart';
import 'package:iptv_player/data/providers/m3u/m3u_identity.dart';
import 'package:iptv_player/data/providers/m3u/m3u_models.dart';
import 'package:iptv_player/data/providers/m3u/m3u_parser.dart';

const _password = 'Pw-7f3a9c1e';

Future<(List<M3uEntry>, M3uSummary)> parseFixture(
  String name, {
  Map<String, String> secrets = const {},
}) async {
  final entries = <M3uEntry>[];
  final summary = await parseM3u(
    File('test_fixtures/m3u/$name').openRead(),
    entries.add,
    secrets: secrets,
  );
  return (entries, summary);
}

Future<(List<M3uEntry>, M3uSummary)> parseText(String text) async {
  final entries = <M3uEntry>[];
  final summary = await parseM3u(Stream.value(text.codeUnits), entries.add);
  return (entries, summary);
}

void main() {
  group('a clean playlist', () {
    test('reads every attribute docs/02 lists', () async {
      final (entries, summary) = await parseFixture('clean.m3u');

      final bbc = entries.first;
      expect(bbc.name, 'BBC One HD');
      expect(bbc.kind, M3uKind.live);
      expect(bbc.tvgId, 'bbc1.uk');
      expect(bbc.tvgName, 'BBC One');
      expect(bbc.logoUrl, 'http://logos.test/bbc1.png');
      expect(bbc.group, 'UK | General');
      expect(bbc.channelNumber, 101);
      expect(bbc.catchup, 'default');
      expect(bbc.catchupDays, 7);
      expect(bbc.catchupSource, '?utc={utc}&lutc={lutc}');
      expect(bbc.streamUrl, 'http://streams.test/live/101.ts');
      expect(bbc.position, 0);
      expect(summary.skipped, 0);
    });

    test('the #EXTM3U header gives the EPG URLs, deduplicated', () async {
      final (_, summary) = await parseFixture('clean.m3u');

      expect(summary.epgUrls, [
        'http://epg.test/guide.xml.gz',
        'http://epg.test/backup.xml',
      ]);
    });

    test('#EXTVLCOPT gives the next entry its user agent and referrer, '
        'and only that one', () async {
      final (entries, _) = await parseFixture('clean.m3u');

      final sky = entries[1];
      expect(sky.userAgent, 'Mozilla/5.0 (SmartTV)');
      expect(sky.referrer, 'http://portal.test/');
      expect(entries[2].userAgent, isNull);
    });

    test('classifies by URL path, then by a video file extension', () async {
      final (entries, summary) = await parseFixture('clean.m3u');

      expect(entries.map((e) => e.kind), [
        M3uKind.live,
        M3uKind.live,
        M3uKind.movie,
        M3uKind.episode,
        M3uKind.movie,
      ]);
      expect((summary.live, summary.movies, summary.episodes), (2, 2, 1));
    });

    test('an episode name gives series, season and episode', () async {
      final (entries, _) = await parseFixture('clean.m3u');

      final dark = entries[3];
      expect((dark.seriesName, dark.season, dark.episode), ('Dark', 1, 2));
    });

    test('#EXTGRP stands in for a missing group-title', () async {
      final (entries, _) = await parseFixture('clean.m3u');

      expect(entries.last.group, 'Movies | Sci-Fi');
    });

    test('gzip is detected by its bytes, not its name', () async {
      final (plain, _) = await parseFixture('clean.m3u');
      final (zipped, _) = await parseFixture('clean.m3u.gz');

      expect(zipped, plain);
    });
  });

  group('a malformed playlist', () {
    late List<M3uEntry> entries;
    late M3uSummary summary;

    setUpAll(() async {
      (entries, summary) = await parseFixture('malformed.m3u');
    });

    M3uEntry named(String name) => entries.singleWhere((e) => e.name == name);

    test('BOM, CRLF and lone CR line ends are read', () {
      expect(entries.first.tvgId, 'arte.fr');
      expect(
        named('radio-one').streamUrl,
        'http://streams.test/live/radio-one.aac',
      );
    });

    test('invalid UTF-8 decodes and is cleaned out of the name', () {
      expect(entries.first.name, 'Arte HD');
    });

    test('an unclosed quote does not swallow the title', () {
      expect(entries[1].name, 'Euronews');
    });

    test('unquoted and single-quoted attributes; commas in the title', () {
      final cnn = named('CNN, International');
      expect(cnn.tvgId, 'cnn.us');
      expect(cnn.group, 'US, News');
      expect(cnn.channelNumber, isNull, reason: 'tvg-chno=abc');
    });

    test('unknown directives between #EXTINF and its URL are ignored', () {
      expect(named('DASH channel').streamUrl, 'http://streams.test/live/4.mpd');
    });

    test('a bare URL is an entry named after its file', () {
      expect(named('radio-one').tvgId, isNull);
    });

    test('a blank title falls back to tvg-name, entities decoded', () {
      expect(named('Tom & Jerry').streamUrl, 'http://streams.test/live/5.ts');
    });

    test('an #EXTINF with no URL, a junk URL, a duplicate and the '
        'truncated last line are skipped and counted', () {
      expect(entries.map((e) => e.name), isNot(contains('Orphan')));
      expect(entries.map((e) => e.name), isNot(contains('Junk URL')));
      expect(entries.where((e) => e.name == 'Arte HD'), hasLength(1));
      expect(entries, hasLength(6));
      expect(summary.skipped, 4);
    });

    test('positions count entries, not lines', () {
      expect(entries.map((e) => e.position), [0, 1, 2, 3, 4, 5]);
    });
  });

  group('not a playlist', () {
    test('an HTML error page is a FormatException', () async {
      expect(
        () => parseFixture('html_error.m3u'),
        throwsA(isA<FormatException>()),
      );
    });

    test('an empty body is an empty playlist', () async {
      final (entries, summary) = await parseText('');

      expect(entries, isEmpty);
      expect(summary.entries, 0);
    });

    test('no #EXTM3U line is still read', () async {
      final (entries, _) = await parseText(
        '#EXTINF:-1,One\nhttp://s.test/1.ts\n',
      );

      expect(entries.single.name, 'One');
    });
  });

  group('credentials (hard rule 3)', () {
    final secrets = playlistSecrets(
      'http://panel.test:8080/get.php?username=viewer&password=$_password'
      '&type=m3u_plus',
    );

    test('come from the playlist URL query', () {
      expect(secrets, {'username': 'viewer', 'password': _password});
    });

    test('become placeholders in every stream URL, path and query — a '
        'token equal to the password included', () async {
      final (entries, _) = await parseFixture(
        'xtream_export.m3u',
        secrets: secrets,
      );

      for (final entry in entries) {
        expect(entry.streamUrl, isNot(contains(_password)));
      }
      expect(
        entries.first.streamUrl,
        'http://panel.test:8080/live/{username}/{password}/101.ts',
      );
      expect(
        entries.last.streamUrl,
        'http://cdn.test/hls/7.m3u8?token={password}&quality=hd',
      );
    });

    test('fill back into the exact URL the playlist had', () async {
      final (entries, _) = await parseFixture(
        'xtream_export.m3u',
        secrets: secrets,
      );

      expect(
        fillUrl(entries.first.streamUrl, secrets),
        'http://panel.test:8080/live/viewer/$_password/101.ts',
      );
    });

    test('only whole segments are replaced, and other encoding is '
        'kept', () {
      expect(
        templateUrl('http://h.test/live/ab/abc/ab%20c/1.ts', {
          'username': 'ab',
        }),
        'http://h.test/live/{username}/abc/ab%20c/1.ts',
      );
    });

    test('a one-character secret is not a secret: it would hit every '
        'id', () {
      expect(playlistSecrets('http://h.test/get.php?username=1&password=22'), {
        'password': '22',
      });
    });
  });

  group('identity', () {
    test('survives a new password, a new host, and a new query', () {
      String id(String url) =>
          entryIdentity(tvgId: 'bbc1.uk', name: 'BBC One', streamUrl: url);

      final before = id('http://a.test/live/viewer/old-pass/101.ts');
      expect(id('http://b.test:8080/live/viewer/new-pass/101.ts'), before);
      expect(id('http://a.test/live/{username}/{password}/101.ts'), before);
      expect(id('http://a.test/live/viewer/old-pass/101.ts?t=9'), before);
      expect(id('http://a.test/live/viewer/old-pass/102.ts'), isNot(before));
    });

    test('is stable: the same input always gives the same 16 hex '
        'digits', () {
      final id = entryIdentity(
        tvgId: null,
        name: 'Heat',
        streamUrl: 'http://s.test/movie/u/p/501.mkv',
      );

      expect(id, matches(RegExp(r'^[0-9a-f]{16}$')));
      // Pinned, and cross-checked against an independent FNV-1a in
      // Python: a change here orphans every user's favourites and history.
      expect(id, '8087782f268f0b43');
      expect(
        entryIdentity(
          tvgId: 'bbc1.uk',
          name: 'BBC One',
          streamUrl: 'http://a.test/live/u/p/101.ts',
        ),
        '6d1e705fa0972e5b',
      );
    });

    test('episode names in the common shapes', () {
      expect(parseEpisodeName('Dark S01E02'), (
        series: 'Dark',
        season: 1,
        episode: 2,
      ));
      expect(parseEpisodeName('The Office - s3 e10'), (
        series: 'The Office',
        season: 3,
        episode: 10,
      ));
      expect(parseEpisodeName('Dark 2x05'), (
        series: 'Dark',
        season: 2,
        episode: 5,
      ));
      expect(parseEpisodeName('Dark Season 1 Episode 3'), (
        series: 'Dark',
        season: 1,
        episode: 3,
      ));
      expect(parseEpisodeName('Heat (1995)'), isNull);
      expect(parseEpisodeName('S01E02'), isNull, reason: 'no series name');
    });
  });
}
