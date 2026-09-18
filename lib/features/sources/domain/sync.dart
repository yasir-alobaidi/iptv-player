import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:iptv_player/core/result.dart';
import 'package:iptv_player/features/sources/domain/provider_account.dart';

part 'sync.freezed.dart';

/// Where a sync is. Xtream goes account → categories → live → movies →
/// series; an M3U playlist is one stage, since live, movies and episodes
/// arrive mixed in one file. `finishing` removes what the run didn't see.
enum SyncStage {
  account,
  categories,
  live,
  movies,
  series,
  playlist,
  finishing,
}

/// One progress event, as the onboarding sync screen shows it ("Movies
/// 8,021 of about 13,800", docs/05). Counts are what the run has written
/// so far.
@freezed
abstract class SyncProgress with _$SyncProgress {
  const factory({
    required SyncStage stage,

    /// Set once the account stage is done (Xtream only).
    ProviderAccount? account,
    @Default(0) int categories,
    @Default(0) int channels,
    @Default(0) int movies,
    @Default(0) int series,
    @Default(0) int episodes,

    /// How many rows the current stage will write, once the list is in;
    /// null while it downloads, and throughout an M3U playlist, whose
    /// length is only known at its end.
    int? stageTotal,
  }) = _SyncProgress;
}

/// What a finished sync wrote and removed.
@freezed
abstract class SyncReport with _$SyncReport {
  const factory({
    @Default(0) int categories,
    @Default(0) int channels,
    @Default(0) int movies,
    @Default(0) int series,
    @Default(0) int episodes,

    /// Rows the provider sent that couldn't be used (hard rule 1).
    @Default(0) int skipped,

    /// Items and categories deleted because the provider no longer has
    /// them.
    @Default(0) int removed,
    @Default(Duration.zero) Duration duration,
  }) = _SyncReport;
}

/// A source's sync, as the UI follows it.
@immutable
sealed class SyncStatus {
  const new();
}

/// No sync has run this session.
final class SyncIdle extends SyncStatus {
  const new();
}

final class SyncRunning extends SyncStatus {
  const new(this.progress);

  final SyncProgress progress;
}

final class SyncSucceeded extends SyncStatus {
  const new(this.report);

  final SyncReport report;
}

/// The run failed and the previous data is still there. The UI phrases
/// [failure] with `failureMessage()` and offers Retry.
final class SyncFailed extends SyncStatus {
  const new(this.failure);

  final AppFailure failure;
}

final class SyncCancelled extends SyncStatus {
  const new();
}

/// Keeps each source's catalogue in step with its provider (docs/02 "Sync
/// engine"). The work runs in a background isolate with its own database
/// connection; this side only starts, follows and finishes it.
///
/// - **One sync per source at a time:** [sync] on a source that is already
///   syncing joins the run in progress.
/// - **A failed or cancelled sync keeps the previous data.** Items are only
///   removed at the end of a run that succeeded.
/// - Nothing throws across this boundary.
abstract interface class SyncService {
  /// The source's status now, then every change.
  Stream<SyncStatus> watch(String sourceId);

  SyncStatus statusOf(String sourceId);

  /// Syncs the source, or joins its sync in progress.
  Future<Result<SyncReport>> sync(String sourceId);

  /// Stops the source's sync; its [sync] future completes with a
  /// `CancelledFailure`. Does nothing when none is running.
  Future<void> cancel(String sourceId);

  /// Removes the source for good, with its catalogue and its secrets.
  /// Stops its sync first, so no run is left writing rows for a source
  /// that is gone; a sync asked for meanwhile fails as not found. The UI
  /// removes sources through this, never through `SourceRepository`.
  Future<Result<void>> removeSource(String sourceId);

  /// Once on launch: records runs the last session left unfinished as
  /// failed, then syncs, one after another, every source whose data is
  /// older than its `refresh_hours`.
  Future<void> startUp();
}
