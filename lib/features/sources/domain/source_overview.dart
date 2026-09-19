import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:iptv_player/features/sources/domain/provider_account.dart';

part 'source_overview.freezed.dart';

/// How a source's latest sync run ended, as Settings → Sources shows it.
enum LastSyncOutcome { running, succeeded, failed, cancelled }

/// The failure code a run gets when the app closed before it finished.
const interruptedSyncCode = 'interrupted';

/// The source's latest sync run, whatever its outcome.
@freezed
abstract class LastSync with _$LastSync {
  const factory({
    required LastSyncOutcome outcome,
    required DateTime startedAt,
    DateTime? finishedAt,

    /// An `AppFailure.code`, or [interruptedSyncCode]; null unless the run
    /// failed. The UI phrases it; it is never raw exception text.
    String? failureCode,

    /// The HTTP status the server answered the failed run with, if any.
    int? failureStatus,
  }) = _LastSync;
}

/// What a source holds right now.
@freezed
abstract class SourceCounts with _$SourceCounts {
  const factory({
    @Default(0) int channels,
    @Default(0) int movies,
    @Default(0) int series,
  }) = _SourceCounts;

  const new _();

  bool get isEmpty => channels == 0 && movies == 0 && series == 0;
}

/// Everything Settings → Sources and the top bar say about a source
/// besides the `Source` itself: the account the panel reported, what is
/// in the database, and how the latest sync went.
@freezed
abstract class SourceOverview with _$SourceOverview {
  const factory({
    /// Xtream only, from the latest sign-in; null for a playlist or before
    /// the first sync.
    ProviderAccount? account,
    @Default(SourceCounts()) SourceCounts counts,
    LastSync? lastSync,
  }) = _SourceOverview;
}

/// Reads [SourceOverview]s. Nothing throws across this boundary; a
/// stream's error is an `AppFailure`.
abstract interface class SourceOverviewRepository {
  /// The overview now, then again whenever a sync starts or ends or the
  /// account changes. Null once the source is gone.
  Stream<SourceOverview?> watch(String sourceId);
}
