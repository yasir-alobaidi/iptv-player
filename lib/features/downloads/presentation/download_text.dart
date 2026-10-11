/// The Downloads tab's words (canvas `Library · Downloads`, docs/09).
library;

import 'package:iptv_player/core/downloads/download_task.dart';
import 'package:iptv_player/core/library/library_item.dart';
import 'package:iptv_player/core/text/format.dart';
import 'package:iptv_player/features/library/presentation/library_text.dart';

/// Where a download is listed.
enum DownloadSection {
  /// Running, waiting its turn, or paused by the user.
  inProgress,

  /// Failed, or stopped by something only the user can put right.
  needsAttention,

  /// Finished today.
  finished,
}

/// The section [task] is listed in; null for one not listed (finished on
/// an earlier day: it is in the Library).
DownloadSection? downloadSectionOf(DownloadTask task, DateTime now) {
  switch (task.state) {
    case DownloadTaskState.completed:
      final at = task.completedAt?.toLocal();
      final today = now.toLocal();
      return at != null &&
              at.year == today.year &&
              at.month == today.month &&
              at.day == today.day
          ? DownloadSection.finished
          : null;
    case DownloadTaskState.canceled:
      return null;
    case DownloadTaskState.failed:
      return DownloadSection.needsAttention;
    case DownloadTaskState.paused:
      return switch (task.problem) {
        DownloadProblem.auth ||
        DownloadProblem.noSpace => DownloadSection.needsAttention,
        _ => DownloadSection.inProgress,
      };
    case DownloadTaskState.queued ||
        DownloadTaskState.connecting ||
        DownloadTaskState.downloading ||
        DownloadTaskState.waitingForConnection ||
        DownloadTaskState.retrying ||
        DownloadTaskState.verifying:
      return DownloadSection.inProgress;
  }
}

/// A row's title: the movie, or the episode's show.
String downloadTitle(DownloadTask task) =>
    task.type == VodType.episode ? task.showTitle ?? task.title : task.title;

/// Beside the title: "Movie · 2025", "S2 · E5 · Northbound".
String downloadSubtitle(DownloadTask task) {
  if (task.type == VodType.movie) {
    return ['Movie', if (task.year case final year?) '$year'].join(' · ');
  }
  return [
    if (task.season case final season?) 'S$season',
    if (task.episode case final episode?) 'E$episode',
    if (task.showTitle != null && task.title != task.showTitle) task.title,
  ].join(' · ');
}

/// The whole name, for a toast or a screen reader: "Glass Tide · S2 · E5
/// · Northbound", "Copper Hollow".
String downloadName(DownloadTask task) => task.type == VodType.movie
    ? task.title
    : [
        downloadTitle(task),
        downloadSubtitle(task),
      ].where((part) => part.isNotEmpty).join(' · ');

/// "8.4 MB/s", "640 KB/s".
String downloadSpeed(double bytesPerSecond) {
  const mb = 1024 * 1024;
  if (bytesPerSecond >= mb) {
    return '${(bytesPerSecond / mb).toStringAsFixed(1)} MB/s';
  }
  return '${(bytesPerSecond / 1024).round()} KB/s';
}

/// "about 2 min left", "about 1 h 20 min left", "less than a minute left".
String downloadTimeLeft(Duration left) => left < const Duration(minutes: 1)
    ? 'less than a minute left'
    : 'about ${formatTimeLeft(left)}';

/// "1.0 GB of 2.1 GB", or what has arrived when the size isn't known.
String downloadSizeSoFar(DownloadTask task) => switch (task.totalBytes) {
  final total? when total > 0 =>
    '${librarySize(task.downloadedBytes)} of ${librarySize(total)}',
  _ => librarySize(task.downloadedBytes),
};

/// The bold word a row's line under the bar starts with: "49%" while it
/// downloads, else what it is doing.
String downloadStateWord(DownloadTask task) => switch (task.state) {
  DownloadTaskState.downloading => switch (task.progress) {
    final progress? => '${(progress * 100).floor()}%',
    null => 'Downloading',
  },
  DownloadTaskState.queued => 'Queued',
  DownloadTaskState.connecting => 'Connecting',
  DownloadTaskState.paused => 'Paused',
  DownloadTaskState.waitingForConnection => 'Waiting',
  DownloadTaskState.retrying => 'Trying again',
  DownloadTaskState.verifying => 'Checking the file',
  DownloadTaskState.completed => 'Downloaded',
  DownloadTaskState.failed => 'Failed',
  DownloadTaskState.canceled => 'Canceled',
};

/// The rest of that line (canvas: "1.0 GB of 2.1 GB · 8.4 MB/s · about 2
/// min left"; "starts after Copper Hollow · 0.9 GB"). [before] is the
/// download ahead of a queued one.
List<String> downloadStateDetails(DownloadTask task, {DownloadTask? before}) {
  final size = switch (task.totalBytes) {
    final total? when total > 0 => librarySize(total),
    _ => null,
  };
  return switch (task.state) {
    DownloadTaskState.downloading => [
      downloadSizeSoFar(task),
      if (task.speed case final speed? when speed > 0) downloadSpeed(speed),
      if (task.timeLeft case final left?) downloadTimeLeft(left),
    ],
    DownloadTaskState.queued => [
      if (before != null) 'starts after ${downloadTitle(before)}',
      ?size,
    ],
    DownloadTaskState.paused => [
      if (task.downloadedBytes > 0 || size != null) downloadSizeSoFar(task),
    ],
    DownloadTaskState.waitingForConnection => [
      "your provider's connection is in use",
      if (task.downloadedBytes > 0) downloadSizeSoFar(task),
    ],
    DownloadTaskState.retrying => [
      switch (task.problem) {
        DownloadProblem.server => "your provider's server isn't answering",
        _ => 'the connection was lost',
      },
      if (task.downloadedBytes > 0) downloadSizeSoFar(task),
    ],
    DownloadTaskState.connecting => [
      if (task.downloadedBytes > 0) downloadSizeSoFar(task) else ?size,
    ],
    DownloadTaskState.verifying => [?size],
    _ => const [],
  };
}

/// Why a download needs attention, in the user's words (docs/09; never a
/// raw error).
String downloadProblemText(DownloadTask task) {
  final what = task.type == VodType.movie ? 'movie' : 'episode';
  return switch (task.problem) {
    DownloadProblem.notFound =>
      'This $what is no longer available from your provider.',
    DownloadProblem.auth =>
      'Your provider refused the sign-in. Check the account, then try again.',
    DownloadProblem.noSpace => 'Not enough disk space to go on.',
    DownloadProblem.damaged => 'The download is damaged. Try it again.',
    DownloadProblem.diskWrite => "The file couldn't be written.",
    DownloadProblem.connectionLimit =>
      "Your provider's connections were all in use.",
    DownloadProblem.server => "Your provider's server kept failing.",
    DownloadProblem.network => 'The connection kept failing.',
    null => "The download couldn't finish.",
  };
}

/// "3.4 GB · finished at 2:14 PM".
String downloadFinishedLine(DownloadTask task) => [
  librarySize(task.totalBytes ?? task.downloadedBytes),
  if (task.completedAt case final at?) 'finished at ${formatClock(at)}',
].join(' · ');

/// The meter's "Downloads 42.3 GB" and "118 GB free of 512 GB".
String downloadsUsedLabel(int bytes) => 'Downloads ${librarySize(bytes)}';

String downloadsFreeLabel(({int free, int total})? disk) => disk == null
    ? ''
    : '${librarySize(disk.free)} free of ${librarySize(disk.total)}';

const downloadsEmptyTitle = 'Nothing downloading';
const downloadsEmptyMessage = 'Press D on a movie or episode to download it.';
