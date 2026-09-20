/// `xmltv.php`: the full guide for the generated catalogue (docs/02 "XMLTV",
/// docs/06 "Fake provider"), streamed and optionally gzipped.
///
/// Written onto the response a few kilobytes at a time, like `get.php`: the
/// `large` profile over a few days is hundreds of megabytes, which is the
/// point — docs/06 budgets a 300 MB import, so the file has to be able to
/// get that big without the server (or a test) ever holding it whole.
///
/// The schedule is the same deterministic one `get_short_epg` answers from,
/// so a channel's now/next matches whichever way the app asked.
library;

import 'dart:io';

import 'package:fake_provider/models.dart';
import 'package:fake_provider/player_api.dart';
import 'package:fake_provider/server_state.dart';
import 'package:shelf/shelf.dart';

/// 30 minutes, the generator's programme slot.
const int _slotMs = 30 * 60 * 1000;

/// Programmes before now, as a panel does: the app keeps a day of history
/// (docs/02 retention window).
const _slotsBack = 48;

/// The channel id no stream has, for [XmltvQuirks.orphanChannel].
const orphanXmltvId = 'ghost.channel.zz';

/// The misbehaviours of a real XMLTV file, all off by default. Every one is
/// something docs/02 says the parser must survive.
class XmltvQuirks {
  const new({
    this.noStop = false,
    this.badDate = false,
    this.unknownTimezone = false,
    this.unknownEncoding = false,
    this.duplicateChannel = false,
    this.orphanChannel = false,
    this.unclosed = false,
  });

  factory fromQuery(Map<String, String> query, {required bool fallback}) {
    bool flag(String key) {
      final value = query[key];
      if (value == null) return fallback;
      return value == '1' || value.toLowerCase() == 'true';
    }

    return XmltvQuirks(
      noStop: flag('no_stop'),
      badDate: flag('bad_date'),
      unknownTimezone: flag('unknown_tz'),
      unknownEncoding: flag('unknown_encoding'),
      duplicateChannel: flag('duplicate_channel'),
      orphanChannel: flag('orphan_channel'),
      // Never on by profile: a truncated file is a test's choice, not a
      // panel's habit.
      unclosed: query['unclosed'] == '1',
    );
  }

  /// What the `quirky` profile serves.
  static const all = XmltvQuirks(
    noStop: true,
    badDate: true,
    unknownTimezone: true,
    unknownEncoding: true,
    duplicateChannel: true,
    orphanChannel: true,
  );

  /// Every 7th programme has no `stop`: its end is the next one's start.
  final bool noStop;

  /// Every 11th programme's `start` is not a date at all.
  final bool badDate;

  /// Every 13th programme's `start` carries an offset no zone has.
  final bool unknownTimezone;

  /// The XML declaration names an encoding that does not exist.
  final bool unknownEncoding;

  /// The first channel is declared twice.
  final bool duplicateChannel;

  /// A `<channel>` (with programmes) that matches no stream.
  final bool orphanChannel;

  /// The file stops mid-element: no `</tv>`, as a truncated download ends.
  final bool unclosed;

  /// This set with the flags a query names laid over it, each defaulting to
  /// [fallback] — so the `quirky` profile serves them all and a test can
  /// ask for exactly one.
}

/// What one `xmltv.php` request asks for.
class XmltvOptions {
  const new({
    required this.days,
    required this.gzip,
    required this.quirks,
    this.channelLimit,
  });

  factory fromQuery(Map<String, String> query, FakeServerState state) {
    int? asInt(String key) {
      final value = query[key];
      return value == null ? null : int.tryParse(value);
    }

    final gzip = query['gzip'];
    return XmltvOptions(
      days: (asInt('days') ?? state.epgDays).clamp(1, 60),
      channelLimit: asInt('channels'),
      gzip: gzip == null
          ? state.epgGzip
          : gzip == '1' || gzip.toLowerCase() == 'true',
      quirks: XmltvQuirks.fromQuery(
        query,
        fallback: state.profile.quirks.messyXmltv,
      ),
    );
  }

  /// Days of guide after now (a day of history always comes with it).
  final int days;

  /// `?channels=` — fewer channels than the catalogue has, to size a file.
  final int? channelLimit;

  final bool gzip;
  final XmltvQuirks quirks;
}

/// The handler for `/xmltv.php`; the caller owns the route.
Handler xmltvHandler(FakeServerState state) {
  return (Request request) {
    final params = request.url.queryParameters;
    if (!state.authenticates(params['username'], params['password'])) {
      // As `get.php` does: there is no JSON here to carry `auth: 0`.
      return Response(401, body: 'Unauthorized');
    }
    final options = XmltvOptions.fromQuery(params, state);
    final body = _xmltv(state, options);
    return Response.ok(
      options.gzip ? gzip.encoder.bind(body) : body,
      headers: {
        'content-type': 'application/xml; charset=utf-8',
        if (options.gzip) 'content-encoding': 'gzip',
        'cache-control': 'no-store',
      },
    );
  };
}

/// Programme categories, picked by programme id: a guide's `<category>` is
/// a handful of words repeated over the whole file.
const _categories = <String>[
  'Sports',
  'Movie',
  'News',
  'Documentary',
  'Series',
  'Music',
  'Children',
];

Stream<List<int>> _xmltv(FakeServerState state, XmltvOptions options) async* {
  final quirks = options.quirks;
  final breakUtf8 = state.profile.quirks.invalidUtf8Names;
  final buffer = StringBuffer();
  List<int> take() {
    final bytes = encodeWireText(buffer.toString(), breakUtf8: breakUtf8);
    buffer.clear();
    return bytes;
  }

  final encoding = quirks.unknownEncoding ? 'X-MADE-UP-8' : 'UTF-8';
  buffer
    ..writeln('<?xml version="1.0" encoding="$encoding"?>')
    ..writeln(
      '<tv generator-info-name="fake_provider" '
      'generator-info-url="https://example.invalid/fake_provider">',
    );

  // Channels with no `epg_channel_id` are left out on purpose: they are the
  // app's "No guide information" case (docs/05).
  Iterable<FakeChannel> guided() {
    final all = state.catalog.channels().where((c) => c.epgChannelId != null);
    final limit = options.channelLimit;
    return limit == null ? all : all.take(limit);
  }

  var first = true;
  for (final channel in guided()) {
    _writeChannel(buffer, channel.epgChannelId!, channel.name, channel.icon);
    if (first && quirks.duplicateChannel) {
      _writeChannel(buffer, channel.epgChannelId!, channel.name, channel.icon);
    }
    first = false;
    if (buffer.length > 32 * 1024) yield take();
  }
  if (quirks.orphanChannel) {
    _writeChannel(buffer, orphanXmltvId, 'Ghost Channel', null);
  }

  final now = DateTime.now().toUtc();
  final windowStart = DateTime.fromMillisecondsSinceEpoch(
    (now.millisecondsSinceEpoch ~/ _slotMs - _slotsBack) * _slotMs,
    isUtc: true,
  );
  final slots = _slotsBack + options.days * 48;
  var index = 0;
  for (final channel in guided()) {
    final programmes = state.catalog.shortEpg(
      channel.streamId,
      limit: slots,
      now: windowStart,
    );
    for (final programme in programmes) {
      _writeProgramme(buffer, programme, programme.epgChannelId, quirks, index);
      index++;
      if (buffer.length > 32 * 1024) yield take();
    }
  }
  if (quirks.orphanChannel) {
    for (final programme in state.catalog.shortEpg(
      1,
      limit: 5,
      now: windowStart,
    )) {
      _writeProgramme(buffer, programme, orphanXmltvId, quirks, index++);
    }
  }

  if (quirks.unclosed) {
    // Cut mid-element, with no `</tv>`: a download that ended early.
    buffer.write('  <programme start="20260');
    yield take();
    return;
  }
  buffer.writeln('</tv>');
  yield take();
}

void _writeChannel(StringBuffer buffer, String id, String name, String? icon) {
  buffer
    ..writeln('  <channel id="${_xml(id)}">')
    ..writeln('    <display-name lang="en">${_xml(name)}</display-name>');
  if (icon != null) {
    buffer.writeln('    <icon src="${_xml(icon)}" />');
  }
  buffer.writeln('  </channel>');
}

void _writeProgramme(
  StringBuffer buffer,
  FakeProgramme programme,
  String channelId,
  XmltvQuirks quirks,
  int index,
) {
  final start = quirks.badDate && index % 11 == 10
      ? 'whenever'
      : _stamp(
          programme.start.toUtc(),
          offset: quirks.unknownTimezone && index % 13 == 12
              ? '+2500'
              : '+0000',
        );
  final stop = quirks.noStop && index % 7 == 6
      ? null
      : _stamp(programme.end.toUtc(), offset: '+0000');
  buffer
    ..writeln(
      '  <programme start="$start" '
      '${stop == null ? '' : 'stop="$stop" '}'
      'channel="${_xml(channelId)}">',
    )
    ..writeln('    <title lang="en">${_xml(programme.title)}</title>');
  if (index % 5 == 0) {
    buffer.writeln(
      '    <sub-title lang="en">${_xml('Part ${1 + index % 9}')}</sub-title>',
    );
  }
  buffer
    ..writeln('    <desc lang="en">${_xml(programme.description)}</desc>')
    ..writeln(
      '    <category lang="en">'
      '${_categories[programme.id % _categories.length]}</category>',
    );
  if (index % 4 == 1) {
    final episode = 'S${1 + index % 6}E${1 + index % 24}';
    buffer.writeln('    <episode-num system="onscreen">$episode</episode-num>');
  }
  buffer.writeln('  </programme>');
}

/// `20260914180000 +0000`, XMLTV's own format (docs/02).
String _stamp(DateTime utc, {required String offset}) {
  String p(int value, [int width = 2]) => '$value'.padLeft(width, '0');
  return '${p(utc.year, 4)}${p(utc.month)}${p(utc.day)}'
      '${p(utc.hour)}${p(utc.minute)}${p(utc.second)} $offset';
}

String _xml(String text) => text
    .replaceAll('&', '&amp;')
    .replaceAll('<', '&lt;')
    .replaceAll('>', '&gt;')
    .replaceAll('"', '&quot;');
