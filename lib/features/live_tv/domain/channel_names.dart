/// A channel's name as the screens show it (docs/05 "Channel name
/// cleanup"). Pure: sync runs it in its isolate for every channel, and
/// stores what it returns next to the provider's name.
library;

import 'package:iptv_player/features/live_tv/domain/channel_name_tags.dart';

/// How big a channel's picture is, as its name's tags say: the badge
/// after its name. Stored by name in `channels.quality`, so a value is
/// never renamed.
enum ChannelQuality {
  sd,
  hd,
  fhd,
  uhd;

  /// What the badge says.
  String get label => switch (this) {
    sd => 'SD',
    hd => 'HD',
    fhd => 'FHD',
    uhd => '4K',
  };

  /// The value stored as [name]; null for null or a name this build
  /// doesn't know (a newer one wrote it).
  static ChannelQuality? fromStored(String? name) =>
      values.where((q) => q.name == name).firstOrNull;
}

/// The name to show for a provider's channel name, and the quality its
/// tags gave, which the screens show as a badge instead:
///  1. entities decoded, however often the panel escaped them;
///  2. odd whitespace, control characters and U+FFFD read as spaces, and
///     every run of spaces collapsed to one;
///  3. leading country and language tags dropped where a separator says
///     they are tags (`UK:`, `US |`, `[EN]`, `|AR|`), as the guide's
///     matcher reads them, so `TV 5 Monde` and `ABC News` keep their first
///     word. The category already says the country;
///  4. resolution tags at the end dropped for the badge (`HD`, `FHD`,
///     `Full HD`, `UHD`, `4K`, `1080p`, `ᴴᴰ`, `(HD)`, `[FHD]`), and at the
///     start when a separator or brackets mark them; the highest wins;
///  5. technical tags among them kept, moved after the name: a codec, a
///     frame rate, `Backup`, `VIP` — they tell two feeds of one channel
///     apart, and nothing else would once the badge is gone.
///
/// A timeshift (`+1`), numbers and the provider's capitals are kept, and
/// only whole words at the edges ever go: `HD Kids` keeps its `HD`. A
/// name with nothing left but tags comes back as the provider wrote it
/// (steps 1 and 2 aside), with no badge. Cleaning a cleaned name changes
/// nothing. Never throws.
({String name, ChannelQuality? quality}) cleanChannelName(String raw) {
  var text = raw.contains('&') ? decodeNameEntities(raw) : raw;
  text = _tidySpaces(text);
  if (text.isEmpty) return (name: raw, quality: null);

  ChannelQuality? quality;
  final kept = <String>[];
  final lead = leadingNameTags(text);
  for (final tag in lead.tags) {
    final word = tag.toLowerCase();
    final size = resolutionWords[word];
    if (size != null) {
      quality = _higher(quality, size);
    } else if (technicalWords.contains(word)) {
      kept.add(tag);
    }
  }
  final body = lead.start == 0 ? text : text.substring(lead.start);

  final trailing = <String>[];
  var end = body.length;
  while (true) {
    end = _backOverGaps(body, end);
    if (end == 0) break;
    final tag = _tagBefore(body, end);
    if (tag == null) break;
    if (tag.size != null) quality = _higher(quality, tag.size!);
    if (tag.kept != null) trailing.add(tag.kept!);
    end = tag.start;
  }
  final name = body.substring(_pastGaps(body, 0, end), end);
  if (!_hasWord(name)) return (name: text, quality: null);
  kept.addAll(trailing.reversed);
  return (
    name: kept.isEmpty ? name : '$name ${kept.join(' ')}',
    quality: quality,
  );
}

ChannelQuality _higher(ChannelQuality? held, String size) {
  final found = ChannelQuality.values.byName(size);
  return held == null || found.index > held.index ? found : held;
}

/// Step 2.
String _tidySpaces(String text) {
  final out = StringBuffer();
  var space = false;
  for (var i = 0; i < text.length; i++) {
    final unit = text.codeUnitAt(i);
    if (isSpace(unit) ||
        isOddSpace(unit) ||
        unit < 0x20 ||
        (unit >= 0x7f && unit <= 0x9f)) {
      space = out.isNotEmpty;
      continue;
    }
    if (space) out.write(' ');
    space = false;
    out.writeCharCode(unit);
  }
  return out.toString();
}

/// What may stand between a name and its tags, or between two tags: a
/// space, a separator (`|`, `:`, `•`), a dash.
bool _isGap(int unit) => isSpace(unit) || isTagSeparator(unit) || isDash(unit);

int _backOverGaps(String text, int end) {
  var i = end;
  while (i > 0 && _isGap(text.codeUnitAt(i - 1))) {
    i--;
  }
  return i;
}

int _pastGaps(String text, int start, int end) {
  var i = start;
  while (i < end && _isGap(text.codeUnitAt(i))) {
    i++;
  }
  return i;
}

bool _hasWord(String text) {
  for (var i = 0; i < text.length; i++) {
    if (isWordAt(text, i)) return true;
  }
  return false;
}

/// A tag ending at [end]: where it starts, the resolution it gives, and
/// the text to keep of it (a technical tag). Null when what ends there is
/// not a tag.
({int start, String? size, String? kept})? _tagBefore(String text, int end) {
  final last = text.codeUnitAt(end - 1);
  final opening = switch (last) {
    0x29 => 0x28, // ( )
    0x5d => 0x5b, // [ ]
    0x7d => 0x7b, // { }
    _ => null,
  };
  if (opening != null) return _bracketed(text, end, opening);
  if (raisedLetter(last) != null) {
    var start = end - 1;
    while (start > 0 && raisedLetter(text.codeUnitAt(start - 1)) != null) {
      start--;
    }
    final word = [
      for (var i = start; i < end; i++) raisedLetter(text.codeUnitAt(i)),
    ].join();
    return _classified(word, start, text.substring(start, end));
  }
  final start = _wordStart(text, end);
  if (start == end) return null;
  final word = text.substring(start, end);
  final lower = word.toLowerCase();
  // Two-word tags: `Full HD`, `H 265`, `50 fps`.
  final before = _backOverSpaces(text, start);
  if (before < start && before > 0) {
    final previousStart = _wordStart(text, before);
    final previous = text.substring(previousStart, before).toLowerCase();
    final pair = switch ((previous, lower)) {
      ('full', 'hd') => 'fhd',
      ('h', '264') => 'h264',
      ('h', '265') => 'h265',
      ('25' || '30' || '50' || '60', 'fps') => '${previous}fps',
      _ => null,
    };
    if (pair != null) {
      return _classified(
        pair,
        previousStart,
        text.substring(previousStart, end),
      );
    }
  }
  return _classified(lower.replaceAll('.', ''), start, word);
}

/// `(HD)`, `[FHD]`, `(Backup)`, `[FHD HEVC]`: a tag when every word inside
/// is one. Of a group with technical tags, the brackets and those are
/// kept.
({int start, String? size, String? kept})? _bracketed(
  String text,
  int end,
  int opening,
) {
  var start = end - 2;
  while (start >= 0 && text.codeUnitAt(start) != opening) {
    final unit = text.codeUnitAt(start);
    if (unit == 0x29 || unit == 0x5d || unit == 0x7d) return null;
    start--;
  }
  if (start < 0) return null;
  ChannelQuality? size;
  final kept = <String>[];
  var at = end - 1;
  while (true) {
    at = _backOverGaps(text, at);
    if (at <= start + 1) break;
    final tag = _tagBefore(text, at);
    if (tag == null || tag.start <= start) return null;
    if (tag.size != null) size = _higher(size, tag.size!);
    if (tag.kept != null) kept.insert(0, tag.kept!);
    at = tag.start;
  }
  if (size == null && kept.isEmpty) return null;
  final written =
      '${String.fromCharCode(opening)}${kept.join(' ')}'
      '${String.fromCharCode(text.codeUnitAt(end - 1))}';
  return (start: start, size: size?.name, kept: kept.isEmpty ? null : written);
}

({int start, String? size, String? kept})? _classified(
  String word,
  int start,
  String written,
) {
  final size = resolutionWords[word];
  if (size != null) return (start: start, size: size, kept: null);
  if (technicalWords.contains(word)) {
    return (start: start, size: null, kept: written);
  }
  return null;
}

/// Where the word that ends at [end] starts: back to a gap, a bracket or a
/// superscript letter.
int _wordStart(String text, int end) {
  var i = end;
  while (i > 0) {
    final unit = text.codeUnitAt(i - 1);
    if (_isGap(unit) ||
        unit == 0x28 ||
        unit == 0x29 ||
        unit == 0x5b ||
        unit == 0x5d ||
        unit == 0x7b ||
        unit == 0x7d ||
        raisedLetter(unit) != null) {
      break;
    }
    i--;
  }
  return i;
}

int _backOverSpaces(String text, int end) {
  var i = end;
  while (i > 0 && isSpace(text.codeUnitAt(i - 1))) {
    i--;
  }
  return i;
}
