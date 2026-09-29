/// Attaches the provider's channels to the guide's (docs/02 "EPG ↔ channel
/// matching"). Pure: the match job runs it in an isolate over a whole
/// source, and nothing here touches the database.
library;

import 'package:flutter/foundation.dart';
import 'package:iptv_player/features/guide/domain/epg.dart';
import 'package:iptv_player/features/live_tv/domain/channel_name_tags.dart';

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

/// [leadingCountryTag] for the app's own use: the Match… picker puts the
/// guide's feed for the channel's own country first, as [EpgMatcher]
/// does.
String? channelCountryTag(String name) => _normalize(name).country;

/// A guide id as [EpgMatcher] reads it: trimmed, and split from its
/// country suffix (`.uk`, `.us`, `.tv`, `.com`). `bare` is the id without
/// the suffix (`cnn.us` → `cnn`), or the whole trimmed id when it has no
/// suffix or nothing before one; `country` is the suffix lower-cased,
/// with `gb` read as `uk` and `usa` as `us`, or null.
({String bare, String? country}) splitGuideId(String id) {
  final key = id.trim();
  final length = key.length;
  // A dot, then two or three ASCII letters that end the id.
  var start = length;
  while (start > 0 &&
      length - start < 3 &&
      isAsciiLetter(key.codeUnitAt(start - 1))) {
    start--;
  }
  final dot = start - 1;
  if (length - start < 2 || dot < 0 || key.codeUnitAt(dot) != 0x2e) {
    return (bare: key, country: null);
  }
  return (
    bare: dot > 0 ? key.substring(0, dot) : key,
    country: countryOfTag(key.substring(start).toLowerCase()),
  );
}

/// A guide id read as a name, as [EpgMatcher] reads it for a guide whose
/// display names say less than its ids: [splitGuideId]'s `bare` id,
/// normalized (`sky.news.uk` → `sky news`, `BBCOne.uk` → `bbcone`).
String guideIdKey(String id) {
  final bare = splitGuideId(id).bare;
  // Most ids are one run of ASCII letters and digits, which normalizing
  // only lower-cases (no entity, accent, tag separator or `+` in it), or
  // empties when the whole id is a quality tag: the same key, without
  // the regular expressions.
  if (_isAsciiWord(bare)) {
    final key = bare.toLowerCase();
    return qualityWords.contains(key) ? '' : key;
  }
  return normalizeChannelName(bare);
}

/// [normalizeChannelName], and the [leadingCountryTag] it stripped on the
/// way.
({String key, String? country}) _normalize(String name) {
  if (name.isEmpty) return (key: '', country: null);
  var text = name.contains('&') ? decodeNameEntities(name) : name;
  text = withoutTrailingCountries(foldName(text.toLowerCase()));
  final (:start, :country, tags: _) = leadingNameTags(text);
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
      final (:bare, :country) = splitGuideId(key);
      final displayName = channel.displayName;
      if (displayName != null) {
        final name = normalizeChannelName(displayName);
        if (name.isNotEmpty) _Feeds.add(_byName, name, id, country);
      }
      // Shorter than the id only when a suffix was dropped.
      if (bare.length < key.length) {
        final bareName = normalizeChannelName(bare);
        if (bareName.isNotEmpty) _Feeds.add(_byBareId, bareName, id, country);
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

/// A `+` before a number: `Film4 +1`, `ITV+1`, `+ 1`.
final _timeshiftPlus = RegExp(r'\+(?=\s*[0-9])');

final _nonWord = RegExp(r'[^\p{L}\p{M}\p{N}]+', unicode: true);

/// Steps 4, 6 and 7 over the words: quality tags out, a timeshift joined
/// into one word, the rest joined by single spaces. Each looks back at the
/// last word kept, so a second pass finds nothing left to do.
String _words(String text) {
  final kept = <String>[];
  for (final word in text.split(_nonWord)) {
    if (word.isEmpty) continue;
    if (qualityWords.contains(word)) {
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

/// Only ASCII letters and digits, and at least one.
bool _isAsciiWord(String text) {
  if (text.isEmpty) return false;
  for (var i = 0; i < text.length; i++) {
    final unit = text.codeUnitAt(i);
    if (!isAsciiLetter(unit) && (unit < 0x30 || unit > 0x39)) return false;
  }
  return true;
}
