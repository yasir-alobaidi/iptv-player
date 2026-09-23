/// The XMLTV parser's tokenizer: raw bytes in, tags and text slices out.
/// Internal to the XMLTV parser (`parseXmltv` is the API).
///
/// It scans bytes, not characters. Every encoding a guide is read in
/// writes markup as the same ASCII bytes, so tags are found without
/// decoding anything, and only the slices the guide keeps — a few
/// attribute values, the text of a handful of elements — are ever turned
/// into strings. A token cut by a chunk boundary is carried into the next
/// chunk; nothing else is held.
library;

import 'dart:async';
import 'dart:math' as math;
import 'dart:typed_data';

import 'package:iptv_player/data/providers/xmltv/xmltv_text.dart';

/// The elements the guide reads, as small ints, so a tag is recognized
/// from its bytes without making a string of its name.
abstract final class XmltvName {
  static const other = 0;

  /// The root. The only name compared without regard to case: a `<TV>`
  /// root is still a guide.
  static const tv = 1;
  static const channel = 2;
  static const programme = 3;
  static const displayName = 4;
  static const icon = 5;
  static const title = 6;
  static const subTitle = 7;
  static const desc = 8;
  static const category = 9;
}

/// What the scanner hands on: the parser's side of it.
abstract interface class XmltvSink {
  void startTag(XmltvTag tag);

  void endTag(XmltvTag tag);

  /// A tag the scanner could not read: longer than [maxTagLength] with no
  /// `>`, or cut off by a `<` before its end (a missing `>` or quote).
  /// [preview] is how it starts, for the import's samples.
  void malformedTag(XmltvTag tag, String preview);

  /// Whether text is wanted where the scanner is now: inside an element
  /// the guide keeps the text of. Text nobody wants is never copied.
  bool get wantsText;

  void text(Uint8List bytes, int start, int end);

  /// A CDATA section's content: text, verbatim.
  void cdata(Uint8List bytes, int start, int end);

  /// A future a callback returned, once; the scanner stops until it
  /// completes.
  Future<void>? takeWait();
}

/// A tag longer than this with no `>` is junk (a runaway attribute, a
/// binary body), not markup: the cap keeps what a chunk boundary carries
/// bounded whatever the input.
const int maxTagLength = 64 * 1024;

/// The tag the scanner is on, reused for every tag (a guide has millions
/// of them). Valid only during the [XmltvSink] call it is passed to.
final class XmltvTag {
  Uint8List _bytes = Uint8List(0);
  var _nameStart = 0;
  var _nameEnd = 0;
  var _end = 0;
  var _hash = -1;
  XmltvEncoding _encoding = XmltvEncoding.utf8;

  var _cursor = 0;
  var _attributeStart = 0;
  var _attributeEnd = 0;
  var _valueStart = 0;
  var _valueEnd = 0;

  /// The element's [XmltvName].
  int name = XmltvName.other;

  /// `</name>`.
  bool isEnd = false;

  /// `<name … />`.
  bool selfClosing = false;

  /// Points the tag at `bytes[nameStart, nameEnd)` for its name and
  /// `bytes[nameEnd, end)` for its attributes.
  void _set(
    Uint8List bytes,
    int nameStart,
    int nameEnd,
    int end, {
    required bool isEnd,
    required bool selfClosing,
    required XmltvEncoding encoding,
  }) {
    _bytes = bytes;
    _nameStart = nameStart;
    _nameEnd = nameEnd;
    _end = end;
    _hash = -1;
    _encoding = encoding;
    _cursor = nameEnd;
    name = _nameCode(bytes, nameStart, nameEnd);
    this.isEnd = isEnd;
    this.selfClosing = selfClosing;
  }

  /// A tag whose bytes are gone (a runaway one, reported once skipped):
  /// its name and hash only, no attributes.
  void _setDetached(
    int name,
    int hash, {
    required bool isEnd,
    required bool selfClosing,
  }) {
    _bytes = Uint8List(0);
    _nameStart = _nameEnd = _end = _cursor = 0;
    _hash = hash;
    this.name = name;
    this.isEnd = isEnd;
    this.selfClosing = selfClosing;
  }

  /// The name's FNV-1a hash: how the parser matches the end tag of an
  /// element it skips without keeping its name as a string.
  int get hash => _hash >= 0 ? _hash : _hash = _nameHash();

  int _nameHash() {
    var hash = 0x811c9dc5;
    for (var i = _nameStart; i < _nameEnd; i++) {
      hash = ((hash ^ _bytes[i]) * 0x01000193) & 0xffffffff;
    }
    return hash;
  }

  /// Moves to the next attribute that has a value: `name="v"`, `name='v'`
  /// or `name=v` (up to whitespace; a trailing `/` of `/>` is not part of
  /// it). One with no value is passed over. False after the last.
  bool moveNextAttribute() {
    final bytes = _bytes;
    final end = _end;
    var i = _cursor;
    while (true) {
      while (i < end && _isSpace(bytes[i])) {
        i++;
      }
      if (i >= end) {
        _cursor = end;
        return false;
      }
      final nameStart = i;
      while (i < end && !_isSpace(bytes[i]) && bytes[i] != _equals) {
        i++;
      }
      final nameEnd = i;
      while (i < end && _isSpace(bytes[i])) {
        i++;
      }
      if (i >= end || bytes[i] != _equals) continue; // no value: passed over
      i++;
      while (i < end && _isSpace(bytes[i])) {
        i++;
      }
      if (i < end && (bytes[i] == _doubleQuote || bytes[i] == _singleQuote)) {
        final quote = bytes[i];
        _valueStart = ++i;
        while (i < end && bytes[i] != quote) {
          i++;
        }
        _valueEnd = i;
        if (i < end) i++;
      } else {
        _valueStart = i;
        while (i < end && !_isSpace(bytes[i])) {
          i++;
        }
        _valueEnd = i;
      }
      if (nameEnd > nameStart) {
        _attributeStart = nameStart;
        _attributeEnd = nameEnd;
        _cursor = i;
        return true;
      }
    }
  }

  /// Whether the current attribute is [name] (ASCII, case-sensitive).
  bool attributeIs(List<int> name) =>
      _matches(_bytes, _attributeStart, _attributeEnd, name);

  /// The current attribute's value, decoded and entity-decoded.
  String attributeValue() =>
      decodeEntities(_encoding.decode(_bytes, _valueStart, _valueEnd));
}

/// Scans a guide's bytes and hands tags and text to an [XmltvSink].
///
/// Fed with [add], driven with [run] — which stops early when a callback
/// wants to be waited for — and ended with [close].
final class XmltvScanner {
  new(this._sink);

  final XmltvSink _sink;
  final _tag = XmltvTag();

  var _buffer = Uint8List(0);
  var _pos = 0;
  var _end = 0;

  /// Where a token cut by a chunk boundary is carried; owned, reused.
  Uint8List? _carry;

  int _mode = _start;
  var _closing = false;
  var _sawBytes = false;

  /// The encoding text is decoded with: UTF-8 until the XML declaration
  /// names another.
  XmltvEncoding encoding = XmltvEncoding.utf8;

  /// The declaration's `encoding`, as written.
  String? declaredEncoding;

  /// [declaredEncoding] names an encoding the parser does not know.
  bool unknownEncoding = false;

  var _declared = false;
  var _rootSeen = false;

  /// A character other than whitespace came before the root.
  var _content = false;

  // A tag being scanned: how far, and whether inside a quoted value.
  var _tagIsEnd = false;
  var _scanned = 0;
  var _quote = 0;
  var _afterEquals = false;

  // A runaway tag being skipped.
  int _runawayName = XmltvName.other;
  var _runawayHash = 0;
  var _runawayPreview = '';
  var _previous = 0;

  // A comment or processing instruction being skipped: `-->` or `?>`.
  int _skipMark = _dash;
  var _skipMarks = 2;

  // A DOCTYPE being skipped, internal subset and all.
  var _dtdQuote = 0;
  var _dtdDepth = 0;
  var _dtdComment = false;
  var _dtdMatch = 0;
  var _dtdDashes = 0;

  /// Whether the body had a root element at all.
  bool get sawRoot => _rootSeen;

  /// Whether the body had any bytes.
  bool get sawBytes => _sawBytes;

  /// Adds [chunk] after what is left of the last one: a token cut short,
  /// never more than [maxTagLength] and a few bytes.
  void add(List<int> chunk) {
    if (chunk.isEmpty) return;
    _sawBytes = true;
    final bytes = chunk is Uint8List ? chunk : Uint8List.fromList(chunk);
    final left = _end - _pos;
    if (left == 0) {
      _buffer = bytes;
      _pos = 0;
      _end = bytes.length;
      return;
    }
    final needed = left + bytes.length;
    var carry = _carry;
    if (carry == null || carry.length < needed) {
      carry = Uint8List(math.max(needed, (carry?.length ?? 0) * 2));
      carry.setRange(0, left, _buffer, _pos);
      _carry = carry;
    } else if (!identical(carry, _buffer) || _pos > 0) {
      carry.setRange(0, left, _buffer, _pos);
    }
    carry.setRange(left, needed, bytes);
    _buffer = carry;
    _pos = 0;
    _end = needed;
  }

  /// The body has ended: whatever is still held is a token it cut short,
  /// and is dropped. [run] once more afterwards.
  void close() => _closing = true;

  /// Reads tokens until the bytes run out, or until a callback returns a
  /// future: then that future, and [run] again once it completes.
  Future<void>? run() {
    while (true) {
      final progressed = switch (_mode) {
        _text => _stepText(),
        _markup => _stepMarkup(),
        _tagMode => _stepTag(),
        _runaway => _stepRunaway(),
        _pi => _stepPi(),
        _skip => _stepSkip(),
        _cdata => _stepCdata(),
        _doctype => _stepDoctype(),
        _ => _stepStart(),
      };
      final wait = _sink.takeWait();
      if (wait != null) return wait;
      if (!progressed) return null;
    }
  }

  /// A byte-order mark: UTF-8's is skipped, UTF-16's refused (the scanner
  /// reads ASCII-compatible bytes only).
  bool _stepStart() {
    final available = _end - _pos;
    if (available < 3 && !_closing) return false;
    if (available >= 2) {
      final first = _buffer[_pos];
      final second = _buffer[_pos + 1];
      if ((first == 0xff && second == 0xfe) ||
          (first == 0xfe && second == 0xff)) {
        throw const FormatException('UTF-16 guides are not supported');
      }
      if (available >= 3 &&
          first == 0xef &&
          second == 0xbb &&
          _buffer[_pos + 2] == 0xbf) {
        _pos += 3;
      }
    }
    _mode = _text;
    return true;
  }

  bool _stepText() {
    final bytes = _buffer;
    final end = _end;
    final start = _pos;
    var i = start;
    while (i < end && bytes[i] != _lt) {
      i++;
    }
    if (!_content && !_rootSeen) _prolog(start, i);
    if (i > start && _sink.wantsText) _sink.text(bytes, start, i);
    _pos = i;
    if (i == end) return false;
    _mode = _markup;
    return true;
  }

  /// Text before anything else: a JSON error page, served in place of the
  /// guide, is refused at its first byte.
  void _prolog(int start, int end) {
    for (var i = start; i < end; i++) {
      final byte = _buffer[i];
      if (_isSpace(byte)) continue;
      if (byte == _openBrace || byte == _openBracket) {
        throw const FormatException('not an XMLTV guide: a JSON body');
      }
      _content = true;
      return;
    }
  }

  /// At a `<`: which kind of markup it opens.
  bool _stepMarkup() {
    final bytes = _buffer;
    final available = _end - _pos;
    if (available < 2) return false;
    _content = true;
    final next = bytes[_pos + 1];
    if (next == _slash || _isNameStart(next)) {
      _mode = _tagMode;
      _tagIsEnd = next == _slash;
      _scanned = _tagIsEnd ? 2 : 1;
      _quote = 0;
      _afterEquals = false;
      return true;
    }
    if (next == _question) {
      _mode = _pi;
      _scanned = 2;
      return true;
    }
    if (next == _bang) {
      if (_startsWith(_commentOpen)) {
        _pos += _commentOpen.length;
        _skipMark = _dash;
        _skipMarks = 2;
        _mode = _skip;
        return true;
      }
      if (_startsWith(_cdataOpen)) {
        _pos += _cdataOpen.length;
        _mode = _cdata;
        return true;
      }
      // Not enough bytes yet to tell a comment or CDATA from a DOCTYPE.
      if (_couldStartWith(_commentOpen) || _couldStartWith(_cdataOpen)) {
        return false;
      }
      _pos += 2;
      _dtdQuote = _dtdDepth = _dtdMatch = _dtdDashes = 0;
      _dtdComment = false;
      _mode = _doctype;
      return true;
    }
    if (next == 0 && !_rootSeen) {
      throw const FormatException('UTF-16 guides are not supported');
    }
    // A `<` that opens nothing (`1 < 2`): text, as a lenient reader
    // takes it.
    if (_sink.wantsText) _sink.text(bytes, _pos, _pos + 1);
    _pos++;
    _mode = _text;
    return true;
  }

  /// A start or end tag, up to the `>` outside a quoted value. A `<`
  /// before it means the tag never ended; past [maxTagLength] it is a
  /// runaway. Resumes where the last chunk left it.
  bool _stepTag() {
    final bytes = _buffer;
    final start = _pos;
    final limit = math.min(_end, start + maxTagLength);
    var i = start + _scanned;
    var quote = _quote;
    var afterEquals = _afterEquals;
    while (i < limit) {
      final byte = bytes[i];
      if (quote != 0) {
        if (byte == quote) {
          quote = 0;
        } else if (byte == _lt) {
          _broken(i);
          return true;
        }
      } else if (byte == _gt) {
        _completeTag(i);
        return true;
      } else if (byte == _lt) {
        _broken(i);
        return true;
      } else if (byte == _equals) {
        afterEquals = true;
      } else if (byte == _doubleQuote || byte == _singleQuote) {
        if (afterEquals) quote = byte;
        afterEquals = false;
      } else if (!_isSpace(byte)) {
        afterEquals = false;
      }
      i++;
    }
    _quote = quote;
    _afterEquals = afterEquals;
    if (i - start >= maxTagLength) {
      _startRunaway(i);
      return true;
    }
    _scanned = i - start;
    return false;
  }

  void _completeTag(int gt) {
    final bytes = _buffer;
    final start = _pos;
    final nameStart = start + (_tagIsEnd ? 2 : 1);
    final nameEnd = _nameEnd(nameStart, gt);
    final selfClosing =
        !_tagIsEnd && gt - 1 >= nameEnd && bytes[gt - 1] == _slash;
    _tag._set(
      bytes,
      nameStart,
      nameEnd,
      selfClosing ? gt - 1 : gt,
      isEnd: _tagIsEnd,
      selfClosing: selfClosing,
      encoding: encoding,
    );
    _pos = gt + 1;
    _mode = _text;
    if (_tagIsEnd) {
      _sink.endTag(_tag);
    } else {
      _checkRoot(nameStart, nameEnd);
      _sink.startTag(_tag);
    }
  }

  /// A `<` inside a tag: the tag is malformed, and the `<` starts the
  /// next token.
  void _broken(int lt) {
    final start = _pos;
    final nameStart = start + (_tagIsEnd ? 2 : 1);
    final nameEnd = _nameEnd(nameStart, lt);
    if (!_tagIsEnd) _checkRoot(nameStart, nameEnd);
    final preview = _preview(start, lt);
    _tag._set(
      _buffer,
      nameStart,
      nameEnd,
      nameEnd,
      isEnd: _tagIsEnd,
      selfClosing: false,
      encoding: encoding,
    );
    _pos = lt;
    _mode = _markup;
    _sink.malformedTag(_tag, preview);
  }

  /// Over the length cap: the tag's bytes are let go, and the rest of it
  /// is skipped in [_stepRunaway].
  void _startRunaway(int at) {
    final start = _pos;
    final nameStart = start + (_tagIsEnd ? 2 : 1);
    final nameEnd = _nameEnd(nameStart, at);
    if (!_tagIsEnd) _checkRoot(nameStart, nameEnd);
    _tag._set(
      _buffer,
      nameStart,
      nameEnd,
      nameEnd,
      isEnd: _tagIsEnd,
      selfClosing: false,
      encoding: encoding,
    );
    _runawayName = _tag.name;
    _runawayHash = _tag.hash;
    _runawayPreview = _preview(start, at);
    _previous = _buffer[at - 1];
    _pos = at;
    _mode = _runaway;
  }

  /// The rest of a runaway tag, read as [_stepTag] reads, kept nowhere.
  bool _stepRunaway() {
    final bytes = _buffer;
    final end = _end;
    var i = _pos;
    var quote = _quote;
    var afterEquals = _afterEquals;
    var previous = _previous;
    while (i < end) {
      final byte = bytes[i];
      if (byte == _lt || (quote == 0 && byte == _gt)) {
        _tag._setDetached(
          _runawayName,
          _runawayHash,
          isEnd: _tagIsEnd,
          selfClosing: byte == _gt && !_tagIsEnd && previous == _slash,
        );
        _pos = byte == _gt ? i + 1 : i;
        _mode = byte == _gt ? _text : _markup;
        final preview = _runawayPreview;
        _runawayPreview = '';
        _sink.malformedTag(_tag, preview);
        return true;
      }
      if (quote != 0) {
        if (byte == quote) quote = 0;
      } else if (byte == _equals) {
        afterEquals = true;
      } else if (byte == _doubleQuote || byte == _singleQuote) {
        if (afterEquals) quote = byte;
        afterEquals = false;
      } else if (!_isSpace(byte)) {
        afterEquals = false;
      }
      previous = byte;
      i++;
    }
    _quote = quote;
    _afterEquals = afterEquals;
    _previous = previous;
    _pos = end;
    return false;
  }

  /// A processing instruction, up to `?>`. Only the XML declaration is
  /// read; one past the length cap is skipped like a comment.
  bool _stepPi() {
    final bytes = _buffer;
    final start = _pos;
    final limit = math.min(_end, start + maxTagLength);
    var i = start + _scanned;
    while (i < limit) {
      if (bytes[i] == _gt && i - 1 > start + 1 && bytes[i - 1] == _question) {
        _completePi(i);
        return true;
      }
      i++;
    }
    if (i - start >= maxTagLength) {
      _pos = i - 1;
      _skipMark = _question;
      _skipMarks = 1;
      _mode = _skip;
      return true;
    }
    _scanned = i - start;
    return false;
  }

  void _completePi(int gt) {
    final bytes = _buffer;
    final start = _pos;
    _pos = gt + 1;
    _mode = _text;
    if (_rootSeen || _declared) return;
    // `<?xml` and then a space or the closing `?`.
    final nameEnd = start + 5;
    if (nameEnd > gt - 1 ||
        !_matchesFolded(bytes, start + 2, nameEnd, _xml) ||
        (nameEnd < gt - 1 && !_isSpace(bytes[nameEnd]))) {
      return;
    }
    _declared = true;
    _tag._set(
      bytes,
      start + 2,
      nameEnd,
      gt - 1,
      isEnd: false,
      selfClosing: false,
      encoding: XmltvEncoding.latin1,
    );
    while (_tag.moveNextAttribute()) {
      if (!_tag.attributeIs(_encodingName)) continue;
      final value = _tag.attributeValue();
      if (value.trim().isEmpty) return;
      final known = XmltvEncoding.named(value);
      declaredEncoding = value;
      encoding = known ?? XmltvEncoding.utf8;
      unknownEncoding = known == null;
      return;
    }
  }

  /// A comment (`-->`) or a processing instruction too long to keep
  /// (`?>`), skipped. Only the bytes a terminator cut by the chunk
  /// boundary could start with are kept.
  bool _stepSkip() {
    final bytes = _buffer;
    final end = _end;
    final marks = _skipMarks;
    final mark = _skipMark;
    var i = _pos + marks;
    while (i < end) {
      if (bytes[i] == _gt &&
          bytes[i - 1] == mark &&
          (marks == 1 || bytes[i - 2] == mark)) {
        _pos = i + 1;
        _mode = _text;
        return true;
      }
      i++;
    }
    _pos = math.max(_pos, end - marks);
    return false;
  }

  /// A CDATA section: its content goes to the sink as it is read, all but
  /// the two bytes a `]]>` cut by the chunk boundary could start with.
  bool _stepCdata() {
    final bytes = _buffer;
    final end = _end;
    var i = _pos + 2;
    while (i < end) {
      if (bytes[i] == _gt &&
          bytes[i - 1] == _closeBracket &&
          bytes[i - 2] == _closeBracket) {
        if (_sink.wantsText) _sink.cdata(bytes, _pos, i - 2);
        _pos = i + 1;
        _mode = _text;
        return true;
      }
      i++;
    }
    final keep = math.max(_pos, end - 2);
    if (keep > _pos && _sink.wantsText) _sink.cdata(bytes, _pos, keep);
    _pos = keep;
    return false;
  }

  /// `<!DOCTYPE …>` (or any other `<!` declaration), skipped with its
  /// internal subset: a `>` counts only outside quotes, brackets and
  /// comments.
  bool _stepDoctype() {
    final bytes = _buffer;
    final end = _end;
    var quote = _dtdQuote;
    var depth = _dtdDepth;
    var comment = _dtdComment;
    var match = _dtdMatch;
    var dashes = _dtdDashes;
    for (var i = _pos; i < end; i++) {
      final byte = bytes[i];
      if (comment) {
        if (byte == _dash) {
          dashes++;
        } else {
          if (byte == _gt && dashes >= 2) comment = false;
          dashes = 0;
        }
        continue;
      }
      if (quote != 0) {
        if (byte == quote) quote = 0;
        continue;
      }
      if (byte == _commentOpen[match]) {
        if (++match == _commentOpen.length) {
          comment = true;
          match = dashes = 0;
          continue;
        }
      } else {
        match = byte == _lt ? 1 : 0;
      }
      if (byte == _doubleQuote || byte == _singleQuote) {
        quote = byte;
      } else if (byte == _openBracket) {
        depth++;
      } else if (byte == _closeBracket) {
        if (depth > 0) depth--;
      } else if (byte == _gt && depth == 0) {
        _pos = i + 1;
        _mode = _text;
        return true;
      }
    }
    _dtdQuote = quote;
    _dtdDepth = depth;
    _dtdComment = comment;
    _dtdMatch = match;
    _dtdDashes = dashes;
    _pos = end;
    return false;
  }

  /// The first element must be `<tv>`: anything else is an error page (an
  /// HTML one, an RSS feed), refused before the rest is read.
  void _checkRoot(int nameStart, int nameEnd) {
    if (_rootSeen) return;
    _rootSeen = true;
    if (_nameCode(_buffer, nameStart, nameEnd) == XmltvName.tv) return;
    final shown = math.min(nameEnd, nameStart + 20);
    final name = String.fromCharCodes(_buffer, nameStart, shown);
    throw FormatException('not an XMLTV guide: its root is <$name>');
  }

  /// Where a tag's name, from [start], ends: at whitespace, `/`, `>` or
  /// anything else no name has, and never past [limit].
  int _nameEnd(int start, int limit) {
    final bytes = _buffer;
    var i = start;
    while (i < limit) {
      final byte = bytes[i];
      if (_isSpace(byte) ||
          byte == _slash ||
          byte == _gt ||
          byte == _lt ||
          byte == _equals ||
          byte == _doubleQuote ||
          byte == _singleQuote) {
        break;
      }
      i++;
    }
    return i;
  }

  /// How a malformed tag starts, for the import's samples.
  String _preview(int start, int end) =>
      encoding.decode(_buffer, start, math.min(end, start + 60));

  bool _startsWith(List<int> pattern) =>
      _end - _pos >= pattern.length &&
      _matches(_buffer, _pos, _pos + pattern.length, pattern);

  bool _couldStartWith(List<int> pattern) {
    final available = _end - _pos;
    if (available >= pattern.length) return false;
    for (var i = 0; i < available; i++) {
      if (_buffer[_pos + i] != pattern[i]) return false;
    }
    return true;
  }
}

// Scanner modes.
const _start = 0;
const _text = 1;
const _markup = 2;
const _tagMode = 3;
const _runaway = 4;
const _pi = 5;
const _skip = 6;
const _cdata = 7;
const _doctype = 8;

// Markup bytes: ASCII in every encoding the guide is read in.
const _tab = 0x09;
const _newline = 0x0a;
const _return = 0x0d;
const _space = 0x20;
const _bang = 0x21;
const _doubleQuote = 0x22;
const _singleQuote = 0x27;
const _dash = 0x2d;
const _slash = 0x2f;
const _lt = 0x3c;
const _equals = 0x3d;
const _gt = 0x3e;
const _question = 0x3f;
const _openBracket = 0x5b;
const _closeBracket = 0x5d;
const _openBrace = 0x7b;

final List<int> _commentOpen = '<!--'.codeUnits;
final List<int> _cdataOpen = '<![CDATA['.codeUnits;
final List<int> _xml = 'xml'.codeUnits;
final List<int> _encodingName = 'encoding'.codeUnits;

final List<int> _channel = 'channel'.codeUnits;
final List<int> _programme = 'programme'.codeUnits;
final List<int> _displayName = 'display-name'.codeUnits;
final List<int> _icon = 'icon'.codeUnits;
final List<int> _title = 'title'.codeUnits;
final List<int> _subTitle = 'sub-title'.codeUnits;
final List<int> _desc = 'desc'.codeUnits;
final List<int> _category = 'category'.codeUnits;

bool _isSpace(int byte) =>
    byte == _space || byte == _newline || byte == _tab || byte == _return;

/// A letter, `_`, `:`, or any byte of a non-ASCII character: what a name
/// can start with.
bool _isNameStart(int byte) =>
    ((byte | 0x20) >= 0x61 && (byte | 0x20) <= 0x7a) ||
    byte == 0x5f ||
    byte == 0x3a ||
    byte >= 0x80;

bool _matches(Uint8List bytes, int start, int end, List<int> pattern) {
  if (end - start != pattern.length) return false;
  for (var i = 0; i < pattern.length; i++) {
    if (bytes[start + i] != pattern[i]) return false;
  }
  return true;
}

/// [_matches] for a lower-case ASCII [pattern], ignoring case.
bool _matchesFolded(Uint8List bytes, int start, int end, List<int> pattern) {
  if (end - start != pattern.length) return false;
  for (var i = 0; i < pattern.length; i++) {
    if ((bytes[start + i] | 0x20) != pattern[i]) return false;
  }
  return true;
}

int _nameCode(Uint8List bytes, int start, int end) {
  switch (end - start) {
    case 2:
      if ((bytes[start] | 0x20) == 0x74 && (bytes[start + 1] | 0x20) == 0x76) {
        return XmltvName.tv;
      }
    case 4:
      if (_matches(bytes, start, end, _desc)) return XmltvName.desc;
      if (_matches(bytes, start, end, _icon)) return XmltvName.icon;
    case 5:
      if (_matches(bytes, start, end, _title)) return XmltvName.title;
    case 7:
      if (_matches(bytes, start, end, _channel)) return XmltvName.channel;
    case 8:
      if (_matches(bytes, start, end, _category)) return XmltvName.category;
    case 9:
      if (_matches(bytes, start, end, _programme)) return XmltvName.programme;
      if (_matches(bytes, start, end, _subTitle)) return XmltvName.subTitle;
    case 12:
      if (_matches(bytes, start, end, _displayName)) {
        return XmltvName.displayName;
      }
  }
  return XmltvName.other;
}
