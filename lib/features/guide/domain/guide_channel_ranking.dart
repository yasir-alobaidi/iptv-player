/// Ranks a guide's channels for Settings → Guide's Match… picker. Pure,
/// so the repository can run it in a background isolate when the guide
/// is large (hard rule 2), and every rule is unit-tested.
///
/// How close a guide channel is to the channel being matched is the
/// higher of two similarities: its display name's key to the channel's
/// name key, and its id read as a name (`idKey`) to the same. Keys are
/// [normalizeChannelName]'s, so `UK: BBC One ᴴᴰ` and `BBC One` are one
/// key. Equal keys score 1; for the id, equal without their spaces too
/// (`arenasports1` is `arena sports 1`). Anything else scores below 1:
///
///     0.99 × (0.6 × words + 0.4 × letters)
///
///  * `words`: how much of both names the other one covers, word by
///    word. Each word is matched to its closest word on the other side
///    (1 when equal; letters compared by character pairs, so `sport` is
///    close to `sports` while `one` and `news` are different words;
///    numbers only ever equal, so `2` is as far from `1` as `10` is), and
///    a word weighs its length plus 2, which makes a short word such as a
///    number count for more than its letters.
///  * `letters`: the Dice coefficient of the character pairs of the keys
///    with their spaces taken out, a run of digits being one character,
///    which catches words split or joined differently (`5 USA`, `5USA`).
library;

import 'dart:typed_data';

import 'package:flutter/foundation.dart';
import 'package:iptv_player/features/guide/domain/epg.dart';
import 'package:iptv_player/features/guide/domain/epg_matcher.dart';
import 'package:iptv_player/features/guide/domain/guide_matching.dart';

/// A guide channel with the keys ranking compares, worked out once per
/// guide rather than once per keystroke. Plain values, and few objects:
/// a large guide's list is copied into an isolate for each ranking, and
/// the copy costs by the object.
@immutable
final class RankableGuideChannel {
  /// Takes the two keys as given and works out from them everything else
  /// ranking reads.
  new({
    required GuideChannel channel,
    required String nameKey,
    required String idKey,
  }) : this._(channel, nameKey, idKey, _Packing.of(nameKey, idKey));

  new _(this.channel, this.nameKey, this.idKey, _Packing packing)
    : _country = splitGuideId(channel.xmltvId).country,
      _data = packing.data,
      _namePairs = packing.namePairs,
      _idWords = packing.idWords,
      _idPairs = packing.idPairs,
      _nameWeight = packing.nameWeight,
      _idWeight = packing.idWeight;

  /// Works the keys out for [channel].
  factory of(GuideChannel channel) => RankableGuideChannel(
    channel: channel,
    nameKey: normalizeChannelName(channel.displayName ?? ''),
    idKey: guideIdKey(channel.xmltvId),
  );

  final GuideChannel channel;

  /// `normalizeChannelName` of the channel's display name; empty when it
  /// has none.
  final String nameKey;

  /// Its id read as a name: the country suffix dropped (`cnn.us` →
  /// `cnn`), then normalized.
  final String idKey;

  /// The country its id's suffix names (`gb` read as `uk`, `usa` as
  /// `us`), as `EpgMatcher` reads it; null when the id has none. Settles
  /// ties for a channel tagged with that country.
  final String? _country;

  /// Both keys' words and character pairs, one after the other: where
  /// the name's words start and end (two offsets a word) from 0, its
  /// pairs from [_namePairs], the id's words from [_idWords], its pairs
  /// from [_idPairs] to the end. See [_wordsOf] and [_pairsOf].
  final Uint32List _data;
  final int _namePairs;
  final int _idWords;
  final int _idPairs;

  /// The sum of [_weightOf] over each key's words.
  final int _nameWeight;
  final int _idWeight;
}

/// [RankableGuideChannel.of] for every channel of a guide.
List<RankableGuideChannel> prepareGuideChannels(Iterable<GuideChannel> guide) =>
    [for (final channel in guide) RankableGuideChannel.of(channel)];

/// The guide channels to offer for a provider channel called
/// [channelName] (the provider's own name), best first, at most [limit].
///
/// With an empty [query], every guide channel is a candidate, ordered by
/// how close its name or id is to [channelName]. With one, only those
/// whose name or id contains the query are, and how well they fit the
/// query counts first. The full rules are in the Phase 4 step 5 spec
/// (ADR-011 step 5).
///
/// Equal scores go to the channel whose id carries the country
/// [channelName] is tagged with, then by label ignoring case, then by id,
/// so the order never depends on the guide's.
List<GuideChannelCandidate> rankGuideChannels(
  List<RankableGuideChannel> guide, {
  required String channelName,
  String query = '',
  int limit = 50,
}) {
  if (limit <= 0 || guide.isEmpty) return [];
  final target = _Target.of(channelName);
  final filter = _Query.of(query);
  final best = _Best(limit, target.country);
  for (final channel in guide) {
    var fit = 0;
    if (filter != null) {
      fit = filter.fit(channel);
      if (fit < 0) continue;
    }
    best.offer(channel, fit, target.similarity(channel));
  }
  return best.candidates();
}

// ------------------------------------------------------------- the keys

/// Words and characters compared past these are noise: a name this long
/// is ranked by its start (and stays cheap to rank).
const _maxWords = 32;
const _maxSymbols = 256;

/// Of the blend below 1, the words' share; the letters have the rest.
const _wordShare = 0.6;

/// Two words sharing less of their character pairs than this are
/// different words (`one` and `news` share `ne`), not a near miss
/// (`sport` and `sports`).
const _closeWords = 0.5;

/// What a score short of an equal key is scaled into, so it stays below
/// 1 however close it comes.
const _belowEqual = 0.99;

/// No words and no pairs: one empty list, shared.
final _empty = Uint32List(0);

/// A [RankableGuideChannel]'s keys packed into one list, and where each
/// part starts.
final class _Packing {
  const new(
    this.data,
    this.namePairs,
    this.idWords,
    this.idPairs,
    this.nameWeight,
    this.idWeight,
  );

  factory of(String nameKey, String idKey) {
    final nameWords = 2 * _wordsOf(nameKey, null, 0);
    final namePairs = _pairsOf(nameKey, null, 0);
    final idWords = 2 * _wordsOf(idKey, null, 0);
    final idPairs = _pairsOf(idKey, null, 0);
    final length = nameWords + namePairs + idWords + idPairs;
    if (length == 0) return _Packing(_empty, 0, 0, 0, 0, 0);
    final data = Uint32List(length);
    final idAt = nameWords + namePairs;
    _wordsOf(nameKey, data, 0);
    _pairsOf(nameKey, data, nameWords);
    _wordsOf(idKey, data, idAt);
    _pairsOf(idKey, data, idAt + idWords);
    return _Packing(
      data,
      nameWords,
      idAt,
      idAt + idWords,
      _weightOfWords(data, 0, nameWords),
      _weightOfWords(data, idAt, idAt + idWords),
    );
  }

  final Uint32List data;
  final int namePairs;
  final int idWords;
  final int idPairs;
  final int nameWeight;
  final int idWeight;
}

/// A word's weight: its length, plus 2 so a short word (a number) still
/// counts as a word.
int _weightOf(int length) => length + 2;

/// The sum of [_weightOf] over the words whose offsets are
/// `bounds[start..end)`.
int _weightOfWords(Uint32List bounds, int start, int end) {
  var weight = 0;
  for (var w = start; w < end; w += 2) {
    weight += _weightOf(bounds[w + 1] - bounds[w]);
  }
  return weight;
}

bool _isDigit(int unit) => unit >= 0x30 && unit <= 0x39;

/// How many words [key] has, split at its spaces and wherever digits
/// meet letters (`film4` is `film` `4`), at most [_maxWords]; and, given
/// [into], where each starts and ends, two offsets a word from [at].
int _wordsOf(String key, Uint32List? into, int at) {
  final length = key.length;
  var count = 0;
  var start = -1;
  var digits = false;
  for (var i = 0; i <= length; i++) {
    final unit = i < length ? key.codeUnitAt(i) : 0x20;
    final space = unit == 0x20;
    final digit = _isDigit(unit);
    if (start >= 0 && (space || digit != digits)) {
      if (into != null) {
        into[at + 2 * count] = start;
        into[at + 2 * count + 1] = i;
      }
      if (++count == _maxWords) break;
      start = -1;
    }
    if (!space && start < 0) {
      start = i;
      digits = digit;
    }
  }
  return count;
}

/// How many character pairs [key] has without its spaces, a run of
/// digits being one character (see [_numberSymbol]), so `sports1` and
/// `sports10` differ in one pair exactly as `sports1` and `sports2` do;
/// and, given [into], the pairs from [at], each packed into one int
/// (first << 16 | second) and sorted, for [_dice].
int _pairsOf(String key, Uint32List? into, int at) {
  final length = key.length;
  var previous = -1;
  var count = 0;
  var symbols = 0;
  for (var i = 0; i < length && symbols < _maxSymbols;) {
    final start = i;
    final unit = key.codeUnitAt(i++);
    if (unit == 0x20) continue;
    var symbol = unit;
    if (_isDigit(unit)) {
      while (i < length && _isDigit(key.codeUnitAt(i))) {
        i++;
      }
      if (into != null) symbol = _numberSymbol(key, start, i);
    }
    symbols++;
    if (previous >= 0) {
      if (into != null) _insertSorted(into, at, count, previous << 16 | symbol);
      count++;
    }
    previous = symbol;
  }
  return count;
}

/// Puts [value] into the sorted [count] entries of [list] from [at]
/// (with room after them), keeping them sorted: lists this short sort
/// fastest this way.
void _insertSorted(Uint32List list, int at, int count, int value) {
  var i = at + count;
  while (i > at && list[i - 1] > value) {
    list[i] = list[i - 1];
    i--;
  }
  list[i] = value;
}

/// A run of digits as one UTF-16 unit of the private use area, which no
/// normalized key contains (it keeps only letters, marks and numbers).
/// Up to three digits it is exact (`1`, `01` and `001` differ); a longer
/// run is hashed into the rest of the area.
int _numberSymbol(String key, int start, int end) {
  const base = 0xe000;
  final digits = end - start;
  if (digits <= 3) {
    var value = 0;
    for (var i = start; i < end; i++) {
      value = value * 10 + key.codeUnitAt(i) - 0x30;
    }
    return base + digits * 1000 + value;
  }
  var hash = 0x811c9dc5;
  for (var i = start; i < end; i++) {
    hash = ((hash ^ key.codeUnitAt(i)) * 0x01000193) & 0xffffffff;
  }
  return base + 4000 + hash % 2400;
}

/// The Dice coefficient of `a[aStart..aEnd)` and `b[bStart..bEnd)`, both
/// sorted, as multisets: 1 when equal, 0 when they share nothing (or
/// either is empty).
double _dice(
  Uint32List a,
  int aStart,
  int aEnd,
  Uint32List b,
  int bStart,
  int bEnd,
) {
  if (aStart == aEnd || bStart == bEnd) return 0;
  var i = aStart;
  var j = bStart;
  var common = 0;
  while (i < aEnd && j < bEnd) {
    final x = a[i];
    final y = b[j];
    if (x == y) {
      common++;
      i++;
      j++;
    } else if (x < y) {
      i++;
    } else {
      j++;
    }
  }
  return 2 * common / (aEnd - aStart + bEnd - bStart);
}

/// The character pairs of `text[start..end)`, one word with no digits
/// in it, sorted into [into]; how many there are (at most its length).
int _wordPairsInto(Uint32List into, String text, int start, int end) {
  var count = 0;
  final last = end - 1 - start > into.length ? start + into.length : end - 1;
  for (var i = start; i < last; i++) {
    _insertSorted(
      into,
      0,
      count++,
      text.codeUnitAt(i) << 16 | text.codeUnitAt(i + 1),
    );
  }
  return count;
}

/// [text] equals [free] once its spaces are taken out.
bool _equalIgnoringSpaces(String text, String free) {
  final length = free.length;
  var j = 0;
  for (var i = 0; i < text.length; i++) {
    final unit = text.codeUnitAt(i);
    if (unit == 0x20) continue;
    if (j == length || unit != free.codeUnitAt(j)) return false;
    j++;
  }
  return j == length;
}

/// [text] starts with [pattern] (non-empty, no spaces) once its spaces
/// are taken out.
bool _startsWithIgnoringSpaces(String text, String pattern) {
  final length = pattern.length;
  var j = 0;
  for (var i = 0; i < text.length && j < length; i++) {
    final unit = text.codeUnitAt(i);
    if (unit == 0x20) continue;
    if (unit != pattern.codeUnitAt(j)) return false;
    j++;
  }
  return j == length;
}

/// [text] contains [pattern] (non-empty, no spaces) once its spaces are
/// taken out.
bool _containsIgnoringSpaces(String text, String pattern) {
  final length = text.length;
  final patternLength = pattern.length;
  final first = pattern.codeUnitAt(0);
  for (var i = 0; i < length; i++) {
    if (text.codeUnitAt(i) != first) continue;
    var j = 1;
    for (var k = i + 1; k < length && j < patternLength; k++) {
      final unit = text.codeUnitAt(k);
      if (unit == 0x20) continue;
      if (unit != pattern.codeUnitAt(j)) break;
      j++;
    }
    if (j == patternLength) return true;
  }
  return false;
}

// ------------------------------------------------------- the similarity

/// The channel being matched, worked out once per call.
final class _Target {
  new _(
    this._text,
    this.country,
    this._pairs,
    this._words,
    this._wordPairs,
    this._isNumber,
    this._weight,
  ) : _free = _text.replaceAll(' ', ''),
      _closest = Float64List(_words.length);

  factory of(String channelName) {
    final text = normalizeChannelName(channelName);
    final bounds = Uint32List(2 * _wordsOf(text, null, 0));
    _wordsOf(text, bounds, 0);
    final pairs = Uint32List(_pairsOf(text, null, 0));
    _pairsOf(text, pairs, 0);
    final words = [
      for (var w = 0; w < bounds.length; w += 2)
        text.substring(bounds[w], bounds[w + 1]),
    ];
    final isNumber = [for (final word in words) _isDigit(word.codeUnitAt(0))];
    final scratch = Uint32List(_maxSymbols);
    return _Target._(
      text,
      channelCountryTag(channelName),
      pairs,
      words,
      [
        for (var i = 0; i < words.length; i++)
          if (isNumber[i])
            _empty
          else
            Uint32List.fromList(
              Uint32List.sublistView(
                scratch,
                0,
                _wordPairsInto(scratch, words[i], 0, words[i].length),
              ),
            ),
      ],
      isNumber,
      _weightOfWords(bounds, 0, bounds.length),
    );
  }

  final String _text;

  /// [_text] with its spaces taken out.
  final String _free;

  /// The country the channel's name is tagged with (`UK: …` → `uk`).
  final String? country;

  final Uint32List _pairs;
  final List<String> _words;
  final List<Uint32List> _wordPairs;
  final List<bool> _isNumber;
  final int _weight;

  /// Per word of the target, the closest word of the key being scored.
  /// Scratch, zeroed after each key.
  final Float64List _closest;

  /// A guide word's character pairs, sorted. Scratch.
  final _scratch = Uint32List(_maxSymbols);

  /// 0..1: the higher of the name's and the id's similarity.
  double similarity(RankableGuideChannel channel) {
    if (_text.isEmpty) return 0;
    final data = channel._data;
    final byName = _score(
      channel.nameKey,
      data,
      0,
      channel._namePairs,
      channel._idWords,
      channel._nameWeight,
      spacesAside: false,
    );
    if (byName == 1) return 1;
    final byId = _score(
      channel.idKey,
      data,
      channel._idWords,
      channel._idPairs,
      data.length,
      channel._idWeight,
      spacesAside: true,
    );
    return byId > byName ? byId : byName;
  }

  /// The similarity of [key], whose words' offsets are
  /// `data[words..pairs)` and whose pairs are `data[pairs..end)`.
  double _score(
    String key,
    Uint32List data,
    int words,
    int pairs,
    int end,
    int weight, {
    required bool spacesAside,
  }) {
    if (key.isEmpty) return 0;
    if (key == _text || (spacesAside && _equalIgnoringSpaces(key, _free))) {
      return 1;
    }
    final overlap = _wordOverlap(key, data, words, pairs, weight);
    final letters = _dice(_pairs, 0, _pairs.length, data, pairs, end);
    return _belowEqual * (_wordShare * overlap + (1 - _wordShare) * letters);
  }

  /// How much of both keys the other covers, word by word, each word
  /// weighed by [_weightOf]: a word's closeness to another is 1 when they
  /// are equal, 0 when either is a number and they differ, else the Dice
  /// coefficient of their character pairs, 0 below [_closeWords].
  double _wordOverlap(
    String text,
    Uint32List bounds,
    int from,
    int to,
    int weight,
  ) {
    final targetWords = _words;
    final closest = _closest;
    var covered = 0.0;
    for (var w = from; w < to; w += 2) {
      final start = bounds[w];
      final end = bounds[w + 1];
      final length = end - start;
      final number = _isDigit(text.codeUnitAt(start));
      var best = 0.0;
      var pairs = -1;
      for (var i = 0; i < targetWords.length; i++) {
        final other = targetWords[i];
        double value;
        if (other.length == length && text.startsWith(other, start)) {
          value = 1;
        } else if (number || _isNumber[i]) {
          continue;
        } else {
          final otherPairs = _wordPairs[i];
          // Too different in length to share enough of their pairs.
          final most = length - 1 < otherPairs.length
              ? length - 1
              : otherPairs.length;
          if (2 * most < _closeWords * (length - 1 + otherPairs.length)) {
            continue;
          }
          if (pairs < 0) pairs = _wordPairsInto(_scratch, text, start, end);
          value = _dice(_scratch, 0, pairs, otherPairs, 0, otherPairs.length);
          if (value < _closeWords) continue;
        }
        if (value > best) best = value;
        if (value > closest[i]) closest[i] = value;
      }
      covered += best * _weightOf(length);
    }
    for (var i = 0; i < targetWords.length; i++) {
      covered += closest[i] * _weightOf(targetWords[i].length);
      closest[i] = 0;
    }
    return covered / (_weight + weight);
  }
}

// ------------------------------------------------------------ the query

/// What the user typed in the picker, and how well a channel fits it.
final class _Query {
  new(this._key, this._raw)
    : _free = _key.replaceAll(' ', ''),
      _wordStart = ' $_key';

  /// Null for a blank query: every channel is a candidate.
  static _Query? of(String query) {
    final raw = query.trim().toLowerCase();
    if (raw.isEmpty) return null;
    final key = normalizeChannelName(query);
    // Only a quality tag or punctuation (`HD`, `+`): read as typed.
    return _Query(key.isEmpty ? raw : key, raw);
  }

  final String _key;
  final String _raw;
  final String _free;
  final String _wordStart;

  /// -1 when [channel] doesn't contain the query; else how well it fits,
  /// 0 best: its name is the query (0), its name or id starts with it
  /// (1), a word of its name does (2), it contains it anywhere (3).
  int fit(RankableGuideChannel channel) {
    final name = channel.nameKey;
    final id = channel.idKey;
    if (!_containsIgnoringSpaces(name, _free) &&
        !_containsIgnoringSpaces(id, _free)) {
      final guide = channel.channel;
      if (!guide.label.toLowerCase().contains(_raw) &&
          !guide.xmltvId.toLowerCase().contains(_raw)) {
        return -1;
      }
    }
    if (name == _key) return 0;
    if (name.startsWith(_key) ||
        id.startsWith(_key) ||
        _startsWithIgnoringSpaces(id, _free)) {
      return 1;
    }
    if (name.contains(_wordStart)) return 2;
    return 3;
  }
}

// ------------------------------------------------------------ the order

/// A channel that made the list so far.
final class _Ranked {
  new(this.channel, this.fit, this.score, {required this.home})
    : label = channel.channel.label.toLowerCase();

  final RankableGuideChannel channel;
  final int fit;
  final double score;

  /// Its id carries the country the channel being matched is tagged with.
  final bool home;

  /// Its label lower-cased.
  final String label;
}

/// The best [_limit] channels offered, kept in order as they come: a
/// channel that can't make the list costs one comparison and no
/// allocation. Past [_sortAllAbove] the offers are all kept and sorted
/// once instead.
final class _Best {
  new(this._limit, this._country);

  static const _sortAllAbove = 256;

  final int _limit;
  final String? _country;
  final _ranked = <_Ranked>[];

  void offer(RankableGuideChannel channel, int fit, double score) {
    final ranked = _ranked;
    final keepAll = _limit > _sortAllAbove;
    if (!keepAll && ranked.length == _limit) {
      final last = ranked.last;
      // Worse on fit or score: out without building anything.
      if (fit > last.fit || (fit == last.fit && score < last.score)) return;
    }
    final entry = _Ranked(
      channel,
      fit,
      score,
      home: _country != null && channel._country == _country,
    );
    if (keepAll) {
      ranked.add(entry);
      return;
    }
    if (ranked.length == _limit) {
      if (_compare(entry, ranked.last) >= 0) return;
      ranked.removeLast();
    }
    var low = 0;
    var high = ranked.length;
    while (low < high) {
      final middle = (low + high) >> 1;
      if (_compare(entry, ranked[middle]) < 0) {
        high = middle;
      } else {
        low = middle + 1;
      }
    }
    ranked.insert(low, entry);
  }

  List<GuideChannelCandidate> candidates() {
    final ranked = _ranked;
    if (_limit > _sortAllAbove) ranked.sort(_compare);
    return [
      for (final entry
          in ranked.length > _limit ? ranked.sublist(0, _limit) : ranked)
        GuideChannelCandidate(
          channel: entry.channel.channel,
          score: entry.score,
        ),
    ];
  }

  /// Fit, then score, then the ties: the home country's feed, the label
  /// ignoring case, the id; and, for a guide that lists one id twice,
  /// whatever else differs, so the order is always the same.
  static int _compare(_Ranked a, _Ranked b) {
    if (a.fit != b.fit) return a.fit - b.fit;
    if (a.score != b.score) return a.score > b.score ? -1 : 1;
    if (a.home != b.home) return a.home ? -1 : 1;
    var order = a.label.compareTo(b.label);
    if (order != 0) return order;
    final x = a.channel.channel;
    final y = b.channel.channel;
    order = x.xmltvId.compareTo(y.xmltvId);
    if (order != 0) return order;
    order = x.label.compareTo(y.label);
    if (order != 0) return order;
    order = _compareOptional(x.displayName, y.displayName);
    if (order != 0) return order;
    return _compareOptional(x.iconUrl, y.iconUrl);
  }

  /// Null first.
  static int _compareOptional(String? a, String? b) {
    if (a == null) return b == null ? 0 : -1;
    if (b == null) return 1;
    return a.compareTo(b);
  }
}
