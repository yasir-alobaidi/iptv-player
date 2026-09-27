import 'package:iptv_player/core/text/format.dart';
import 'package:iptv_player/features/guide/domain/epg.dart';

/// When the scheduler refreshes a source's guide (ADR-011 decision 5).
abstract final class GuideRefreshPolicy {
  /// A guide older than this is imported again.
  static const staleAfter = Duration(hours: 24);

  /// An import that failed or was cancelled isn't tried again by the
  /// scheduler for this long; Refresh guide in Settings still tries at
  /// once. One the app was closed during is tried at the next check.
  static const retryAfter = Duration(hours: 6);

  /// How often the scheduler looks, after its check at launch.
  static const checkEvery = Duration(hours: 1);
}

/// Whether the scheduler should import [coverage]'s source's guide at
/// [now]: it has none, or the one in use arrived [staleAfter] ago or
/// more — unless an import is running, or the last one failed or was
/// cancelled less than [retryAfter] ago (then a panel that is down isn't
/// asked every hour).
bool guideRefreshDue(
  GuideCoverage coverage,
  DateTime now, {
  Duration staleAfter = GuideRefreshPolicy.staleAfter,
  Duration retryAfter = GuideRefreshPolicy.retryAfter,
}) {
  final updated = coverage.updatedAt;
  if (updated != null && now.difference(updated) < staleAfter) return false;
  final last = coverage.lastImport;
  if (last == null) return true;
  switch (last.outcome) {
    case GuideImportOutcome.running:
      return false;
    case GuideImportOutcome.failed
        when last.failureCode == interruptedImportCode:
      return true;
    case GuideImportOutcome.failed || GuideImportOutcome.cancelled:
      return now.difference(last.startedAt) >= retryAfter;
    case GuideImportOutcome.succeeded:
      return true;
  }
}

/// The toast after a guide the scheduler imported (docs/05): "Guide
/// updated · 142 channels matched", with the source's name when there
/// are several. [matched] counts the channels the user can see, as
/// Settings → Guide does.
String guideUpdatedMessage(int matched, {String? source}) {
  final count = matched == 1 ? '1 channel' : '${formatCount(matched)} channels';
  return ['Guide updated', ?source, '$count matched'].join(' · ');
}
