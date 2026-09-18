import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:iptv_player/core/result.dart';
import 'package:iptv_player/features/sources/domain/provider_account.dart';
import 'package:iptv_player/features/sources/domain/source.dart';

part 'source_check.freezed.dart';

/// What "Test connection" found, for the onboarding result card.
@freezed
abstract class SourceCheck with _$SourceCheck {
  const factory({
    /// The server's host, or the file's name: safe to show.
    required String where,

    /// How long the server took to answer, or the file to open.
    required Duration responseTime,

    /// Xtream only: the account the panel signed in.
    ProviderAccount? account,

    /// M3U only: what the start of the playlist holds.
    PlaylistPreview? playlist,
  }) = _SourceCheck;
}

/// The start of a playlist, read far enough to know it is one. A small
/// playlist is read whole ([complete]); a big one only until the first
/// entries arrive, so the check stays quick.
@freezed
abstract class PlaylistPreview with _$PlaylistPreview {
  const factory({
    required bool complete,
    @Default(0) int entries,
    @Default(0) int live,
    @Default(0) int movies,
    @Default(0) int episodes,

    /// The file's size; null for a URL.
    int? bytes,
  }) = _PlaylistPreview;
}

/// Tries a [SourceDraft] before it is saved: signs in to an Xtream panel,
/// or reads the start of a playlist. Nothing is stored, nothing throws.
abstract interface class SourceChecker {
  /// A wrong password is an `AuthFailure`; a server that can't be reached
  /// a `NetworkFailure` or `TimeoutFailure`; a body that isn't a playlist
  /// a `ParseFailure`; a missing file a `NotFoundFailure`.
  Future<Result<SourceCheck>> check(SourceDraft draft);
}
