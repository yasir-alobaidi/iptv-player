import 'package:flutter/foundation.dart';
import 'package:iptv_player/features/guide/domain/epg_matcher.dart';

/// What one match run attached for a source: the log says it after every
/// run, and Settings → Guide will ("1,284 of 1,310 channels matched").
/// Plain values, so it crosses isolates.
@immutable
final class EpgMatchSummary {
  const new({
    required this.channels,
    this.byRule = const {},
    this.guideChannels = 0,
    this.skipped = 0,
  });

  /// The source's channels the run read, [skipped] ones included.
  final int channels;

  /// How many channels each rule attached. A channel counts under the one
  /// rule that matched it, so the values add up to [matched].
  final Map<GuideMatchRule, int> byRule;

  /// The guide channels the run matched against; 0 when the source has no
  /// guide (only the user's mappings can match then).
  final int guideChannels;

  /// Channels left unmatched because their row could not be read or the
  /// matcher failed on it (hard rule 1): counted, never thrown.
  final int skipped;

  int get matched => byRule.values.fold(0, (sum, n) => sum + n);

  int get unmatched => channels - matched;

  int of(GuideMatchRule rule) => byRule[rule] ?? 0;

  @override
  bool operator ==(Object other) =>
      other is EpgMatchSummary &&
      other.channels == channels &&
      mapEquals(other.byRule, byRule) &&
      other.guideChannels == guideChannels &&
      other.skipped == skipped;

  @override
  int get hashCode => Object.hash(
    channels,
    Object.hashAll([for (final rule in GuideMatchRule.values) of(rule)]),
    guideChannels,
    skipped,
  );

  /// Counts only: never a channel's name or a guide id.
  @override
  String toString() {
    final rules = [
      for (final rule in GuideMatchRule.values) '${rule.name} ${of(rule)}',
    ].join(', ');
    return '$matched of $channels channels matched against $guideChannels '
        'guide channels ($rules)${skipped == 0 ? '' : '; $skipped skipped'}';
  }
}
