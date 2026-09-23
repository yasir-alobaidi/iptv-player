/// The XMLTV guide parser (docs/02 "XMLTV"). It streams: bytes in,
/// channels and programmes out one at a time, so a 300 MB guide is never
/// held whole — never a DOM, never the file in memory. Run it off the UI
/// isolate (the guide import's isolate, `runEpgImportWork`).
library;

import 'dart:async';
import 'dart:typed_data';

import 'package:iptv_player/data/providers/provider_bytes.dart';
import 'package:iptv_player/data/providers/provider_text.dart';
import 'package:iptv_player/data/providers/xmltv/xmltv_scanner.dart';
import 'package:iptv_player/data/providers/xmltv/xmltv_text.dart';
import 'package:iptv_player/data/providers/xmltv/xmltv_time.dart';
import 'package:meta/meta.dart';

/// Why a row was left out. Stable codes: they are stored in the import's
/// `counts_json` (`EpgImportCounts.skipped`) and shown by Settings → Guide
/// and the diagnostics export, so a code is never renamed.
abstract final class XmltvSkip {
  /// A `<channel>` with no `id`, or an empty one.
  static const noId = 'no_id';

  /// A `<channel>` whose id was already declared. The first one wins.
  static const duplicateChannel = 'duplicate_channel';

  /// A `<programme>` with no `channel` attribute, or an empty one.
  static const noChannel = 'no_channel';

  /// A `start` that is not a date at all.
  static const badDate = 'bad_date';

  /// A `start` whose zone is not one (`+2500`, a name we don't know).
  static const badTimezone = 'bad_timezone';

  /// No usable `stop`, and no later programme on the channel to end it.
  static const noStop = 'no_stop';

  /// Ends at or before it starts.
  static const badDuration = 'bad_duration';

  /// Longer than a day. Nothing real is, and the store's reads assume it
  /// (`DbEpgRepository`'s look-back is 24 hours).
  static const tooLong = 'too_long';

  /// No `<title>`, or one with no text.
  static const noTitle = 'no_title';

  /// The same channel and start as the programme before it on that
  /// channel. The first one wins.
  static const duplicateProgramme = 'duplicate_programme';

  /// Starts before the programme already read for its channel. A guide
  /// lists a channel in time order, so going back is a second schedule for
  /// the same id — panels that give an HD and an SD stream one id, guides
  /// joined end to end — and keeping both would put two programmes on at
  /// once. The first schedule read wins.
  static const outOfOrder = 'out_of_order';

  /// An element the parser could not read: a runaway tag, a broken
  /// attribute list.
  static const malformed = 'malformed';
}

/// A channel the guide declares: `<channel id>`, its first
/// `<display-name>` and its `<icon src>`.
@immutable
final class XmltvChannel {
  const new({required this.id, this.displayName, this.iconUrl});

  /// The XMLTV id, exactly as the file writes it (trimmed).
  final String id;

  /// Cleaned like every provider text (`cleanText`); null when empty.
  final String? displayName;

  /// Only a URL worth requesting (`cleanImageUrl`); null otherwise.
  final String? iconUrl;

  @override
  bool operator ==(Object other) =>
      other is XmltvChannel &&
      other.id == id &&
      other.displayName == displayName &&
      other.iconUrl == iconUrl;

  @override
  int get hashCode => Object.hash(id, displayName, iconUrl);

  @override
  String toString() => 'XmltvChannel($id, $displayName)';
}

/// One programme, with its times resolved: epoch milliseconds UTC, the
/// source's offset already applied.
@immutable
final class XmltvProgramme {
  const new({
    required this.channelId,
    required this.startMs,
    required this.endMs,
    required this.title,
    this.subtitle,
    this.description,
    this.category,
  });

  /// The XMLTV channel id the programme names (trimmed). It need not be
  /// one the file declared.
  final String channelId;
  final int startMs;
  final int endMs;

  /// The first `<title>`, cleaned. Never empty.
  final String title;

  /// The first `<sub-title>`, `<desc>` and `<category>`, cleaned; null
  /// when missing or empty.
  final String? subtitle;
  final String? description;
  final String? category;

  @override
  bool operator ==(Object other) =>
      other is XmltvProgramme &&
      other.channelId == channelId &&
      other.startMs == startMs &&
      other.endMs == endMs &&
      other.title == title &&
      other.subtitle == subtitle &&
      other.description == description &&
      other.category == category;

  @override
  int get hashCode => Object.hash(
    channelId,
    startMs,
    endMs,
    title,
    subtitle,
    description,
    category,
  );

  @override
  String toString() => 'XmltvProgramme($channelId, $startMs–$endMs, $title)';
}

/// The retention window (docs/02, ADR-011 decision 4): a programme is kept
/// when it overlaps `[startMs, endMs)`, and never exists otherwise.
@immutable
final class XmltvWindow {
  const new({required this.startMs, required this.endMs});

  /// `now − behind` to `now + ahead`: a day back and seven ahead unless
  /// the user's setting says otherwise.
  factory around(
    DateTime now, {
    Duration behind = const Duration(days: 1),
    Duration ahead = const Duration(days: 7),
  }) {
    final ms = now.millisecondsSinceEpoch;
    return XmltvWindow(
      startMs: ms - behind.inMilliseconds,
      endMs: ms + ahead.inMilliseconds,
    );
  }

  final int startMs;
  final int endMs;

  bool overlaps(int startMs, int endMs) =>
      endMs > this.startMs && startMs < this.endMs;
}

/// What one parse read, and what it left out.
@immutable
final class XmltvSummary {
  const new({
    required this.channels,
    required this.programmes,
    this.outsideWindow = 0,
    this.skipped = const {},
    this.truncated = false,
    this.declaredEncoding,
    this.unknownEncoding = false,
    this.samples = const [],
  });

  /// Channels handed to `onChannel`.
  final int channels;

  /// Programmes handed to `onProgramme`.
  final int programmes;

  /// Well-formed programmes left out because they fall outside the
  /// window. Not a fault, so not in [skipped].
  final int outsideWindow;

  /// Rows left out, by [XmltvSkip] code.
  final Map<String, int> skipped;

  /// The file ended mid-element or without `</tv>`. What was read before
  /// it is kept (hard rule 1).
  final bool truncated;

  /// The `encoding` the XML declaration names, as written; null when it
  /// names none.
  final String? declaredEncoding;

  /// [declaredEncoding] is not one the parser knows, so the file was read
  /// as UTF-8 (malformed bytes replaced, never thrown on).
  final bool unknownEncoding;

  /// A few examples per skip reason, for the import's log: the reason,
  /// the channel id and the offending value, shortened. Never a URL.
  final List<String> samples;

  int get skippedTotal => skipped.values.fold(0, (sum, n) => sum + n);
}

/// Parses an XMLTV guide from [bytes] — plain or gzip, detected by the
/// magic number rather than a name — handing each channel to [onChannel]
/// and each programme inside [window] to [onProgramme].
///
/// Times like `20260914180000 +0200` become epoch ms UTC, then
/// [offsetMinutes] (the source's EPG offset, positive = later) is added.
/// A time with no zone is UTC, as the XMLTV DTD says. A programme with no
/// usable `stop` ends where the next programme on its channel starts; one
/// that overlaps the next on its channel is cut at the next one's start;
/// one that starts before the programme already read for its channel is a
/// second schedule and is skipped ([XmltvSkip.outOfOrder]), so a channel
/// never has two programmes on at once.
///
/// Tolerant throughout (hard rule 1): bad rows are counted in
/// [XmltvSummary.skipped] by [XmltvSkip] code, never thrown; an unknown
/// declared encoding reads as UTF-8; a file that stops mid-element
/// returns what it read with [XmltvSummary.truncated] set. It is fed by
/// bytes, not lines, so a guide written on one line is fine.
///
/// When a callback returns a future, reading pauses until it completes,
/// so a caller writing rows in batches holds one batch, not the guide. An
/// error from that future ends the parse with the same error.
///
/// Throws [FormatException] only when the body is plainly not XMLTV — an
/// empty body, an HTML or JSON error page, a root element that is not
/// `<tv>` — and passes on whatever error [bytes] ends with.
Future<XmltvSummary> parseXmltv(
  Stream<List<int>> bytes, {
  required FutureOr<void> Function(XmltvChannel channel) onChannel,
  required FutureOr<void> Function(XmltvProgramme programme) onProgramme,
  XmltvWindow? window,
  int offsetMinutes = 0,
}) async {
  final guide = _Guide(
    onChannel: onChannel,
    onProgramme: onProgramme,
    window: window,
    offsetMs: offsetMinutes * Duration.millisecondsPerMinute,
  );
  final scanner = guide.scanner;
  // `await for` pauses the body while a callback's future is awaited. Its
  // cost is per chunk (tens of kilobytes), not per row, so it is noise.
  await for (final chunk in gunzipIfNeeded(bytes)) {
    scanner.add(chunk);
    final wait = scanner.run();
    if (wait != null) await _drain(scanner, wait);
  }
  scanner.close();
  final wait = scanner.run();
  if (wait != null) await _drain(scanner, wait);
  if (!scanner.sawRoot) {
    throw FormatException(
      scanner.sawBytes
          ? 'not an XMLTV guide: no <tv> element'
          : 'not an XMLTV guide: the body is empty',
    );
  }
  return await guide.finish();
}

/// Waits for [wait], then reads on, as long as callbacks keep returning
/// futures.
Future<void> _drain(XmltvScanner scanner, Future<void> wait) async {
  for (Future<void>? next = wait; next != null; next = scanner.run()) {
    await next;
  }
}

/// A day: nothing real is longer (`XmltvSkip.tooLong`).
const int _dayMs = Duration.millisecondsPerDay;

/// Samples kept per skip reason.
const _samplesPerReason = 3;

/// A sample's value is cut to this many characters.
const _sampleLength = 40;

/// The most characters a text field keeps; the rest is discarded. A
/// display name gets a title's cap.
const _shortTextChars = 512;
const _descriptionChars = 4096;

/// Elements open inside a skipped one that are matched by name; deeper
/// ones are only counted, so memory stays bounded however deep the junk.
const _maxSkippedDepth = 256;

final List<int> _idName = 'id'.codeUnits;
final List<int> _srcName = 'src'.codeUnits;
final List<int> _startName = 'start'.codeUnits;
final List<int> _stopName = 'stop'.codeUnits;
final List<int> _channelName = 'channel'.codeUnits;

/// A programme that passed the rules read at its close, waiting for the
/// next one on its channel to settle where it ends.
final class _Pending {
  const new({
    required this.channelId,
    required this.startMs,
    required this.stopMs,
    required this.start,
    required this.stop,
    required this.title,
    required this.subtitle,
    required this.description,
    required this.category,
  });

  final String channelId;
  final int startMs;

  /// Its own `stop`; null when it had none that is a time.
  final int? stopMs;

  /// The `start` and `stop` as written, for the import's samples.
  final String start;
  final String? stop;

  final String? title;
  final String? subtitle;
  final String? description;
  final String? category;
}

/// The guide as the scanner reads it: where it is in the document, the
/// row being read, each channel's pending programme, and the counts.
final class _Guide implements XmltvSink {
  new({
    required this.onChannel,
    required this.onProgramme,
    required this.window,
    required this._offsetMs,
  });

  final FutureOr<void> Function(XmltvChannel channel) onChannel;
  final FutureOr<void> Function(XmltvProgramme programme) onProgramme;
  final XmltvWindow? window;
  final int _offsetMs;

  late final scanner = XmltvScanner(this);

  // Where the scanner is. Only `<channel>` and `<programme>` rows and
  // their text fields are read; everything else is skipped, with what is
  // inside it.
  var _inTv = false;
  int _row = XmltvName.other;
  int _field = XmltvName.other;
  final _skipped = Uint32List(_maxSkippedDepth);
  var _skippedDepth = 0;

  // The row being read.
  String? _id;
  String? _skip;
  var _collect = false;
  var _startMs = 0;
  int? _stopMs;
  String? _start;
  String? _stop;
  String? _title;
  String? _subtitle;
  String? _description;
  String? _category;
  String? _iconUrl;
  final _text = XmltvTextBuffer();

  final _pending = <String, _Pending>{};
  final _channelIds = <String>{};

  var _channels = 0;
  var _programmes = 0;
  var _outsideWindow = 0;
  final _counts = <String, int>{};
  final _sampleCounts = <String, int>{};
  final _samples = <String>[];

  Future<void>? _wait;

  @override
  bool get wantsText => _field != XmltvName.other && _skippedDepth == 0;

  @override
  void text(Uint8List bytes, int start, int end) =>
      _text.add(bytes, start, end);

  @override
  void cdata(Uint8List bytes, int start, int end) =>
      _text.addCdata(bytes, start, end);

  @override
  Future<void>? takeWait() {
    final wait = _wait;
    _wait = null;
    return wait;
  }

  @override
  void startTag(XmltvTag tag) {
    final name = tag.name;
    if (!_inTv) {
      // Before the root the scanner lets nothing but `<tv>` through;
      // after `</tv>`, only another `<tv>` (guides joined end to end) is
      // read.
      if (name == XmltvName.tv && !tag.selfClosing) _inTv = true;
      return;
    }
    if (name == XmltvName.channel || name == XmltvName.programme) {
      // Rows never nest: a new one finishes the open one, closed or not.
      _closeRow();
      _openRow(tag);
      return;
    }
    if (name == XmltvName.tv) return; // a `<tv>` inside the root: nothing
    if (_skippedDepth > 0 || _row == XmltvName.other) {
      _skipElement(tag);
    } else if (_isField(name)) {
      // Fields never nest either: a missing `</title>` ends at the next.
      _closeField();
      _openField(tag);
    } else if (name == XmltvName.icon &&
        _row == XmltvName.channel &&
        _field == XmltvName.other) {
      _readIcon(tag);
      _skipElement(tag);
    } else {
      _skipElement(tag);
    }
  }

  @override
  void endTag(XmltvTag tag) => _endElement(tag);

  void _endElement(XmltvTag tag) {
    final name = tag.name;
    if (name == XmltvName.tv) {
      if (_inTv) {
        _closeRow();
        _inTv = false;
      }
      return;
    }
    if (!_inTv) return;
    if (name != XmltvName.other && name == _row) {
      _closeRow();
      return;
    }
    if (_skippedDepth > 0 && _unwind(tag.hash)) return;
    if (name != XmltvName.other && name == _field) {
      _skippedDepth = 0; // elements left open inside the field end with it
      _closeField();
    }
    // Anything else closes nothing that is open: a stray end tag.
  }

  @override
  void malformedTag(XmltvTag tag, String preview) {
    final name = tag.name;
    // Junk after `</tv>` is not read, so not counted either.
    if (!_inTv && name != XmltvName.tv) return;
    final row = name == XmltvName.channel || name == XmltvName.programme;
    _count(
      XmltvSkip.malformed,
      row || _row == XmltvName.other ? null : _id,
      preview,
    );
    if (tag.isEnd) {
      if (name != XmltvName.other && name == _row) {
        _dropRow(); // the element it belongs to is skipped
      } else {
        _endElement(tag);
      }
      return;
    }
    // A start tag: its element is skipped, with what is inside it.
    if (name == XmltvName.tv) {
      if (!_inTv && !tag.selfClosing) _inTv = true;
      return;
    }
    if (row) _closeRow();
    _skipElement(tag);
  }

  bool _isField(int name) => _row == XmltvName.channel
      ? name == XmltvName.displayName
      : name == XmltvName.title ||
            name == XmltvName.subTitle ||
            name == XmltvName.desc ||
            name == XmltvName.category;

  /// Skips [tag]'s element and everything inside it, to its end tag.
  void _skipElement(XmltvTag tag) {
    if (tag.selfClosing) return;
    if (_skippedDepth < _maxSkippedDepth) _skipped[_skippedDepth] = tag.hash;
    _skippedDepth++;
  }

  /// Closes the skipped element named by [hash] and any left open inside
  /// it. False when no skipped element has that name.
  bool _unwind(int hash) {
    if (_skippedDepth > _maxSkippedDepth) {
      _skippedDepth--;
      return true;
    }
    for (var i = _skippedDepth - 1; i >= 0; i--) {
      if (_skipped[i] == hash) {
        _skippedDepth = i;
        return true;
      }
    }
    return false;
  }

  void _openField(XmltvTag tag) {
    final name = tag.name;
    if (tag.selfClosing) return;
    // The first non-empty one wins: a second is skipped unread.
    if (!_collect || _fieldValue(name) != null) {
      _skipElement(tag);
      return;
    }
    _field = name;
    _text.reset(name == XmltvName.desc ? _descriptionChars : _shortTextChars);
  }

  String? _fieldValue(int name) => switch (name) {
    XmltvName.title || XmltvName.displayName => _title,
    XmltvName.subTitle => _subtitle,
    XmltvName.desc => _description,
    _ => _category,
  };

  void _closeField() {
    final name = _field;
    if (name == XmltvName.other) return;
    _field = XmltvName.other;
    final value = _text.finish(scanner.encoding);
    if (value == null) return;
    switch (name) {
      case XmltvName.title || XmltvName.displayName:
        _title ??= value;
      case XmltvName.subTitle:
        _subtitle ??= value;
      case XmltvName.desc:
        _description ??= value;
      case XmltvName.category:
        _category ??= value;
    }
  }

  void _readIcon(XmltvTag tag) {
    if (_iconUrl != null) return;
    while (tag.moveNextAttribute()) {
      if (tag.attributeIs(_srcName)) {
        _iconUrl = cleanImageUrl(tag.attributeValue());
        return;
      }
    }
  }

  void _openRow(XmltvTag tag) {
    _row = tag.name;
    _field = XmltvName.other;
    _skippedDepth = 0;
    _title = _subtitle = _description = _category = _iconUrl = null;
    _id = _skip = _start = _stop = null;
    _stopMs = null;
    if (_row == XmltvName.channel) {
      while (tag.moveNextAttribute()) {
        if (tag.attributeIs(_idName)) {
          _id = _blank(tag.attributeValue());
          break;
        }
      }
      _collect = true; // a skipped channel's name still goes in its sample
    } else {
      _readProgramme(tag);
    }
    if (tag.selfClosing) _closeRow();
  }

  /// Rules 1–3 are all in the start tag, so they are settled here (and
  /// counted when the element closes). So is whether the text is worth
  /// decoding: a programme its own times already rule out never needs it.
  void _readProgramme(XmltvTag tag) {
    String? channel;
    String? start;
    String? stop;
    while (tag.moveNextAttribute()) {
      if (start == null && tag.attributeIs(_startName)) {
        start = tag.attributeValue();
      } else if (stop == null && tag.attributeIs(_stopName)) {
        stop = tag.attributeValue();
      } else if (channel == null && tag.attributeIs(_channelName)) {
        channel = tag.attributeValue();
      }
    }
    _start = start;
    _stop = stop;
    _collect = false;
    final id = _id = _blank(channel);
    if (id == null) {
      _skip = XmltvSkip.noChannel;
      return;
    }
    final begin = parseXmltvTime(start ?? '');
    if (begin.skip != null) {
      _skip = begin.skip;
      return;
    }
    final startMs = _startMs = begin.ms + _offsetMs;
    final pending = _pending[id]?.startMs;
    if (pending != null && startMs <= pending) {
      _skip = startMs == pending
          ? XmltvSkip.duplicateProgramme
          : XmltvSkip.outOfOrder;
      return;
    }
    if (stop != null) {
      final end = parseXmltvTime(stop);
      if (end.skip == null) _stopMs = end.ms + _offsetMs;
    }
    // The next programme can only move the end earlier, so one that ends
    // at or before its start stays `bad_duration`, and one outside the
    // window stays outside it (or `too_long`): neither reaches `no_title`.
    final stopMs = _stopMs;
    _collect =
        stopMs == null ||
        (stopMs > startMs && (window?.overlaps(startMs, stopMs) ?? true));
  }

  /// Finishes the open row as if it had closed.
  void _closeRow() {
    final row = _row;
    if (row == XmltvName.other) return;
    _closeField();
    _row = XmltvName.other;
    _skippedDepth = 0;
    if (row == XmltvName.channel) {
      _finishChannel();
    } else {
      _finishProgramme();
    }
  }

  /// Forgets the open row, uncounted: the body ended inside it, or its
  /// end tag was malformed (counted as that).
  void _dropRow() {
    _row = _field = XmltvName.other;
    _skippedDepth = 0;
  }

  void _finishChannel() {
    final id = _id;
    if (id == null) {
      _count(XmltvSkip.noId, null, _title);
    } else if (!_channelIds.add(id)) {
      _count(XmltvSkip.duplicateChannel, id, _title);
    } else {
      _channels++;
      _emit(
        onChannel(XmltvChannel(id: id, displayName: _title, iconUrl: _iconUrl)),
      );
    }
  }

  void _finishProgramme() {
    final skip = _skip;
    if (skip != null) {
      _count(skip, _id, _start);
      return;
    }
    final channelId = _id!;
    final programme = _Pending(
      channelId: channelId,
      startMs: _startMs,
      stopMs: _stopMs,
      start: _start!,
      stop: _stop,
      title: _title,
      subtitle: _subtitle,
      description: _description,
      category: _category,
    );
    final previous = _pending[channelId];
    _pending[channelId] = programme;
    if (previous == null) return;
    // It starts after the one before it (anything else was skipped as it
    // was read): that is where one with no stop ends, and where one
    // running past it is cut.
    final stop = previous.stopMs;
    _finalize(
      previous,
      stop == null || stop > programme.startMs ? programme.startMs : stop,
    );
  }

  /// Rules 4–9, in order, for a programme whose end is now known.
  void _finalize(_Pending programme, int? endMs) {
    final start = programme.startMs;
    final channelId = programme.channelId;
    if (endMs == null) {
      _count(XmltvSkip.noStop, channelId, programme.start);
    } else if (endMs <= start) {
      _count(
        XmltvSkip.badDuration,
        channelId,
        programme.stop ?? programme.start,
      );
    } else if (endMs - start > _dayMs) {
      _count(XmltvSkip.tooLong, channelId, programme.stop ?? programme.start);
    } else if (window != null && !window!.overlaps(start, endMs)) {
      _outsideWindow++;
    } else if (programme.title == null) {
      _count(XmltvSkip.noTitle, channelId, programme.start);
    } else {
      _programmes++;
      _emit(
        onProgramme(
          XmltvProgramme(
            channelId: channelId,
            startMs: start,
            endMs: endMs,
            title: programme.title!,
            subtitle: programme.subtitle,
            description: programme.description,
            category: programme.category,
          ),
        ),
      );
    }
  }

  void _emit(FutureOr<void> result) {
    if (result is! Future<void>) return;
    final waiting = _wait;
    // One callback per token is the most there is; two are awaited
    // together rather than one lost.
    _wait = waiting == null ? result : Future.wait([waiting, result]);
  }

  void _count(String reason, String? channelId, String? value) {
    _counts[reason] = (_counts[reason] ?? 0) + 1;
    final shown = _sampleCounts[reason] ?? 0;
    if (shown >= _samplesPerReason) return;
    _sampleCounts[reason] = shown + 1;
    _samples.add(
      '$reason: ${_sample(channelId) ?? '-'}: ${_sample(value) ?? ''}',
    );
  }

  /// The body has ended. The row it ended inside is dropped; every
  /// pending programme is finalized, with its own stop or none.
  Future<XmltvSummary> finish() async {
    final truncated = _inTv;
    _dropRow();
    for (final programme in _pending.values) {
      _finalize(programme, programme.stopMs);
      final wait = takeWait();
      if (wait != null) await wait;
    }
    _pending.clear();
    return XmltvSummary(
      channels: _channels,
      programmes: _programmes,
      outsideWindow: _outsideWindow,
      skipped: Map.unmodifiable(_counts),
      truncated: truncated,
      declaredEncoding: scanner.declaredEncoding,
      unknownEncoding: scanner.unknownEncoding,
      samples: List.unmodifiable(_samples),
    );
  }

  static String? _blank(String? value) {
    final trimmed = value?.trim();
    return trimmed == null || trimmed.isEmpty ? null : trimmed;
  }

  /// A value for a sample: shortened, and never a URL (which could carry
  /// credentials, hard rule 3).
  static String? _sample(String? value) {
    if (value == null || value.isEmpty) return null;
    if (value.contains('://')) return '<url>';
    if (value.length <= _sampleLength) return value;
    var cut = _sampleLength;
    final last = value.codeUnitAt(cut - 1);
    if (last >= 0xd800 && last <= 0xdbff) cut--;
    return value.substring(0, cut);
  }
}
