import 'dart:async';

import 'package:iptv_player/app/router.dart';
import 'package:iptv_player/app/shell/shell_state.dart';
import 'package:iptv_player/core/core_providers.dart';
import 'package:iptv_player/features/settings/presentation/settings_section.dart';
import 'package:iptv_player/features/sources/data/source_providers.dart';
import 'package:iptv_player/features/sources/domain/source_overview.dart';
import 'package:iptv_player/features/sources/domain/sync.dart';
import 'package:iptv_player/features/sources/presentation/current_source.dart';
import 'package:iptv_player/features/sources/presentation/source_text.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'source_shell_slots.g.dart';

/// The shell's source and sync slots, filled from this feature (ADR-008:
/// the shell stays free of domain state; the feature that owns the data
/// overrides its providers). `bootstrap()` applies these.
List<Override> get sourceShellOverrides => [
  shellSourceProvider.overrideWith((ref) => ref.watch(sourceChipProvider)),
  shellSourceChoicesProvider.overrideWith(
    (ref) => ref.watch(sourceSwitcherProvider),
  ),
  shellSyncStatusProvider.overrideWith(
    (ref) => ref.watch(sourceSyncLineProvider),
  ),
  shellNoticeProvider.overrideWith((ref) => ref.watch(sourceBannerProvider)),
];

/// The chip: the current source, green while its last sync worked and
/// its account is usable, amber otherwise.
@riverpod
ShellSource? sourceChip(Ref ref) {
  final source = ref.watch(currentSourceProvider);
  if (source == null) return null;
  final overview = ref.watch(sourceOverviewProvider(source.id)).value;
  final now = ref.watch(appClockProvider)();
  return ShellSource(
    id: source.id,
    name: source.name,
    connected: overview == null || _healthy(overview, now),
  );
}

bool _healthy(SourceOverview overview, DateTime now) {
  if (overview.lastSync?.outcome == LastSyncOutcome.failed) return false;
  final account = overview.account;
  if (account == null) return true;
  final days = daysToExpiry(account, now);
  return accountIsActive(account) && (days == null || days >= 0);
}

/// Every source, for the switcher; null below two.
@riverpod
ShellSourceChoices? sourceSwitcher(Ref ref) {
  final sources = ref.watch(sourcesProvider).value ?? const [];
  if (sources.length < 2) return null;
  // Read now: a callback must not use a ref that may be disposed by the
  // time it runs. The notifiers are kept alive.
  final chosen = ref.read(chosenSourceIdProvider.notifier);
  return ShellSourceChoices(
    sources: [
      for (final source in sources)
        ShellSource(id: source.id, name: source.name, connected: true),
    ],
    onSelect: chosen.choose,
  );
}

/// "Syncing channels · 12,340" while any source syncs; with more than
/// one source, the line names which.
@riverpod
ShellSyncStatus? sourceSyncLine(Ref ref) {
  final sources = ref.watch(sourcesProvider).value ?? const [];
  for (final source in sources) {
    if (ref.watch(syncStatusProvider(source.id)).value case SyncRunning(
      :final progress,
    )) {
      final line = syncProgressLine(progress);
      return ShellSyncStatus(
        message: sources.length > 1 ? '${source.name} · $line' : line,
        busy: true,
      );
    }
  }
  return null;
}

/// The notices the user closed this session, by source and kind. A new
/// launch shows them again: an expiring subscription is worth one
/// reminder a session.
@Riverpod(keepAlive: true)
class DismissedSourceNotices extends _$DismissedSourceNotices {
  @override
  Set<(String, SourceNoticeKind)> build() => const {};

  void dismiss(String sourceId, SourceNoticeKind kind) =>
      state = {...state, (sourceId, kind)};
}

/// The banner for the current source: sign-in refused, account not
/// active, expired, or expiring within a week.
@riverpod
ShellNotice? sourceBanner(Ref ref) {
  final source = ref.watch(currentSourceProvider);
  if (source == null) return null;
  final overview = ref.watch(sourceOverviewProvider(source.id)).value;
  if (overview == null) return null;
  final notice = sourceNotice(source, overview, ref.watch(appClockProvider)());
  if (notice == null) return null;
  if (ref.watch(dismissedSourceNoticesProvider).contains((
    source.id,
    notice.kind,
  ))) {
    return null;
  }

  // Read now, for the same reason as the switcher's callback.
  final router = ref.read(routerProvider);
  final location = ref.read(settingsLocationProvider.notifier);
  final dismissed = ref.read(dismissedSourceNoticesProvider.notifier);
  final refused = notice.kind == SourceNoticeKind.signInRefused;
  return ShellNotice(
    message: notice.message,
    tone: switch (notice.kind) {
      SourceNoticeKind.expiring => ShellNoticeTone.warning,
      _ => ShellNoticeTone.error,
    },
    actionLabel: refused ? 'Edit source' : 'Open Sources',
    onAction: refused
        ? () => unawaited(router.push<void>(editSourcePath(source.id)))
        : () => openSettings(router, location, SettingsSection.sources),
    onDismiss: () => dismissed.dismiss(source.id, notice.kind),
  );
}
