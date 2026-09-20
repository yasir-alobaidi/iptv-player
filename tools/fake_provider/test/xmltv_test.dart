import 'dart:convert';
import 'dart:io';

import 'package:fake_provider/profile.dart';
import 'package:fake_provider/server_state.dart';
import 'package:fake_provider/xmltv.dart';
import 'package:shelf/shelf.dart';
import 'package:test/test.dart';

FakeServerState _state({
  FakeProfile? profile,
  int epgDays = 1,
  bool epgGzip = false,
}) => FakeServerState(
  profile: profile ?? fakeProfiles['default']!,
  samplesDir: Directory.systemTemp.path,
  ffmpegPath: 'ffmpeg',
  runDir: Directory.systemTemp.path,
  epgDays: epgDays,
  epgGzip: epgGzip,
);

Future<Response> _get(FakeServerState state, [String query = '']) async =>
    await xmltvHandler(state)(
      Request(
        'GET',
        Uri.parse(
          'http://x/xmltv.php?username=test&password=test'
          '${query.isEmpty ? '' : '&$query'}',
        ),
      ),
    );

Future<String> _body(Response response) =>
    response.read().transform(utf8.decoder).join();

void main() {
  group('xmltv.php', () {
    test('bad credentials are 401', () async {
      final response = await xmltvHandler(_state())(
        Request('GET', Uri.parse('http://x/xmltv.php?username=test')),
      );
      expect(response.statusCode, HttpStatus.unauthorized);
    });

    test('channels and programmes for the guided channels', () async {
      final state = _state();
      final text = await _body(await _get(state, 'channels=3'));

      expect(text, startsWith('<?xml version="1.0" encoding="UTF-8"?>'));
      expect(text, contains('<tv generator-info-name="fake_provider"'));
      expect(text.trimRight(), endsWith('</tv>'));

      final guided = state.catalog
          .channels()
          .where((c) => c.epgChannelId != null)
          .take(3)
          .toList();
      expect(guided, hasLength(3));
      for (final channel in guided) {
        expect(text, contains('<channel id="${channel.epgChannelId}">'));
        expect(text, contains(channel.name));
        expect(text, contains('channel="${channel.epgChannelId}"'));
      }
      // A day of history and a day ahead, in 30-minute slots.
      expect(RegExp('<programme ').allMatches(text), hasLength(3 * (48 + 48)));
      expect(text, contains('<title lang="en">'));
      expect(text, contains('<desc lang="en">'));
      expect(text, contains('<category lang="en">'));
    });

    test('a channel with no epg_channel_id is left out', () async {
      final state = _state();
      final text = await _body(await _get(state, 'channels=40'));
      final blind = state.catalog
          .channels()
          .take(40)
          .where((c) => c.epgChannelId == null)
          .toList();
      expect(blind, isNotEmpty, reason: 'the generator makes every 9th blind');
      for (final channel in blind) {
        expect(text, isNot(contains('>${channel.name}<')));
      }
    });

    test('times are XMLTV stamps in UTC, and stop follows start', () async {
      final text = await _body(await _get(_state(), 'channels=1'));
      final stamps = RegExp(
        r'<programme start="(\d{14}) \+0000" stop="(\d{14}) \+0000"',
      ).allMatches(text).toList();
      expect(stamps, isNotEmpty);
      for (final match in stamps.take(20)) {
        final start = _parse(match.group(1)!);
        final stop = _parse(match.group(2)!);
        expect(stop.difference(start), const Duration(minutes: 30));
      }
    });

    test('days and channels size the file', () async {
      final oneDay = await _body(await _get(_state(), 'channels=2&days=1'));
      final threeDays = await _body(await _get(_state(), 'channels=2&days=3'));
      expect(
        RegExp('<programme ').allMatches(threeDays).length,
        RegExp('<programme ').allMatches(oneDay).length + 2 * 2 * 48,
      );
    });

    test('gzip when asked, and it unzips to the same guide', () async {
      final plain = await _body(await _get(_state(), 'channels=2'));
      final response = await _get(_state(), 'channels=2&gzip=1');
      expect(response.headers['content-encoding'], 'gzip');
      final bytes = <int>[];
      await response.read().forEach(bytes.addAll);
      expect(bytes.length, lessThan(plain.length));
      expect(utf8.decode(gzip.decode(bytes)), plain);
    });

    group('quirks (docs/02)', () {
      test('no_stop leaves every 7th programme without an end', () async {
        final text = await _body(await _get(_state(), 'channels=1&no_stop=1'));
        final all = RegExp('<programme ').allMatches(text).length;
        final withStop = RegExp(' stop="').allMatches(text).length;
        expect(withStop, lessThan(all));
        expect(all - withStop, (all / 7).floor());
      });

      test('bad_date writes a start that is not a date', () async {
        final text = await _body(await _get(_state(), 'channels=1&bad_date=1'));
        expect(text, contains('start="whenever"'));
      });

      test('unknown_tz writes an offset no zone has', () async {
        final text = await _body(
          await _get(_state(), 'channels=1&unknown_tz=1'),
        );
        expect(text, contains('+2500"'));
      });

      test('unknown_encoding names an encoding that does not exist', () async {
        final text = await _body(
          await _get(_state(), 'channels=1&unknown_encoding=1'),
        );
        expect(text, startsWith('<?xml version="1.0" encoding="X-MADE-UP-8"'));
      });

      test('duplicate_channel declares the first channel twice', () async {
        final state = _state();
        final text = await _body(
          await _get(state, 'channels=2&duplicate_channel=1'),
        );
        final first = state.catalog
            .channels()
            .firstWhere((c) => c.epgChannelId != null)
            .epgChannelId;
        expect(RegExp('<channel id="$first">').allMatches(text), hasLength(2));
      });

      test('orphan_channel has programmes but no stream', () async {
        final text = await _body(
          await _get(_state(), 'channels=1&orphan_channel=1'),
        );
        expect(text, contains('<channel id="$orphanXmltvId">'));
        expect(text, contains('channel="$orphanXmltvId"'));
      });

      test('unclosed ends mid-element with no </tv>', () async {
        final text = await _body(await _get(_state(), 'channels=1&unclosed=1'));
        expect(text, isNot(contains('</tv>')));
        expect(text.trimRight(), endsWith('<programme start="20260'));
      });

      test('the quirky profile serves them all but never truncates', () async {
        final text = await _body(
          await _get(_state(profile: fakeProfiles['quirky']), 'channels=2'),
        );
        expect(text, startsWith('<?xml version="1.0" encoding="X-MADE-UP-8"'));
        expect(text, contains('start="whenever"'));
        expect(text, contains('<channel id="$orphanXmltvId">'));
        expect(text.trimRight(), endsWith('</tv>'));
      });
    });

    test('the body is written in chunks, never built whole', () async {
      // 60 channels over 7 days is a few megabytes: it must arrive as many
      // pieces, or the large profile would need the file in memory.
      final response = await _get(_state(), 'channels=60&days=7');
      var chunks = 0;
      var bytes = 0;
      await for (final chunk in response.read()) {
        chunks++;
        bytes += chunk.length;
      }
      expect(bytes, greaterThan(1024 * 1024));
      expect(chunks, greaterThan(bytes ~/ (64 * 1024)));
    });
  });
}

DateTime _parse(String stamp) => DateTime.utc(
  int.parse(stamp.substring(0, 4)),
  int.parse(stamp.substring(4, 6)),
  int.parse(stamp.substring(6, 8)),
  int.parse(stamp.substring(8, 10)),
  int.parse(stamp.substring(10, 12)),
  int.parse(stamp.substring(12, 14)),
);
