import 'package:fake_provider/models.dart';
import 'package:fake_provider/profile.dart';
import 'package:fake_provider/server_state.dart';
import 'package:fake_provider/xmltv.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:iptv_player/data/providers/provider_text.dart';
import 'package:iptv_player/data/providers/xmltv/xmltv_parser.dart';
import 'package:shelf/shelf.dart';

/// The fake panel's own `xmltv.php` through the parser, in-process (no
/// socket). What the parse must give is worked out from the generator's
/// rules (tools/fake_provider/lib/xmltv.dart) and its catalogue, not from a
/// parse — so a change on either side that breaks the other shows here.

/// The generator's programme slot.
const int _slotMs = 30 * 60 * 1000;

/// The `<category>` words xmltv.dart writes, picked by programme id.
const _categories = <String>[
  'Sports',
  'Movie',
  'News',
  'Documentary',
  'Series',
  'Music',
  'Children',
];

typedef _Parse = ({
  List<XmltvChannel> channels,
  List<XmltvProgramme> programmes,
  XmltvSummary summary,
});

FakeServerState _state(String profile) => FakeServerState(
  profile: fakeProfiles[profile]!,
  // xmltv.php reads neither.
  samplesDir: 'unused',
  ffmpegPath: 'unused',
  runDir: 'unused',
);

Future<Response> _get(FakeServerState state, String query) async {
  final profile = state.profile;
  final response = await xmltvHandler(state)(
    Request(
      'GET',
      Uri.parse(
        'http://panel.test/xmltv.php?username=${profile.username}'
        '&password=${profile.password}&$query',
      ),
    ),
  );
  expect(response.statusCode, 200);
  return response;
}

Future<_Parse> _parse(Stream<List<int>> bytes, XmltvWindow window) async {
  final channels = <XmltvChannel>[];
  final programmes = <XmltvProgramme>[];
  final summary = await parseXmltv(
    bytes,
    onChannel: channels.add,
    onProgramme: programmes.add,
    window: window,
  );
  return (channels: channels, programmes: programmes, summary: summary);
}

int _slotOf(DateTime time) => time.millisecondsSinceEpoch ~/ _slotMs;

/// Parses `xmltv.php?[query]` with the window [windowAt] gives for the
/// time the guide was written. The generator reads the clock as it writes;
/// a parse that straddles a half hour saw another grid than the one this
/// test would work out, so it is read again (at most twice more).
Future<({_Parse parse, DateTime now})> _readGuide(
  FakeServerState state,
  String query,
  XmltvWindow Function(DateTime now) windowAt,
) async {
  for (var attempt = 1; ; attempt++) {
    final now = DateTime.now();
    final response = await _get(state, query);
    final parse = await _parse(response.read(), windowAt(now));
    if (_slotOf(DateTime.now()) == _slotOf(now) || attempt == 3) {
      return (parse: parse, now: now);
    }
  }
}

int _byChannelAndTime(XmltvProgramme a, XmltvProgramme b) {
  final byChannel = a.channelId.compareTo(b.channelId);
  if (byChannel != 0) return byChannel;
  final byStart = a.startMs.compareTo(b.startMs);
  if (byStart != 0) return byStart;
  return a.title.compareTo(b.title);
}

List<XmltvProgramme> _sorted(List<XmltvProgramme> programmes) =>
    [...programmes]..sort(_byChannelAndTime);

Map<String, int> _nonZero(Map<String, int> counts) => {
  for (final MapEntry(:key, :value) in counts.entries)
    if (value != 0) key: value,
};

final class _Expected {
  const new({
    required this.channels,
    required this.programmes,
    required this.skipped,
    required this.outsideWindow,
    required this.collisions,
  });

  final List<XmltvChannel> channels;
  final List<XmltvProgramme> programmes;
  final Map<String, int> skipped;
  final int outsideWindow;

  /// Guided channels whose `epg_channel_id` an earlier one already has:
  /// the catalogue's own duplicates, apart from the quirk's.
  final int collisions;
}

/// What the parser must hand over for `xmltv.php` written at [now].
///
/// The generator writes every guided channel's programmes as one block in
/// time order, 30 minutes each, numbering programmes across the whole file
/// (`index`): every 11th start is `whenever` (bad_date), every 13th of the
/// rest is `+2500` (bad_timezone), every 7th has no stop. Within a block,
/// the parser's pending rules then come down to: a programme with no stop
/// ends where the next readable one starts, and the last readable one
/// with no stop is no_stop. A later block with the same channel id (the
/// catalogue gives some HD and SD streams one id) starts the day over:
/// every programme of it that goes back before the first block's pending
/// one is out of order, one on the same start is a duplicate, and only
/// what runs past the first block is kept. So the model keeps one pending
/// programme per id across blocks, as the parser does.
_Expected _expected(
  FakeServerState state, {
  required XmltvQuirks quirks,
  required int days,
  required int channelLimit,
  required DateTime now,
  required XmltvWindow window,
}) {
  final guided = state.catalog
      .channels()
      .where((c) => c.epgChannelId != null)
      .take(channelLimit)
      .toList();
  final skipped = <String, int>{};
  void skip(String code) =>
      skipped.update(code, (n) => n + 1, ifAbsent: () => 1);

  final channels = <XmltvChannel>[];
  final ids = <String>{};
  var collisions = 0;
  for (final (i, channel) in guided.indexed) {
    final id = channel.epgChannelId!;
    if (ids.add(id)) {
      channels.add(
        XmltvChannel(
          id: id,
          // The invalid-UTF-8 quirk's byte decodes to U+FFFD.
          displayName: cleanText(
            channel.name.replaceAll(invalidUtf8Marker, '\ufffd'),
          ),
          iconUrl: cleanImageUrl(channel.icon),
        ),
      );
    } else {
      collisions++;
      skip(XmltvSkip.duplicateChannel);
    }
    if (i == 0 && quirks.duplicateChannel) skip(XmltvSkip.duplicateChannel);
  }
  if (quirks.orphanChannel) {
    channels.add(
      const XmltvChannel(id: orphanXmltvId, displayName: 'Ghost Channel'),
    );
  }

  final from = DateTime.fromMillisecondsSinceEpoch(
    (_slotOf(now) - 48) * _slotMs,
    isUtc: true,
  );
  final blocks = <(String, List<FakeProgramme>)>[
    for (final channel in guided)
      (
        channel.epgChannelId!,
        state.catalog.shortEpg(
          channel.streamId,
          limit: 48 + days * 48,
          now: from,
        ),
      ),
    if (quirks.orphanChannel)
      (orphanXmltvId, state.catalog.shortEpg(1, limit: 5, now: from)),
  ];

  final programmes = <XmltvProgramme>[];
  var outsideWindow = 0;
  final pending = <String, ({FakeProgramme programme, int index, int? stop})>{};

  void finalize(
    String id,
    ({FakeProgramme programme, int index, int? stop}) row,
    int? end,
  ) {
    final start = row.programme.start.millisecondsSinceEpoch;
    if (end == null) {
      skip(XmltvSkip.noStop);
    } else if (!window.overlaps(start, end)) {
      outsideWindow++;
    } else {
      programmes.add(
        XmltvProgramme(
          channelId: id,
          startMs: start,
          endMs: end,
          title: cleanText(row.programme.title)!,
          subtitle: row.index % 5 == 0 ? 'Part ${1 + row.index % 9}' : null,
          description: cleanText(row.programme.description),
          category: _categories[row.programme.id % _categories.length],
        ),
      );
    }
  }

  var index = 0;
  for (final (id, block) in blocks) {
    for (final programme in block) {
      final i = index++;
      if (quirks.badDate && i % 11 == 10) {
        skip(XmltvSkip.badDate);
        continue;
      }
      if (quirks.unknownTimezone && i % 13 == 12) {
        skip(XmltvSkip.badTimezone);
        continue;
      }
      final start = programme.start.millisecondsSinceEpoch;
      final previous = pending[id];
      if (previous != null) {
        final previousStart = previous.programme.start.millisecondsSinceEpoch;
        if (start == previousStart) {
          skip(XmltvSkip.duplicateProgramme);
          continue;
        }
        if (start < previousStart) {
          skip(XmltvSkip.outOfOrder);
          continue;
        }
        final stop = previous.stop;
        finalize(id, previous, stop == null || stop > start ? start : stop);
      }
      pending[id] = (
        programme: programme,
        index: i,
        stop: quirks.noStop && i % 7 == 6
            ? null
            : programme.end.millisecondsSinceEpoch,
      );
    }
  }
  for (final MapEntry(key: id, value: row) in pending.entries) {
    finalize(id, row, row.stop);
  }
  return _Expected(
    channels: channels,
    programmes: programmes,
    skipped: skipped,
    outsideWindow: outsideWindow,
    collisions: collisions,
  );
}

/// Everything but the channels' display names, which have a test of their
/// own: the quirky names carry HTML entities, and whether those are
/// decoded is one question, not a reason to hide every other check.
void _expectMatches(_Parse parse, _Expected expected) {
  expect(
    [for (final c in parse.channels) (c.id, c.iconUrl)],
    [for (final c in expected.channels) (c.id, c.iconUrl)],
  );
  expect(parse.summary.channels, expected.channels.length);
  expect(_sorted(parse.programmes), _sorted(expected.programmes));
  expect(parse.summary.programmes, expected.programmes.length);
  expect(_nonZero(parse.summary.skipped), expected.skipped);
  expect(parse.summary.outsideWindow, expected.outsideWindow);
}

void main() {
  // Big enough for every rule to fire many times, small enough to be
  // quick: the quirky profile's first 20 guided channels include one whose
  // name carries the invalid-UTF-8 byte (index 16).
  const days = 1;
  const channelLimit = 20;
  const query = 'days=$days&channels=$channelLimit';

  test('the clean guide: every guided channel once, every programme, '
      'nothing skipped', () async {
    final state = _state('default');
    final (:parse, :now) = await _readGuide(state, query, XmltvWindow.around);
    final expected = _expected(
      state,
      quirks: const XmltvQuirks(),
      days: days,
      channelLimit: channelLimit,
      now: now,
      window: XmltvWindow.around(now),
    );

    _expectMatches(parse, expected);
    expect(parse.channels, expected.channels);
    // Every programme has a stop and a date; only a catalogue id collision
    // could skip anything: its channel, and its second schedule.
    expect(
      expected.skipped.keys,
      everyElement(
        isIn([
          XmltvSkip.duplicateChannel,
          XmltvSkip.outOfOrder,
          XmltvSkip.duplicateProgramme,
        ]),
      ),
    );
    expect(parse.programmes, hasLength(greaterThan(1000)));
    expect(parse.summary.outsideWindow, 0);
    expect(parse.summary.truncated, isFalse);
    expect(parse.summary.declaredEncoding, 'UTF-8');
    expect(parse.summary.unknownEncoding, isFalse);
    expect(parse.summary.samples, hasLength(expected.collisions.clamp(0, 3)));
  });

  group('the quirky guide (XmltvQuirks.all)', () {
    late FakeServerState state;
    late _Parse parse;
    late _Expected expected;

    setUpAll(() async {
      state = _state('quirky');
      expect(state.profile.quirks.messyXmltv, isTrue);
      final read = await _readGuide(state, query, XmltvWindow.around);
      parse = read.parse;
      expected = _expected(
        state,
        quirks: XmltvQuirks.all,
        days: days,
        channelLimit: channelLimit,
        now: read.now,
        window: XmltvWindow.around(read.now),
      );
    });

    test('matches what the generator wrote, row for row', () {
      _expectMatches(parse, expected);
    });

    test('display names: the invalid byte cleaned out, entities decoded as '
        'cleanText decodes them', () {
      // The generator XML-escapes names that already carry HTML entities
      // (`&amp;amp;`, `&amp;#39;`): the parser decodes the XML, then
      // cleanText decodes the HTML, as the Xtream client does for the same
      // names — so a channel reads the same from either.
      expect(parse.channels, expected.channels);
    });

    test('the first channel, declared twice, is handed over once', () {
      expect(
        parse.summary.skipped[XmltvSkip.duplicateChannel],
        1 + expected.collisions,
      );
      final first = parse.channels.first.id;
      expect(parse.channels.where((c) => c.id == first), hasLength(1));
    });

    test('the orphan channel and its programmes are kept', () {
      expect(parse.channels.last, expected.channels.last);
      expect(parse.channels.last.id, orphanXmltvId);
      final orphans = parse.programmes.where(
        (p) => p.channelId == orphanXmltvId,
      );
      expect(orphans, isNotEmpty);
      expect(
        orphans,
        unorderedEquals(
          expected.programmes.where((p) => p.channelId == orphanXmltvId),
        ),
      );
    });

    test('every 11th start is a bad date, every 13th a bad zone, each '
        'counted once', () {
      // Every programme written, numbered across the file: the channels'
      // blocks, then the orphan's five. A bad date wins over a bad zone.
      final written = List.generate(
        channelLimit * (48 + days * 48) + 5,
        (i) => i,
      );
      final badDates = written.where((i) => i % 11 == 10).length;
      final badZones = written
          .where((i) => i % 13 == 12 && i % 11 != 10)
          .length;
      expect(parse.summary.skipped[XmltvSkip.badDate], badDates);
      expect(parse.summary.skipped[XmltvSkip.badTimezone], badZones);
      expect(
        parse.samplesFor(XmltvSkip.badDate),
        everyElement(endsWith(': whenever')),
      );
      expect(
        parse.samplesFor(XmltvSkip.badTimezone),
        everyElement(contains('+2500')),
      );
    });

    test('a missing stop is filled from the next start, except the last '
        'one per channel', () {
      // The row-for-row match above is the exact check. Here, the shape of
      // it: every programme lasts a whole number of slots — one filled
      // across a skipped programme lasts two or more — and some have
      // nothing to end them.
      final filled = parse.programmes.where(
        (p) => p.endMs - p.startMs != _slotMs,
      );
      expect(filled, isNotEmpty);
      expect(filled, everyElement(_wholeSlotsOverOne));
      expect(parse.summary.skipped[XmltvSkip.noStop], greaterThan(0));
    });

    test('the made-up encoding is read as UTF-8, and said so', () {
      expect(parse.summary.declaredEncoding, 'X-MADE-UP-8');
      expect(parse.summary.unknownEncoding, isTrue);
      expect(parse.summary.truncated, isFalse);
    });

    test('samples: at most three per reason', () {
      for (final reason in parse.summary.skipped.keys) {
        expect(
          parse.samplesFor(reason).length,
          lessThanOrEqualTo(3),
          reason: reason,
        );
      }
      expect(parse.summary.samples.join(), isNot(contains('://')));
    });

    test('a narrower window: outside it is counted, not skipped', () async {
      XmltvWindow nextSixHours(DateTime now) => XmltvWindow(
        startMs: now.millisecondsSinceEpoch,
        endMs: now.add(const Duration(hours: 6)).millisecondsSinceEpoch,
      );
      final read = await _readGuide(state, query, nextSixHours);
      final narrow = _expected(
        state,
        quirks: XmltvQuirks.all,
        days: days,
        channelLimit: channelLimit,
        now: read.now,
        window: nextSixHours(read.now),
      );

      _expectMatches(read.parse, narrow);
      expect(read.parse.summary.outsideWindow, greaterThan(1000));
    });

    test('gzip=1: the raw gzipped body is sniffed by its magic '
        'number', () async {
      final read = await _readGuide(state, '$query&gzip=1', XmltvWindow.around);
      final response = await _get(state, '$query&gzip=1');
      // The handler says so in a header; the parser must not need it.
      expect(response.headers['content-encoding'], 'gzip');
      final head = await response.read().first;
      expect(head.take(2), [0x1f, 0x8b]);

      final zipped = _expected(
        state,
        quirks: XmltvQuirks.all,
        days: days,
        channelLimit: channelLimit,
        now: read.now,
        window: XmltvWindow.around(read.now),
      );
      _expectMatches(read.parse, zipped);
      expect(read.parse.summary.unknownEncoding, isTrue);
    });

    test('unclosed=1: truncated, and everything before the cut kept', () async {
      final read = await _readGuide(
        state,
        '$query&unclosed=1',
        XmltvWindow.around,
      );
      final cut = _expected(
        state,
        quirks: XmltvQuirks.all,
        days: days,
        channelLimit: channelLimit,
        now: read.now,
        window: XmltvWindow.around(read.now),
      );

      expect(read.parse.summary.truncated, isTrue);
      // The half-written `<programme start="20260` is dropped, not counted.
      _expectMatches(read.parse, cut);
    });
  });
}

/// A programme longer than one slot, by whole slots.
final Matcher _wholeSlotsOverOne = predicate<XmltvProgramme>((p) {
  final length = p.endMs - p.startMs;
  return length > _slotMs && length % _slotMs == 0;
}, 'lasts whole slots, more than one');

extension on _Parse {
  List<String> samplesFor(String reason) => [
    for (final sample in summary.samples)
      if (sample.startsWith('$reason: ')) sample,
  ];
}
