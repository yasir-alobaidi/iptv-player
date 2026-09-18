import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:iptv_player/core/result.dart';
import 'package:iptv_player/data/providers/xtream/xtream_models.dart';
import 'package:iptv_player/data/providers/xtream/xtream_parse.dart';

/// One test per quirk docs/02 says the parser MUST tolerate, each against
/// its own fixture in `test_fixtures/xtream/`. The same quirks all at once,
/// over HTTP, are in `xtream_fake_provider_test.dart`.
Object? fixture(String name) =>
    decodeJsonBytes(File('test_fixtures/xtream/$name').readAsBytesSync());

DateTime utc(int seconds) =>
    DateTime.fromMillisecondsSinceEpoch(seconds * 1000, isUtc: true);

void main() {
  group('live streams', () {
    test('a clean panel reads as sent', () {
      final rows = parseChannels(fixture('live_streams_clean.json'));

      expect(rows.skipped, 0);
      expect(
        rows.items.first,
        XtreamChannel(
          streamId: '101',
          name: 'BBC One HD',
          number: 1,
          iconUrl: 'http://logos.test/bbc1.png',
          epgChannelId: 'bbc1.uk',
          categoryId: '7',
          archiveDays: 7,
          addedAt: utc(1726000000),
        ),
      );
      expect(rows.items.last.archiveDays, 0);
      expect(rows.items.last.epgChannelId, isNull);
    });

    test('quirk: numbers, booleans and timestamps as strings', () {
      final rows = parseChannels(
        fixture('live_streams_numbers_as_strings.json'),
      );

      final [itv1, itv2] = rows.items;
      expect(itv1.number, 12);
      expect(itv1.categoryId, '7');
      expect(itv1.archiveDays, 3);
      expect(itv1.addedAt, utc(1726000200));
      expect(itv2.streamId, '104');
      expect(itv2.number, 12);
      expect(itv2.addedAt, utc(1726000300));
      // tv_archive "0" wins over a duration: no catch-up.
      expect(itv2.archiveDays, 0);
    });

    test('quirk: "" and null for missing values', () {
      final rows = parseChannels(fixture('live_streams_empty_for_null.json'));

      expect(rows.skipped, 0);
      for (final channel in rows.items) {
        expect(channel.number, isNull);
        expect(channel.iconUrl, isNull);
        expect(channel.epgChannelId, isNull);
        expect(channel.categoryId, isNull);
        expect(channel.addedAt, isNull);
        expect(channel.archiveDays, 0);
      }
      // No name at all still gives the user something to read.
      expect(rows.items.last.name, 'Channel 106');
    });

    test('quirk: category_id null, "", missing or dangling', () {
      final rows = parseChannels(fixture('live_streams_categories.json'));

      // The client passes a dangling id through: only the sync knows
      // which categories exist, and files it under "Uncategorized".
      expect(rows.items.map((c) => c.categoryId), [
        '7',
        null,
        null,
        null,
        '99999',
      ]);
    });

    test('quirk: broken and junk stream_icon URLs', () {
      final rows = parseChannels(fixture('live_streams_junk_icons.json'));

      expect(rows.items.map((c) => c.iconUrl), [
        'https://logos.test/a.png',
        null,
        null,
        null,
        null,
        null,
        null,
      ]);
    });

    test('quirk: HTML entities and stray whitespace in names', () {
      final rows = parseChannels(fixture('live_streams_html_entities.json'));

      expect(rows.items.map((c) => c.name), [
        'Tom & Jerry',
        "Rock'n'Roll TV",
        '<UK> Sports 1',
        'Café "Noir"',
        'Unknown &bogus; stays',
        'Channel 6',
      ]);
    });

    test('quirk: invalid UTF-8 decodes instead of failing', () {
      final rows = parseChannels(fixture('live_streams_invalid_utf8.bin'));

      expect(rows.items.map((c) => c.name), [
        'Das Erste HD',
        'Arte (',
        'Françe 2',
      ]);
    });

    test('rows that are not objects, lack an id or repeat one are skipped '
        'and counted', () {
      final rows = parseChannels(fixture('live_streams_malformed_rows.json'));

      expect(rows.items.map((c) => c.name), ['Kept', 'Also kept']);
      expect(rows.skipped, 6);
      // A bad field loses the field, not the row.
      final alsoKept = rows.items.last;
      expect(alsoKept.number, isNull);
      expect(alsoKept.addedAt, isNull);
      expect(alsoKept.archiveDays, 0);
    });

    test('rows keyed by id instead of an array', () {
      final rows = parseChannels(fixture('live_streams_keyed_object.json'));

      expect(rows.items.map((c) => c.streamId), ['101', '102']);
    });

    test('a body that is not a list at all is no rows, not a crash', () {
      expect(parseChannels('nonsense').items, isEmpty);
      expect(parseChannels(null).items, isEmpty);
      expect(parseChannels(42).items, isEmpty);
    });
  });

  group('movies and series', () {
    test('ratings, years and extensions in all their shapes', () {
      final rows = parseMovies(fixture('vod_streams.json'));

      expect(rows.items.map((m) => m.rating), [
        8.3,
        7.4,
        null,
        null,
        null,
        null,
      ]);
      expect(rows.items.map((m) => m.year), [
        1995,
        2016,
        null,
        null,
        2001,
        2019,
      ]);
      expect(rows.items.map((m) => m.ext), [
        'mkv',
        'mp4',
        'mp4',
        null,
        null,
        null,
      ]);
      expect(rows.items.first.posterUrl, 'http://img.test/heat.jpg');
      expect(rows.items.first.addedAt, utc(1726000000));
    });

    test('series: entities in the plot, "" for missing, id required', () {
      final rows = parseSeries(fixture('series.json'));

      expect(rows.skipped, 1);
      final [dark, broadchurch] = rows.items;
      expect(dark.plot, 'A missing boy & a cave.');
      expect(dark.year, 2017);
      expect(dark.lastModified, utc(1726000000));
      expect(dark.rating, 8.7);
      expect(broadchurch.year, 2013);
      expect(broadchurch.posterUrl, isNull);
      expect(broadchurch.rating, isNull);
      expect(broadchurch.lastModified, isNull);
      expect(broadchurch.categoryId, isNull);
    });
  });

  group('get_vod_info', () {
    test('a full answer', () {
      final info = parseMovieInfo(fixture('vod_info_full.json'));

      expect(
        info,
        const XtreamMovieInfo(
          plot: 'A crew of thieves & the detective chasing them.',
          cast: 'Al Pacino, Robert De Niro',
          director: 'Michael Mann',
          genre: 'Crime',
          runtimeMinutes: 171,
          backdropUrl: 'http://img.test/heat_bg.jpg',
          posterUrl: 'http://img.test/heat.jpg',
          year: 1995,
          rating: 8.3,
          ext: 'mkv',
        ),
      );
    });

    test('quirk: info as [] instead of {}', () {
      final info = parseMovieInfo(fixture('vod_info_info_empty_list.json'));

      expect(info.plot, isNull);
      expect(info.ext, 'mkv');
    });

    test('an unknown movie is an empty info, not an error', () {
      expect(
        parseMovieInfo(fixture('vod_info_unknown.json')),
        const XtreamMovieInfo(),
      );
    });
  });

  group('get_series_info', () {
    test('quirk: episodes as a map keyed by season', () {
      final info = parseSeriesInfo(fixture('series_info_episodes_map.json'));

      expect(info.episodes.map((e) => (e.season, e.episode, e.id)), [
        (1, 1, '9001'),
        (1, 2, '9002'),
        (2, 1, '9101'),
      ]);
      final first = info.episodes.first;
      expect(first.durationSeconds, 3100);
      expect(first.plot, 'A boy goes missing.');
      expect(first.stillUrl, 'http://img.test/e1.jpg');
      // info: [] on an episode, and a zero duration, lose the field only.
      expect(info.episodes[1].plot, isNull);
      expect(info.episodes[2].durationSeconds, isNull);
    });

    test('the same episodes as a flat list read the same', () {
      final fromMap = parseSeriesInfo(fixture('series_info_episodes_map.json'));
      final fromList = parseSeriesInfo(
        fixture('series_info_episodes_list.json'),
      );

      expect(fromList.episodes, fromMap.episodes);
    });

    test('an unknown series has no episodes, not an error', () {
      expect(
        parseSeriesInfo(fixture('series_info_unknown.json')).episodes,
        isEmpty,
      );
    });
  });

  group('account', () {
    test('auth 0 is a wrong username or password', () {
      final result = parseAccount(fixture('account_auth_0.json'));

      expect(result.failureOrNull, isA<AuthFailure>());
    });

    test('quirk: exp_date null means no expiry', () {
      final account = parseAccount(fixture('account_exp_date_null.json'))
          .valueOrNull!;

      expect(account.expiresAt, isNull);
      expect(account.status, 'Active');
      expect(account.maxConnections, 1);
      expect(account.allowedOutputFormats, ['m3u8', 'ts', 'rtmp']);
      expect(account.serverTimezone, 'Europe/London');
      expect(account.serverTime, utc(1726650000));
    });

    test('everything as strings, and the echoed password never kept', () {
      final account = parseAccount(fixture('account_full.json')).valueOrNull!;

      expect(account.expiresAt, utc(1762128000));
      expect(account.isTrial, isTrue);
      expect(account.activeConnections, 1);
      expect(account.maxConnections, 2);
      expect(account.createdAt, utc(1718000000));
      expect(account.allowedOutputFormats, ['ts']);
      final stored = account.toStoredJson().toString();
      expect(stored, isNot(contains('Pw-7f3a9c1e')));
      expect(stored, isNot(contains('viewer')));
    });

    test('an answer without user_info is not an Xtream panel', () {
      final result = parseAccount(fixture('account_not_xtream.json'));

      expect(result.failureOrNull, isA<ParseFailure>());
    });
  });

  test('get_short_epg: base64 decoded, unencoded tolerated, bad times '
      'skipped, sorted by start', () {
    final rows = parseShortEpg(fixture('short_epg.json'));

    expect(rows.items.map((e) => e.title), [
      'Breakfast',
      'The News at Six',
      'News',
    ]);
    expect(rows.items[1].description, 'Headlines & weather.');
    expect(rows.items[1].start, utc(1726682400));
    expect(rows.items[1].end, utc(1726684200));
    expect(rows.skipped, 2);
  });

  test('a body that is not JSON throws FormatException for the client to '
      'report', () {
    expect(
      () => fixture('html_error_page.html'),
      throwsA(isA<FormatException>()),
    );
  });
}
