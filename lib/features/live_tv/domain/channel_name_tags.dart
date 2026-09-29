/// The tag tables and scanners two readers of a provider's channel names
/// share: the guide's matcher (`normalizeChannelName`), which reduces a
/// name to a key, and the name the screens show (`cleanChannelName`).
/// One set of tables, so the two never disagree about what a tag is.
///
/// Not for screens: they show a channel item's name, which is already clean.
library;

/// Countries that go by two tags.
const _countryAliases = <String, String>{'gb': 'uk', 'usa': 'us'};

/// A country tag as both readers compare it: `gb` read as `uk`, `usa`
/// as `us`. [tag] is lower-cased.
String countryOfTag(String tag) => _countryAliases[tag] ?? tag;

// ------------------------------------------------------------- entities

final _entity = RegExp('&(#[0-9]+|#[xX][0-9a-fA-F]+|[a-zA-Z]+);');

const _namedEntities = <String, String>{
  'amp': '&',
  'lt': '<',
  'gt': '>',
  'quot': '"',
  'apos': "'",
  'nbsp': ' ',
};

/// `cleanText`'s decoding (lib/data is below the domain, so it is not
/// imported), repeated while it still changes something: a panel's
/// `&amp;amp;` has to read the same whether or not a parser already
/// decoded it once.
String decodeNameEntities(String text) {
  var decoded = text;
  for (var round = 0; round < 4; round++) {
    final next = decoded.replaceAllMapped(_entity, _entityText);
    if (next == decoded) break;
    decoded = next;
  }
  return decoded;
}

String _entityText(Match m) {
  final body = m[1]!;
  if (!body.startsWith('#')) return _namedEntities[body.toLowerCase()] ?? m[0]!;
  final hex = body.length > 1 && (body[1] == 'x' || body[1] == 'X');
  final code = int.tryParse(
    hex ? body.substring(2) : body.substring(1),
    radix: hex ? 16 : 10,
  );
  // Out of range, a surrogate, or NUL: left as it was, like cleanText.
  if (code == null ||
      code <= 0 ||
      code > 0x10ffff ||
      (code >= 0xd800 && code <= 0xdfff)) {
    return m[0]!;
  }
  return String.fromCharCode(code);
}

// ---------------------------------------------------------------- folding

/// Latin letters with diacritics, by what they fold to. Lower case only:
/// the name is lower-cased first.
const _foldGroups = <String, String>{
  'a': 'àáâãäåāăąǎ',
  'ae': 'æ',
  'c': 'çćĉċč',
  'd': 'ðďđ',
  'e': 'èéêëēĕėęě',
  'g': 'ĝğġģ',
  'h': 'ĥħ',
  'i': 'ìíîïĩīĭįıǐ',
  'ij': 'ĳ',
  'j': 'ĵ',
  'k': 'ķĸ',
  'l': 'ĺļľŀł',
  'n': 'ñńņňŉŋ',
  'o': 'òóôõöøōŏőǒơ',
  'oe': 'œ',
  'r': 'ŕŗř',
  's': 'śŝşšșſ',
  'ss': 'ß',
  't': 'ţťŧț',
  'th': 'þ',
  'u': 'ùúûüũūŭůűųǔǖǘǚǜư',
  'w': 'ŵ',
  'y': 'ýÿŷ',
  'z': 'źżž',
};

/// Superscript letters and digits, which panels write quality tags in
/// (`ᴴᴰ`, `ᶠᴴᴰ`, `ᴿᴬᵂ`, `⁴ᴷ`). Read as letters, and as a word of their own
/// even when glued to the name (`Oneᴴᴰ`), so a tag is found.
const _raisedGroups = <String, String>{
  'a': 'ᴬᵃ',
  'b': 'ᴮᵇ',
  'c': 'ᶜ',
  'd': 'ᴰᵈ',
  'e': 'ᴱᵉ',
  'f': 'ᶠ',
  'g': 'ᴳᵍ',
  'h': 'ᴴʰ',
  'i': 'ᴵⁱᶦ',
  'j': 'ᴶʲ',
  'k': 'ᴷᵏ',
  'l': 'ᴸˡᶫ',
  'm': 'ᴹᵐ',
  'n': 'ᴺⁿᶰ',
  'o': 'ᴼᵒ',
  'p': 'ᴾᵖ',
  'r': 'ᴿʳ',
  's': 'ˢ',
  't': 'ᵀᵗ',
  'u': 'ᵁᵘᶸ',
  'v': 'ⱽᵛ',
  'w': 'ᵂʷ',
  'x': 'ˣ',
  'y': 'ʸ',
  'z': 'ᶻ',
  '0': '⁰',
  '1': '¹',
  '2': '²',
  '3': '³',
  '4': '⁴',
  '5': '⁵',
  '6': '⁶',
  '7': '⁷',
  '8': '⁸',
  '9': '⁹',
};

final Map<int, String> _folds = _byCodeUnit(_foldGroups);
final Map<int, String> _raised = _byCodeUnit(_raisedGroups);

Map<int, String> _byCodeUnit(Map<String, String> groups) => {
  for (final MapEntry(key: folded, value: chars) in groups.entries)
    for (final unit in chars.codeUnits) unit: folded,
};

/// The plain letter or digit a superscript one stands for (`ᴴ` → `h`),
/// or null when [unit] is not one.
String? raisedLetter(int unit) => _raised[unit];

/// Case and Latin diacritics folded on an already lower-cased name;
/// superscript tags (`ᴴᴰ`) and full-width letters read as plain ones, a
/// superscript run as a word of its own, odd whitespace as a space. Plain
/// ASCII, most names, comes back as it went in.
String foldName(String text) {
  final length = text.length;
  var i = 0;
  while (i < length && text.codeUnitAt(i) < 0x80) {
    i++;
  }
  if (i == length) return text;
  final out = StringBuffer(text.substring(0, i));
  var raised = false;
  for (; i < length; i++) {
    final unit = text.codeUnitAt(i);
    final up = _raised[unit];
    if (up != null) {
      // A superscript run is a word of its own.
      if (!raised) out.write(' ');
      raised = true;
      out.write(up);
      continue;
    }
    if (raised) {
      out.write(' ');
      raised = false;
    }
    if (unit < 0x80) {
      out.writeCharCode(unit);
    } else if (unit >= 0x300 && unit <= 0x36f) {
      // A combining accent: the name came decomposed (`e` + U+0301).
    } else if (isOddSpace(unit)) {
      out.write(' ');
    } else if (unit >= 0xff01 && unit <= 0xff5e) {
      // Full-width ASCII.
      out.writeCharCode(unit - 0xfee0);
    } else {
      final folded = _folds[unit];
      if (folded != null) {
        out.write(folded);
      } else {
        out.writeCharCode(unit);
      }
    }
  }
  return out.toString();
}

/// What `cleanText` collapses as whitespace beyond ASCII, and the U+FFFD
/// malformed UTF-8 decodes to, which it drops.
bool isOddSpace(int unit) =>
    unit == 0xa0 ||
    unit == 0x1680 ||
    (unit >= 0x2000 && unit <= 0x200b) ||
    unit == 0x2028 ||
    unit == 0x2029 ||
    unit == 0x202f ||
    unit == 0x205f ||
    unit == 0x3000 ||
    unit == 0xfeff ||
    unit == 0xfffd;

// ----------------------------------------------------------- leading tags

/// Where the name starts once its leading country and language tags are
/// gone, the country the first of them named, and every tag's word.
///
/// A tag is a 2–3 letter word, `ex-yu`, or a quality word
/// ([qualityWords]: `FHD`, `4K`), with a separator after it (`UK:`,
/// `UK |`, `AR -`) or brackets round it (`[US]`, `(4K)`); one with
/// neither is the name's own first word and stays (`TV 5 Monde`,
/// `ABC News`). A tag is also kept when nothing would be left after it.
/// Any case: the matcher reads a lower-cased name, the screens the
/// provider's own capitals.
///
/// `country` is the first tag that is not a quality word, lower-cased and
/// read by [countryOfTag]; `tags` are the words of every tag stripped, as
/// [text] writes them, in order.
({int start, String? country, List<String> tags}) leadingNameTags(String text) {
  var start = 0;
  String? country;
  List<String>? tags;
  while (true) {
    final at = _skipJunk(text, start);
    final tag = _tagAt(text, at);
    if (tag == null || !_hasWordFrom(text, tag.end)) {
      return (start: start, country: country, tags: tags ?? const []);
    }
    final written = text.substring(tag.word, tag.wordEnd);
    (tags ??= []).add(written);
    final word = written.toLowerCase();
    if (country == null && !qualityWords.contains(word)) {
      // `[FHD] UK: …` is a UK channel.
      final letters = word.replaceAll(_notLetter, '');
      if (!qualityWords.contains(letters)) country = countryOfTag(letters);
    }
    start = tag.end;
  }
}

final _notLetter = RegExp('[^a-z]');

/// The tag at [at]: where its word starts and ends, and where the tag
/// ends, separator or closing bracket included. Null when there is none.
({int word, int wordEnd, int end})? _tagAt(String text, int at) {
  final length = text.length;
  if (at >= length) return null;
  final unit = text.codeUnitAt(at);
  if (unit == 0x5b || unit == 0x28 || unit == 0x7b) {
    // `[US]`, `(UK)`, `{EN}`.
    final start = _skipSpaces(text, at + 1);
    final word = _tagWordEnd(text, start);
    if (word == null) return null;
    final close = _skipSpaces(text, word);
    if (close >= length) return null;
    final closing = text.codeUnitAt(close);
    return closing == 0x5d || closing == 0x29 || closing == 0x7d
        ? (word: start, wordEnd: word, end: close + 1)
        : null;
  }
  final word = _tagWordEnd(text, at);
  if (word == null) return null;
  final separator = _skipSpaces(text, word);
  if (separator >= length) return null;
  final next = text.codeUnitAt(separator);
  if (isTagSeparator(next)) {
    return (word: at, wordEnd: word, end: separator + 1);
  }
  // A dash separates only with a space beside it: `AR - MBC` and `AR- MBC`
  // are tagged, `Al-Jazeera` and `RTL-2` are names.
  if (isDash(next) &&
      (separator > word ||
          (separator + 1 < length &&
              isSpace(text.codeUnitAt(separator + 1))))) {
    return (word: at, wordEnd: word, end: separator + 1);
  }
  return null;
}

/// The end of a tag-shaped word at [at]: 2–3 ASCII letters, `ex-yu`
/// (`ex yu`, `exyu`), or a quality word, standing as a word of its own.
int? _tagWordEnd(String text, int at) {
  final length = text.length;
  int? end;
  if (_startsWithIgnoringCase(text, 'ex-yu', at) ||
      _startsWithIgnoringCase(text, 'ex yu', at)) {
    end = at + 5;
  } else if (_startsWithIgnoringCase(text, 'exyu', at)) {
    end = at + 4;
  }
  if (end != null && !isWordAt(text, end)) return end;
  var i = at;
  var letters = true;
  while (i < length) {
    final unit = text.codeUnitAt(i);
    if (isAsciiLetter(unit)) {
      i++;
    } else if (unit >= 0x30 && unit <= 0x39) {
      letters = false;
      i++;
    } else {
      break;
    }
  }
  if (i == at || isWordAt(text, i)) return null;
  final run = i - at;
  if (letters && run >= 2 && run <= 3) return i;
  return qualityWords.contains(text.substring(at, i).toLowerCase()) ? i : null;
}

/// [lower] is lower case.
bool _startsWithIgnoringCase(String text, String lower, int at) {
  if (at + lower.length > text.length) return false;
  for (var i = 0; i < lower.length; i++) {
    var unit = text.codeUnitAt(at + i);
    if (unit >= 0x41 && unit <= 0x5a) unit |= 0x20;
    if (unit != lower.codeUnitAt(i)) return false;
  }
  return true;
}

/// Past anything before a tag that is neither a word nor a bracket: the
/// `|` of `|UK|`, a leading `▎`, a flag emoji.
int _skipJunk(String text, int at) {
  var i = at;
  final length = text.length;
  while (i < length) {
    final unit = text.codeUnitAt(i);
    if (unit == 0x5b || unit == 0x28 || unit == 0x7b || isWordAt(text, i)) {
      break;
    }
    i++;
  }
  return i;
}

int _skipSpaces(String text, int at) {
  var i = at;
  while (i < text.length && isSpace(text.codeUnitAt(i))) {
    i++;
  }
  return i;
}

bool _hasWordFrom(String text, int at) {
  for (var i = at; i < text.length; i++) {
    if (isWordAt(text, i)) return true;
  }
  return false;
}

// ------------------------------------------------------------- characters

final _wordChar = RegExp(r'[\p{L}\p{M}\p{N}]', unicode: true);

/// A letter or a digit at [at] in any script (false past the end).
bool isWordAt(String text, int at) {
  if (at >= text.length) return false;
  final unit = text.codeUnitAt(at);
  if (unit < 0x80) {
    return isAsciiLetter(unit) || (unit >= 0x30 && unit <= 0x39);
  }
  return _wordChar.matchAsPrefix(text, at) != null;
}

/// An ASCII letter of either case.
bool isAsciiLetter(int unit) {
  final lower = unit | 0x20;
  return lower >= 0x61 && lower <= 0x7a;
}

bool isSpace(int unit) => unit == 0x20 || (unit >= 0x09 && unit <= 0x0d);

/// `:`, `|`, `¦`, `·`, `•`, `»`, `›`, `★`, and the box-drawing, block and
/// shape characters panels draw bars with (`┃`, `▎`, `●`, `▶`).
bool isTagSeparator(int unit) =>
    unit == 0x3a ||
    unit == 0x7c ||
    unit == 0xa6 ||
    unit == 0xb7 ||
    unit == 0xbb ||
    unit == 0x2022 ||
    unit == 0x203a ||
    unit == 0x2605 ||
    unit == 0x2606 ||
    (unit >= 0x2500 && unit <= 0x25ff);

bool isDash(int unit) =>
    unit == 0x2d || (unit >= 0x2010 && unit <= 0x2015) || unit == 0x2212;

// ----------------------------------------------------------- quality tags

/// The picture's size, as a tag says it: what the screens show as a badge
/// and the matcher drops. Lower case, as the words the matcher splits a
/// name into (`H.265` is `h` `265`, which it deals with itself).
const resolutionWords = <String, String>{
  'sd': 'sd',
  '480i': 'sd',
  '480p': 'sd',
  '576i': 'sd',
  '576p': 'sd',
  'hd': 'hd',
  '720p': 'hd',
  'fhd': 'fhd',
  'fullhd': 'fhd',
  '1080i': 'fhd',
  '1080p': 'fhd',
  '1440p': 'fhd',
  'uhd': 'uhd',
  '4k': 'uhd',
  '8k': 'uhd',
  '2160p': 'uhd',
};

/// Tags that say how a feed is made rather than what it shows: its codec,
/// frame rate, range, or the panel's own markers. The matcher drops them;
/// the screens keep them, because they tell two feeds of one channel
/// apart (`ESPN` and `ESPN HEVC`, `History` and `History (Backup)`).
const technicalWords = <String>{
  'hevc',
  'h264',
  'h265',
  'x264',
  'x265',
  '25fps',
  '30fps',
  '50fps',
  '60fps',
  'hdr',
  'hdr10',
  'raw',
  'vip',
  'backup',
  'multi',
};

/// Every quality tag, as the words the matcher splits a name into.
final Set<String> qualityWords = {...resolutionWords.keys, ...technicalWords};
