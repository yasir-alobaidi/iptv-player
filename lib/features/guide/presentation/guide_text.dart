import 'package:iptv_player/app/failure_message.dart';
import 'package:iptv_player/core/result.dart';
import 'package:iptv_player/core/text/format.dart';
import 'package:iptv_player/features/guide/domain/epg.dart';
import 'package:iptv_player/features/guide/domain/epg_matcher.dart';
import 'package:iptv_player/features/guide/domain/guide_matching.dart';

/// Every phrase Settings → Guide uses about a guide, in one place (like
/// `source_text.dart` for sources).

/// Where the guide comes from: "From your provider's XMLTV".
String guideOriginLabel(GuideOrigin origin) => switch (origin.kind) {
  GuideOriginKind.panel => "From your provider's XMLTV",
  GuideOriginKind.sourceUrl =>
    origin.isFile
        ? 'From the guide file set for this source'
        : 'From the EPG URL set for this source',
  GuideOriginKind.playlist =>
    origin.isFile
        ? 'From the guide file your playlist names'
        : 'From the EPG URL your playlist names',
};

/// "1,284 of 1,310 channels matched", "All 12 channels matched".
String matchedLine(ChannelMatchCounts counts) {
  if (counts.channels == 0) return 'No channels to match yet';
  if (counts.unmatched == 0) {
    return counts.channels == 1
        ? 'Its one channel is matched'
        : 'All ${formatCount(counts.channels)} channels matched';
  }
  return '${formatCount(counts.matched)} of ${formatCount(counts.channels)} '
      '${counts.channels == 1 ? 'channel' : 'channels'} matched';
}

/// "142,880 programmes until Sep 28"; empty when the guide holds none.
String coverageLine(GuideCoverage coverage) {
  if (coverage.programmes == 0) return '';
  final count =
      '${formatCount(coverage.programmes)} '
      '${coverage.programmes == 1 ? 'programme' : 'programmes'}';
  final end = coverage.lastEnd;
  return end == null ? count : '$count until ${formatShortDate(end)}';
}

/// The human line for a failed import's stored code, with what the
/// server answered when it answered with an HTTP status.
String importFailureMessage(GuideImport import) => switch (import.failureCode) {
  null => failureMessage(UnexpectedFailure()),
  interruptedImportCode => 'The app was closed before it finished.',
  final code => failureWithAnswer(
    AppFailure.fromCode(code, statusCode: import.failureStatus),
  ),
};

/// A running import, for the progress line: "Importing the guide ·
/// 12.4 MB of 80.0 MB · 1,204 programmes".
String importProgressLine(EpgImportProgress? progress) {
  if (progress == null || progress.bytesRead == 0) {
    return 'Importing the guide…';
  }
  final total = progress.totalBytes;
  final read = total == null || total <= 0
      ? formatBytes(progress.bytesRead)
      : '${formatBytes(progress.bytesRead)} of ${formatBytes(total)}';
  final programmes = progress.programmes == 0
      ? ''
      : ' · ${formatCount(progress.programmes)} '
            '${progress.programmes == 1 ? 'programme' : 'programmes'}';
  return 'Importing the guide · $read$programmes';
}

/// "1 day", "7 days".
String keepDaysLabel(int days) => days == 1 ? '1 day' : '$days days';

/// A guide time offset in words: "None", "+1 h", "−30 min",
/// "+1 h 30 min". The minus is a real minus sign.
String guideOffsetLabel(int minutes) {
  if (minutes == 0) return 'None';
  final sign = minutes < 0 ? '−' : '+';
  final size = minutes.abs();
  final hours = size ~/ 60;
  final rest = size % 60;
  final parts = [if (hours > 0) '$hours h', if (rest > 0) '$rest min'];
  return '$sign${parts.join(' ')}';
}

/// What a channel is attached to, for its row and the picker:
/// "No guide channel", "→ BBC One · by name", "→ bbc1.uk · yours, not in
/// this guide".
String matchStatus(ChannelGuideMatch channel) {
  final id = channel.xmltvId;
  if (id == null) return 'No guide channel';
  final target = channel.guideLabel ?? id;
  final how = switch (channel.rule) {
    GuideMatchRule.manual =>
      channel.inGuide ? 'yours' : 'yours, not in this guide',
    GuideMatchRule.exactId || GuideMatchRule.caseInsensitiveId => 'by id',
    GuideMatchRule.normalizedName => 'by name',
    null => 'matched',
  };
  return '→ $target · $how';
}

/// A match the user chose that couldn't be saved.
String matchNotSaved(AppFailure failure) =>
    "Couldn't save that match. ${failureMessage(failure)}";

/// A match that was saved, but the source's channels couldn't be matched
/// again, so the rest of the app doesn't show it yet.
String matchNotApplied(AppFailure failure) =>
    "Your match is saved, but the channels couldn't be matched again. "
    '${failureMessage(failure)}';

// The Guide screen (Phase 4 step 6).

/// A programme's time in its Guide cell, as wide as the cell allows:
/// "8:00 – 10:00 PM", "8:00 – 10:00", then "8:00".
String guideCellTime(
  EpgProgramme programme, {
  required bool full,
  required bool range,
}) {
  if (full) return formatTimeRange(programme.start, programme.end);
  if (range) return formatTimeRangeShort(programme.start, programme.end);
  return formatClockShort(programme.start);
}

/// When a programme is on, relative to [now]: "on now", "ended", or
/// nothing for one to come. For screen readers, after its title and time.
String? guideProgrammeState(EpgProgramme programme, DateTime now) {
  if (!programme.end.isAfter(now)) return 'ended';
  if (!programme.start.isAfter(now)) return 'on now';
  return null;
}

/// The detail sheet's line under the title: "Today · 8:00 – 10:00 PM ·
/// Sport".
String programmeSheetMeta(EpgProgramme programme, DateTime now) => [
  formatRelativeDay(programme.start, now),
  formatTimeRange(programme.start, programme.end),
  if (programme.category?.trim().isNotEmpty ?? false) programme.category!,
].join(' · ');

/// [day] inside a sentence, from [now]: "today", "tomorrow",
/// "yesterday", else "on Thu Sep 17".
String dayInSentence(DateTime day, DateTime now) {
  final word = formatRelativeDay(day, now);
  return switch (word) {
    'Today' || 'Tomorrow' || 'Yesterday' => word.toLowerCase(),
    _ => 'on $word',
  };
}

/// "Arena Sports 1 · 201".
String guideChannelLine(String name, int? number) =>
    number == null ? name : '$name · $number';

/// The Guide toolbar's line about a refresh that failed while an older
/// guide stays in use: "Offline · guide from 2 h ago".
String guideStaleLine(GuideCoverage coverage, DateTime now) {
  final code = coverage.lastImport?.failureCode;
  final offline = code != null && AppFailure.fromCode(code) is NetworkFailure;
  final updated = coverage.updatedAt;
  final age = updated == null ? '' : ' · guide from ${formatAgo(updated, now)}';
  return '${offline ? 'Offline' : "Couldn't refresh"}$age';
}
