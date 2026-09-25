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
