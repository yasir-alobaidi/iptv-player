import 'package:freezed_annotation/freezed_annotation.dart';

part 'xtream_models.freezed.dart';

/// Rows parsed from one list response, and how many were dropped because
/// they had no usable id or weren't objects at all (hard rule 1: skipped
/// and logged, never thrown).
@freezed
abstract class XtreamRows<T> with _$XtreamRows<T> {
  const factory({required List<T> items, @Default(0) int skipped}) =
      _XtreamRows<T>;
}

/// `player_api.php` with no action: the account and the server. Built from
/// an allow-list of fields, so the username and password the panel echoes
/// back in `user_info` never get this far.
@freezed
abstract class XtreamAccount with _$XtreamAccount {
  const factory({
    /// `Active`, `Expired`, `Banned`, `Disabled`, as the panel words it.
    String? status,

    /// Null means no expiry (docs/02).
    DateTime? expiresAt,
    @Default(false) bool isTrial,
    int? activeConnections,
    int? maxConnections,
    DateTime? createdAt,
    @Default(<String>[]) List<String> allowedOutputFormats,

    /// The panel's time zone name, e.g. `Europe/London`.
    String? serverTimezone,

    /// The panel's clock when it answered, for spotting a skewed server.
    DateTime? serverTime,
  }) = _XtreamAccount;
}

extension XtreamAccountStorage on XtreamAccount {
  /// What `sources.account_json` stores: only these fields, so free of
  /// credentials by construction.
  Map<String, Object?> toStoredJson() => {
    'status': status,
    'expires_at': expiresAt?.toIso8601String(),
    'is_trial': isTrial,
    'active_connections': activeConnections,
    'max_connections': maxConnections,
    'created_at': createdAt?.toIso8601String(),
    'allowed_output_formats': allowedOutputFormats,
    'server_timezone': serverTimezone,
    'server_time': serverTime?.toIso8601String(),
  };
}

@freezed
abstract class XtreamCategory with _$XtreamCategory {
  const factory({required String id, required String name}) = _XtreamCategory;
}

@freezed
abstract class XtreamChannel with _$XtreamChannel {
  const factory({
    required String streamId,
    required String name,
    int? number,
    String? iconUrl,
    String? epgChannelId,

    /// As sent: null when missing, possibly pointing at a category the
    /// panel doesn't list. The sync files both under "Uncategorized".
    String? categoryId,
    @Default(0) int archiveDays,
    DateTime? addedAt,
  }) = _XtreamChannel;
}

@freezed
abstract class XtreamMovie with _$XtreamMovie {
  const factory({
    required String streamId,
    required String name,
    int? number,
    String? posterUrl,

    /// Out of 10; null when unrated (panels send 0 or `""`).
    double? rating,
    int? year,

    /// The container extension the stream URL needs, e.g. `mkv`.
    String? ext,
    String? categoryId,
    DateTime? addedAt,
  }) = _XtreamMovie;
}

@freezed
abstract class XtreamSeries with _$XtreamSeries {
  const factory({
    required String seriesId,
    required String name,
    int? number,
    String? posterUrl,
    double? rating,
    int? year,
    String? plot,
    String? genre,
    String? categoryId,

    /// `last_modified`: when it changes, fetched episodes are stale.
    DateTime? lastModified,
  }) = _XtreamSeries;
}

/// `get_vod_info`. Every field can be missing: an unknown movie, or a
/// panel with no metadata, answers `{}` or `info: []`, and the details
/// page shows what there is.
@freezed
abstract class XtreamMovieInfo with _$XtreamMovieInfo {
  const factory({
    String? plot,
    String? cast,
    String? director,
    String? genre,
    int? runtimeMinutes,
    String? backdropUrl,
    String? posterUrl,
    int? year,
    double? rating,
    String? ext,
  }) = _XtreamMovieInfo;
}

@freezed
abstract class XtreamEpisode with _$XtreamEpisode {
  const factory({
    required String id,
    required int season,
    required int episode,
    required String title,
    String? ext,
    int? durationSeconds,
    String? plot,
    String? stillUrl,
  }) = _XtreamEpisode;
}

/// `get_series_info`: its episodes, in season then episode order.
@freezed
abstract class XtreamSeriesInfo with _$XtreamSeriesInfo {
  const factory({
    @Default(<XtreamEpisode>[]) List<XtreamEpisode> episodes,
    @Default(0) int skipped,
  }) = _XtreamSeriesInfo;
}

/// One `get_short_epg` listing, title and description already decoded
/// from base64.
@freezed
abstract class XtreamEpgEntry with _$XtreamEpgEntry {
  const factory({
    required String title,
    required DateTime start,
    required DateTime end,
    String? description,
  }) = _XtreamEpgEntry;
}
