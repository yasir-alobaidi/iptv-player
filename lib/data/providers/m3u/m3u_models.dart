import 'package:freezed_annotation/freezed_annotation.dart';

part 'm3u_models.freezed.dart';

/// What an M3U line points at, from its URL (docs/02): `/movie/` is a
/// movie, `/series/` an episode, a video-file extension a movie, anything
/// else live. Xtream `m3u_plus` exports mix all three.
enum M3uKind { live, movie, episode }

/// One playable line of a playlist.
@freezed
abstract class M3uEntry with _$M3uEntry {
  const factory({
    /// The stable identity: a hash of `tvg-id`, the name and the URL path
    /// without credentials, so favourites and history survive a refresh
    /// and a password change. The entry's `remote_key`.
    required String identity,
    required M3uKind kind,
    required String name,

    /// With the source's credentials replaced by `{username}`-style
    /// placeholders (`M3uCredentials`), never the real values.
    required String streamUrl,

    /// Its position in the playlist, from 0.
    required int position,
    String? tvgId,
    String? tvgName,
    String? logoUrl,

    /// `group-title`, or `#EXTGRP` when there is none.
    String? group,
    int? channelNumber,

    /// `catchup`: `default`, `append`, `shift`, `flussonic`, `xc`…
    String? catchup,
    int? catchupDays,
    String? catchupSource,

    /// From `#EXTVLCOPT` lines just before the URL.
    String? userAgent,
    String? referrer,

    /// For episodes whose name says so (`Dark S01 E02`).
    String? seriesName,
    int? season,
    int? episode,
  }) = _M3uEntry;
}

/// What a whole playlist came to.
@freezed
abstract class M3uSummary with _$M3uSummary {
  const factory({
    /// `url-tvg` / `x-tvg-url` / `tvg-url` from the `#EXTM3U` line; a
    /// comma-separated list is split. Credentials in them are left as
    /// sent: the caller keeps these in the secure store (ADR-009).
    @Default(<String>[]) List<String> epgUrls,
    @Default(0) int entries,
    @Default(0) int live,
    @Default(0) int movies,
    @Default(0) int episodes,

    /// Lines that couldn't become an entry: an `#EXTINF` with no URL, a
    /// URL that isn't one, a repeated identity.
    @Default(0) int skipped,
  }) = _M3uSummary;
}
