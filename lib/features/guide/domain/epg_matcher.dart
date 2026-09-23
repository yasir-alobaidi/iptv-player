/// Attaches the provider's channels to the guide's (docs/02 "EPG ↔ channel
/// matching"). Pure: the match job runs it in an isolate over a whole
/// source, and nothing here touches the database.
library;

import 'package:flutter/foundation.dart';
import 'package:iptv_player/features/guide/domain/epg.dart';

/// Which rule attached a channel to a guide channel, strongest first in
/// the order they are tried after [manual]. Stored by name in
/// `epg_matches.rule` (`EpgMatchRule` in the database has the same names),
/// so a value is never renamed.
enum GuideMatchRule {
  /// The user's own mapping (Settings → Guide). Always wins, and nothing
  /// automatic ever replaces it.
  manual,

  /// The channel's guide id (`epg_channel_id` / `tvg-id`) is a guide
  /// channel's id exactly.
  exactId,

  /// The same, ignoring case and the spaces around it.
  caseInsensitiveId,

  /// The channel's name, normalized ([normalizeChannelName]), is a guide
  /// channel's normalized display name.
  normalizedName,
}

/// A provider channel as the matcher sees it.
@immutable
final class MatchCandidate {
  const new({
    required this.channelId,
    required this.remoteKey,
    required this.name,
    this.epgKey,
  });

  /// The channel's row id, which `epg_matches` is keyed by.
  final int channelId;

  /// The provider's key, which the user's mappings are keyed by.
  final String remoteKey;

  /// The provider's name for it (not the user's rename).
  final String name;

  /// Its guide id: Xtream's `epg_channel_id`, M3U's `tvg-id`.
  final String? epgKey;
}

/// One channel attached to one guide channel, and how.
@immutable
final class ChannelMatch {
  const new({
    required this.channelId,
    required this.xmltvId,
    required this.rule,
  });

  final int channelId;

  /// The guide channel's id, exactly as the guide writes it.
  final String xmltvId;
  final GuideMatchRule rule;

  @override
  bool operator ==(Object other) =>
      other is ChannelMatch &&
      other.channelId == channelId &&
      other.xmltvId == xmltvId &&
      other.rule == rule;

  @override
  int get hashCode => Object.hash(channelId, xmltvId, rule);

  @override
  String toString() => 'ChannelMatch($channelId → $xmltvId, ${rule.name})';
}

/// A channel name reduced to what two sources of the same channel share,
/// for [GuideMatchRule.normalizedName]. Empty when nothing is left.
///
/// The order is docs/02 rule 3's, and every step is one both sides of a
/// match go through, so a panel's `UK: BBC One ᴴᴰ` and a guide's
/// `BBC One` meet at `bbc one`:
///  1. entities decoded (until none is left: panels double-escape);
///  2. case and Latin diacritics folded; superscript tags (`ᴴᴰ`) and
///     full-width letters read as plain ones, odd whitespace as a space;
///  3. leading country and language tags dropped, but only where a
///     separator says they are tags (`UK:`, `|EN|`, `[US]`, `AR -`), so
///     `TV 5 Monde` and `ABC News` keep their first word;
///  4. quality tags dropped as whole words anywhere (`HD`, `H.265`, …);
///  5. `&` read as `and`;
///  6. a timeshift kept as one word (`+1`, `Plus 1` → `plus1`): a `+1`
///     channel is a different channel;
///  7. anything else that is not a letter or a digit a space.
///
/// Normalizing a result again changes nothing.
String normalizeChannelName(String name) => _normalize(name).key;

/// The country the leading tags of [name] named, as [EpgMatcher] reads
/// it to choose between feeds of one channel: the first tag step 3
/// strips that is not a quality tag, lower-cased, with `gb` read as `uk`
/// and `usa` as `us`. Null when no tag was stripped.
@visibleForTesting
String? leadingCountryTag(String name) => _normalize(name).country;

/// [normalizeChannelName], and the [leadingCountryTag] it stripped on the
/// way.
({String key, String? country}) _normalize(String name) {
  if (name.isEmpty) return (key: '', country: null);
  var text = name.contains('&') ? _decodeEntities(name) : name;
  text = _fold(text.toLowerCase());
  final (:start, :country) = _leadingTags(text);
  if (start > 0) text = text.substring(start);
  if (text.contains('&')) text = text.replaceAll('&', ' and ');
  if (text.contains('+')) text = text.replaceAll(_timeshiftPlus, ' plus ');
  return (key: _words(text), country: country);
}

/// Matches a source's channels against its guide. Build it once per
/// source from the guide's channels and the user's mappings; [match] is
/// then a few map lookups per channel.
final class EpgMatcher {
  /// [mappings] is the user's: a channel's remote key → a guide id.
  new(Iterable<GuideChannel> guide, {Map<String, String> mappings = const {}})
    : _mappings = {
        for (final MapEntry(:key, :value) in mappings.entries)
          if (value.trim().isNotEmpty) key: value.trim(),
      } {
    for (final channel in guide) {
      final id = channel.xmltvId;
      final key = id.trim();
      if (key.isEmpty) continue;
      _keep(_byId, key, id);
      _keep(_byLowerId, key.toLowerCase(), id);
      final suffix = _countrySuffix.firstMatch(key);
      final country = suffix == null
          ? null
          : _countryOf(key.substring(suffix.start + 1).toLowerCase());
      final displayName = channel.displayName;
      if (displayName != null) {
        final name = normalizeChannelName(displayName);
        if (name.isNotEmpty) _Feeds.add(_byName, name, id, country);
      }
      if (suffix != null && suffix.start > 0) {
        final bare = normalizeChannelName(key.substring(0, suffix.start));
        if (bare.isNotEmpty) _Feeds.add(_byBareId, bare, id, country);
      }
    }
  }

  /// Trimmed, and without the blank ones: a blank mapping maps nothing.
  final Map<String, String> _mappings;

  /// Each keyed as its rule looks it up, each to the guide's id as the
  /// guide writes it.
  final _byId = <String, String>{};
  final _byLowerId = <String, String>{};
  final _byName = <String, _Feeds>{};

  /// Normalized ids with their country suffix dropped (`cnn.us` → `cnn`),
  /// for a guide whose display names say less than its ids.
  final _byBareId = <String, _Feeds>{};

  /// The match for [channel] by the first rule that finds one, or null.
  ChannelMatch? match(MatchCandidate channel) {
    final mapped = _mappings[channel.remoteKey];
    if (mapped != null) {
      // Even for an id the guide lacks today: the user's word is kept,
      // and it holds again once the guide has the channel back.
      return _found(channel, mapped, GuideMatchRule.manual);
    }
    final epgKey = channel.epgKey?.trim();
    if (epgKey != null && epgKey.isNotEmpty) {
      final exact = _byId[epgKey];
      if (exact != null) return _found(channel, exact, GuideMatchRule.exactId);
      final loose = _byLowerId[epgKey.toLowerCase()];
      if (loose != null) {
        return _found(channel, loose, GuideMatchRule.caseInsensitiveId);
      }
    }
    final (:key, :country) = _normalize(channel.name);
    if (key.isEmpty) return null;
    final feeds = _byName[key] ?? _byBareId[key];
    if (feeds == null) return null;
    return _found(channel, feeds.pick(country), GuideMatchRule.normalizedName);
  }

  /// [match] for each channel, leaving out the unmatched.
  List<ChannelMatch> matchAll(Iterable<MatchCandidate> channels) => [
    for (final channel in channels) ?match(channel),
  ];

  static ChannelMatch _found(
    MatchCandidate channel,
    String xmltvId,
    GuideMatchRule rule,
  ) => ChannelMatch(channelId: channel.channelId, xmltvId: xmltvId, rule: rule);

  /// Several guide channels under one id key: the id that sorts first
  /// wins, whatever order the guide listed them in, so a rerun matches the
  /// same.
  static void _keep(Map<String, String> byKey, String key, String id) {
    final held = byKey[key];
    if (held == null || id.compareTo(held) < 0) byKey[key] = id;
  }
}

/// The guide channels one name key leads to: usually one, but a guide
/// often carries a channel once per country (`marlowdrama.uk`,
/// `marlowdrama.fr`), and stripping the country tag makes their names one
/// key. The channel's own tag chooses between them: a UK channel must not
/// show the French schedule.
final class _Feeds {
  new(this._first);

  /// The id that sorts first: the answer when the tag chooses nothing, so
  /// a rerun matches the same.
  String _first;

  /// Country suffix → the id that sorts first with it. Null until one has
  /// a suffix.
  Map<String, String>? _byCountry;

  static void add(
    Map<String, _Feeds> byKey,
    String key,
    String id,
    String? country,
  ) {
    final feeds = byKey[key];
    if (feeds == null) {
      byKey[key] = _Feeds(id).._addCountry(id, country);
      return;
    }
    if (id.compareTo(feeds._first) < 0) feeds._first = id;
    feeds._addCountry(id, country);
  }

  void _addCountry(String id, String? country) {
    if (country == null) return;
    final byCountry = _byCountry ??= {};
    final held = byCountry[country];
    if (held == null || id.compareTo(held) < 0) byCountry[country] = id;
  }

  /// The feed for [country] when the guide has one, else the first.
  String pick(String? country) =>
      (country == null ? null : _byCountry?[country]) ?? _first;
}

/// Countries that go by two tags.
const _countryAliases = <String, String>{'gb': 'uk', 'usa': 'us'};

String _countryOf(String tag) => _countryAliases[tag] ?? tag;

// ------------------------------------------------------------ rule 3 steps

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
String _decodeEntities(String text) {
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
/// even when glued to the name (`Oneᴴᴰ`), so rule 4 finds the tag.
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

/// Step 2 on an already lower-cased name. Plain ASCII, most names, comes
/// back as it went in.
String _fold(String text) {
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
    } else if (_isOddSpace(unit)) {
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
bool _isOddSpace(int unit) =>
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

/// Where the name starts once its leading country and language tags are
/// gone (step 3), and the country the first of them named. A tag is a 2–3
/// letter word, or `ex-yu`, with a separator after it (`UK:`, `UK |`,
/// `AR -`) or brackets round it (`[US]`); one with neither is the name's
/// own first word and stays. A tag is also kept when nothing would be
/// left after it.
({int start, String? country}) _leadingTags(String text) {
  var start = 0;
  String? country;
  while (true) {
    final at = _skipJunk(text, start);
    final tag = _tagAt(text, at);
    if (tag == null || !_hasWordFrom(text, tag.end)) {
      return (start: start, country: country);
    }
    if (country == null) {
      final word = text
          .substring(tag.word, tag.wordEnd)
          .replaceAll(_notLetter, '');
      // `[FHD] UK: …` is a UK channel.
      if (!_qualityWords.contains(word)) country = _countryOf(word);
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
  if (_isTagSeparator(next)) {
    return (word: at, wordEnd: word, end: separator + 1);
  }
  // A dash separates only with a space beside it: `AR - MBC` and `AR- MBC`
  // are tagged, `Al-Jazeera` and `RTL-2` are names.
  if (_isDash(next) &&
      (separator > word ||
          (separator + 1 < length &&
              _isSpace(text.codeUnitAt(separator + 1))))) {
    return (word: at, wordEnd: word, end: separator + 1);
  }
  return null;
}

/// The end of a tag-shaped word at [at]: 2–3 ASCII letters, or `ex-yu`
/// (`ex yu`, `exyu`), standing as a word of its own.
int? _tagWordEnd(String text, int at) {
  final length = text.length;
  int? end;
  if (text.startsWith('ex-yu', at) || text.startsWith('ex yu', at)) {
    end = at + 5;
  } else if (text.startsWith('exyu', at)) {
    end = at + 4;
  }
  if (end != null && !_isWordAt(text, end)) return end;
  var i = at;
  while (i < length && _isAsciiLetter(text.codeUnitAt(i))) {
    i++;
  }
  final letters = i - at;
  if (letters < 2 || letters > 3 || _isWordAt(text, i)) return null;
  return i;
}

/// Past anything before a tag that is neither a word nor a bracket: the
/// `|` of `|UK|`, a leading `▎`, a flag emoji.
int _skipJunk(String text, int at) {
  var i = at;
  final length = text.length;
  while (i < length) {
    final unit = text.codeUnitAt(i);
    if (unit == 0x5b || unit == 0x28 || unit == 0x7b || _isWordAt(text, i)) {
      break;
    }
    i++;
  }
  return i;
}

int _skipSpaces(String text, int at) {
  var i = at;
  while (i < text.length && _isSpace(text.codeUnitAt(i))) {
    i++;
  }
  return i;
}

bool _hasWordFrom(String text, int at) {
  for (var i = at; i < text.length; i++) {
    if (_isWordAt(text, i)) return true;
  }
  return false;
}

final _wordChar = RegExp(r'[\p{L}\p{M}\p{N}]', unicode: true);

/// A letter or a digit at [at] in any script (false past the end).
bool _isWordAt(String text, int at) {
  if (at >= text.length) return false;
  final unit = text.codeUnitAt(at);
  if (unit < 0x80) {
    return _isAsciiLetter(unit) || (unit >= 0x30 && unit <= 0x39);
  }
  return _wordChar.matchAsPrefix(text, at) != null;
}

bool _isAsciiLetter(int unit) => unit >= 0x61 && unit <= 0x7a;

bool _isSpace(int unit) => unit == 0x20 || (unit >= 0x09 && unit <= 0x0d);

/// `:`, `|`, `¦`, `·`, `•`, `»`, `›`, `★`, and the box-drawing, block and
/// shape characters panels draw bars with (`┃`, `▎`, `●`, `▶`).
bool _isTagSeparator(int unit) =>
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

bool _isDash(int unit) =>
    unit == 0x2d || (unit >= 0x2010 && unit <= 0x2015) || unit == 0x2212;

/// A `+` before a number: `Film4 +1`, `ITV+1`, `+ 1`.
final _timeshiftPlus = RegExp(r'\+(?=\s*[0-9])');

final _nonWord = RegExp(r'[^\p{L}\p{M}\p{N}]+', unicode: true);

/// Step 4's tags, as the words step 7 leaves (`H.265` is `h` `265`, dealt
/// with in [_words]).
const _qualityWords = <String>{
  'hd',
  'fhd',
  'uhd',
  'sd',
  'fullhd',
  '4k',
  '8k',
  'hevc',
  'h264',
  'h265',
  'x264',
  'x265',
  '480i',
  '480p',
  '576i',
  '576p',
  '720p',
  '1080i',
  '1080p',
  '1440p',
  '2160p',
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

/// Steps 4, 6 and 7 over the words: quality tags out, a timeshift joined
/// into one word, the rest joined by single spaces. Each looks back at the
/// last word kept, so a second pass finds nothing left to do.
String _words(String text) {
  final kept = <String>[];
  for (final word in text.split(_nonWord)) {
    if (word.isEmpty) continue;
    if (_qualityWords.contains(word)) {
      // `Full HD` goes whole.
      if (word == 'hd' && kept.isNotEmpty && kept.last == 'full') {
        kept.removeLast();
      }
      continue;
    }
    if (kept.isNotEmpty) {
      final last = kept.last;
      if (last == 'h' && (word == '264' || word == '265')) {
        kept.removeLast();
        continue;
      }
      if (last == 'plus' && _isHours(word)) {
        kept[kept.length - 1] = 'plus$word';
        continue;
      }
    }
    kept.add(word);
  }
  return kept.join(' ');
}

/// One or two ASCII digits: the hours of a timeshift.
bool _isHours(String word) {
  if (word.isEmpty || word.length > 2) return false;
  for (final unit in word.codeUnits) {
    if (unit < 0x30 || unit > 0x39) return false;
  }
  return true;
}

/// `.uk`, `.us`, `.tv`, `.com` at the end of a guide id.
final _countrySuffix = RegExp(r'\.[A-Za-z]{2,3}$');
