import 'package:iptv_player/app/failure_message.dart';
import 'package:iptv_player/core/result.dart';
import 'package:iptv_player/core/text/format.dart';
import 'package:iptv_player/features/sources/domain/provider_account.dart';
import 'package:iptv_player/features/sources/domain/source.dart';
import 'package:iptv_player/features/sources/domain/source_overview.dart';
import 'package:iptv_player/features/sources/domain/sync.dart';

/// How the app words a source's state: Settings → Sources, the top bar's
/// sync status and the expiry banner all say it the same way.

/// An account ending within this many days is flagged in amber and gets
/// the top bar's banner (docs/05: "amber under a week").
const expiryWarningDays = 7;

String sourceTypeLabel(SourceType type) => switch (type) {
  SourceType.xtream => 'Xtream',
  SourceType.m3uUrl => 'M3U URL',
  SourceType.m3uFile => 'M3U file',
};

/// True unless the panel said something other than Active.
bool accountIsActive(ProviderAccount account) {
  final status = account.status?.trim().toLowerCase();
  return status == null || status.isEmpty || status == 'active';
}

/// Days until [account] expires, counted from [now]; negative once it
/// has; null when it doesn't expire.
int? daysToExpiry(ProviderAccount account, DateTime now) {
  final expires = account.expiresAt;
  if (expires == null) return null;
  final left = expires.difference(now);
  return left.isNegative ? -1 : left.inDays;
}

/// `Active · exp Nov 3`, `Expired Nov 3, 2026`, `Banned`.
String accountSummary(ProviderAccount account, DateTime now) {
  final status = account.status?.trim();
  final expires = account.expiresAt;
  final days = daysToExpiry(account, now);
  if (expires != null && days != null && days < 0) {
    return 'Expired ${formatDate(expires)}';
  }
  final sameYear = expires?.toLocal().year == now.toLocal().year;
  final parts = [
    if (status != null && status.isNotEmpty) _capitalized(status),
    if (account.isTrial) 'Trial',
    if (expires != null && sameYear) 'exp ${formatShortDate(expires)}',
    if (expires != null && !sameYear) 'exp ${formatDate(expires)}',
  ];
  return parts.join(' · ');
}

/// `12,340 channels · 8,021 movies · 1,204 series`; empty lists are left
/// out, and nothing at all reads as `No channels, movies or series`.
String countsSummary(SourceCounts counts) {
  final parts = [
    if (counts.channels > 0) _items(counts.channels, 'channel', 'channels'),
    if (counts.movies > 0) _items(counts.movies, 'movie', 'movies'),
    if (counts.series > 0) '${formatCount(counts.series)} series',
  ];
  return parts.isEmpty ? 'No channels, movies or series' : parts.join(' · ');
}

String _items(int count, String one, String many) =>
    '${formatCount(count)} ${count == 1 ? one : many}';

/// The human line for a failed run's stored code.
String syncFailureMessage(String? code) => switch (code) {
  null => failureMessage(UnexpectedFailure()),
  interruptedSyncCode => 'The app was closed before it finished.',
  _ => failureMessage(AppFailure.fromCode(code)),
};

/// The top bar's words for a running sync: `Syncing channels · 12,340`.
String syncProgressLine(SyncProgress progress) => switch (progress.stage) {
  SyncStage.account => 'Signing in',
  SyncStage.categories => 'Syncing categories',
  SyncStage.live => _counted('Syncing channels', progress.channels),
  SyncStage.movies => _counted('Syncing movies', progress.movies),
  SyncStage.series => _counted('Syncing series', progress.series),
  SyncStage.playlist => _counted(
    'Reading the playlist',
    progress.channels + progress.movies + progress.series,
  ),
  SyncStage.finishing => 'Finishing the sync',
};

String _counted(String what, int count) =>
    count == 0 ? what : '$what · ${formatCount(count)}';

String _capitalized(String text) =>
    text.isEmpty ? text : text[0].toUpperCase() + text.substring(1);

/// What the top bar's banner says about the source being browsed, most
/// urgent first; null when all is well.
enum SourceNoticeKind { signInRefused, notActive, expired, expiring }

/// The notice [overview] calls for, if any.
({SourceNoticeKind kind, String message})? sourceNotice(
  Source source,
  SourceOverview overview,
  DateTime now,
) {
  final name = source.name;
  final last = overview.lastSync;
  if (last != null &&
      last.outcome == LastSyncOutcome.failed &&
      last.failureCode == 'auth') {
    return (
      kind: SourceNoticeKind.signInRefused,
      message:
          "$name didn't accept the saved username or password, so the "
          "last sync couldn't sign in.",
    );
  }
  final account = overview.account;
  if (account == null) return null;
  final days = daysToExpiry(account, now);
  if (days != null && days < 0) {
    return (
      kind: SourceNoticeKind.expired,
      message:
          'Your $name subscription expired on '
          '${formatDate(account.expiresAt!)}.',
    );
  }
  if (!accountIsActive(account)) {
    return (
      kind: SourceNoticeKind.notActive,
      message:
          '$name says this account is ${account.status!.trim()}. '
          'Channels may not play until your provider sorts it out.',
    );
  }
  if (days != null && days < expiryWarningDays) {
    final when = switch (days) {
      0 => 'today',
      1 => 'tomorrow',
      _ => 'in $days days',
    };
    return (
      kind: SourceNoticeKind.expiring,
      message:
          'Your $name subscription ends $when '
          '(${formatDate(account.expiresAt!)}). Renew it with your provider '
          'to keep watching.',
    );
  }
  return null;
}
