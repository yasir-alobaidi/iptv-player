import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math' as math;

import 'package:flutter_test/flutter_test.dart';
import 'package:iptv_player/data/providers/xmltv/xmltv_parser.dart';

/// Black-box fixture tests for the XMLTV parser (hard rules 1 and 10): every
/// expectation is worked out from the parser's contract and the fixture
/// itself — times with `DateTime.utc`, text by hand — never copied from a
/// parse.

const _dir = 'test_fixtures/xmltv';

int _ms(int year, int month, int day, [int hour = 0, int minute = 0]) =>
    DateTime.utc(year, month, day, hour, minute).millisecondsSinceEpoch;

/// Sep 14 2026 at [hour]:[minute] UTC, the day most fixtures are set on.
int _sep14(int hour, [int minute = 0]) => _ms(2026, 9, 14, hour, minute);

/// All of September 2026: every fixture's programmes fall in it but one,
/// so only the window tests see a programme left out for its dates.
final _september = XmltvWindow(
  startMs: _ms(2026, 9, 1),
  endMs: _ms(2026, 10, 1),
);

final class _Parse {
  const new(this.channels, this.programmes, this.summary);

  final List<XmltvChannel> channels;
  final List<XmltvProgramme> programmes;
  final XmltvSummary summary;

  /// [XmltvSummary.skipped] without zero counts, so a test names only the
  /// codes it expects.
  Map<String, int> get skipped => {
    for (final MapEntry(:key, :value) in summary.skipped.entries)
      if (value != 0) key: value,
  };

  List<String> get titles => [for (final p in programmes) p.title];

  XmltvProgramme titled(String title) =>
      programmes.singleWhere((p) => p.title == title);

  /// One channel's programmes, in the order they were handed over.
  List<XmltvProgramme> on(String channelId) => [
    for (final p in programmes)
      if (p.channelId == channelId) p,
  ];

  List<String> samplesFor(String reason) => [
    for (final sample in summary.samples)
      if (sample.startsWith('$reason: ')) sample,
  ];
}

Future<_Parse> _parse(
  Stream<List<int>> bytes, {
  XmltvWindow? window,
  int offsetMinutes = 0,
}) async {
  final channels = <XmltvChannel>[];
  final programmes = <XmltvProgramme>[];
  final summary = await parseXmltv(
    bytes,
    onChannel: channels.add,
    onProgramme: programmes.add,
    window: window,
    offsetMinutes: offsetMinutes,
  );
  return _Parse(channels, programmes, summary);
}

Future<_Parse> _fixture(
  String name, {
  XmltvWindow? window,
  int offsetMinutes = 0,
}) => _parse(
  File('$_dir/$name').openRead(),
  window: window ?? _september,
  offsetMinutes: offsetMinutes,
);

Future<_Parse> _text(String xml, {XmltvWindow? window}) =>
    _parse(Stream.value(utf8.encode(xml)), window: window ?? _september);

List<int> _bytes(String name) => File('$_dir/$name').readAsBytesSync();

Stream<List<int>> _chunks(List<int> bytes, int size) => Stream.fromIterable([
  for (var i = 0; i < bytes.length; i += size)
    bytes.sublist(i, math.min(i + size, bytes.length)),
]);

/// Emission order across channels is not part of the contract, so
/// comparisons that don't care about it sort first.
int _byChannelAndTime(XmltvProgramme a, XmltvProgramme b) {
  final byChannel = a.channelId.compareTo(b.channelId);
  if (byChannel != 0) return byChannel;
  final byStart = a.startMs.compareTo(b.startMs);
  if (byStart != 0) return byStart;
  final byEnd = a.endMs.compareTo(b.endMs);
  if (byEnd != 0) return byEnd;
  return a.title.compareTo(b.title);
}

/// Everything a parse produced, in a form `equals` compares deeply: the
/// channels in file order (that order is contractual), the programmes
/// sorted, the summary field by field. A body that is not XMLTV is its
/// exception's type.
Future<Object> _outcome(Stream<List<int>> bytes) async {
  try {
    final parse = await _parse(bytes, window: _september);
    final summary = parse.summary;
    return {
      'channels': parse.channels,
      'programmes': [...parse.programmes]..sort(_byChannelAndTime),
      'channelCount': summary.channels,
      'programmeCount': summary.programmes,
      'outsideWindow': summary.outsideWindow,
      'skipped': parse.skipped,
      'truncated': summary.truncated,
      'declaredEncoding': summary.declaredEncoding,
      'unknownEncoding': summary.unknownEncoding,
      'samples': [...summary.samples]..sort(),
    };
  } on FormatException {
    return 'FormatException';
  }
}

/// A one-programme guide whose title is [titleBytes], under a declaration
/// naming [encoding].
List<int> _declared(String encoding, List<int> titleBytes) => [
  ...ascii.encode(
    '<?xml version="1.0" encoding="$encoding"?>\n<tv>\n'
    '<programme start="20260914100000 +0000" stop="20260914110000 +0000" '
    'channel="x"><title>',
  ),
  ...titleBytes,
  ...ascii.encode('</title></programme></tv>'),
];

void main() {
  group('clean.xml, a real-shaped panel export', () {
    late _Parse parse;

    setUpAll(() async => parse = await _fixture('clean.xml'));

    test('every channel, in file order, with its first display-name and '
        'its icon', () {
      expect(parse.channels, const [
        XmltvChannel(
          id: 'north.news.uk',
          displayName: 'Northwind News',
          iconUrl: 'http://logos.example.test/north-news.png',
        ),
        XmltvChannel(
          id: 'aurora.movies.de',
          displayName: 'Aurora Filme',
          iconUrl: 'https://logos.example.test/aurora.png',
        ),
        XmltvChannel(
          id: 'kestrel.sport.us',
          displayName: 'Kestrel Sport',
          iconUrl: 'https://logos.example.test/kestrel.png',
        ),
        XmltvChannel(id: 'lumen.kids.fr', displayName: 'Lumen Enfants'),
      ]);
    });

    test('every programme, its times resolved from +0100, +0000 and -0500, '
        'the first of each text field kept', () {
      expect(
        parse.programmes,
        unorderedEquals([
          XmltvProgramme(
            channelId: 'north.news.uk',
            // 18:00 +0100.
            startMs: _sep14(17),
            endMs: _sep14(18),
            title: 'Evening News',
            subtitle: 'Headlines at Six',
            description: "The day's main stories, with sport and weather.",
            category: 'News',
          ),
          XmltvProgramme(
            channelId: 'north.news.uk',
            startMs: _sep14(18),
            endMs: _sep14(18, 30),
            title: 'Weather Outlook',
            description: 'The forecast for the week ahead.',
            category: 'News',
          ),
          XmltvProgramme(
            channelId: 'aurora.movies.de',
            startMs: _sep14(20),
            endMs: _sep14(22, 5),
            // The first <title> wins over the English one after it.
            title: 'Der lange Hafen',
            description: 'Ein Kapitän kehrt nach zwanzig Jahren zurück.',
            category: 'Spielfilm',
          ),
          XmltvProgramme(
            channelId: 'aurora.movies.de',
            startMs: _sep14(22, 5),
            endMs: _ms(2026, 9, 15),
            title: 'Spätfilm',
            description: 'Ein Klassiker zur Nacht.',
            category: 'Spielfilm',
          ),
          XmltvProgramme(
            channelId: 'kestrel.sport.us',
            // 19:00 -0500 is midnight UTC, the next day.
            startMs: _ms(2026, 9, 15),
            endMs: _ms(2026, 9, 15, 2),
            title: 'Harbour Cup Final',
            subtitle: 'Northport v Southport',
            description: 'Live coverage of the final.',
            category: 'Sports',
          ),
          XmltvProgramme(
            channelId: 'kestrel.sport.us',
            startMs: _ms(2026, 9, 15, 2),
            endMs: _ms(2026, 9, 15, 3, 30),
            title: 'Post-Match',
            category: 'Sports',
          ),
          XmltvProgramme(
            channelId: 'lumen.kids.fr',
            startMs: _ms(2026, 9, 15, 6),
            endMs: _ms(2026, 9, 15, 6, 30),
            title: 'Dessins animés',
            description: 'Des histoires pour les petits.',
            category: 'Jeunesse',
          ),
        ]),
      );
    });

    test('within a channel written in time order, they come out in time '
        'order', () {
      expect(parse.on('north.news.uk').map((p) => p.title), [
        'Evening News',
        'Weather Outlook',
      ]);
      expect(parse.on('aurora.movies.de').map((p) => p.title), [
        'Der lange Hafen',
        'Spätfilm',
      ]);
      expect(parse.on('kestrel.sport.us').map((p) => p.title), [
        'Harbour Cup Final',
        'Post-Match',
      ]);
    });

    test('the summary: everything counted, nothing skipped', () {
      final summary = parse.summary;
      expect(summary.channels, 4);
      expect(summary.programmes, 7);
      expect(summary.outsideWindow, 0);
      expect(summary.skippedTotal, 0);
      expect(summary.truncated, isFalse);
      expect(summary.declaredEncoding, 'UTF-8');
      expect(summary.unknownEncoding, isFalse);
      expect(summary.samples, isEmpty);
    });

    test('gzip is detected by its bytes, not its name', () async {
      final zipped = await _fixture('clean.xml.gz');

      expect(zipped.channels, parse.channels);
      expect(zipped.programmes, unorderedEquals(parse.programmes));
      expect(zipped.summary.programmes, 7);
      expect(zipped.summary.declaredEncoding, 'UTF-8');
      expect(zipped.summary.truncated, isFalse);
    });
  });

  group('the window and the offset', () {
    test('a programme is kept when it overlaps the window, and only '
        'counted when it does not', () async {
      final parse = await _fixture(
        'clean.xml',
        window: XmltvWindow(startMs: _sep14(17, 30), endMs: _ms(2026, 9, 15)),
      );

      expect(
        parse.titles,
        unorderedEquals([
          // 17:00–18:00 overlaps the window's start.
          'Evening News',
          'Weather Outlook',
          'Der lange Hafen',
          'Spätfilm',
        ]),
      );
      expect(parse.summary.programmes, 4);
      expect(parse.summary.outsideWindow, 3);
      // Outside the window is not a fault.
      expect(parse.summary.skippedTotal, 0);
    });

    test('ending at the window start, or starting at its end, is '
        'outside', () async {
      final parse = await _fixture(
        'clean.xml',
        window: XmltvWindow(startMs: _sep14(18), endMs: _ms(2026, 9, 15)),
      );

      // Evening News ends at 18:00, the Final starts at midnight.
      expect(
        parse.titles,
        unorderedEquals(['Weather Outlook', 'Der lange Hafen', 'Spätfilm']),
      );
      expect(parse.summary.outsideWindow, 4);
    });

    test('channels are never windowed', () async {
      final parse = await _fixture(
        'clean.xml',
        window: XmltvWindow(startMs: _ms(2030, 1, 1), endMs: _ms(2030, 1, 8)),
      );

      expect(parse.channels, hasLength(4));
      expect(parse.summary.channels, 4);
      expect(parse.programmes, isEmpty);
      expect(parse.summary.outsideWindow, 7);
    });

    // A window over the small hours of Sep 15; the offset moves programmes
    // into it and out of it.
    final smallHours = XmltvWindow(
      startMs: _ms(2026, 9, 15, 0, 30),
      endMs: _ms(2026, 9, 15, 6),
    );

    test('with no offset, the window holds the Final and the '
        'Post-Match', () async {
      final parse = await _fixture('clean.xml', window: smallHours);

      expect(
        parse.titles,
        unorderedEquals(['Harbour Cup Final', 'Post-Match']),
      );
      expect(parse.summary.outsideWindow, 5);
    });

    test('an offset of +60 moves start and stop alike, and the late film '
        'into the window', () async {
      final parse = await _fixture(
        'clean.xml',
        window: smallHours,
        offsetMinutes: 60,
      );

      expect(
        parse.titles,
        unorderedEquals(['Spätfilm', 'Harbour Cup Final', 'Post-Match']),
      );
      expect(parse.summary.outsideWindow, 4);
      final late = parse.titled('Spätfilm');
      expect((late.startMs, late.endMs), (_sep14(23, 5), _ms(2026, 9, 15, 1)));
      final start = parse.titled('Harbour Cup Final');
      expect(
        (start.startMs, start.endMs),
        (_ms(2026, 9, 15, 1), _ms(2026, 9, 15, 3)),
      );
    });

    test('an offset of -120 moves the Final out and the cartoons in', () async {
      final parse = await _fixture(
        'clean.xml',
        window: smallHours,
        offsetMinutes: -120,
      );

      expect(parse.titles, unorderedEquals(['Post-Match', 'Dessins animés']));
      expect(parse.summary.outsideWindow, 5);
      final cartoons = parse.titled('Dessins animés');
      expect(
        (cartoons.startMs, cartoons.endMs),
        (_ms(2026, 9, 15, 4), _ms(2026, 9, 15, 4, 30)),
      );
    });

    test('with no window, nothing is left out for its dates', () async {
      final parse = await _parse(File('$_dir/clean.xml').openRead());

      expect(parse.summary.programmes, 7);
      expect(parse.summary.outsideWindow, 0);
    });
  });

  group('one_line.xml, the whole guide on one line', () {
    late _Parse parse;

    setUpAll(() async => parse = await _fixture('one_line.xml'));

    test('reads as a guide written over many lines would', () {
      expect(parse.channels, const [
        XmltvChannel(id: 'a.one', displayName: 'Channel A'),
        XmltvChannel(
          id: 'b.two',
          displayName: 'Channel B',
          iconUrl: 'http://logos.example.test/b.png',
        ),
      ]);
      expect(
        parse.programmes,
        unorderedEquals([
          XmltvProgramme(
            channelId: 'a.one',
            startMs: _sep14(12),
            endMs: _sep14(13),
            title: 'Noon Show',
            description: 'Lunchtime.',
          ),
          XmltvProgramme(
            channelId: 'a.one',
            startMs: _sep14(13),
            endMs: _sep14(14),
            title: 'Afternoon',
          ),
          XmltvProgramme(
            channelId: 'b.two',
            startMs: _sep14(12),
            endMs: _sep14(12, 30),
            title: 'Quick News',
            category: 'News',
          ),
        ]),
      );
      expect(parse.on('a.one').map((p) => p.title), ['Noon Show', 'Afternoon']);
      expect(parse.summary.skippedTotal, 0);
    });

    test('the declared encoding is kept as written, not lower- or '
        'upper-cased', () {
      expect(parse.summary.declaredEncoding, 'utf-8');
      expect(parse.summary.unknownEncoding, isFalse);
    });
  });

  group('no_stop.xml', () {
    late _Parse parse;

    setUpAll(() async => parse = await _fixture('no_stop.xml'));

    test('a missing or unusable stop ends at the next start on the '
        'channel', () {
      expect(parse.on('c.fill'), [
        XmltvProgramme(
          channelId: 'c.fill',
          startMs: _sep14(10),
          endMs: _sep14(11),
          title: 'No Stop At All',
        ),
        // stop="soon": not a date, so no stop.
        XmltvProgramme(
          channelId: 'c.fill',
          startMs: _sep14(11),
          endMs: _sep14(12),
          title: 'Garbage Stop',
        ),
        // A stop with a bad zone is no stop either, not bad_timezone.
        XmltvProgramme(
          channelId: 'c.fill',
          startMs: _sep14(12),
          endMs: _sep14(12, 30),
          title: 'Stop With A Bad Zone',
        ),
        XmltvProgramme(
          channelId: 'c.fill',
          startMs: _sep14(12, 30),
          endMs: _sep14(13),
          title: 'Stop At Hour 25',
        ),
        XmltvProgramme(
          channelId: 'c.fill',
          startMs: _sep14(13),
          endMs: _sep14(14),
          title: 'Empty Stop',
        ),
        XmltvProgramme(
          channelId: 'c.fill',
          startMs: _sep14(14),
          endMs: _sep14(15),
          title: 'Proper Stop',
        ),
      ]);
    });

    test('a programme that is skipped does not end the one before it', () {
      // The bad start at 08:30 is never a "next programme": Before ends
      // at After's 09:00.
      expect(parse.on('e.gap'), [
        XmltvProgramme(
          channelId: 'e.gap',
          startMs: _sep14(8),
          endMs: _sep14(9),
          title: 'Before The Bad One',
        ),
        XmltvProgramme(
          channelId: 'e.gap',
          startMs: _sep14(9),
          endMs: _sep14(9, 30),
          title: 'After The Bad One',
        ),
      ]);
    });

    test('the last one per channel has nothing to end it: no_stop', () {
      expect(parse.titles, isNot(contains('Last Without A Stop')));
      expect(parse.on('d.alone'), isEmpty);
      expect(parse.skipped, {XmltvSkip.noStop: 2, XmltvSkip.badDate: 1});
      expect(parse.summary.programmes, 8);
      expect(parse.summary.channels, 3);
    });

    test('samples name the reason, the channel and the value', () {
      expect(parse.samplesFor(XmltvSkip.badDate), ['bad_date: e.gap: soon']);
      expect(
        parse.samplesFor(XmltvSkip.noStop),
        unorderedEquals([
          startsWith('no_stop: c.fill: '),
          startsWith('no_stop: d.alone: '),
        ]),
      );
    });
  });

  group('times.xml', () {
    late _Parse parse;

    setUpAll(() async => parse = await _fixture('times.xml'));

    test('every accepted date length and zone form', () {
      final times = {
        for (final p in parse.programmes) p.title: (p.startMs, p.endMs),
      };
      expect(times, {
        '14 digits, +0200': (_sep14(16), _sep14(17)),
        '12 digits': (_sep14(18), _sep14(18, 30)),
        '10 digits': (_sep14(18), _sep14(19)),
        // Exactly a day is not too long.
        '8 digits, a whole day': (_sep14(0), _ms(2026, 9, 15)),
        // The XMLTV DTD: no zone is UTC.
        'No zone is UTC': (_sep14(18), _sep14(18, 30)),
        'Z': (_sep14(18), _sep14(18, 30)),
        'UTC': (_sep14(18), _sep14(18, 30)),
        'gmt, lower case': (_sep14(18), _sep14(18, 30)),
        'No space before the zone': (_sep14(16), _sep14(17)),
        '+HH:MM': (_sep14(12, 30), _sep14(13, 30)),
        '+HH': (_sep14(16), _sep14(17)),
        '-0930': (_sep14(17, 30), _sep14(18, 30)),
        // 08:00 on the 15th at +1400 is 18:00 on the 14th.
        '+1400, the furthest east': (_sep14(18), _sep14(18, 30)),
        'Start and stop in different zones': (_sep14(17), _sep14(18)),
        'Z with no space': (_sep14(18), _sep14(18, 30)),
        '-HH:MM': (_sep14(15, 30), _sep14(16, 30)),
      });
    });

    test('bad dates, calendar-invalid ones included, and bad zones are '
        'skipped, each counted once', () {
      expect(parse.titles.where((t) => t.startsWith('bad:')), isEmpty);
      expect(parse.titles.where((t) => t.startsWith('zone:')), isEmpty);
      // b14 is both not digits and a bad zone: the date rule comes first.
      expect(parse.skipped, {XmltvSkip.badDate: 15, XmltvSkip.badTimezone: 7});
      expect(parse.summary.programmes, 16);
      expect(parse.summary.channels, 0);
    });

    test('at most three samples per reason', () {
      final badDates = parse.samplesFor(XmltvSkip.badDate);
      expect(badDates, hasLength(3));
      expect(badDates, everyElement(matches(RegExp(r'^bad_date: b\d\d: '))));
      final badZones = parse.samplesFor(XmltvSkip.badTimezone);
      expect(badZones, hasLength(3));
      expect(
        badZones,
        everyElement(matches(RegExp(r'^bad_timezone: z\d\d: '))),
      );
      expect(parse.summary.samples, hasLength(6));
    });
  });

  group('overlaps_and_duplicates.xml', () {
    late _Parse parse;

    setUpAll(() async => parse = await _fixture('overlaps_and_duplicates.xml'));

    test('an overlap is cut at the next start; a duplicate start loses to '
        'the first; going back in time is skipped', () {
      expect(
        parse.on('o.one'),
        unorderedEquals([
          // 10:00–11:30, cut at Next Show's 11:00.
          XmltvProgramme(
            channelId: 'o.one',
            startMs: _sep14(10),
            endMs: _sep14(11),
            title: 'Runs Over',
          ),
          XmltvProgramme(
            channelId: 'o.one',
            startMs: _sep14(11),
            endMs: _sep14(12),
            title: 'Next Show',
          ),
          // Not cut by its own duplicate: a duplicate is dropped as it is
          // read, before it can end anything.
          XmltvProgramme(
            channelId: 'o.one',
            startMs: _sep14(12),
            endMs: _sep14(13),
            title: 'Noon Show',
          ),
          // Out Of Order (11:30) starts before Noon Show: skipped, and
          // it ends nothing. Afternoon then ends Noon Show at its own 13:00.
          XmltvProgramme(
            channelId: 'o.one',
            startMs: _sep14(13),
            endMs: _sep14(14),
            title: 'Afternoon',
          ),
          // Noon Show's start listed again after Afternoon: out of order,
          // not a duplicate, since Afternoon is the one pending.
        ]),
      );
    });

    test('out of order says nothing about when the pending one ends, and a '
        'duplicate of a programme with no stop does not lend it one', () {
      // Late, No Stop is pending; Earlier goes back (out of order); Later
      // repeats its start (duplicate). Nothing ends Late, No Stop.
      expect(parse.on('o.two'), isEmpty);
    });

    test('over a day, whether stopped or filled from the next start, is '
        'too long', () {
      expect(parse.on('o.four'), [
        XmltvProgramme(
          channelId: 'o.four',
          startMs: _ms(2026, 9, 17, 2),
          endMs: _ms(2026, 9, 17, 3),
          title: 'Ends It',
        ),
      ]);
    });

    test('ending at or before the start is a bad duration', () {
      expect(parse.on('o.five'), isEmpty);
    });

    test('each row is counted once, under its own reason', () {
      expect(parse.skipped, {
        XmltvSkip.duplicateProgramme: 2,
        XmltvSkip.outOfOrder: 3,
        XmltvSkip.noStop: 1,
        XmltvSkip.tooLong: 2,
        XmltvSkip.badDuration: 2,
        XmltvSkip.duplicateChannel: 2,
      });
      expect(parse.summary.programmes, 5);
    });

    test('a channel declared twice keeps the first; ids are trimmed before '
        'they are compared', () {
      expect(parse.channels, const [
        XmltvChannel(id: 'o.one', displayName: 'One'),
        XmltvChannel(id: 'o.two', displayName: 'Two'),
        XmltvChannel(id: 'o.three', displayName: 'Three'),
        XmltvChannel(id: 'o.four', displayName: 'Four'),
        XmltvChannel(id: 'o.five', displayName: 'Five'),
      ]);
      expect(parse.summary.channels, 5);
    });
  });

  group('missing_fields.xml', () {
    late _Parse parse;

    setUpAll(() async => parse = await _fixture('missing_fields.xml'));

    test('a channel with no id, or an empty or blank one, is skipped; the '
        'first non-empty display-name wins', () {
      expect(parse.channels, const [
        XmltvChannel(id: 'm.named', displayName: 'Named Channel'),
        XmltvChannel(
          id: 'm.bare',
          iconUrl: 'http://logos.example.test/bare.png',
        ),
      ]);
    });

    test('only a programme with a channel and a title is kept; the channel '
        'attribute is trimmed', () {
      expect(parse.programmes, [
        XmltvProgramme(
          channelId: 'm.named',
          startMs: _sep14(12),
          endMs: _sep14(13),
          title: 'Only A Title',
        ),
        XmltvProgramme(
          channelId: 'm.named',
          startMs: _sep14(13),
          endMs: _sep14(14),
          title: 'Padded Channel',
          description: 'Second Desc',
          category: 'Talk',
        ),
      ]);
    });

    test('no title covers a missing, empty, blank or non-breaking-space '
        'title, one inside <credits>, and <TITLE>', () {
      expect(parse.skipped, {
        XmltvSkip.noId: 3,
        // The bad date on the fourth does not matter: no channel is
        // checked first.
        XmltvSkip.noChannel: 4,
        XmltvSkip.noTitle: 6,
      });
    });

    test('outside the window is decided before the title', () {
      // August's untitled programme is outside, not no_title.
      expect(parse.summary.outsideWindow, 1);
    });

    test('with no window, the same programme is no_title', () async {
      final unwindowed = await _parse(
        File('$_dir/missing_fields.xml').openRead(),
      );

      expect(unwindowed.summary.outsideWindow, 0);
      expect(unwindowed.skipped[XmltvSkip.noTitle], 7);
    });

    test('samples: "-" stands in for a missing channel id', () {
      final noIds = parse.samplesFor(XmltvSkip.noId);
      expect(noIds, hasLength(3));
      expect(noIds, everyElement(startsWith('no_id: -: ')));
      final noChannels = parse.samplesFor(XmltvSkip.noChannel);
      expect(noChannels, hasLength(3));
      expect(noChannels, everyElement(startsWith('no_channel: -: ')));
      final noTitles = parse.samplesFor(XmltvSkip.noTitle);
      expect(noTitles, hasLength(3));
      expect(noTitles, everyElement(startsWith('no_title: m.named: ')));
    });
  });

  group('entities.xml', () {
    late _Parse parse;

    setUpAll(() async => parse = await _fixture('entities.xml'));

    test('channels: quoting of every kind, entities in text and attributes, '
        'nested elements ignored, the commented-out one never read', () {
      expect(parse.channels, const [
        XmltvChannel(
          id: 'e.single',
          displayName: 'Tom & Jerry <TV>',
          iconUrl: 'http://logos.example.test/e.png?w=100&h=100',
        ),
        // The first display-name is empty, so the second wins.
        XmltvChannel(id: 'e.unquoted', displayName: 'Café ☕ Kids'),
        // `hidden` has no value, and is ignored.
        XmltvChannel(id: 'e.bare-attr', displayName: 'Quote "Q" \'A\''),
        // The display-name and icon nested in <extra> are not the
        // channel's.
        XmltvChannel(id: 'e.nested', displayName: 'Right Name'),
        XmltvChannel(id: 'news&weather.uk', displayName: 'News and Weather'),
      ]);
    });

    test('programmes', () {
      XmltvProgramme single(
        int hour,
        String title, {
        String? subtitle,
        String? description,
      }) => XmltvProgramme(
        channelId: 'e.single',
        startMs: _sep14(hour),
        endMs: _sep14(hour + 1),
        title: title,
        subtitle: subtitle,
        description: description,
      );

      expect(
        parse.programmes,
        unorderedEquals([
          // An unescaped & and unknown entities stay as written.
          single(
            10,
            'Tom & Jerry',
            description: 'Fish &chips; &unknown; night',
          ),
          // CDATA is text, verbatim, then cleaned.
          single(11, 'Rock & Roll <Live>', description: 'Spaced out'),
          // A comment inside an element is skipped.
          single(12, 'Before After'),
          // Numeric entities, &nbsp; and a newline, collapsed.
          single(
            13,
            'Café été night',
            description: 'Line one. Line two. Line three.',
          ),
          // The first non-empty title and sub-title win.
          single(14, 'Zweiter Titel', subtitle: 'Real Sub'),
          single(15, 'Single Quotes'),
          single(16, 'Bare Attributes'),
          // Titles nested in <extra>, twice over, are not the programme's.
          single(17, 'After Nesting'),
          single(18, '<b>Bold</b> & Brash'),
          XmltvProgramme(
            channelId: 'news&weather.uk',
            startMs: _sep14(10),
            endMs: _sep14(11),
            title: 'Numeric Entity In The Channel',
          ),
        ]),
      );
    });

    test('the internal DTD subset, PIs and comments are all skipped', () {
      expect(parse.summary.skippedTotal, 0);
      expect(parse.summary.channels, 5);
      expect(parse.summary.programmes, 10);
      expect(parse.summary.declaredEncoding, 'UTF-8');
      expect(parse.summary.truncated, isFalse);
    });
  });

  group('encodings', () {
    test('ISO-8859-1: é ü ß as single bytes', () async {
      final parse = await _fixture('latin1.xml');

      expect(parse.channels.single.displayName, 'Café Zürich');
      final programme = parse.programmes.single;
      expect(programme.title, 'Straßenfest');
      expect(programme.description, 'Grüße aus München.');
      expect(parse.summary.declaredEncoding, 'ISO-8859-1');
      expect(parse.summary.unknownEncoding, isFalse);
    });

    test(
      'windows-1252: 0x80–0x9F are the euro sign and curly quotes',
      () async {
        final parse = await _fixture('windows1252.xml');

        expect(parse.channels.single.displayName, 'Cinéma');
        final programme = parse.programmes.single;
        expect(programme.title, 'Price € 5');
        expect(programme.description, '“Quoted” – café…');
        expect(parse.summary.declaredEncoding, 'windows-1252');
        expect(parse.summary.unknownEncoding, isFalse);
      },
    );

    test('ISO-8859-15: Latin-1 but for its eight, 0xA4 the euro', () async {
      final parse = await _fixture('iso8859_15.xml');

      expect(parse.channels.single.displayName, 'Cinéma');
      final programme = parse.programmes.single;
      expect(programme.title, 'Prix € 10');
      expect(programme.description, 'Cœur de pierre');
      expect(parse.summary.declaredEncoding, 'ISO-8859-15');
      expect(parse.summary.unknownEncoding, isFalse);
    });

    test('an encoding no one knows is read as UTF-8, and said so', () async {
      final parse = await _fixture('unknown_encoding.xml');

      final programme = parse.programmes.single;
      expect(programme.title, 'Crème brûlée');
      expect(programme.description, 'Déjà vu');
      expect(parse.channels.single.displayName, 'Unknown');
      expect(parse.summary.declaredEncoding, 'X-MADE-UP-8');
      expect(parse.summary.unknownEncoding, isTrue);
    });

    test('a UTF-16 header with no UTF-16 BOM lies: read as UTF-8, '
        'unknown', () async {
      final parse = await _fixture('utf16_declared.xml');

      expect(parse.programmes.single.title, 'Plain Title');
      expect(parse.channels.single.displayName, 'Header Lies');
      expect(parse.summary.declaredEncoding, 'UTF-16');
      expect(parse.summary.unknownEncoding, isTrue);
    });

    test(
      'invalid UTF-8 is replaced and cleaned out, never thrown on',
      () async {
        final parse = await _fixture('invalid_utf8.xml');

        // A lead byte with no continuation, then a stray 0xFF.
        expect(parse.channels.single.displayName, 'Caf Noir');
        final programme = parse.programmes.single;
        expect(programme.title, 'Bad Byte');
        // A valid sequence right after a broken one still decodes.
        expect(programme.description, 'Café au lait');
        expect(parse.summary.declaredEncoding, 'UTF-8');
        expect(parse.summary.unknownEncoding, isFalse);
      },
    );

    test('a UTF-8 BOM is skipped', () async {
      final parse = await _fixture('bom.xml');

      expect(parse.channels, const [
        XmltvChannel(id: 'bom.one', displayName: 'Bom Channel'),
      ]);
      expect(parse.programmes.single.title, 'Über Alles');
      expect(parse.summary.declaredEncoding, 'UTF-8');
    });

    test('a UTF-16 BOM, either order, is not supported', () async {
      await expectLater(_fixture('utf16_bom.xml'), throwsFormatException);
      await expectLater(_fixture('utf16be_bom.xml'), throwsFormatException);
    });

    test('no declaration, or one with no encoding: UTF-8, nothing '
        'declared', () async {
      const body =
          '<tv><programme start="20260914100000 +0000" '
          'stop="20260914110000 +0000" channel="x"><title>Café</title>\n'
          '</programme></tv>';
      for (final xml in [body, '<?xml version="1.0"?>\n$body']) {
        final parse = await _text(xml);

        expect(parse.programmes.single.title, 'Café', reason: xml);
        expect(parse.summary.declaredEncoding, isNull, reason: xml);
        expect(parse.summary.unknownEncoding, isFalse, reason: xml);
      }
    });

    group('every name the spec lists, in any case', () {
      final cafeLatin1 = [0x43, 0x61, 0x66, 0xe9];
      final aliases = <String, (List<int>, String)>{
        'utf-8': (utf8.encode('Café'), 'Café'),
        'UTF8': (utf8.encode('Café'), 'Café'),
        'us-ascii': (utf8.encode('Café'), 'Café'),
        'ASCII': (utf8.encode('Café'), 'Café'),
        'iso-8859-1': (cafeLatin1, 'Café'),
        'Latin1': (cafeLatin1, 'Café'),
        'LATIN-1': (cafeLatin1, 'Café'),
        'l1': (cafeLatin1, 'Café'),
        'ISO_8859-1': (cafeLatin1, 'Café'),
        'Windows-1252': ([0x80, 0x20, 0x35], '€ 5'),
        'cp1252': ([0x93, 0x51, 0x94], '“Q”'),
        'iso-8859-15': ([0xa4, 0x20, 0xe9], '€ é'),
        'Latin-9': ([0xa4, 0x20, 0xbd], '€ œ'),
      };
      for (final MapEntry(key: name, value: (bytes, title))
          in aliases.entries) {
        test(name, () async {
          final parse = await _parse(
            Stream.value(_declared(name, bytes)),
            window: _september,
          );

          expect(parse.programmes.single.title, title);
          expect(parse.summary.declaredEncoding, name);
          expect(parse.summary.unknownEncoding, isFalse);
        });
      }
    });
  });

  group('truncated files keep what they read', () {
    test('a file that stops inside a programme drops that one, and '
        'finalizes the rest', () async {
      final parse = await _fixture('truncated_mid_element.xml');

      expect(parse.summary.truncated, isTrue);
      expect(parse.channels.map((c) => c.id), ['t.cut', 't.other']);
      expect(
        parse.programmes,
        unorderedEquals([
          XmltvProgramme(
            channelId: 't.cut',
            startMs: _sep14(10),
            endMs: _sep14(11),
            title: 'Complete',
          ),
          XmltvProgramme(
            channelId: 't.other',
            startMs: _sep14(10),
            endMs: _sep14(12),
            title: 'Other Channel',
          ),
        ]),
      );
      // The cut-off programme is not a "next programme": the one waiting
      // for a stop has nothing to end it. The cut one is not counted.
      expect(parse.skipped, {XmltvSkip.noStop: 1});
      expect(parse.summary.programmes, 2);
    });

    test('a file with no closing tv tag is truncated, and loses '
        'nothing', () async {
      final parse = await _fixture('truncated_no_close.xml');

      expect(parse.summary.truncated, isTrue);
      expect(parse.channels, const [
        XmltvChannel(id: 'n.one', displayName: 'One'),
      ]);
      expect(parse.on('n.one'), [
        XmltvProgramme(
          channelId: 'n.one',
          startMs: _sep14(10),
          endMs: _sep14(11),
          title: 'First',
        ),
        XmltvProgramme(
          channelId: 'n.one',
          startMs: _sep14(11),
          endMs: _sep14(12),
          title: 'Second',
        ),
      ]);
      expect(parse.summary.skippedTotal, 0);
    });

    test('a channel cut mid-element is dropped, not counted', () async {
      final parse = await _text(
        '<tv><channel id="a"><display-name>A</display-name></channel>\n'
        '<channel id="b"><display-name>B',
      );

      expect(parse.channels, const [XmltvChannel(id: 'a', displayName: 'A')]);
      expect(parse.summary.channels, 1);
      expect(parse.summary.skippedTotal, 0);
      expect(parse.summary.truncated, isTrue);
    });
  });

  group('not XMLTV at all', () {
    for (final name in [
      'html_error.html',
      'json_error.json',
      'empty.xml',
      'whitespace_only.xml',
      'not_tv_root.xml',
      'prolog_only.xml',
    ]) {
      test('$name is a FormatException', () async {
        await expectLater(_fixture(name), throwsFormatException);
      });
    }

    test('a JSON array, a BOM alone, and a doctype that is not tv', () async {
      for (final bytes in [
        utf8.encode(' \n[{"error": "not found"}]'),
        [0xef, 0xbb, 0xbf],
        utf8.encode('<!DOCTYPE html>\n<HTML><BODY>Not found</BODY></HTML>'),
      ]) {
        await expectLater(
          _parse(Stream.value(bytes)),
          throwsFormatException,
          reason: '$bytes',
        );
      }
    });

    test('an empty but valid <tv> is not an error: zero counts', () async {
      final parse = await _fixture('empty_tv.xml');

      expect(parse.channels, isEmpty);
      expect(parse.programmes, isEmpty);
      expect(parse.summary.channels, 0);
      expect(parse.summary.programmes, 0);
      expect(parse.summary.skippedTotal, 0);
      expect(parse.summary.truncated, isFalse);
      expect(parse.summary.declaredEncoding, 'UTF-8');
    });
  });

  test('orphan_channel.xml: programmes for an undeclared channel are '
      'kept', () async {
    final parse = await _fixture('orphan_channel.xml');

    expect(parse.channels, const [
      XmltvChannel(id: 'declared.one', displayName: 'Declared'),
    ]);
    expect(
      parse.programmes,
      unorderedEquals([
        XmltvProgramme(
          channelId: 'declared.one',
          startMs: _sep14(10),
          endMs: _sep14(11),
          title: 'Declared Show',
        ),
        XmltvProgramme(
          channelId: 'ghost.zz',
          startMs: _sep14(10),
          endMs: _sep14(10, 30),
          title: 'Ghost Show',
        ),
        XmltvProgramme(
          channelId: 'ghost.zz',
          startMs: _sep14(10, 30),
          endMs: _sep14(11),
          title: 'Ghost Show Two',
        ),
      ]),
    );
    expect(parse.summary.skippedTotal, 0);
  });

  test('icons.xml: junk icons are passed over; the first worth requesting '
      'wins', () async {
    final parse = await _fixture('icons.xml');

    expect(parse.channels, const [
      XmltvChannel(
        id: 'i.first-valid',
        displayName: 'First Valid',
        iconUrl: 'https://logos.example.test/first-valid.png',
      ),
      XmltvChannel(id: 'i.none', displayName: 'None Usable'),
      // cleanImageUrl trims.
      XmltvChannel(
        id: 'i.padded',
        displayName: 'Padded',
        iconUrl: 'http://logos.example.test/padded.png',
      ),
      XmltvChannel(id: 'i.no-icon', displayName: 'No Icon'),
    ]);
    // A junk icon is not a fault.
    expect(parse.summary.skippedTotal, 0);
  });

  group('runaway_and_long.xml: memory stays bounded', () {
    late _Parse parse;

    setUpAll(() async => parse = await _fixture('runaway_and_long.xml'));

    test('a tag over 64 KiB with no > is malformed, and its element is '
        'skipped', () {
      expect(parse.titles, isNot(contains('Runaway Tag')));
      expect(parse.on('r.one').take(2), [
        XmltvProgramme(
          channelId: 'r.one',
          startMs: _sep14(10),
          endMs: _sep14(11),
          title: 'Before',
        ),
        XmltvProgramme(
          channelId: 'r.one',
          startMs: _sep14(12),
          endMs: _sep14(13),
          title: 'After',
        ),
      ]);
      expect(parse.skipped, {XmltvSkip.malformed: 1});
      expect(parse.summary.programmes, 3);
    });

    test('text past its cap is dropped, not an error', () {
      final long = parse.on('r.one').last;
      expect(long.title, 'T' * 512);
      expect(long.subtitle, 'S' * 512);
      expect(long.description, 'D' * 4096);
      expect(long.category, 'C' * 512);
      expect((long.startMs, long.endMs), (_sep14(13), _sep14(14)));
    });
  });

  group('samples', () {
    test('a value is shortened to 40 characters', () async {
      final parse = await _text(
        '<tv><programme start="${'2' * 60}" channel="long">\n'
        '<title>Long</title></programme></tv>',
      );

      final sample = parse.samplesFor(XmltvSkip.badDate).single;
      expect(sample, startsWith('bad_date: long: 2222'));
      expect(
        sample.substring('bad_date: long: '.length).length,
        lessThanOrEqualTo(40),
      );
    });

    test('a value with a URL in it is written <url>, so no credential '
        'reaches a log (hard rule 3)', () async {
      final parse = await _text(
        '<tv><programme '
        'start="http://epg.example.test/get?username=u&amp;password=Pw-7f3a" '
        'channel="urls"><title>Url</title></programme></tv>',
      );

      expect(parse.samplesFor(XmltvSkip.badDate), ['bad_date: urls: <url>']);
      expect(parse.summary.samples.join(), isNot(contains('Pw-7f3a')));
    });
  });

  group('the byte stream and the callbacks', () {
    test('an error the stream ends with is passed on as it is, not a '
        'truncation', () async {
      const drop = SocketException('Connection reset by peer');
      final bytes = _bytes('clean.xml');
      Stream<List<int>> dropped() async* {
        yield bytes.sublist(0, 1500);
        throw drop;
      }

      await expectLater(_parse(dropped()), throwsA(same(drop)));
    });

    test("a corrupt gzip body is the decoder's error, not a truncation or "
        'a "not XMLTV"', () async {
      final zipped = _bytes('clean.xml.gz');
      // The header intact, the deflate data behind it garbage.
      final corrupt = [...zipped.sublist(0, 10), ...List.filled(200, 0xff)];

      // dart:io's gzip decoder says "Filter error"; the parser's own
      // FormatException would name the body instead.
      await expectLater(
        _parse(Stream.value(corrupt)),
        throwsA(
          isA<FormatException>().having(
            (e) => e.message,
            'message',
            contains('Filter error'),
          ),
        ),
      );
    });

    test('a future from onChannel holds back the next channel', () async {
      final received = <String>[];
      final release = Completer<void>();
      final parsing = parseXmltv(
        Stream.value(_bytes('clean.xml')),
        onChannel: (channel) {
          received.add(channel.id);
          return received.length == 1 ? release.future : null;
        },
        onProgramme: (_) {},
        window: _september,
      );

      await pumpEventQueue();
      expect(received, ['north.news.uk']);

      release.complete();
      final summary = await parsing;
      expect(received, hasLength(4));
      expect(summary.channels, 4);
    });

    test("an error from onProgramme's future ends the parse with it", () async {
      var received = 0;
      final parsing = parseXmltv(
        Stream.value(_bytes('clean.xml')),
        onChannel: (_) {},
        onProgramme: (_) {
          received++;
          return received == 2
              ? Future<void>.error(StateError('disk full'))
              : null;
        },
        window: _september,
      );

      await expectLater(parsing, throwsA(isA<StateError>()));
      expect(received, 2);
    });
  });

  group('every fixture reads the same whatever the chunking', () {
    final names = [
      for (final entity in Directory(_dir).listSync())
        if (entity is File) entity.uri.pathSegments.last,
    ]..sort();

    test('the fixture set is all here', () {
      expect(
        names,
        containsAll([
          'clean.xml',
          'clean.xml.gz',
          'utf16_bom.xml',
          'empty.xml',
        ]),
      );
    });

    for (final name in names) {
      test('$name in 1-byte and 7-byte chunks', () async {
        final bytes = _bytes(name);
        final whole = await _outcome(Stream.value(bytes));

        expect(await _outcome(_chunks(bytes, 1)), whole, reason: '1-byte');
        expect(await _outcome(_chunks(bytes, 7)), whole, reason: '7-byte');
      });
    }
  });
}
