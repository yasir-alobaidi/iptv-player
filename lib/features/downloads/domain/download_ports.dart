import 'package:iptv_player/core/downloads/download_runner.dart';
import 'package:iptv_player/core/downloads/download_task.dart';
import 'package:meta/meta.dart';

/// Where the queue keeps its downloads (`downloads`, schema v9).
abstract interface class DownloadStore {
  /// Every download, in the queue's order.
  Future<List<DownloadTask>> all();

  /// Adds [request] at the end of the queue, to become [targetPath]; the
  /// new download, or null when the title is already in the queue.
  Future<DownloadTask?> add(
    DownloadRequest request, {
    required String targetPath,
    required DateTime at,
  });

  /// Writes [task]'s state, progress, problem, validators and result.
  Future<void> save(DownloadTask task);

  Future<void> remove(int id);

  /// Puts [id] at [index]; the queue's order after it.
  Future<List<DownloadTask>> move(int id, int index);
}

/// Whether a download has a way to its provider now.
@immutable
sealed class DownloadSourceAnswer {
  const new();
}

/// A download's way to its provider: the URL, built afresh, and how many
/// connections the source allows.
final class DownloadSource extends DownloadSourceAnswer {
  const new(this.upstream, {required this.maxConnections});

  final DownloadUpstream upstream;
  final int maxConnections;
}

/// The title is no longer in the catalogue, or its source was removed.
final class DownloadSourceGone extends DownloadSourceAnswer {
  const new([this.detail]);

  final String? detail;
}

/// Something that may pass: the keyring is locked, the database busy.
final class DownloadSourceUnavailable extends DownloadSourceAnswer {
  const new([this.detail]);

  final String? detail;
}

/// The catalogue's side of downloads: the URL of a title, and where new
/// downloads go.
abstract interface class DownloadTitles {
  /// [task]'s stream, built from its source now (docs/09: never stored).
  Future<DownloadSourceAnswer> source(DownloadTask task);

  /// The download folder now.
  Future<String> folder();

  /// Whether the library already holds [request]'s title as a file.
  Future<bool> downloaded(DownloadRequest request);
}

/// How finishing a download went.
sealed class DownloadFinish {
  const new();
}

/// Verified and renamed; it is the library item [libraryItemId].
final class DownloadFinished extends DownloadFinish {
  const new(this.libraryItemId, {required this.bytes});

  final int libraryItemId;
  final int bytes;
}

/// The file failed its check (docs/09: "The download is damaged"); its
/// `.part` is gone.
final class DownloadDamaged extends DownloadFinish {
  const new(this.detail);

  final String detail;
}

/// It couldn't be renamed or added (a disk error); the `.part` stays.
final class DownloadNotFinished extends DownloadFinish {
  const new(this.detail);

  final String detail;
}

/// The files' side of downloads: verification, the final name, the
/// library item (docs/09 "DownloadFinalizer").
abstract interface class DownloadFinisher {
  /// Checks [task]'s `.part`, renames it, saves its artwork and details,
  /// and adds it to the library.
  Future<DownloadFinish> finish(DownloadTask task);

  /// Deletes [task]'s `.part`, if any (a cancel, a damaged file).
  Future<void> discard(DownloadTask task);

  /// What [task]'s `.part` holds on disk now: the truth after a crash
  /// (docs/09).
  Future<int> partSize(DownloadTask task);
}

/// What the queue tells the screens, beside the list itself.
@immutable
sealed class DownloadNotice {
  const new();
}

/// Playback or a cast took the connection a download had: docs/05's
/// "Downloads paused while you watch — your provider allows 1
/// connection." Once a viewing.
final class DownloadsWaitForPlayback extends DownloadNotice {
  const new(this.sourceId, {required this.maxConnections});

  final String sourceId;
  final int maxConnections;
}

/// docs/05's "Download finished · <title>", with Play.
final class DownloadFinishedNotice extends DownloadNotice {
  const new(this.task);

  final DownloadTask task;
}

/// Every download paused: the drive has less than the next one needs
/// plus 1 GB (docs/09).
final class DownloadsNeedSpace extends DownloadNotice {
  const new({required this.neededBytes, required this.folder});

  /// What would have to be freed.
  final int neededBytes;
  final String folder;
}

/// The provider refused the source's sign-in: its downloads pause.
final class DownloadsAccountRefused extends DownloadNotice {
  const new(this.sourceId);

  final String sourceId;
}
