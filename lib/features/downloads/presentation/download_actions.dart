import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:iptv_player/app/destinations.dart';
import 'package:iptv_player/app/failure_message.dart';
import 'package:iptv_player/app/router.dart';
import 'package:iptv_player/app/shell/shell_state.dart';
import 'package:iptv_player/core/core_providers.dart';
import 'package:iptv_player/core/downloads/download_task.dart';
import 'package:iptv_player/core/library/library_item.dart';
import 'package:iptv_player/core/library/library_repository.dart';
import 'package:iptv_player/core/notices/app_notices.dart';
import 'package:iptv_player/core/platform/file_reveal.dart';
import 'package:iptv_player/core/result.dart';
import 'package:iptv_player/design/components.dart';
import 'package:iptv_player/features/downloads/data/download_providers.dart';
import 'package:iptv_player/features/downloads/domain/download_ports.dart';
import 'package:iptv_player/features/downloads/presentation/download_text.dart';
import 'package:iptv_player/features/library/data/library_providers.dart';
import 'package:iptv_player/features/library/presentation/library_actions.dart';
import 'package:iptv_player/features/library/presentation/library_folders.dart';
import 'package:iptv_player/features/library/presentation/library_state.dart';
import 'package:iptv_player/features/library/presentation/library_text.dart';
import 'package:iptv_player/features/playback/domain/playable.dart';
import 'package:iptv_player/features/playback/presentation/vod_launch.dart';
import 'package:iptv_player/features/vod/data/vod_providers.dart';
import 'package:iptv_player/features/vod/domain/titles.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'download_actions.g.dart';

/// Where a title's download is: the queue's task while it is on its way
/// or has stopped, its file once it is in the library; neither when it
/// was never downloaded.
@immutable
final class TitleDownload {
  const new({this.task, this.file});

  final DownloadTask? task;
  final LibraryItem? file;

  bool get none => task == null && file == null;

  @override
  bool operator ==(Object other) =>
      other is TitleDownload && other.task == task && other.file == file;

  @override
  int get hashCode => Object.hash(task, file);
}

/// The downloaded file of a provider's title, read again when the
/// library changes.
@riverpod
Stream<LibraryItem?> downloadedFile(
  Ref ref,
  VodType type,
  String sourceId,
  String remoteKey,
) async* {
  final library = ref.watch(libraryRepositoryProvider);
  yield await library.downloadOf(type, sourceId, remoteKey);
  await for (final _ in library.watchCount(const LibraryQuery())) {
    yield await library.downloadOf(type, sourceId, remoteKey);
  }
}

/// A title's download, live (the Download button, sketch E).
@riverpod
TitleDownload titleDownload(
  Ref ref,
  VodType type,
  String sourceId,
  String remoteKey,
) {
  final file = ref
      .watch(downloadedFileProvider(type, sourceId, remoteKey))
      .value;
  if (file != null) return TitleDownload(file: file);
  final tasks = ref.watch(downloadTasksProvider).value ?? const [];
  return TitleDownload(task: _taskOf(tasks, type, sourceId, remoteKey));
}

DownloadTask? _taskOf(
  List<DownloadTask> tasks,
  VodType type,
  String sourceId,
  String remoteKey,
) => tasks
    .where(
      (task) =>
          task.type == type &&
          task.sourceId == sourceId &&
          task.remoteKey == remoteKey &&
          task.state != DownloadTaskState.completed &&
          task.state != DownloadTaskState.canceled,
    )
    .firstOrNull;

/// What the queue is asked for a movie.
DownloadRequest movieDownloadRequest(MovieItem movie) => DownloadRequest(
  sourceId: movie.sourceId,
  type: VodType.movie,
  remoteKey: movie.remoteKey,
  title: movie.name,
  year: movie.year,
  artworkUrl: movie.posterUrl,
  extension: movie.ext,
);

/// What the queue is asked for an episode.
DownloadRequest episodeDownloadRequest(
  SeriesItem series,
  EpisodeItem episode,
) => DownloadRequest(
  sourceId: episode.sourceId,
  type: VodType.episode,
  remoteKey: episode.remoteKey,
  title: episode.title,
  seriesKey: series.remoteKey,
  showTitle: series.name,
  season: episode.season,
  episode: episode.episode,
  artworkUrl: episode.stillUrl ?? series.posterUrl,
  extension: episode.ext,
);

String _requestName(DownloadRequest request) => request.type == VodType.movie
    ? request.title
    : [
        request.showTitle ?? request.title,
        if (request.season case final season?) 'S$season',
        if (request.episode case final episode?) 'E$episode',
      ].join(' · ');

/// Opens Library → Downloads.
void showDownloads(ProviderContainer container) {
  container.read(libraryViewProvider.notifier).showTab(LibraryTab.downloads);
  container.read(routerProvider).go(AppDestination.library.path);
}

/// Download, from a button, a menu or the D key: queues what isn't
/// downloaded or on its way yet, and says what happened — "Downloading
/// Copper Hollow" with Show, "8 episodes added to your downloads", or
/// that it already is.
Future<void> startDownloads(
  BuildContext context,
  List<DownloadRequest> requests,
) async {
  if (requests.isEmpty) return;
  final container = ProviderScope.containerOf(context, listen: false);
  final notices = container.read(appNoticesProvider);
  final library = container.read(libraryRepositoryProvider);
  final tasks = container.read(downloadTasksProvider).value ?? const [];
  final wanted = <DownloadRequest>[];
  var downloaded = 0;
  var onTheWay = 0;
  for (final request in requests) {
    if (_taskOf(tasks, request.type, request.sourceId, request.remoteKey) !=
        null) {
      onTheWay++;
    } else if (await library.downloadOf(
          request.type,
          request.sourceId,
          request.remoteKey,
        ) !=
        null) {
      downloaded++;
    } else {
      wanted.add(request);
    }
  }
  void show() => showDownloads(container);
  if (wanted.isEmpty) {
    final one = requests.length == 1;
    notices.show(
      AppNotice(
        one
            ? onTheWay > 0
                  ? '${_requestName(requests.single)} is already downloading.'
                  : '${_requestName(requests.single)} is already downloaded.'
            : downloaded == requests.length
            ? 'These episodes are already downloaded.'
            : 'These episodes are already in your downloads.',
        actionLabel: onTheWay > 0 ? 'Show' : null,
        onAction: onTheWay > 0 ? show : null,
      ),
    );
    return;
  }
  switch (await container.read(downloadServiceProvider).enqueue(wanted)) {
    case Ok():
      notices.show(
        AppNotice(
          wanted.length == 1
              ? 'Downloading ${_requestName(wanted.single)}'
              : '${wanted.length} episodes added to your downloads',
          actionLabel: 'Show',
          onAction: show,
        ),
      );
    case Err(:final failure):
      notices.show(
        AppNotice(
          "Couldn't start the download. ${failureMessage(failure)}",
          tone: NoticeTone.error,
        ),
      );
  }
}

/// The Download button's label and icon for where the download is
/// (sketch E): "Download", "49% · about 2 min left", "Downloaded".
({String label, AppIcons icon}) downloadButtonFace(TitleDownload download) {
  if (download.file != null) {
    return (label: 'Downloaded', icon: AppIcons.check);
  }
  final task = download.task;
  if (task == null) return (label: 'Download', icon: AppIcons.download);
  final percent = switch (task.progress) {
    final progress? => '${(progress * 100).floor()}%',
    null => null,
  };
  return switch (downloadSectionOf(task, DateTime.now())) {
    DownloadSection.needsAttention => (
      label: 'Download stopped',
      icon: AppIcons.alertCircle,
    ),
    _ => switch (task.state) {
      DownloadTaskState.downloading => (
        label: [
          percent ?? 'Downloading',
          if (task.timeLeft case final left?) downloadTimeLeft(left),
        ].join(' · '),
        icon: AppIcons.downloadActive,
      ),
      DownloadTaskState.paused => (
        label: ['Paused', ?percent].join(' · '),
        icon: AppIcons.pause,
      ),
      DownloadTaskState.queued => (label: 'Queued', icon: AppIcons.clock),
      _ => (label: downloadStateWord(task), icon: AppIcons.downloadActive),
    },
  };
}

/// Enter on the Download button (sketch E): starts the download; on one
/// that is on its way, its menu (Pause or Resume, Cancel download, Show
/// in Downloads); on a stopped one, the reason with Retry and Remove; on
/// a finished one, Show in folder and Delete download….
Future<void> downloadPressed(
  BuildContext anchor,
  TitleDownload download,
  DownloadRequest request,
) async {
  final container = ProviderScope.containerOf(anchor, listen: false);
  final service = container.read(downloadServiceProvider);
  final file = download.file;
  final task = download.task;
  if (file != null) {
    await showAppMenu(
      anchor,
      items: [
        AppMenuItem(
          label: 'Show in folder',
          icon: AppIcons.folder,
          onPressed: () {
            final path = file.path;
            if (path != null) {
              unawaited(container.read(fileRevealProvider).showInFolder(path));
            }
          },
        ),
        AppMenuItem(
          label: 'Delete download…',
          icon: AppIcons.trash,
          destructive: true,
          onPressed: () => unawaited(confirmDeleteFile(anchor, file)),
        ),
      ],
    );
    return;
  }
  if (task == null) {
    await startDownloads(anchor, [request]);
    return;
  }
  final stopped =
      downloadSectionOf(task, DateTime.now()) == DownloadSection.needsAttention;
  final paused = task.state == DownloadTaskState.paused;
  await showAppMenu(
    anchor,
    items: [
      if (stopped) ...[
        if (task.problem == DownloadProblem.auth)
          AppMenuItem(
            label: 'Edit source',
            icon: AppIcons.edit,
            onPressed: () => unawaited(
              container
                  .read(routerProvider)
                  .push<void>(editSourcePath(task.sourceId)),
            ),
          ),
        AppMenuItem(
          label: 'Retry',
          icon: AppIcons.retry,
          onPressed: () => unawaited(service.retry(task.id)),
        ),
      ] else
        AppMenuItem(
          label: paused ? 'Resume' : 'Pause',
          icon: paused ? AppIcons.play : AppIcons.pause,
          onPressed: () => unawaited(
            paused ? service.resume(task.id) : service.pause(task.id),
          ),
        ),
      AppMenuItem(
        label: 'Show in Downloads',
        icon: AppIcons.download,
        onPressed: () => showDownloads(container),
      ),
      AppMenuItem(
        label: stopped ? 'Remove' : 'Cancel download',
        icon: AppIcons.close,
        destructive: true,
        onPressed: () => unawaited(
          stopped ? service.remove(task.id) : service.cancel(task.id),
        ),
      ),
    ],
  );
}

/// Change folder (Library → Downloads, Settings): the folder dialog,
/// then new downloads go to the folder chosen and it joins the library;
/// a toast says so, and that what was downloaded stays where it is.
Future<void> pickDownloadFolder(ProviderContainer container) async {
  final notices = container.read(appNoticesProvider);
  final change = container.read(changeDownloadFolderProvider);
  final home = container.read(homeFolderProvider);
  final chosen = await container.read(folderPickerProvider)();
  if (chosen == null) return;
  switch (await change(chosen)) {
    case Ok():
      notices.show(
        AppNotice(
          'New downloads go to ${displayFolderPath(chosen, home)}. What '
          'you downloaded stays where it is.',
        ),
      );
    case Err(:final failure):
      notices.show(
        AppNotice(
          "Couldn't change the folder. ${failureMessage(failure)}",
          tone: NoticeTone.error,
        ),
      );
  }
}

/// What the queue last said it lacks on the drive, for the Downloads
/// tab's banner (sketch G: "Free up 3.2 GB or choose another download
/// folder."); null when it never said.
@Riverpod(keepAlive: true)
class DownloadSpaceNeeded extends _$DownloadSpaceNeeded {
  @override
  int? build() => null;

  void need(int bytes) {
    if (state != bytes) state = bytes;
  }
}

/// The banner's sentence (sketch G).
String downloadSpaceBanner(int? neededBytes) => neededBytes == null
    ? 'Downloads paused: not enough disk space. Free up some space or '
          'choose another download folder.'
    : 'Downloads paused: not enough disk space. Free up '
          '${librarySize(neededBytes)} or choose another download folder.';

/// The queue's news as toasts (docs/05): "Download finished · <title>"
/// with Play, "Downloads paused while you watch — your provider allows 1
/// connection.", a refused account with Edit source, and no disk space
/// with Show (the Downloads tab has the banner and Change folder). Alive
/// from launch (`bootstrap()` reads it once).
@Riverpod(keepAlive: true)
void downloadToasts(Ref ref) {
  final notices = ref.watch(appNoticesProvider);
  final listening = ref.watch(downloadNoticeStreamProvider).listen((notice) {
    switch (notice) {
      case DownloadFinishedNotice(:final task):
        notices.show(
          AppNotice(
            'Download finished · ${downloadName(task)}',
            tone: NoticeTone.success,
            actionLabel: 'Play',
            onAction: () => unawaited(_playFinished(ref, task)),
          ),
        );
      case DownloadsWaitForPlayback(:final maxConnections):
        final allowed = maxConnections == 1
            ? '1 connection'
            : '$maxConnections connections';
        notices.show(
          AppNotice(
            'Downloads paused while you watch — your provider allows '
            '$allowed.',
          ),
        );
      case DownloadsAccountRefused(:final sourceId):
        notices.show(
          AppNotice(
            'Downloads stopped: your provider refused the sign-in.',
            tone: NoticeTone.error,
            actionLabel: 'Edit source',
            onAction: () => unawaited(
              ref.read(routerProvider).push<void>(editSourcePath(sourceId)),
            ),
          ),
        );
      case DownloadsNeedSpace(:final neededBytes):
        ref.read(downloadSpaceNeededProvider.notifier).need(neededBytes);
        notices.show(
          AppNotice(
            'Downloads paused: not enough disk space.',
            tone: NoticeTone.error,
            actionLabel: 'Show',
            onAction: () {
              ref
                  .read(libraryViewProvider.notifier)
                  .showTab(LibraryTab.downloads);
              ref.read(routerProvider).go(AppDestination.library.path);
            },
          ),
        );
    }
  });
  ref.onDispose(listening.cancel);
}

Future<void> _playFinished(Ref ref, DownloadTask task) async {
  final id = task.libraryItemId;
  final item = id == null
      ? null
      : await ref.read(libraryRepositoryProvider).item(id);
  if (item == null) return;
  final mark = await ref
      .read(watchProgressProvider)
      .watch(libraryVodRef(item))
      .first;
  await ref
      .read(vodLauncherProvider)
      .playLibraryItem(
        item,
        from: mark != null && mark.resumable ? mark.position : null,
      );
}

/// The shell's download slot (docs/05: "↓ 2 · 34 %" while downloads run;
/// it opens Library → Downloads). `bootstrap()` applies these.
final List<Override> downloadShellOverrides = [
  shellDownloadsProvider.overrideWith((ref) {
    final running = downloadSections(
      ref.watch(downloadTasksProvider).value ?? const [],
      ref.watch(appClockProvider)(),
    ).inProgress;
    if (running.isEmpty) return null;
    var done = 0;
    var total = 0;
    for (final task in running) {
      // One whose size isn't known yet counts for nothing either way.
      final size = task.totalBytes;
      if (size == null || size <= 0) continue;
      done += task.downloadedBytes.clamp(0, size);
      total += size;
    }
    return ShellDownloads(
      active: running.length,
      progress: total == 0 ? 0 : done / total,
    );
  }),
  shellShowDownloadsProvider.overrideWith(
    (ref) =>
        () => ref
            .read(libraryViewProvider.notifier)
            .showTab(LibraryTab.downloads),
  ),
];
