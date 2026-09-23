// The documents are XML written in adjacent pieces: a space between two
// of them would be text in the document, not formatting.
// ignore_for_file: missing_whitespace_between_adjacent_strings

import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:iptv_player/data/providers/provider_text.dart';
import 'package:iptv_player/data/providers/xmltv/xmltv_parser.dart';
import 'package:iptv_player/data/providers/xmltv/xmltv_text.dart';
import 'package:iptv_player/data/providers/xmltv/xmltv_time.dart';

/// What one parse handed out, and its summary.
final class _Parsed {
  final channels = <XmltvChannel>[];
  final programmes = <XmltvProgramme>[];
  late final XmltvSummary summary;

  XmltvProgramme programme(String title) =>
      programmes.singleWhere((p) => p.title == title);

  List<String> get titles => [for (final p in programmes) p.title];

  /// Everything, as a value two parses are compared by.
  Map<String, Object?> describe() => {
    'channels': channels,
    'programmes': programmes,
    'summary': _describe(summary),
  };
}

Map<String, Object?> _describe(XmltvSummary summary) => {
  'channels': summary.channels,
  'programmes': summary.programmes,
  'outsideWindow': summary.outsideWindow,
  'skipped': summary.skipped,
  'truncated': summary.truncated,
  'declaredEncoding': summary.declaredEncoding,
  'unknownEncoding': summary.unknownEncoding,
  'samples': summary.samples,
};

List<int> _bytes(Object body) =>
    body is String ? utf8.encode(body) : body as List<int>;

/// [body] (a string, UTF-8 encoded, or bytes) parsed; [split] cuts it
/// into chunks, one whole chunk by default.
Future<_Parsed> _parse(
  Object body, {
  XmltvWindow? window,
  int offsetMinutes = 0,
  Stream<List<int>> Function(List<int> bytes)? split,
}) async {
  final parsed = _Parsed();
  final bytes = _bytes(body);
  parsed.summary = await parseXmltv(
    split == null ? Stream.value(bytes) : split(bytes),
    onChannel: parsed.channels.add,
    onProgramme: parsed.programmes.add,
    window: window,
    offsetMinutes: offsetMinutes,
  );
  return parsed;
}

Stream<List<int>> _bytewise(List<int> bytes) =>
    Stream.fromIterable([for (final byte in bytes) Uint8List(1)..[0] = byte]);

/// Chunks of random sizes, mostly tiny, some large, as a network gives.
Stream<List<int>> Function(List<int>) _randomly(int seed) => (bytes) {
  final random = Random(seed);
  final chunks = <List<int>>[];
  var at = 0;
  while (at < bytes.length) {
    final size = random.nextBool()
        ? 1 + random.nextInt(12)
        : 1 + random.nextInt(3000);
    final end = min(at + size, bytes.length);
    // Both kinds of list a stream can carry.
    chunks.add(
      random.nextBool()
          ? Uint8List.fromList(bytes.sublist(at, end))
          : bytes.sublist(at, end),
    );
    at = end;
  }
  return Stream.fromIterable(chunks);
};

const _entityDesc =
    '<desc>Fish &chips; &copy; &#0; &#xD800; a&nbsp;&nbsp;b &#8364;</desc>';

const _allFields =
    '<sub-title>S</sub-title><desc>Déjà vu, ☕.</desc>'
    '<category>News</category>'
    '<episode-num system="onscreen">S1E1</episode-num>';

/// The day the tests' programmes run on.
final _day = DateTime.utc(2026, 9, 14);

int _ms(num hours) =>
    _day.add(Duration(minutes: (hours * 60).round())).millisecondsSinceEpoch;

/// [hours] after [_day] began, as XMLTV writes it.
String _at(num hours, [String zone = '+0000']) {
  final time = _day.add(Duration(minutes: (hours * 60).round()));
  String two(int value) => value.toString().padLeft(2, '0');
  return '${time.year}${two(time.month)}${two(time.day)}'
      '${two(time.hour)}${two(time.minute)}${two(time.second)}'
      '${zone.isEmpty ? '' : ' $zone'}';
}

String _guide(String body, {String prolog = '<?xml version="1.0"?>'}) =>
    '$prolog\n<tv>\n$body\n</tv>\n';

String _channel(String id, [String name = 'A Channel']) =>
    '<channel id="$id"><display-name>$name</display-name></channel>';

/// A programme on [channel] from [start] to [stop] hours (no `stop` when
/// null), with [title] (no `<title>` when null) and [inner] markup.
String _programme(
  String channel,
  num start,
  num? stop, {
  String? title = 'Show',
  String inner = '',
}) =>
    '<programme start="${_at(start)}"'
    '${stop == null ? '' : ' stop="${_at(stop)}"'} channel="$channel">'
    '${title == null ? '' : '<title>$title</title>'}$inner</programme>';

Matcher _throwsFormat([String? containing]) => throwsA(
  isA<FormatException>().having(
    (e) => e.message,
    'message',
    containing == null ? anything : contains(containing),
  ),
);

void main() {
  group('times', () {
    int time(String text) {
      final parsed = parseXmltvTime(text);
      expect(parsed.skip, isNull, reason: text);
      return parsed.ms;
    }

    String? skip(String text) => parseXmltvTime(text).skip;

    int utc(int y, int mo, int d, [int h = 0, int mi = 0, int s = 0]) =>
        DateTime.utc(y, mo, d, h, mi, s).millisecondsSinceEpoch;

    test('14 digits and a zone: epoch ms UTC', () {
      expect(time('20260914180000 +0200'), utc(2026, 9, 14, 16));
      expect(time('20260914180507 +0000'), utc(2026, 9, 14, 18, 5, 7));
      expect(time('20260914013000 -0930'), utc(2026, 9, 14, 11));
    });

    test('12, 10 and 8 digits: the missing parts are zero', () {
      expect(time('202609141830 +0000'), utc(2026, 9, 14, 18, 30));
      expect(time('2026091418 +0000'), utc(2026, 9, 14, 18));
      expect(time('20260914 +0000'), utc(2026, 9, 14));
      expect(time('20260914'), utc(2026, 9, 14));
    });

    test('no zone is UTC, as the XMLTV DTD says', () {
      expect(time('20260914180000'), utc(2026, 9, 14, 18));
    });

    test('the zone follows with or without whitespace', () {
      expect(time('20260914180000+0200'), utc(2026, 9, 14, 16));
      expect(time('20260914180000   +0200'), utc(2026, 9, 14, 16));
      expect(time('20260914180000\t+0200'), utc(2026, 9, 14, 16));
      expect(time('20260914180000Z'), utc(2026, 9, 14, 18));
    });

    test('every zone form', () {
      final expected = utc(2026, 9, 14, 12, 30);
      expect(time('20260914180000 +0530'), expected);
      expect(time('20260914180000 +05:30'), expected);
      expect(time('20260914070000 -05:30'), utc(2026, 9, 14, 12, 30));
      expect(time('20260914180000 +05'), utc(2026, 9, 14, 13));
      expect(time('20260914180000 -05'), utc(2026, 9, 14, 23));
      for (final zone in ['Z', 'z', 'UTC', 'utc', 'GMT', 'Gmt']) {
        expect(
          time('20260914180000 $zone'),
          utc(2026, 9, 14, 18),
          reason: zone,
        );
      }
    });

    test('±14 hours is the furthest a zone goes', () {
      expect(time('20260914180000 +1400'), utc(2026, 9, 14, 4));
      expect(time('20260914180000 -1400'), utc(2026, 9, 15, 8));
      expect(time('20260914180000 +1459'), utc(2026, 9, 14, 3, 1));
      expect(skip('20260914180000 +1500'), XmltvSkip.badTimezone);
      expect(skip('20260914180000 +2500'), XmltvSkip.badTimezone);
      expect(skip('20260914180000 -2500'), XmltvSkip.badTimezone);
    });

    test('a zone that is not one is bad_timezone', () {
      for (final zone in [
        '+0160',
        '+0060',
        '+01:60',
        'EST',
        'CET',
        '+ab',
        '+abcd',
        '+1',
        '+123',
        '+12345',
        '+01:0',
        '+ 0100',
        '+0100 (CET)',
        'UTC+2',
        '++0100',
        '.000 +0000',
      ]) {
        expect(
          skip('20260914180000 $zone'),
          XmltvSkip.badTimezone,
          reason: zone,
        );
      }
    });

    test('anything but 14, 12, 10 or 8 digits is bad_date', () {
      for (final text in [
        '',
        '   ',
        'whenever',
        '2026',
        '202609141',
        '2026091418000 +0000',
        '202609141800000 +0000',
        '2026-09-14 18:00:00',
        'x20260914180000',
        '1726336800',
      ]) {
        expect(skip(text), XmltvSkip.badDate, reason: text);
      }
    });

    test('a calendar-invalid value is bad_date', () {
      for (final text in [
        '20261314180000', // month 13
        '20260014180000', // month 0
        '20260900180000', // day 0
        '20260931180000', // 31 September
        '20260230120000', // 30 February
        '20260229120000', // 29 February, not a leap year
        '21000229120000', // nor is 2100
        '20260914240000', // hour 24
        '20260914186000', // minute 60
        '20260914180060', // second 60
        '20260914180099',
      ]) {
        expect(skip('$text +0000'), XmltvSkip.badDate, reason: text);
      }
      expect(time('20240229120000'), utc(2024, 2, 29, 12));
      expect(time('20000229120000'), utc(2000, 2, 29, 12));
    });

    test('a bad date wins over a bad zone', () {
      expect(skip('20261314180000 +2500'), XmltvSkip.badDate);
    });

    test('whitespace around the value is ignored', () {
      expect(time('  20260914180000 +0200  '), utc(2026, 9, 14, 16));
    });

    test('agrees with DateTime across centuries', () {
      final random = Random(7);
      for (var n = 0; n < 2000; n++) {
        final expected = DateTime.utc(
          1900 + random.nextInt(250),
          1 + random.nextInt(12),
          1 + random.nextInt(28),
          random.nextInt(24),
          random.nextInt(60),
          random.nextInt(60),
        );
        String p(int v, [int w = 2]) => v.toString().padLeft(w, '0');
        final text =
            '${p(expected.year, 4)}${p(expected.month)}${p(expected.day)}'
            '${p(expected.hour)}${p(expected.minute)}${p(expected.second)}';
        expect(time(text), expected.millisecondsSinceEpoch, reason: text);
      }
      expect(time('19691231235959'), -1000);
      expect(time('19700101000000'), 0);
    });
  });

  group('cleaning', () {
    test('cleanXmltvText is cleanText, without its regular expressions', () {
      const pieces = [
        'a', 'Zed', '9', ' ', '  ', '\t', '\n', '\r', '\u000b', '\u000c', //
        '\u0001', '\u001f', '\u0085', '\u180e', '\u00a0', '\u1680', //
        '\u2000', '\u200a', '\u200b', '\u200c', '\u2028', '\u2029', //
        '\u202f', '\u205f', '\u3000', '\ufeff', '\ufffd', 'é', '😀', //
        '&', '#', 'x', ';', 'amp', '&amp;', '&AMP;', '&#39;', '&#x41;', //
        '&nbsp;', '&bogus;', '&#65533;', '&#10;', '&#0;', '& ', '&&', '&#', //
      ];
      final random = Random(11);
      for (var n = 0; n < 20000; n++) {
        final text = [
          for (var i = random.nextInt(14); i > 0; i--)
            pieces[random.nextInt(pieces.length)],
        ].join();
        expect(
          cleanXmltvText(text),
          cleanText(text),
          reason: text.runes.toList().toString(),
        );
      }
    });

    test('text that needs no cleaning comes back as it is', () {
      const text = 'Tom & Jerry: the café 😀 years';
      expect(identical(cleanXmltvText(text), text), isTrue);
    });
  });

  group('programmes', () {
    test('reads the four fields, cleaned, and the resolved times', () async {
      final parsed = await _parse(
        _guide(
          _programme(
            'bbc1.uk',
            18,
            19,
            title: '  Evening   News ',
            inner:
                '<sub-title>Headlines</sub-title>'
                '<desc>The day&apos;s  stories.</desc>'
                '<category>News</category>',
          ),
        ),
      );

      expect(parsed.programmes, [
        XmltvProgramme(
          channelId: 'bbc1.uk',
          startMs: _ms(18),
          endMs: _ms(19),
          title: 'Evening News',
          subtitle: 'Headlines',
          description: "The day's stories.",
          category: 'News',
        ),
      ]);
      expect(parsed.summary.programmes, 1);
      expect(parsed.summary.skipped, isEmpty);
      expect(parsed.summary.truncated, isFalse);
    });

    test('the zone is applied to start and stop', () async {
      final parsed = await _parse(
        _guide(
          '<programme start="20260914180000 +0200" '
          'stop="20260914173000 -0100" channel="a"><title>T</title>'
          '</programme>',
        ),
      );

      expect(parsed.programmes.single.startMs, _ms(16));
      expect(parsed.programmes.single.endMs, _ms(18.5));
    });

    test('the first non-empty of each field wins', () async {
      final parsed = await _parse(
        _guide(
          _programme(
            'a',
            1,
            2,
            title: null,
            inner:
                '<title lang="en">  </title><title lang="en">First</title>'
                '<title lang="de">Zweiter</title>'
                '<sub-title/><sub-title>Sub</sub-title><sub-title>No</sub-title>'
                '<desc></desc><desc>Desc</desc><desc>No</desc>'
                '<category>Movie</category><category>Drama</category>',
          ),
        ),
      );

      final programme = parsed.programmes.single;
      expect(programme.title, 'First');
      expect(programme.subtitle, 'Sub');
      expect(programme.description, 'Desc');
      expect(programme.category, 'Movie');
    });

    test('missing optional fields are null', () async {
      final parsed = await _parse(_guide(_programme('a', 1, 2)));

      final programme = parsed.programmes.single;
      expect(programme.subtitle, isNull);
      expect(programme.description, isNull);
      expect(programme.category, isNull);
    });

    test('other children are ignored, with a <title> nested in them', () async {
      final parsed = await _parse(
        _guide(
          _programme(
            'a',
            1,
            2,
            title: null,
            inner:
                '<episode-num system="onscreen">S1E2</episode-num>'
                '<credits><actor>Someone</actor><title>Nested</title></credits>'
                '<rating><value>PG</value><icon src="http://x.test/pg.png"/>'
                '</rating><date>2026</date><icon src="http://x.test/i.png"/>'
                '<extra><extra><title>Deeper</title></extra></extra>'
                '<title>Real</title>',
          ),
        ),
      );

      expect(parsed.titles, ['Real']);
    });

    test('an ignored element left open inside the programme does not swallow '
        'the title', () async {
      final parsed = await _parse(
        _guide(
          _programme(
            'a',
            1,
            2,
            title: null,
            inner: '<credits><actor>A</credits><title>Kept</title>',
          ),
        ),
      );

      expect(parsed.titles, ['Kept']);
    });

    test('markup inside a field is left out of its text', () async {
      final parsed = await _parse(
        _guide(
          _programme('a', 1, 2, inner: '<desc>Before <b>bold</b> after</desc>'),
        ),
      );

      expect(parsed.programmes.single.description, 'Before after');
    });

    test(
      'a programme for a channel the file never declares is emitted',
      () async {
        final parsed = await _parse(
          _guide('${_channel('declared')}${_programme('ghost.zz', 1, 2)}'),
        );

        expect(parsed.programmes.single.channelId, 'ghost.zz');
        expect(parsed.summary.skipped, isEmpty);
      },
    );

    test('the channel attribute is trimmed and entity-decoded', () async {
      final parsed = await _parse(
        _guide(
          '<programme start="${_at(1)}" stop="${_at(2)}" '
          'channel="  news&amp;weather&#46;uk "><title>T</title></programme>',
        ),
      );

      expect(parsed.programmes.single.channelId, 'news&weather.uk');
    });

    test('within a channel in time order, programmes come out in time order, '
        'each one step late', () async {
      final controller = StreamController<List<int>>();
      final emitted = <String>[];
      final done = parseXmltv(
        controller.stream,
        onChannel: (_) {},
        onProgramme: (p) => emitted.add(p.title),
      );
      Future<void> feed(String text) async {
        controller.add(utf8.encode(text));
        await pumpEventQueue();
      }

      await feed('<tv>${_programme('a', 1, 2, title: 'One')}');
      expect(emitted, isEmpty, reason: 'the next one may still cut it');
      await feed(_programme('a', 2, 3, title: 'Two'));
      expect(emitted, ['One']);
      await feed(_programme('b', 2, 3, title: 'Other'));
      expect(emitted, ['One']);
      await feed(_programme('a', 3, 4, title: 'Three'));
      expect(emitted, ['One', 'Two']);
      await feed('</tv>');
      await controller.close();
      await done;
      expect(emitted, containsAllInOrder(['One', 'Two', 'Three']));
      expect(emitted, hasLength(4));
    });
  });

  group('the pending programme', () {
    test(
      'one with no stop ends where the next on its channel starts',
      () async {
        final parsed = await _parse(
          _guide(
            '${_programme('a', 1, null, title: 'Open')}'
            '${_programme('b', 1.5, 2)}'
            '${_programme('a', 2.5, 3, title: 'Next')}',
          ),
        );

        expect(parsed.programme('Open').endMs, _ms(2.5));
        expect(parsed.summary.skipped, isEmpty);
      },
    );

    test('a stop that is not a time is no stop, not a skip', () async {
      final parsed = await _parse(
        _guide(
          '<programme start="${_at(1)}" stop="later" channel="a">'
          '<title>Garbage Stop</title></programme>'
          '<programme start="${_at(2)}" stop="${_at(3, '+2500')}" channel="a">'
          '<title>Bad Zone Stop</title></programme>'
          '<programme start="${_at(3)}" stop="" channel="a">'
          '<title>Empty Stop</title></programme>'
          '${_programme('a', 4, 5, title: 'Last')}',
        ),
      );

      expect(parsed.programme('Garbage Stop').endMs, _ms(2));
      expect(parsed.programme('Bad Zone Stop').endMs, _ms(3));
      expect(parsed.programme('Empty Stop').endMs, _ms(4));
      expect(parsed.summary.skipped, isEmpty);
    });

    test('the last one on a channel with no stop is no_stop', () async {
      final parsed = await _parse(
        _guide(
          '${_programme('a', 1, 2, title: 'Fine')}'
          '${_programme('a', 2, null, title: 'Open')}',
        ),
      );

      expect(parsed.titles, ['Fine']);
      expect(parsed.summary.skipped, {XmltvSkip.noStop: 1});
    });

    test('one that overlaps the next is cut at its start', () async {
      final parsed = await _parse(
        _guide(
          '${_programme('a', 1, 3, title: 'Runs Over')}'
          '${_programme('a', 2, 4, title: 'Next')}',
        ),
      );

      expect(parsed.programme('Runs Over').endMs, _ms(2));
      expect(parsed.programme('Next').endMs, _ms(4));
    });

    test(
      'one that ends before the next keeps its stop: a gap stays a gap',
      () async {
        final parsed = await _parse(
          _guide(
            '${_programme('a', 1, 2, title: 'Early')}'
            '${_programme('a', 3, 4, title: 'Late')}',
          ),
        );

        expect(parsed.programme('Early').endMs, _ms(2));
      },
    );

    test('going back in time is a second schedule: the first one read '
        'wins, and the pending one keeps its own stop', () async {
      final parsed = await _parse(
        _guide(
          '${_programme('a', 5, 6, title: 'Later')}'
          '${_programme('a', 1, 2, title: 'Earlier')}'
          '${_programme('a', 2, 3, title: 'After Earlier')}',
        ),
      );

      expect(parsed.titles, ['Later']);
      expect(parsed.programme('Later').endMs, _ms(6));
      expect(parsed.summary.skipped, {XmltvSkip.outOfOrder: 2});
    });

    test('out of order says nothing about when the pending one ends: with no '
        'stop, it is no_stop', () async {
      final parsed = await _parse(
        _guide(
          '${_programme('a', 5, null, title: 'Later, Open')}'
          '${_programme('a', 1, 2, title: 'Earlier')}',
        ),
      );

      expect(parsed.titles, isEmpty);
      expect(parsed.summary.skipped, {
        XmltvSkip.outOfOrder: 1,
        XmltvSkip.noStop: 1,
      });
    });

    test(
      'the same channel and start as the pending one: the first wins',
      () async {
        final parsed = await _parse(
          _guide(
            '${_programme('a', 1, 2, title: 'First')}'
            '${_programme('a', 1, 3, title: 'Second')}'
            '${_programme('b', 1, 2, title: 'Other Channel')}',
          ),
        );

        expect(parsed.titles, containsAll(['First', 'Other Channel']));
        expect(parsed.programme('First').endMs, _ms(2));
        expect(parsed.summary.skipped, {XmltvSkip.duplicateProgramme: 1});
      },
    );

    test('a start listed again after a later one is out of order, not a '
        'duplicate: only the pending one is a duplicate', () async {
      final parsed = await _parse(
        _guide(
          '${_programme('a', 1, 2, title: 'Noon')}'
          '${_programme('a', 2, 3, title: 'Next')}'
          '${_programme('a', 1, 2, title: 'Noon Again')}',
        ),
      );

      expect(parsed.titles, unorderedEquals(['Noon', 'Next']));
      expect(parsed.summary.skipped, {XmltvSkip.outOfOrder: 1});
    });

    test('a second schedule for the same id later in the file keeps only '
        'what runs past the first', () async {
      // Two streams sharing one id, each with its own day, as a panel
      // with HD and SD variants writes them.
      final parsed = await _parse(
        _guide(
          '${_programme('a', 1, 2, title: 'HD 1')}'
          '${_programme('a', 2, 3, title: 'HD 2')}'
          '${_programme('b', 1, 2, title: 'Other')}'
          '${_programme('a', 1, 2, title: 'SD 1')}'
          '${_programme('a', 2, 3, title: 'SD 2')}'
          '${_programme('a', 3, 4, title: 'SD 3')}',
        ),
      );

      expect(parsed.titles, unorderedEquals(['HD 1', 'HD 2', 'Other', 'SD 3']));
      expect(parsed.summary.skipped, {
        XmltvSkip.outOfOrder: 1,
        XmltvSkip.duplicateProgramme: 1,
      });
    });

    test('channels do not affect each other', () async {
      final parsed = await _parse(
        _guide(
          '${_programme('a', 1, null, title: 'A1')}'
          '${_programme('b', 1, null, title: 'B1')}'
          '${_programme('b', 3, 4, title: 'B2')}'
          '${_programme('a', 2, 4, title: 'A2')}',
        ),
      );

      expect(parsed.programme('A1').endMs, _ms(2));
      expect(parsed.programme('B1').endMs, _ms(3));
    });

    test('ends at or before it starts: bad_duration', () async {
      final parsed = await _parse(
        _guide(
          '${_programme('a', 2, 2, title: 'Zero')}'
          '${_programme('b', 3, 2, title: 'Backwards')}',
        ),
      );

      expect(parsed.programmes, isEmpty);
      expect(parsed.summary.skipped, {XmltvSkip.badDuration: 2});
    });

    test('longer than a day: too_long; a day exactly is fine', () async {
      final parsed = await _parse(
        _guide(
          '${_programme('a', 0, 24, title: 'A Day')}'
          '${_programme('b', 0, 24.05, title: 'Longer')}',
        ),
      );

      expect(parsed.titles, ['A Day']);
      expect(parsed.summary.skipped, {XmltvSkip.tooLong: 1});
    });

    test('no stop and the next programme 30 hours later: too_long', () async {
      final parsed = await _parse(
        _guide(
          '${_programme('a', 0, null, title: 'Open')}'
          '${_programme('a', 30, 31, title: 'Much Later')}',
        ),
      );

      expect(parsed.titles, ['Much Later']);
      expect(parsed.summary.skipped, {XmltvSkip.tooLong: 1});
    });

    test('a stop past a day that the next programme cuts is fine', () async {
      final parsed = await _parse(
        _guide(
          '${_programme('a', 0, 30, title: 'Says 30 Hours')}'
          '${_programme('a', 1, 2, title: 'Next')}',
        ),
      );

      expect(parsed.programme('Says 30 Hours').endMs, _ms(1));
      expect(parsed.summary.skipped, isEmpty);
    });
  });

  group('the offset and the window', () {
    test('the offset applies to start and stop alike', () async {
      final later = await _parse(
        _guide(_programme('a', 10, 11)),
        offsetMinutes: 90,
      );
      final earlier = await _parse(
        _guide(_programme('a', 10, 11)),
        offsetMinutes: -60,
      );

      expect(later.programmes.single.startMs, _ms(11.5));
      expect(later.programmes.single.endMs, _ms(12.5));
      expect(earlier.programmes.single.startMs, _ms(9));
      expect(earlier.programmes.single.endMs, _ms(10));
    });

    test('a programme is kept when it overlaps [start, end)', () async {
      final window = XmltvWindow(startMs: _ms(10), endMs: _ms(20));
      final parsed = await _parse(
        _guide(
          '${_programme('a', 8, 10, title: 'Ends At Start')}'
          '${_programme('b', 9, 11, title: 'Straddles Start')}'
          '${_programme('c', 12, 13, title: 'Inside')}'
          '${_programme('d', 19, 21, title: 'Straddles End')}'
          '${_programme('e', 20, 21, title: 'Starts At End')}'
          '${_programme('f', 9, 22, title: 'Covers It')}',
        ),
        window: window,
      );

      expect(
        parsed.titles,
        unorderedEquals([
          'Straddles Start',
          'Inside',
          'Straddles End',
          'Covers It',
        ]),
      );
      expect(parsed.summary.outsideWindow, 2);
      expect(parsed.summary.skipped, isEmpty, reason: 'not a fault');
    });

    test('the window is applied to the offset times', () async {
      final window = XmltvWindow(startMs: _ms(10), endMs: _ms(20));
      final body = _guide(
        '${_programme('a', 8, 9, title: 'Moved In')}'
        '${_programme('b', 19, 20, title: 'Moved Out')}',
      );

      final plus = await _parse(body, window: window, offsetMinutes: 90);
      final none = await _parse(body, window: window);

      expect(plus.titles, ['Moved In']);
      expect(plus.summary.outsideWindow, 1);
      expect(none.titles, ['Moved Out']);
    });

    test(
      'a programme with no stop is windowed by where the next one starts',
      () async {
        final window = XmltvWindow(startMs: _ms(10), endMs: _ms(20));
        final parsed = await _parse(
          _guide(
            '${_programme('a', 8, null, title: 'Reaches In')}'
            '${_programme('a', 11, 12, title: 'Next')}'
            '${_programme('b', 7, null, title: 'Stays Out')}'
            '${_programme('b', 9, 10, title: 'Also Out')}',
          ),
          window: window,
        );

        expect(parsed.titles, unorderedEquals(['Reaches In', 'Next']));
        expect(parsed.programme('Reaches In').endMs, _ms(11));
        expect(parsed.summary.outsideWindow, 2);
      },
    );

    test('XmltvWindow.around is a day back and seven ahead by default', () {
      final now = DateTime.utc(2026, 9, 14, 12);
      final window = XmltvWindow.around(now);

      expect(window.startMs, now.millisecondsSinceEpoch - 86400000);
      expect(window.endMs, now.millisecondsSinceEpoch + 7 * 86400000);
    });
  });

  group('the order of the rules: each programme counted once', () {
    Future<_Parsed> one(String programme, {XmltvWindow? window}) =>
        _parse(_guide(programme), window: window);

    test('no channel comes first', () async {
      final parsed = await one(
        '<programme start="whenever"><title>T</title></programme>',
      );
      expect(parsed.summary.skipped, {XmltvSkip.noChannel: 1});

      final empty = await one(
        '<programme start="${_at(1)}" stop="${_at(2)}" channel="  ">'
        '<title>T</title></programme>',
      );
      expect(empty.summary.skipped, {XmltvSkip.noChannel: 1});
    });

    test('then the start: missing or not a date, then its zone', () async {
      final missing = await one(
        '<programme channel="a"><title>T</title></programme>',
      );
      final bad = await one(
        '<programme start="soon" stop="${_at(2)}" channel="a"></programme>',
      );
      final zone = await one(
        '<programme start="${_at(1, 'CET')}" stop="${_at(2)}" channel="a">'
        '</programme>',
      );

      expect(missing.summary.skipped, {XmltvSkip.badDate: 1});
      expect(bad.summary.skipped, {XmltvSkip.badDate: 1});
      expect(zone.summary.skipped, {XmltvSkip.badTimezone: 1});
    });

    test('then a duplicate, before anything about its stop or title', () async {
      final parsed = await _parse(
        _guide(
          '${_programme('a', 1, 2)}'
          '${_programme('a', 1, 0.5, title: null)}',
        ),
      );
      expect(parsed.summary.skipped, {XmltvSkip.duplicateProgramme: 1});
    });

    test('at finalize: no end, then the duration, then too long', () async {
      final noStop = await one(_programme('a', 1, null, title: null));
      final backwards = await one(_programme('a', 3, 1, title: null));
      final tooLong = await one(
        _programme('a', 1, 40, title: null),
        window: XmltvWindow(startMs: _ms(100), endMs: _ms(200)),
      );

      expect(noStop.summary.skipped, {XmltvSkip.noStop: 1});
      expect(backwards.summary.skipped, {XmltvSkip.badDuration: 1});
      expect(tooLong.summary.skipped, {XmltvSkip.tooLong: 1});
    });

    test('then the window, and only then the title', () async {
      final window = XmltvWindow(startMs: _ms(10), endMs: _ms(20));
      final outside = await one(
        _programme('a', 1, 2, title: null),
        window: window,
      );
      final inside = await one(
        _programme('a', 11, 12, title: '   '),
        window: window,
      );

      expect(outside.summary.outsideWindow, 1);
      expect(outside.summary.skipped, isEmpty);
      expect(inside.summary.skipped, {XmltvSkip.noTitle: 1});
    });

    test('every programme lands in exactly one place', () async {
      final window = XmltvWindow(startMs: _ms(0), endMs: _ms(48));
      final programmes = [
        _programme('a', 1, 2), // kept
        _programme('a', 1, 3), // duplicate
        '<programme start="${_at(3)}"><title>T</title></programme>', // no channel
        '<programme start="x" channel="a"><title>T</title></programme>',
        '<programme start="${_at(3, '+9900')}" channel="a"></programme>',
        _programme('a', 5, 5), // bad duration
        _programme('b', 5, 40), // too long
        _programme('c', 60, 61), // outside
        _programme('d', 6, 7, title: null), // no title
        _programme('e', 6, null), // no stop
        _programme('f', 6, 7), // kept
      ];
      final parsed = await _parse(_guide(programmes.join()), window: window);

      final summary = parsed.summary;
      expect(
        summary.programmes + summary.outsideWindow + summary.skippedTotal,
        programmes.length,
      );
      expect(summary.programmes, 2);
      expect(summary.outsideWindow, 1);
      expect(summary.skipped, {
        XmltvSkip.duplicateProgramme: 1,
        XmltvSkip.noChannel: 1,
        XmltvSkip.badDate: 1,
        XmltvSkip.badTimezone: 1,
        XmltvSkip.badDuration: 1,
        XmltvSkip.tooLong: 1,
        XmltvSkip.noTitle: 1,
        XmltvSkip.noStop: 1,
      });
    });
  });

  group('channels', () {
    test(
      'id, the first non-empty display name, the first usable icon',
      () async {
        final parsed = await _parse(
          _guide(
            '<channel id=" bbc1.uk ">'
            '<display-name lang="en">  </display-name>'
            '<display-name lang="en">BBC  One &amp; Two</display-name>'
            '<display-name>Second</display-name>'
            '<icon src="data:image/png;base64,AAAA"/>'
            '<icon src="http://logos.test/"/>'
            '<icon src="  http://logos.test/bbc1.png?w=1&amp;h=2 "/>'
            '<icon src="http://logos.test/second.png"></icon>'
            '</channel>',
          ),
        );

        expect(parsed.channels, [
          const XmltvChannel(
            id: 'bbc1.uk',
            displayName: 'BBC One & Two',
            iconUrl: 'http://logos.test/bbc1.png?w=1&h=2',
          ),
        ]);
      },
    );

    test(
      'no display name and no icon are null; a self-closing channel counts',
      () async {
        final parsed = await _parse(
          _guide('<channel id="a"></channel><channel id="b"/>'),
        );

        expect(parsed.channels, const [
          XmltvChannel(id: 'a'),
          XmltvChannel(id: 'b'),
        ]);
      },
    );

    test(
      'a display name or icon nested in another element does not count',
      () async {
        final parsed = await _parse(
          _guide(
            '<channel id="a"><extra><display-name>Wrong</display-name>'
            '<icon src="http://logos.test/wrong.png"/></extra>'
            '<display-name>Right<icon src="http://logos.test/in-name.png"/>'
            '</display-name></channel>',
          ),
        );

        expect(parsed.channels, const [
          XmltvChannel(id: 'a', displayName: 'Right'),
        ]);
      },
    );

    test('no id, or an empty one: no_id', () async {
      final parsed = await _parse(
        _guide(
          '<channel><display-name>No Id</display-name></channel>'
          '<channel id=""><display-name>Empty</display-name></channel>'
          '<channel id="  "></channel>'
          '<channel id><display-name>Bare</display-name></channel>',
        ),
      );

      expect(parsed.channels, isEmpty);
      expect(parsed.summary.skipped, {XmltvSkip.noId: 4});
      expect(parsed.summary.samples.first, 'no_id: -: No Id');
    });

    test('an id already seen: duplicate_channel, and the first wins', () async {
      final parsed = await _parse(
        _guide(
          '${_channel('a', 'First')}${_channel('b')}${_channel('a', 'Again')}'
          '${_channel(' a ', 'Padded')}',
        ),
      );

      expect(parsed.channels.map((c) => c.displayName), ['First', 'A Channel']);
      expect(parsed.summary.channels, 2);
      expect(parsed.summary.skipped, {XmltvSkip.duplicateChannel: 2});
    });

    test('come out in file order, and are never windowed', () async {
      final parsed = await _parse(
        _guide(
          '${_channel('c')}${_programme('c', 1, 2)}${_channel('a')}'
          '${_channel('b')}',
        ),
        window: XmltvWindow(startMs: _ms(100), endMs: _ms(200)),
      );

      expect(parsed.channels.map((c) => c.id), ['c', 'a', 'b']);
    });

    test('a channel left open is finished by the next row', () async {
      final parsed = await _parse(
        _guide(
          '<channel id="a"><display-name>Open'
          '<channel id="b"><display-name>B</display-name>'
          '${_programme('a', 1, 2)}',
        ),
      );

      expect(parsed.channels, const [
        XmltvChannel(id: 'a', displayName: 'Open'),
        XmltvChannel(id: 'b', displayName: 'B'),
      ]);
      expect(parsed.programmes, hasLength(1));
    });
  });

  group('markup', () {
    test('entities in text and attributes; unknown ones and a bare & '
        'stay', () async {
      final parsed = await _parse(
        _guide(
          '<channel id="caf&#233;&#x2e;fr"><display-name>'
          'Tom &amp; Jerry &lt;TV&gt; &quot;Q&quot; &apos;A&apos;'
          '</display-name></channel>'
          '${_programme('a', 1, 2, title: 'Tom & Jerry', inner: _entityDesc)}',
        ),
      );

      expect(parsed.channels.single.id, 'café.fr');
      expect(parsed.channels.single.displayName, 'Tom & Jerry <TV> "Q" \'A\'');
      final programme = parsed.programmes.single;
      expect(programme.title, 'Tom & Jerry');
      expect(programme.description, 'Fish &chips; &copy; &#0; &#xD800; a b €');
    });

    test('text is XML-decoded, then cleanText decodes it again, as the '
        'Xtream client shows the same names', () async {
      final parsed = await _parse(
        _guide(
          '<channel id="a&amp;amp;b"><display-name>UK: &amp;amp; Drama '
          'Marlow&amp;#39;s</display-name></channel>'
          '${_programme('a', 1, 2, title: '&amp;lt;b&amp;gt; &amp;amp;amp;')}',
        ),
      );

      expect(parsed.channels.single.displayName, "UK: & Drama Marlow's");
      expect(parsed.titles, ['<b> &amp;']);
      // An attribute is not display text: decoded once.
      expect(parsed.channels.single.id, 'a&amp;b');
    });

    test('CDATA is text, verbatim, then cleaned', () async {
      final parsed = await _parse(
        _guide(
          _programme(
            'a',
            1,
            2,
            title: '<![CDATA[Rock & Roll <Live> &amp; ]]]]>',
            inner: '<desc>Part <![CDATA[one]]> and <![CDATA[]]>two</desc>',
          ),
        ),
      );

      expect(parsed.programmes.single.title, 'Rock & Roll <Live> & ]]');
      expect(parsed.programmes.single.description, 'Part one and two');
    });

    test(
      'comments, processing instructions and a DOCTYPE are skipped',
      () async {
        final parsed = await _parse(
          '<?xml version="1.0" encoding="UTF-8"?>\n'
          '<?xml-stylesheet type="text/xsl" href="x.xsl"?>\n'
          '<!-- <tv> in a comment is no root -->\n'
          '<!DOCTYPE tv SYSTEM "xmltv.dtd" [\n'
          '  <!ENTITY gt2 "a > b">\n'
          '  <!-- ] > a comment in the subset -->\n'
          "  <!ATTLIST tv x CDATA '>'>\n"
          ']>\n'
          '<tv>\n'
          '<!-- <channel id="commented.out"></channel> -->\n'
          '<?panel-hint refresh="daily"?>\n'
          '${_channel('a')}'
          '${_programme('a', 1, 2, title: 'Before <!-- hidden --> After')}'
          '</tv>',
        );

        expect(parsed.channels.map((c) => c.id), ['a']);
        expect(parsed.titles, ['Before After']);
        expect(parsed.summary.skipped, isEmpty);
      },
    );

    test('attributes: quoted either way, unquoted, spaced, bare', () async {
      final parsed = await _parse(
        _guide(
          "<channel id='single'></channel>"
          '<channel id=unquoted/>'
          '<channel id = "spaced" ></channel>'
          '<channel hidden id="after-bare"></channel>'
          '<programme catchup\n start=${_at(1).replaceAll(' ', '')} '
          "stop='${_at(2)}'\tchannel=a catchup-id><title>T</title></programme>",
        ),
      );

      expect(parsed.channels.map((c) => c.id), [
        'single',
        'unquoted',
        'spaced',
        'after-bare',
      ]);
      expect(parsed.programmes.single.endMs, _ms(2));
    });

    test('an unquoted value ends at whitespace or />', () async {
      final parsed = await _parse(
        _guide(
          '<channel id=a><icon src=http://logos.test/a.png/></channel>'
          '<channel id=b/>',
        ),
      );

      expect(parsed.channels, const [
        XmltvChannel(id: 'a', iconUrl: 'http://logos.test/a.png'),
        XmltvChannel(id: 'b'),
      ]);
    });

    test('a > inside a quoted value does not end the tag', () async {
      final parsed = await _parse(
        _guide('<channel id="a>b"><display-name>X</display-name></channel>'),
      );

      expect(parsed.channels.single.id, 'a>b');
    });

    test('a < that opens nothing is text', () async {
      final parsed = await _parse(
        _guide(_programme('a', 1, 2, title: '1 < 2')),
      );

      expect(parsed.titles, ['1 < 2']);
    });

    test(
      'a missing </programme> is finished by the next row or </tv>',
      () async {
        final parsed = await _parse(
          _guide(
            '<programme start="${_at(1)}" stop="${_at(2)}" channel="a">'
            '<title>One</title>'
            '<programme start="${_at(2)}" stop="${_at(3)}" channel="a">'
            '<title>Two'
            '<channel id="c"></channel>'
            '<programme start="${_at(3)}" stop="${_at(4)}" channel="a">'
            '<title>Three</title>',
          ),
        );

        expect(parsed.titles, ['One', 'Two', 'Three']);
        expect(parsed.channels.single.id, 'c');
        expect(parsed.summary.truncated, isFalse);
      },
    );

    test('a missing </title> ends at the next field', () async {
      final parsed = await _parse(
        _guide(
          _programme('a', 1, 2, title: null, inner: '<title>T<desc>D</desc>'),
        ),
      );

      expect(parsed.programmes.single.title, 'T');
      expect(parsed.programmes.single.description, 'D');
    });

    test('one line, CR LF or tabs: the file reads the same', () async {
      final lines = await _parse(
        _guide('${_channel('a')}\n${_programme('a', 1, 2)}\n'),
      );
      final oneLine = await _parse(
        '<?xml version="1.0"?><tv>${_channel('a')}${_programme('a', 1, 2)}</tv>',
      );
      final crlf = await _parse(
        _guide('${_channel('a')}\r\n\t${_programme('a', 1, 2)}\r\n'),
      );

      expect(oneLine.describe(), lines.describe());
      expect(crlf.describe(), lines.describe());
    });

    test('element names are case-sensitive, except the root', () async {
      final parsed = await _parse(
        '<TV><Channel id="x"></Channel>${_channel('a')}'
        '<programme start="${_at(1)}" stop="${_at(2)}" channel="a">'
        '<Title>Upper</Title><title>Lower</title></programme></TV>',
      );

      expect(parsed.channels.map((c) => c.id), ['a']);
      expect(parsed.titles, ['Lower']);
      expect(parsed.summary.truncated, isFalse);
    });

    test('what follows </tv> is ignored, unless it is another <tv>', () async {
      final parsed = await _parse(
        '<tv>${_channel('a')}</tv>${_channel('junk')}'
        '<?xml version="1.0"?><tv>${_channel('b')}</tv>',
      );

      expect(parsed.channels.map((c) => c.id), ['a', 'b']);
    });

    test(
      'elements nested deeper than the parser tracks are still skipped',
      () async {
        final deep = '<x>' * 1000;
        final parsed = await _parse(
          _guide(
            _programme('a', 1, 2, title: null, inner: '$deep<title>No</title>'),
          ),
        );

        expect(parsed.programmes, isEmpty);
        expect(parsed.summary.skipped, {XmltvSkip.noTitle: 1});
      },
    );
  });

  group('encodings', () {
    List<int> latin(String declaration, List<int> title) => [
      ...ascii.encode(
        '<?xml version="1.0" encoding="$declaration"?>\n<tv>'
        '<programme start="${_at(1)}" stop="${_at(2)}" channel="a"><title>',
      ),
      ...title,
      ...ascii.encode('</title></programme></tv>'),
    ];

    test('ISO-8859-1', () async {
      final parsed = await _parse(
        latin('ISO-8859-1', [...ascii.encode('Caf'), 0xe9, 0x20, 0x80, 0xa4]),
      );

      expect(parsed.titles, ['Café \u0080¤']);
      expect(parsed.summary.declaredEncoding, 'ISO-8859-1');
      expect(parsed.summary.unknownEncoding, isFalse);
    });

    test('every Latin-1 name, case-insensitive and trimmed', () async {
      for (final name in [
        'latin1',
        'LATIN-1',
        'l1',
        'iso_8859-1',
        ' Iso-8859-1 ',
      ]) {
        final parsed = await _parse(latin(name, [0xe9]));
        expect(parsed.titles, ['é'], reason: name);
        expect(parsed.summary.declaredEncoding, name);
      }
    });

    test('Windows-1252: 0x80–0x9F as Windows draws them', () async {
      for (final name in ['windows-1252', 'CP1252']) {
        final parsed = await _parse(
          latin(name, [0x80, 0x20, 0x93, 0x51, 0x94, 0x20, 0x96, 0x20, 0xe9]),
        );
        expect(parsed.titles, ['€ “Q” – é'], reason: name);
      }
    });

    test('ISO-8859-15: its eight differences from Latin-1', () async {
      for (final name in ['iso-8859-15', 'Latin-9']) {
        final parsed = await _parse(
          latin(name, [0xa4, 0xa6, 0xa8, 0xb4, 0xb8, 0xbc, 0xbd, 0xbe, 0xe9]),
        );
        expect(parsed.titles, ['€ŠšŽžŒœŸé'], reason: name);
      }
    });

    test('UTF-8 and its aliases', () async {
      for (final name in ['utf-8', 'UTF8', 'us-ascii', 'ASCII']) {
        final parsed = await _parse(latin(name, utf8.encode('Grüße ☕')));
        expect(parsed.titles, ['Grüße ☕'], reason: name);
        expect(parsed.summary.unknownEncoding, isFalse);
      }
    });

    test('an unknown encoding reads as UTF-8, flagged', () async {
      final parsed = await _parse(latin('X-MADE-UP-8', utf8.encode('Déjà vu')));

      expect(parsed.titles, ['Déjà vu']);
      expect(parsed.summary.declaredEncoding, 'X-MADE-UP-8');
      expect(parsed.summary.unknownEncoding, isTrue);
    });

    test(
      'utf-16 declared on ASCII bytes: the header lies, read as UTF-8',
      () async {
        final parsed = await _parse(latin('UTF-16', ascii.encode('Plain')));

        expect(parsed.titles, ['Plain']);
        expect(parsed.summary.unknownEncoding, isTrue);
      },
    );

    test('no declaration, or none with an encoding: UTF-8, nothing '
        'declared', () async {
      final none = await _parse(
        '<tv>${_programme('a', 1, 2, title: 'é')}</tv>',
      );
      final bare = await _parse(
        '<?xml version="1.0"?><tv>${_programme('a', 1, 2, title: 'é')}</tv>',
      );
      final empty = await _parse(
        '<?xml version="1.0" encoding=""?><tv>${_programme('a', 1, 2, title: 'é')}</tv>',
      );

      for (final parsed in [none, bare, empty]) {
        expect(parsed.titles, ['é']);
        expect(parsed.summary.declaredEncoding, isNull);
        expect(parsed.summary.unknownEncoding, isFalse);
      }
    });

    test('attributes are decoded in the declared encoding', () async {
      final parsed = await _parse([
        ...ascii.encode(
          '<?xml version="1.0" encoding="ISO-8859-1"?><tv><channel id="caf',
        ),
        0xe9,
        ...ascii.encode('"/></tv>'),
      ]);

      expect(parsed.channels.single.id, 'café');
    });

    test('invalid UTF-8 is replaced, cleaned, and never thrown', () async {
      final parsed = await _parse([
        ...ascii.encode('<tv><channel id="a"><display-name>Caf'),
        0xe9, 0x20, 0x4e, 0x6f, 0x69, 0x72, 0xff, 0xc3, //
        ...ascii.encode('</display-name></channel></tv>'),
      ]);

      expect(parsed.channels.single.displayName, 'Caf Noir');
    });

    test('a UTF-8 byte order mark is skipped', () async {
      final parsed = await _parse([
        0xef,
        0xbb,
        0xbf,
        ...utf8.encode(_guide(_programme('a', 1, 2, title: 'Über'))),
      ]);

      expect(parsed.titles, ['Über']);
    });

    test('a UTF-16 byte order mark is refused', () async {
      final body = _guide(_channel('a'));
      final little = [0xff, 0xfe];
      final big = [0xfe, 0xff];
      for (final unit in body.codeUnits) {
        little.addAll([unit & 0xff, unit >> 8]);
        big.addAll([unit >> 8, unit & 0xff]);
      }

      await expectLater(_parse(little), _throwsFormat('UTF-16'));
      await expectLater(_parse(big), _throwsFormat('UTF-16'));
    });

    test('UTF-16 with no byte order mark is refused too', () async {
      final little = <int>[];
      for (final unit in _guide(_channel('a')).codeUnits) {
        little.addAll([unit & 0xff, unit >> 8]);
      }

      await expectLater(_parse(little), _throwsFormat());
    });
  });

  group('gzip', () {
    final body = _guide(
      '${_channel('a', 'Grüße')}${_programme('a', 1, 2)}'
      '${_programme('a', 2, 3)}',
    );

    test('is detected by its magic number and read the same', () async {
      final plain = await _parse(body);
      final gzipped = await _parse(gzip.encode(utf8.encode(body)));
      final bytewise = await _parse(
        gzip.encode(utf8.encode(body)),
        split: _bytewise,
      );

      expect(gzipped.describe(), plain.describe());
      expect(bytewise.describe(), plain.describe());
    });

    test('a corrupt gzip body ends the parse with its error', () async {
      final gzipped = gzip.encode(utf8.encode(body));
      final corrupt = [...gzipped.take(20), ...List.filled(40, 0x55)];

      await expectLater(_parse(corrupt), throwsA(anything));
    });
  });

  group('not XMLTV', () {
    test('an empty body', () async {
      await expectLater(_parse(<int>[]), _throwsFormat('empty'));
      await expectLater(
        parseXmltv(
          const Stream.empty(),
          onChannel: (_) {},
          onProgramme: (_) {},
        ),
        _throwsFormat('empty'),
      );
    });

    test('whitespace, a BOM, a declaration, comments, text, a first tag cut '
        'short: no element', () async {
      for (final body in [
        ' \n\t\r\n',
        '\ufeff',
        '<?xml version="1.0" encoding="UTF-8"?>\n',
        '<?xml version="1.0"?><!-- a comment --><!-- another -->',
        '<!DOCTYPE tv SYSTEM "xmltv.dtd">',
        'Unauthorized',
        '<?xml version="1.0"?><error msg="x',
      ]) {
        await expectLater(_parse(body), _throwsFormat('no <tv>'), reason: body);
      }
    });

    test('a JSON body', () async {
      for (final body in [
        '{"user_info":{"auth":0}}',
        '  \n[]',
        '\ufeff{"error":"x"}',
      ]) {
        await expectLater(_parse(body), _throwsFormat('JSON'), reason: body);
      }
    });

    test('a first element that is not tv', () async {
      for (final body in [
        '<html><body>502 Bad Gateway</body></html>',
        '<!DOCTYPE html>\n<html lang="en"><head></head></html>',
        '<?xml version="1.0"?><HTML></HTML>',
        '<?xml version="1.0"?><rss version="2.0"></rss>',
        '<?xml version="1.0"?><tvguide></tvguide>',
      ]) {
        await expectLater(_parse(body), _throwsFormat('root'), reason: body);
      }
    });

    test(
      'an error page is refused at its first tag, and the body let go',
      () async {
        var cancelled = false;
        final controller = StreamController<List<int>>(
          onCancel: () => cancelled = true,
        )..add(utf8.encode('<!DOCTYPE html><html><body>'));
        // Never closed: the parse must not wait for the rest.

        await expectLater(
          parseXmltv(controller.stream, onChannel: (_) {}, onProgramme: (_) {}),
          _throwsFormat('root'),
        );
        expect(cancelled, isTrue);
      },
    );

    test('a <tv> with nothing in it is not an error', () async {
      for (final body in [
        '<tv/>',
        '<tv></tv>',
        '<?xml version="1.0"?>\n<tv>\n</tv>',
      ]) {
        final parsed = await _parse(body);
        expect(parsed.summary.channels, 0, reason: body);
        expect(parsed.summary.programmes, 0);
        expect(parsed.summary.skipped, isEmpty);
        expect(parsed.summary.truncated, isFalse);
      }
    });
  });

  group('truncation', () {
    const complete =
        '<tv><channel id="a"><display-name>A</display-name>'
        '</channel><programme start="20260914010000 +0000" '
        'stop="20260914020000 +0000" channel="a"><title>Done</title>'
        '</programme>';

    test('ending mid-tag: truncated, what came before kept', () async {
      final parsed = await _parse('$complete<programme start="20260');

      expect(parsed.summary.truncated, isTrue);
      expect(parsed.channels, hasLength(1));
      expect(parsed.titles, ['Done']);
      expect(parsed.summary.skipped, isEmpty);
    });

    test('ending inside a programme drops it, uncounted', () async {
      final parsed = await _parse(
        '$complete<programme start="20260914020000 +0000" channel="b">'
        '<title>Cut Sh',
      );

      expect(parsed.summary.truncated, isTrue);
      expect(parsed.titles, ['Done']);
      expect(parsed.summary.skipped, isEmpty);
    });

    test('ending inside a skipped row drops it, uncounted too', () async {
      final parsed = await _parse(
        '$complete<programme start="whenever" channel="b"><title>X</title>',
      );

      expect(parsed.summary.skipped, isEmpty);
    });

    test('ending inside a channel drops it', () async {
      final parsed = await _parse(
        '$complete<channel id="b"><display-name>B</display-name>',
      );

      expect(parsed.channels.map((c) => c.id), ['a']);
    });

    test(
      'pending programmes are finalized: one with no stop is no_stop',
      () async {
        final parsed = await _parse(
          '<tv>${_programme('a', 1, null, title: 'Open')}'
          '${_programme('b', 1, 2, title: 'Closed')}<programme',
        );

        expect(parsed.summary.truncated, isTrue);
        expect(parsed.titles, ['Closed']);
        expect(parsed.summary.skipped, {XmltvSkip.noStop: 1});
      },
    );

    test('missing </tv> alone is truncated', () async {
      final parsed = await _parse(complete);

      expect(parsed.summary.truncated, isTrue);
      expect(parsed.titles, ['Done']);
    });

    test(
      'ending inside a comment, CDATA, a DOCTYPE or a runaway tag',
      () async {
        for (final tail in [
          '<!-- never closed',
          '<!-',
          '<![CDATA[never',
          '<!DOCTYPE tv [ <!ENTITY',
          '<',
          '<?pi never',
          '<programme note="${'x' * (70 * 1024)}',
        ]) {
          final parsed = await _parse('$complete$tail');
          expect(parsed.summary.truncated, isTrue, reason: tail);
          expect(parsed.titles, ['Done'], reason: tail);
        }
      },
    );

    test('junk cut short after </tv> is not a truncation', () async {
      final parsed = await _parse('$complete</tv><!-- trailing');

      expect(parsed.summary.truncated, isFalse);
    });
  });

  group('errors', () {
    test("the byte stream's error is passed on as it is", () async {
      final error = StateError('connection reset');
      final bytes = Stream<List<int>>.multi((controller) {
        controller
          ..add(utf8.encode('<tv>${_channel('a')}'))
          ..addError(error);
        unawaited(controller.close());
      });

      await expectLater(
        parseXmltv(bytes, onChannel: (_) {}, onProgramme: (_) {}),
        throwsA(same(error)),
      );
    });

    test("a callback's error ends the parse with it", () async {
      final error = StateError('disk full');

      await expectLater(
        parseXmltv(
          Stream.value(utf8.encode(_guide(_channel('a')))),
          onChannel: (_) => throw error,
          onProgramme: (_) {},
        ),
        throwsA(same(error)),
      );
    });

    test("a callback's failed future ends the parse with its error", () async {
      final error = StateError('write failed');
      var calls = 0;

      await expectLater(
        parseXmltv(
          Stream.value(
            utf8.encode(
              _guide(
                [for (var i = 0; i < 10; i++) _programme('c$i', 1, 2)].join(),
              ),
            ),
          ),
          onChannel: (_) {},
          onProgramme: (_) async {
            calls++;
            throw error;
          },
        ),
        throwsA(same(error)),
      );
      expect(calls, 1);
    });
  });

  group('backpressure', () {
    test(
      'a callback returning a future pauses reading until it completes',
      () async {
        final controller = StreamController<List<int>>();
        final writes = <Completer<void>>[];
        final done = parseXmltv(
          controller.stream,
          onChannel: (_) {
            final write = Completer<void>();
            writes.add(write);
            return write.future;
          },
          onProgramme: (_) {},
        );

        controller.add(utf8.encode('<tv>${_channel('a')}'));
        await pumpEventQueue();
        expect(writes, hasLength(1));
        expect(controller.isPaused, isTrue);

        controller.add(utf8.encode('${_channel('b')}</tv>'));
        await pumpEventQueue();
        expect(writes, hasLength(1), reason: 'still waiting for the first');

        writes.single.complete();
        await pumpEventQueue();
        expect(writes, hasLength(2));
        expect(controller.isPaused, isTrue);
        writes.last.complete();
        await controller.close();
        expect((await done).channels, 2);
      },
    );

    test('rows in one chunk are handed over one future at a time', () async {
      var active = 0;
      var most = 0;
      final titles = <String>[];
      final summary = await parseXmltv(
        Stream.value(
          utf8.encode(
            _guide(
              [
                for (var i = 0; i < 20; i++)
                  _programme('c${i % 3}', i, i + 1, title: 'P$i'),
              ].join(),
            ),
          ),
        ),
        onChannel: (_) {},
        onProgramme: (p) async {
          active++;
          most = max(most, active);
          await Future<void>.delayed(const Duration(milliseconds: 1));
          titles.add(p.title);
          active--;
        },
      );

      expect(most, 1);
      expect(titles, hasLength(20));
      expect(summary.programmes, 20);
    });

    test('a callback returning nothing does not pause', () async {
      final controller = StreamController<List<int>>();
      final done = parseXmltv(
        controller.stream,
        onChannel: (_) {},
        onProgramme: (_) {},
      );

      controller.add(utf8.encode('<tv>${_channel('a')}'));
      await pumpEventQueue();
      expect(controller.isPaused, isFalse);
      controller.add(utf8.encode('</tv>'));
      await controller.close();
      await done;
    });
  });

  group('caps', () {
    test('a 1 MB description is cut to 4,096 characters', () async {
      final text = List.generate(200000, (i) => 'word$i').join(' ');
      final parsed = await _parse(
        _guide(_programme('a', 1, 2, inner: '<desc>$text</desc>')),
      );

      final description = parsed.programmes.single.description!;
      expect(description.length, lessThanOrEqualTo(4096));
      expect(description.length, greaterThan(4080));
      expect(text, startsWith(description));
    });

    test('a long title, sub-title and category are cut to 512', () async {
      final parsed = await _parse(
        _guide(
          _programme(
            'a',
            1,
            2,
            title: 'T' * 100000,
            inner:
                '<sub-title>${'S' * 600}</sub-title>'
                '<category>${'C' * 513}</category>',
          ),
        ),
      );

      final programme = parsed.programmes.single;
      expect(programme.title, 'T' * 512);
      expect(programme.subtitle, 'S' * 512);
      expect(programme.category, 'C' * 512);
    });

    test('the cut never splits a character', () async {
      final parsed = await _parse(
        _guide(
          _programme(
            'a',
            1,
            2,
            title: 'é' * 5000,
            inner: '<desc>${'😀' * 5000}</desc>',
          ),
        ),
      );

      final programme = parsed.programmes.single;
      expect(programme.title, 'é' * 512);
      expect(programme.description, '😀' * 2048);
    });

    test(
      'a runaway tag is malformed: its element is skipped, parsing goes on',
      () async {
        final parsed = await _parse(
          _guide(
            '${_programme('a', 1, 2, title: 'Before')}'
            '<programme start="${_at(2)}" stop="${_at(3)}" channel="a" '
            'note="${'A' * (70 * 1024)}"><title>Runaway</title></programme>'
            '${_programme('a', 3, 4, title: 'After')}',
          ),
        );

        expect(parsed.titles, ['Before', 'After']);
        expect(parsed.summary.skipped, {XmltvSkip.malformed: 1});
        expect(
          parsed.summary.samples.single,
          startsWith('malformed: -: <programme start="'),
        );
      },
    );

    test('a runaway with no > at all ends at the next <', () async {
      final parsed = await _parse(
        _guide(
          '<channel id="junk" x=${'J' * (70 * 1024)}\n'
          '${_channel('a')}${_programme('a', 1, 2)}',
        ),
      );

      expect(parsed.channels.map((c) => c.id), ['a']);
      expect(parsed.programmes, hasLength(1));
      expect(parsed.summary.skipped, {XmltvSkip.malformed: 1});
    });

    test('a runaway field tag skips only that field', () async {
      final parsed = await _parse(
        _guide(
          _programme(
            'a',
            1,
            2,
            inner: '<desc lang="${'x' * (70 * 1024)}">Lost</desc>',
          ),
        ),
      );

      expect(parsed.programmes.single.title, 'Show');
      expect(parsed.programmes.single.description, isNull);
      expect(parsed.summary.skipped, {XmltvSkip.malformed: 1});
    });

    test('a tag broken by a < (a missing > or quote) is malformed', () async {
      final parsed = await _parse(
        _guide(
          '<programme start="${_at(1)}" stop="${_at(2)}" channel="a"\n'
          '<title>Broken</title></programme>'
          '<programme start="${_at(2)}" stop="${_at(3)}" channel="a>\n'
          '<title>Unclosed Quote</title></programme>'
          '${_programme('a', 3, 4, title: 'Fine')}',
        ),
      );

      expect(parsed.titles, ['Fine']);
      expect(parsed.summary.skipped, {XmltvSkip.malformed: 2});
    });

    test(
      'a runaway comment, CDATA or DOCTYPE costs no memory and is skipped',
      () async {
        final long = 'z' * (200 * 1024);
        final parsed = await _parse(
          '<!DOCTYPE tv [ <!-- $long --> ]>'
          '<tv><!-- $long -->'
          '${_programme('a', 1, 2, inner: '<desc><![CDATA[$long]]></desc>')}'
          '<?pi $long?>${_channel('b')}</tv>',
        );

        expect(parsed.programmes.single.description, 'z' * 4096);
        expect(parsed.channels.single.id, 'b');
        expect(parsed.summary.skipped, isEmpty);
      },
    );
  });

  group('samples', () {
    test('at most three per reason, as reason: channel: value', () async {
      final parsed = await _parse(
        _guide(
          [
            for (var i = 0; i < 5; i++)
              '<programme start="bad$i" channel="c$i"></programme>',
            '<programme start="${_at(1, '+2500')}" channel="z"></programme>',
            '<programme start="${_at(1)}"><title>T</title></programme>',
          ].join(),
        ),
      );

      expect(parsed.summary.skipped, {
        XmltvSkip.badDate: 5,
        XmltvSkip.badTimezone: 1,
        XmltvSkip.noChannel: 1,
      });
      expect(parsed.summary.samples, [
        'bad_date: c0: bad0',
        'bad_date: c1: bad1',
        'bad_date: c2: bad2',
        'bad_timezone: z: 20260914010000 +2500',
        'no_channel: -: 20260914010000 +0000',
      ]);
    });

    test('a value is shortened to 40 characters, and never a URL', () async {
      final parsed = await _parse(
        _guide(
          '<programme start="${'9' * 60}" channel="a"></programme>'
          '<programme start="http://panel.test/u/p/x" channel="a"></programme>'
          '<channel><display-name>http://user:pass@panel.test/</display-name>'
          '</channel>'
          '<programme start="x" channel="rtsp://h/c"></programme>',
        ),
      );

      expect(parsed.summary.samples, [
        'bad_date: a: ${'9' * 40}',
        'bad_date: a: <url>',
        'no_id: -: <url>',
        'bad_date: <url>: x',
      ]);
      for (final sample in parsed.summary.samples) {
        expect(sample, isNot(contains('://')));
      }
    });

    test('no sample for a window miss', () async {
      final parsed = await _parse(
        _guide(_programme('a', 1, 2)),
        window: XmltvWindow(startMs: _ms(10), endMs: _ms(20)),
      );

      expect(parsed.summary.samples, isEmpty);
    });
  });

  group('chunk boundaries', () {
    // Every construct the scanner carries across a chunk boundary.
    final latin1Body = [
      ...ascii.encode(
        '<?xml version="1.0" encoding="windows-1252"?>\n<tv>'
        '<channel id="w"><display-name>Caf',
      ),
      0xe9, 0x20, 0x80, //
      ...ascii.encode(
        '</display-name></channel>'
        '<programme start="${_at(1)}" stop="${_at(2)}" channel="w"><title>',
      ),
      0x93, 0x51, 0x94, //
      ...ascii.encode('</title></programme></tv>'),
    ];
    final corpus = <String, Object>{
      'clean': _guide(
        '${_channel('a', 'Grüße ☕ 😀')}'
        '<channel id="b"><display-name>B</display-name>'
        '<icon src="http://logos.test/b.png"/></channel>'
        '${_programme('a', 1, 2, title: 'Éire 😀', inner: _allFields)}'
        '${_programme('b', 1, null)}${_programme('b', 1.5, 3)}'
        '${_programme('a', 2, 4)}',
      ),
      'markup': [
        0xef,
        0xbb,
        0xbf,
        ...utf8.encode(
          '<?xml version="1.0" encoding="UTF-8"?>\n'
          '<?xml-stylesheet href="x"?><!-- c -- c -->'
          '<!DOCTYPE tv SYSTEM "xmltv.dtd" [ <!ENTITY a "]>"> '
          '<!-- ]> --> ]>'
          "<tv a='1'><channel id=u><display-name>&amp;&#233;&#x2615;"
          '</display-name></channel>'
          '<programme start="${_at(1)}" stop="${_at(2)}" channel="u" x=">">'
          '<title>A<![CDATA[ & <b> ]]]]><!-- x -->B</title>'
          '<desc>1 < 2 &nbsp; 3</desc><credits><title>No</title></credits>'
          '</programme><?pi ?>'
          '<programme start="${_at(2)}" channel="u"><title>T</title>'
          '<programme start="${_at(3)}" stop="${_at(4)}" channel="u">'
          '<title>Q</title></programme></tv>',
        ),
      ],
      'windows-1252': latin1Body,
      'faults': _guide(
        '<channel></channel><channel id="a"/><channel id="a"/>'
        '<programme start="soon" channel="a"/>'
        '${_programme('a', 1, 1)}${_programme('b', 1, 30)}'
        '${_programme('c', 5, 6)}${_programme('c', 5, 7)}'
        '<programme start="${_at(1)}" stop="${_at(2)}" channel="d"\n'
        '<title>Broken</title></programme>'
        '${_programme('d', 2, 3, title: null)}',
      ),
      'runaway': _guide(
        '${_programme('a', 1, 2)}'
        '<programme start="${_at(2)}" stop="${_at(3)}" channel="a" '
        'note="${'Ä' * (40 * 1024)}"><title>R</title></programme>'
        '${_programme('a', 3, 4, inner: '<desc>${'é' * 9000}</desc>')}',
      ),
      'truncated':
          '<tv>${_programme('a', 1, 2)}${_programme('a', 2, null)}'
          '<programme start="${_at(3)}" channel="a"><title>Cut',
    };

    for (final MapEntry(key: name, value: body) in corpus.entries) {
      test(
        '$name: whole, one byte at a time and in random chunks alike',
        () async {
          final window = XmltvWindow(startMs: _ms(0), endMs: _ms(3.5));
          final whole = await _parse(body, window: window);
          expect(
            whole.programmes.length + whole.channels.length,
            greaterThan(0),
            reason: 'the document must say something',
          );

          final bytewise = await _parse(body, window: window, split: _bytewise);
          expect(bytewise.describe(), whole.describe(), reason: 'byte by byte');
          for (var seed = 0; seed < 8; seed++) {
            final random = await _parse(
              body,
              window: window,
              split: _randomly(seed),
            );
            expect(random.describe(), whole.describe(), reason: 'seed $seed');
          }
        },
      );
    }

    test('the corpus reads as expected in one piece', () async {
      final markup = await _parse(corpus['markup']!);
      expect(markup.channels.single.displayName, '&é☕');
      expect(markup.programmes.map((p) => (p.title, p.description)), [
        ('A & <b> ]]B', '1 < 2 3'),
        ('T', null),
        ('Q', null),
      ]);
      expect(markup.summary.truncated, isFalse);

      final windows = await _parse(corpus['windows-1252']!);
      expect(windows.channels.single.displayName, 'Café €');
      expect(windows.titles, ['“Q”']);

      final faults = await _parse(corpus['faults']!);
      expect(faults.summary.skipped, {
        XmltvSkip.noId: 1,
        XmltvSkip.duplicateChannel: 1,
        XmltvSkip.badDate: 1,
        XmltvSkip.badDuration: 1,
        XmltvSkip.tooLong: 1,
        XmltvSkip.duplicateProgramme: 1,
        XmltvSkip.malformed: 1,
        XmltvSkip.noTitle: 1,
      });

      final truncated = await _parse(corpus['truncated']!);
      expect(truncated.summary.truncated, isTrue);
      expect(truncated.summary.skipped, {XmltvSkip.noStop: 1});
    });
  });

  group('the fake provider', () {
    test("its guide's shape reads whole, quirks and all", () async {
      // What tools/fake_provider/lib/xmltv.dart writes, quirky profile.
      final body = StringBuffer()
        ..writeln('<?xml version="1.0" encoding="X-MADE-UP-8"?>')
        ..writeln(
          '<tv generator-info-name="fake_provider" '
          'generator-info-url="https://example.invalid/fake_provider">',
        )
        ..writeln('  <channel id="ch1.uk">')
        ..writeln('    <display-name lang="en">One &amp; Co</display-name>')
        ..writeln('    <icon src="http://logos.test/1.png" />')
        ..writeln('  </channel>')
        ..writeln('  <channel id="ch1.uk">')
        ..writeln('    <display-name lang="en">One &amp; Co</display-name>')
        ..writeln('  </channel>');
      for (var i = 0; i < 14; i++) {
        final start = i == 10
            ? 'whenever'
            : _at(i / 2, i == 12 ? '+2500' : '+0000');
        final stop = i == 6 ? '' : 'stop="${_at((i + 1) / 2)}" ';
        body
          ..writeln('  <programme start="$start" ${stop}channel="ch1.uk">')
          ..writeln('    <title lang="en">P$i</title>')
          ..writeln('    <desc lang="en">About $i</desc>')
          ..writeln('    <category lang="en">News</category>')
          ..writeln('    <episode-num system="onscreen">S1E$i</episode-num>')
          ..writeln('  </programme>');
      }
      body.write('  <programme start="20260');

      final parsed = await _parse(body.toString());

      expect(parsed.summary.channels, 1);
      expect(parsed.summary.programmes, 12);
      expect(parsed.summary.skipped, {
        XmltvSkip.duplicateChannel: 1,
        XmltvSkip.badDate: 1,
        XmltvSkip.badTimezone: 1,
      });
      expect(parsed.summary.truncated, isTrue);
      expect(parsed.summary.unknownEncoding, isTrue);
      expect(parsed.programme('P6').endMs, _ms(3.5));
      expect(parsed.programme('P13').endMs, _ms(7));
    });
  });
}
