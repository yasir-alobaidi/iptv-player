/// What moves a download's bytes, and what it says (Phase 8 decision 2):
/// the queue (the app's isolate) orders, the runner (the downloads
/// isolate) answers. Plain classes, sendable between isolates: nothing
/// here may import Flutter, or the SIGKILL test's `dart run` victim stops
/// compiling.
library;

/// Moves downloads' bytes: one connection per started download, the URL
/// asked for through [DownloadRunner.start]'s `upstream` on every
/// connection. What each says comes on [news], ending with
/// [DownloadDone], [DownloadHalted] or [DownloadFailedNews].
abstract interface class DownloadRunner {
  Stream<DownloadNews> get news;

  /// Starts [order] (one attempt).
  Future<void> start(
    DownloadOrder order, {
    required Future<DownloadUpstream?> Function() upstream,
  });

  /// Stops [id]: its `.part` flushed and closed. Completes once it has
  /// said [DownloadHalted] (or had already ended).
  Future<void> stop(int id);

  /// Stops everything (the app quits).
  Future<void> close();
}

/// A provider's answer that ends a download, or the network's.
enum DownloadEnd {
  /// No answer, a broken connection, a body shorter than it said: tried
  /// again later.
  network,

  /// 5xx, or an answer that makes no sense: tried again later.
  server,

  /// 401, or a 403 that isn't about connections.
  auth,

  /// 404 / 410: the title is gone.
  notFound,

  /// 429, or a 403 saying the account's connections are in use.
  connectionLimit,

  /// The file couldn't be written.
  diskWrite,

  /// The app had no URL for it (the title or its source is gone).
  unresolved,
}

/// Where a download reads from: asked for on every connection, built from
/// the source each time (docs/09).
final class DownloadUpstream {
  const new({required this.url, this.userAgent, this.hls = false});

  /// Carries credentials: never logged unredacted.
  final String url;
  final String? userAgent;

  /// The source says this is HLS (an M3U line), before any answer does.
  final bool hls;

  @override
  String toString() => 'DownloadUpstream(hls: $hls)';
}

/// What starts a download in the isolate.
final class DownloadOrder {
  const new({
    required this.id,
    required this.sourceId,
    required this.partPath,
    this.etag,
    this.lastModified,
    this.total,
    this.bytesPerSecond,
    this.maxConnections = 1,
  });

  final int id;
  final String sourceId;

  /// `<final name>.part`: written to, never the final name (hard rule
  /// 11).
  final String partPath;

  /// The validators of the copy the `.part` holds, for `If-Range`.
  final String? etag;
  final String? lastModified;

  /// The whole file's size, when an earlier answer said.
  final int? total;

  /// The speed limit; null is none.
  final int? bytesPerSecond;

  /// The source's connections, for an HLS item's segments.
  final int maxConnections;
}

/// Something a download reports.
sealed class DownloadNews {
  const new(this.id);

  final int id;
}

/// The provider answered and bytes are coming. [restarted]: the `.part`
/// was emptied first (a 200 to a resume, a changed file).
final class DownloadOpened extends DownloadNews {
  const new(
    super.id, {
    required this.bytes,
    this.total,
    this.etag,
    this.lastModified,
    this.restarted = false,
    this.hls = false,
  });

  /// What the `.part` holds as the body begins.
  final int bytes;
  final int? total;
  final String? etag;
  final String? lastModified;
  final bool restarted;

  /// Saved with FFmpeg from a playlist: no resume, no size known.
  final bool hls;
}

/// How far it is: [bytes] written, [durable] of them flushed to disk.
final class DownloadMoved extends DownloadNews {
  const new(super.id, {required this.bytes, required this.durable});

  final int bytes;
  final int durable;
}

/// The whole file is in the `.part`.
final class DownloadDone extends DownloadNews {
  const new(super.id, {required this.bytes, this.total});

  final int bytes;
  final int? total;
}

/// Stopped as asked: the `.part` is flushed and closed at [bytes].
final class DownloadHalted extends DownloadNews {
  const new(super.id, {required this.bytes});

  final int bytes;
}

/// It ended short of the whole file.
final class DownloadFailedNews extends DownloadNews {
  const new(
    super.id,
    this.end, {
    required this.bytes,
    this.status,
    this.detail,
  });

  final DownloadEnd end;

  /// What the `.part` holds now.
  final int bytes;
  final int? status;

  /// Redacted.
  final String? detail;
}
