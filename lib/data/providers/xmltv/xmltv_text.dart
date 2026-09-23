/// Text in an XMLTV guide: the declared encodings the parser reads, the
/// entities in attribute values, and the capped buffer a text field is
/// read into. Internal to the XMLTV parser.
library;

import 'dart:convert';
import 'dart:typed_data';

import 'package:iptv_player/data/providers/provider_text.dart';

/// The encodings a guide is read in. Every one keeps markup (`<`, `>`,
/// `"`, `=`) as the same ASCII bytes, which is why the scanner can find
/// tags in raw bytes and decode only the slices it keeps.
enum XmltvEncoding {
  utf8,
  latin1,

  /// Latin-1 with 0x80–0x9F as Windows draws them (0x80 = €).
  windows1252,

  /// Latin-1 with ISO-8859-15's eight differences (0xA4 = €).
  iso885915;

  /// The encoding an XML declaration's `encoding` names, or null for one
  /// the parser does not know (the guide is then read as UTF-8).
  static XmltvEncoding? named(String name) =>
      switch (name.trim().toLowerCase()) {
        'utf-8' || 'utf8' || 'us-ascii' || 'ascii' => utf8,
        'iso-8859-1' || 'latin1' || 'latin-1' || 'l1' || 'iso_8859-1' => latin1,
        'windows-1252' || 'cp1252' => windows1252,
        'iso-8859-15' || 'latin-9' => iso885915,
        _ => null,
      };

  /// [end] − [start] bytes from [start] as text. Malformed UTF-8 becomes
  /// U+FFFD, which `cleanText` drops; bytes never throw.
  String decode(Uint8List bytes, int start, int end) {
    switch (this) {
      case utf8:
        return const Utf8Decoder(allowMalformed: true)
            .convert(bytes, start, end);
      case latin1:
        return String.fromCharCodes(bytes, start, end);
      case windows1252:
        return _mapped(bytes, start, end, 0x80, 0x9f, _windows1252);
      case iso885915:
        return _mapped(bytes, start, end, 0xa4, 0xbe, _iso885915);
    }
  }

  /// Latin-1, except the bytes from [low] to [high] that [table] (indexed
  /// from [low]) gives another code point. Most text never has one, so it
  /// is checked for before anything is copied.
  static String _mapped(
    Uint8List bytes,
    int start,
    int end,
    int low,
    int high,
    List<int> table,
  ) {
    var i = start;
    while (i < end) {
      final byte = bytes[i];
      if (byte >= low && byte <= high && table[byte - low] != byte) break;
      i++;
    }
    if (i == end) return String.fromCharCodes(bytes, start, end);
    final units = Uint16List(end - start);
    for (var j = start; j < end; j++) {
      final byte = bytes[j];
      units[j - start] = byte >= low && byte <= high ? table[byte - low] : byte;
    }
    return String.fromCharCodes(units);
  }
}

/// 0x80–0x9F in Windows-1252. The five bytes it leaves undefined map to
/// themselves, as the WHATWG encoding standard does.
const _windows1252 = <int>[
  0x20ac, 0x81, 0x201a, 0x0192, 0x201e, 0x2026, 0x2020, 0x2021, //
  0x02c6, 0x2030, 0x0160, 0x2039, 0x0152, 0x8d, 0x017d, 0x8f, //
  0x90, 0x2018, 0x2019, 0x201c, 0x201d, 0x2022, 0x2013, 0x2014, //
  0x02dc, 0x2122, 0x0161, 0x203a, 0x0153, 0x9d, 0x017e, 0x0178, //
];

/// 0xA4–0xBE in ISO-8859-15; the bytes between its eight changes are
/// Latin-1's.
const _iso885915 = <int>[
  0x20ac, 0xa5, 0x0160, 0xa7, 0x0161, 0xa9, 0xaa, 0xab, //
  0xac, 0xad, 0xae, 0xaf, 0xb0, 0xb1, 0xb2, 0xb3, //
  0x017d, 0xb5, 0xb6, 0xb7, 0x017e, 0xb9, 0xba, 0xbb, //
  0x0152, 0x0153, 0x0178, //
];

/// [value] with its entities decoded once: the XML five, decimal and hex
/// character references, and the names `cleanText` knows. An unknown
/// entity, or an `&` that starts none, stays as written. Attribute values
/// get only this (an id is not display text, and keeps its inner spaces);
/// text fields get `cleanText` after it.
String decodeEntities(String value) {
  var amp = value.indexOf('&');
  if (amp < 0) return value;
  final out = StringBuffer();
  var copied = 0;
  while (amp >= 0) {
    final semicolon = value.indexOf(';', amp + 1);
    if (semicolon < 0) break;
    final decoded = _entity(value.substring(amp + 1, semicolon));
    if (decoded != null) {
      out
        ..write(value.substring(copied, amp))
        ..write(decoded);
      copied = semicolon + 1;
      amp = value.indexOf('&', copied);
    } else {
      amp = value.indexOf('&', amp + 1);
    }
  }
  out.write(value.substring(copied));
  return out.toString();
}

String? _entity(String body) {
  if (body.isEmpty) return null;
  if (body.codeUnitAt(0) == 0x23) {
    final hex = body.length > 1 && (body[1] == 'x' || body[1] == 'X');
    final digits = hex ? body.substring(2) : body.substring(1);
    if (digits.isEmpty || !_allOf(digits, hex: hex)) return null;
    final code = int.tryParse(digits, radix: hex ? 16 : 10);
    // Out of range, a surrogate, or NUL: left as written, like cleanText.
    if (code == null ||
        code <= 0 ||
        code > 0x10ffff ||
        (code >= 0xd800 && code <= 0xdfff)) {
      return null;
    }
    return String.fromCharCode(code);
  }
  return switch (body.toLowerCase()) {
    'amp' => '&',
    'lt' => '<',
    'gt' => '>',
    'quot' => '"',
    'apos' => "'",
    'nbsp' => '\u00a0',
    _ => null,
  };
}

bool _allOf(String digits, {required bool hex}) {
  for (var i = 0; i < digits.length; i++) {
    final unit = digits.codeUnitAt(i) | 0x20; // a-f and A-F alike
    final decimal = unit >= 0x30 && unit <= 0x39;
    if (!decimal && !(hex && unit >= 0x61 && unit <= 0x66)) return false;
  }
  return true;
}

/// One text field's bytes as the scanner hands them over, kept up to its
/// cap: a number of characters of cleaned text ([reset]), read from at
/// most four bytes a character. The rest is discarded, so a 1 MB `<desc>`
/// costs 16 KiB, not a megabyte.
final class XmltvTextBuffer {
  final _bytes = Uint8List(_maxChars * 4);
  var _length = 0;
  var _limit = 0;
  var _chars = 0;
  var _cut = false;

  /// The largest cap a field has (`<desc>`).
  static const _maxChars = 4096;

  void reset(int maxChars) {
    assert(maxChars <= _maxChars, 'a cap over the buffer');
    _length = 0;
    _chars = maxChars;
    _limit = maxChars * 4;
    _cut = false;
  }

  void add(Uint8List bytes, int start, int end) {
    final room = _limit - _length;
    var last = end;
    if (last - start > room) {
      _cut = true;
      last = start + room;
    }
    if (last <= start) return;
    _bytes.setRange(_length, _length + last - start, bytes, start);
    _length += last - start;
  }

  /// A CDATA section's bytes: verbatim to XML, so each `&` goes in as
  /// `&amp;`, which the field's XML decoding turns back into the `&` it
  /// was. `cleanText` then cleans it like any other text.
  void addCdata(Uint8List bytes, int start, int end) {
    var run = start;
    for (var i = start; i < end; i++) {
      if (bytes[i] == 0x26) {
        add(bytes, run, i);
        add(_escapedAmp, 0, _escapedAmp.length);
        run = i + 1;
      }
    }
    add(bytes, run, end);
  }

  /// The field's text: decoded with [encoding], its XML entities decoded,
  /// cleaned (`cleanText`), and cut to its cap. Null when nothing is left.
  ///
  /// `cleanText` decodes entities again, on purpose (ADR-011): panels
  /// XML-escape names that already carry HTML entities (`&amp;amp;`,
  /// `&amp;#39;`), and the Xtream client shows the same names through
  /// `cleanText` once — so a channel reads the same from either, which the
  /// guide's name matching depends on.
  String? finish(XmltvEncoding encoding) {
    var end = _length;
    // Don't let the byte cap split a character into a U+FFFD.
    if (_cut && encoding == XmltvEncoding.utf8) end = _utf8Boundary(end);
    final text = cleanXmltvText(
      decodeEntities(encoding.decode(_bytes, 0, end)),
    );
    if (text == null || text.length <= _chars) return text;
    var cut = _chars;
    final last = text.codeUnitAt(cut - 1);
    if (last >= 0xd800 && last <= 0xdbff) cut--; // half a surrogate pair
    final kept = text.substring(0, cut).trimRight();
    return kept.isEmpty ? null : kept;
  }

  /// [end], moved back to the start of a UTF-8 sequence the buffer holds
  /// only part of.
  int _utf8Boundary(int end) {
    var lead = end - 1;
    while (lead >= 0 && lead > end - 4 && _bytes[lead] & 0xc0 == 0x80) {
      lead--;
    }
    if (lead < 0) return end;
    final byte = _bytes[lead];
    final size = byte < 0x80
        ? 1
        : byte >= 0xf0
        ? 4
        : byte >= 0xe0
        ? 3
        : byte >= 0xc0
        ? 2
        : 1;
    return lead + size > end ? lead : end;
  }
}

final _escapedAmp = Uint8List.fromList('&amp;'.codeUnits);

/// Exactly what `cleanText` returns for [text], without its three
/// regular-expression passes unless an entity needs decoding. They cost
/// ~10 µs a field, which at four fields a programme was most of the
/// parse; this is one pass, and a second only to collapse whitespace.
///
/// `cleanText` decodes entities, turns U+FFFD into a space, collapses
/// whitespace runs to one space and trims. With no `&` that could start
/// an entity (one followed by `#` or a letter), only the last three can
/// apply, and U+FFFD is simply one more whitespace character.
String? cleanXmltvText(String text) {
  final length = text.length;
  var collapse = false;
  var space = true; // before the first character: a leading space goes
  for (var i = 0; i < length; i++) {
    final unit = text.codeUnitAt(i);
    if (unit == 0x26 && i + 1 < length) {
      final next = text.codeUnitAt(i + 1);
      final letter = next | 0x20; // a-z and A-Z alike
      if (next == 0x23 || (letter >= 0x61 && letter <= 0x7a)) {
        return cleanText(text);
      }
    }
    if (_isSpace(unit)) {
      if (space || unit != 0x20) collapse = true;
      space = true;
    } else {
      space = false;
    }
  }
  if (space) collapse = true; // a trailing space, or nothing at all
  var cleaned = text;
  if (collapse) {
    final out = Uint16List(length);
    var kept = 0;
    var pending = false;
    for (var i = 0; i < length; i++) {
      final unit = text.codeUnitAt(i);
      if (_isSpace(unit)) {
        pending = kept > 0;
      } else {
        if (pending) out[kept++] = 0x20;
        pending = false;
        out[kept++] = unit;
      }
    }
    cleaned = String.fromCharCodes(out, 0, kept);
  }
  // `cleanText` ends with Dart's trim, whose whitespace (Unicode's) has a
  // character its collapsing does not (U+0085). Nothing to trim returns
  // the same string.
  final trimmed = cleaned.trim();
  return trimmed.isEmpty ? null : trimmed;
}

/// The whitespace `cleanText` collapses — its `[\s\u00a0\u2000-\u200b\u3000]`,
/// with `\s` as Dart's (ECMAScript's) — and U+FFFD, which it turns into a
/// space first.
bool _isSpace(int unit) =>
    unit == 0x20 ||
    (unit >= 0x09 && unit <= 0x0d) ||
    (unit >= 0x80 &&
        (unit == 0xa0 ||
            unit == 0x1680 ||
            (unit >= 0x2000 && unit <= 0x200b) ||
            unit == 0x2028 ||
            unit == 0x2029 ||
            unit == 0x202f ||
            unit == 0x205f ||
            unit == 0x3000 ||
            unit == 0xfeff ||
            unit == 0xfffd));
