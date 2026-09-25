import 'package:flutter/foundation.dart';
import 'package:iptv_player/core/result.dart';
import 'package:iptv_player/features/guide/domain/epg.dart';
import 'package:iptv_player/features/guide/domain/epg_match_summary.dart';
import 'package:iptv_player/features/guide/domain/epg_matcher.dart';

/// Which of a source's channels Settings → Guide lists.
enum ChannelMatchFilter {
  /// Channels no rule attached to a guide channel.
  unmatched,

  /// Channels the user attached themselves ([GuideMatchRule.manual]).
  manual,

  /// Every channel.
  all,
}

/// One of the provider's channels, and the guide channel the matcher
/// attached it to (Settings → Guide's channel list and the Match…
/// picker).
@immutable
final class ChannelGuideMatch {
  const new({
    required this.channelId,
    required this.sourceId,
    required this.remoteKey,
    required this.name,
    required this.providerName,
    this.number,
    this.logoUrl,
    this.epgKey,
    this.xmltvId,
    this.rule,
    this.guideLabel,
    this.inGuide = false,
  });

  final int channelId;
  final String sourceId;

  /// The provider's key, which the user's mappings are keyed by.
  final String remoteKey;

  /// What the app shows: the user's rename, else the provider's name.
  final String name;

  /// The provider's own name: what the matcher read, and what the picker
  /// ranks the guide's channels against.
  final String providerName;
  final int? number;
  final String? logoUrl;

  /// Its guide id as the provider sent it (`epg_channel_id` / `tvg-id`).
  final String? epgKey;

  /// The guide channel it is attached to; null when unmatched.
  final String? xmltvId;

  /// How it was attached; null when unmatched.
  final GuideMatchRule? rule;

  /// The attached guide channel's name (its label: the display name, or
  /// its id when the guide gave none); null when unmatched or when the
  /// live guide doesn't declare that id.
  final String? guideLabel;

  /// False for a match to an id the live guide doesn't declare — only
  /// the user's own mapping can be one (the matcher keeps it anyway).
  final bool inGuide;

  bool get isMatched => xmltvId != null;

  bool get isManual => rule == GuideMatchRule.manual;

  @override
  bool operator ==(Object other) =>
      other is ChannelGuideMatch &&
      other.channelId == channelId &&
      other.sourceId == sourceId &&
      other.remoteKey == remoteKey &&
      other.name == name &&
      other.providerName == providerName &&
      other.number == number &&
      other.logoUrl == logoUrl &&
      other.epgKey == epgKey &&
      other.xmltvId == xmltvId &&
      other.rule == rule &&
      other.guideLabel == guideLabel &&
      other.inGuide == inGuide;

  @override
  int get hashCode => Object.hash(
    channelId,
    sourceId,
    remoteKey,
    name,
    providerName,
    number,
    logoUrl,
    epgKey,
    xmltvId,
    rule,
    guideLabel,
    inGuide,
  );

  @override
  String toString() =>
      'ChannelGuideMatch($channelId, ${rule?.name ?? 'unmatched'})';
}

/// How well the guide covers the channels the user can see: those not
/// hidden and not in a hidden category (ADR-011 step 5). Hidden channels
/// are matched like any other; they are only left out of these numbers
/// and of Settings → Guide's list.
@immutable
final class ChannelMatchCounts {
  const new({this.channels = 0, this.matched = 0, this.manual = 0});

  /// The source's visible channels.
  final int channels;

  /// Of those, attached to a guide channel by any rule, [manual]
  /// included.
  final int matched;

  /// Of those, attached by the user.
  final int manual;

  int get unmatched => channels - matched < 0 ? 0 : channels - matched;

  /// The count a [ChannelMatchFilter] lists with no text filter.
  int of(ChannelMatchFilter filter) => switch (filter) {
    ChannelMatchFilter.unmatched => unmatched,
    ChannelMatchFilter.manual => manual,
    ChannelMatchFilter.all => channels,
  };

  @override
  bool operator ==(Object other) =>
      other is ChannelMatchCounts &&
      other.channels == channels &&
      other.matched == matched &&
      other.manual == manual;

  @override
  int get hashCode => Object.hash(channels, matched, manual);

  @override
  String toString() =>
      'ChannelMatchCounts($matched of $channels, $manual manual)';
}

/// A guide channel the Match… picker offers, with how close its name is
/// to the channel being matched.
@immutable
final class GuideChannelCandidate {
  const new({required this.channel, required this.score});

  final GuideChannel channel;

  /// 0..1: 1 when its normalized name is the channel's
  /// (`normalizeChannelName`), 0 when they share nothing. Orders the
  /// list; the picker marks a 1 as the best match.
  final double score;

  @override
  bool operator ==(Object other) =>
      other is GuideChannelCandidate &&
      other.channel == channel &&
      other.score == score;

  @override
  int get hashCode => Object.hash(channel, score);

  @override
  String toString() =>
      'GuideChannelCandidate(${channel.xmltvId}, ${score.toStringAsFixed(3)})';
}

/// Keeps a source's matches in step after the user maps or unmaps a
/// channel (`EpgMatchService` implements it).
abstract interface class GuideMatching {
  /// Rematches [sourceId]'s channels against its guide and the user's
  /// mappings. Never throws.
  Future<Result<EpgMatchSummary>> rematch(String sourceId);
}

/// Where a source's guide comes from, as Settings → Guide words it.
enum GuideOriginKind {
  /// The EPG URL the user typed for the source.
  sourceUrl,

  /// The Xtream panel's own `xmltv.php`.
  panel,

  /// The first `url-tvg` the playlist's header names.
  playlist,
}

/// Where a source's guide comes from: never the URL itself, which can
/// carry a password or a token (hard rule 3).
@immutable
final class GuideOrigin {
  const new(this.kind, {this.isFile = false});

  final GuideOriginKind kind;

  /// A path on this computer rather than a web address.
  final bool isFile;

  @override
  bool operator ==(Object other) =>
      other is GuideOrigin && other.kind == kind && other.isFile == isFile;

  @override
  int get hashCode => Object.hash(kind, isFile);

  @override
  String toString() => 'GuideOrigin(${kind.name}${isFile ? ', file' : ''})';
}

/// Imports guides: what Settings → Guide starts, cancels and watches
/// (`EpgImporter` implements it). When to import on its own is the
/// scheduler's business (step 7).
abstract interface class GuideImportService {
  /// Every running import's progress, by source id.
  Stream<(String, EpgImportProgress)> get progress;

  bool isImporting(String sourceId);

  /// Imports [sourceId]'s guide; asking again while one runs joins it.
  Future<Result<EpgImportCounts>> importGuide(String sourceId);

  /// Imports [sourceId]'s guide from the start: a running import read the
  /// old settings (the days kept, the offset), so it is cancelled first
  /// rather than joined (decision 4: a change re-imports).
  Future<Result<EpgImportCounts>> reimport(String sourceId);

  /// Stops [sourceId]'s import, if one runs; the old guide stays.
  Future<void> cancel(String sourceId);

  /// Where [sourceId]'s guide would come from, without fetching it. A
  /// `NotFoundFailure` when it has none (a playlist that names no guide,
  /// with no EPG URL set); a `SecureStorageFailure` when the keyring
  /// can't be read. Never throws.
  Future<Result<GuideOrigin>> guideOrigin(String sourceId);
}
