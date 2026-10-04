import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:iptv_player/core/library/library_item.dart';

part 'download_task.freezed.dart';

/// Where a download is (docs/09): `queued → connecting → downloading ⇄
/// paused → verifying → completed`, plus the waits and the ends.
enum DownloadTaskState {
  queued,
  connecting,
  downloading,
  paused,

  /// Playback or a cast needs the source's connection, or the provider
  /// said it has none free (docs/09 "Connections").
  waitingForConnection,

  /// A network failure, tried again after a wait (docs/09 "Errors").
  retrying,
  verifying,
  completed,
  failed,
  canceled;

  /// Holds, or is about to hold, one of the source's connections.
  bool get isActive => switch (this) {
    connecting || downloading || verifying => true,
    _ => false,
  };

  /// Will run when its turn comes, without the user doing anything.
  bool get isPending => switch (this) {
    queued || retrying || waitingForConnection => true,
    _ => false,
  };

  bool get isFinished => switch (this) {
    completed || failed || canceled => true,
    _ => false,
  };
}

/// Why a download stopped or waits (docs/09 "Errors", the watchdog's
/// classes).
enum DownloadProblem {
  /// No answer, or the connection broke: tried again.
  network,

  /// The provider answered with an error of its own (5xx): tried again.
  server,

  /// 401 / 403: that source's downloads pause, with the account message.
  auth,

  /// 404: "No longer available from your provider".
  notFound,

  /// 429 or the source's connection limit: waits, tried again in 60 s.
  connectionLimit,

  /// Not enough room on the drive: every download pauses (docs/09).
  noSpace,

  /// Writing the file failed.
  diskWrite,

  /// The finished file failed its check: "The download is damaged".
  damaged,
}

/// A download, as the queue and the screens see it (`downloads`, schema
/// v9). Never holds a URL: it is built from the source at every start
/// (docs/09).
@freezed
abstract class DownloadTask with _$DownloadTask {
  const factory({
    required int id,
    required String sourceId,
    required VodType type,

    /// The movie's or the episode's key at its source.
    required String remoteKey,

    /// A movie's title, or an episode's own.
    required String title,

    /// The file it becomes, absolute; `<targetPath>.part` until it is
    /// verified (hard rule 11).
    required String targetPath,
    required DownloadTaskState state,
    required int downloadedBytes,

    /// Its place in the queue: lower runs first.
    required int sortOrder,
    required DateTime createdAt,
    int? year,

    /// An episode's series: its key and its name.
    String? seriesKey,
    String? showTitle,
    int? season,
    int? episode,
    String? artworkUrl,

    /// The whole file's size, once the provider said.
    int? totalBytes,

    /// What a resume's `If-Range` sends: the copy the `.part` holds.
    String? etag,
    String? lastModified,
    DownloadProblem? problem,

    /// The problem's technical detail, redacted, for Details.
    String? problemDetail,

    /// Tries since the last progress.
    @Default(0) int attempts,

    /// The library item it became.
    int? libraryItemId,
    DateTime? completedAt,

    /// Bytes a second right now, while it runs (not stored).
    double? speed,
  }) = _DownloadTask;

  const new _();

  /// 0–1 once the size is known.
  double? get progress => switch (totalBytes) {
    final total? when total > 0 => (downloadedBytes / total).clamp(0.0, 1.0),
    _ => null,
  };

  /// At [speed], how long the rest takes.
  Duration? get timeLeft {
    final total = totalBytes;
    final rate = speed;
    if (total == null || rate == null || rate <= 0) return null;
    final left = total - downloadedBytes;
    if (left <= 0) return Duration.zero;
    return Duration(milliseconds: (left / rate * 1000).round());
  }
}

/// A movie or an episode to download: what it is at its source, and what
/// its file is named after. The URL is built from the source when it
/// runs.
@freezed
abstract class DownloadRequest with _$DownloadRequest {
  const factory({
    required String sourceId,
    required VodType type,
    required String remoteKey,
    required String title,
    int? year,
    String? seriesKey,
    String? showTitle,
    int? season,
    int? episode,
    String? artworkUrl,

    /// The provider's container extension (`mkv`), which the file keeps.
    String? extension,
  }) = _DownloadRequest;
}
