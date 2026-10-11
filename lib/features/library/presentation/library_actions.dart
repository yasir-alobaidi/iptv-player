import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:iptv_player/app/failure_message.dart';
import 'package:iptv_player/core/core_providers.dart';
import 'package:iptv_player/core/library/library_item.dart';
import 'package:iptv_player/core/library/library_repository.dart';
import 'package:iptv_player/core/notices/app_notices.dart';
import 'package:iptv_player/core/platform/file_reveal.dart';
import 'package:iptv_player/core/result.dart';
import 'package:iptv_player/design/components.dart';
import 'package:iptv_player/design/tokens.dart';
import 'package:iptv_player/features/library/data/library_providers.dart';
import 'package:iptv_player/features/library/presentation/library_edit_dialog.dart';
import 'package:iptv_player/features/library/presentation/library_routes.dart';
import 'package:iptv_player/features/library/presentation/library_text.dart';
import 'package:iptv_player/features/playback/domain/playable.dart';
import 'package:iptv_player/features/playback/presentation/vod_launch.dart';
import 'package:iptv_player/features/vod/data/vod_providers.dart';

/// Where a library movie opens (the Library's grid, Search): a download
/// the provider still lists at its page there, with everything the
/// provider says of it; any other at the Library's own.
Future<String> libraryMovieLocation(
  ProviderContainer container,
  LibraryItem item,
) async {
  final link = item.provider;
  if (link != null && link.type == VodType.movie) {
    final listed = await container
        .read(movieRepositoryProvider)
        .byRemoteKey(link.sourceId, link.remoteKey);
    if (listed case Ok(value: final movie?)) {
      return libraryProviderMoviePath(movie);
    }
  }
  return libraryMoviePath(item);
}

/// Where a library show opens: a provider's series it still lists at its
/// page there; any other at the Library's own.
Future<String> libraryShowLocation(
  ProviderContainer container,
  LibraryShow show,
) async {
  final source = show.providerSourceId;
  final key = show.providerSeriesKey;
  if (source != null && key != null) {
    final listed = await container
        .read(seriesRepositoryProvider)
        .byRemoteKey(source, key);
    if (listed case Ok(value: final series?)) {
      return libraryProviderSeriesPath(series);
    }
  }
  return libraryShowPath(show.key);
}

/// Enter on a video: it plays, from where it was left. One whose drive is
/// away says so instead of opening the player on a file that isn't there.
Future<void> playLibraryItem(
  ProviderContainer container,
  LibraryItem item, {
  String? folderLabel,
}) async {
  if (!item.available) {
    container
        .read(appNoticesProvider)
        .show(AppNotice(driveAwayNotice(folderLabel)));
    return;
  }
  final launcher = container.read(vodLauncherProvider);
  final mark = await container
      .read(watchProgressProvider)
      .watch(libraryVodRef(item))
      .first;
  await launcher.playLibraryItem(
    item,
    from: mark != null && mark.resumable ? mark.position : null,
  );
}

/// Delete file (sketch F; hard rule 11): always asked, Keep focused. The
/// video and its subtitle files go to the system's trash; on a drive with
/// none it is asked once more before they are deleted for good. True when
/// the file is gone.
Future<bool> confirmDeleteFile(BuildContext context, LibraryItem item) async {
  final container = ProviderScope.containerOf(context, listen: false);
  final library = container.read(libraryRepositoryProvider);
  final notices = container.read(appNoticesProvider);
  final name = libraryFileName(item);

  Future<bool> ask({
    required String title,
    required String body,
    required String action,
  }) async =>
      await showAppDialog<bool>(
        context,
        builder: (context) => AppDialog(
          title: title,
          primaryLabel: action,
          destructive: true,
          onPrimary: () => Navigator.of(context).pop(true),
          secondaryLabel: 'Keep',
          onSecondary: () => Navigator.of(context).pop(false),
          child: Text(
            body,
            style: context.tokens.text.body.copyWith(
              color: context.tokens.colors.textSecondary,
            ),
          ),
        ),
      ) ??
      false;

  if (!await ask(
    title: 'Delete "$name"?',
    body: deleteFileBody(item),
    action: 'Move to trash',
  )) {
    return false;
  }
  var outcome = await library.deleteFile(item.id);
  if (outcome case Ok(value: DeleteOutcome.noTrash)) {
    if (!context.mounted ||
        !await ask(
          title: 'This drive has no trash. Delete "$name" for good?',
          body: "It can't be undone.",
          action: 'Delete for good',
        )) {
      return false;
    }
    outcome = await library.deleteFile(item.id, permanently: true);
  }
  switch (outcome) {
    case Ok(value: DeleteOutcome.trashed):
      notices.show(AppNotice('Moved "$name" to the trash.'));
      return true;
    case Ok(value: DeleteOutcome.deleted):
      notices.show(AppNotice('Deleted "$name".'));
      return true;
    case Ok(value: DeleteOutcome.noTrash):
      return false;
    case Err(:final failure):
      notices.show(
        AppNotice(
          'Couldn\'t delete "$name". ${failureMessage(failure)}',
          tone: NoticeTone.error,
        ),
      );
      return false;
  }
}

/// The item menu (sketch D; the menu key, Shift+F10 or a right-click):
/// Resume or Play, Play from the start, the favorite, Mark as watched,
/// Show in folder, Edit details…, Hide, Remove from library, Delete
/// file…. Cast joins it with step 7. [onGone] is told when the item has
/// left the library (its page goes back), [onChanged] when its details
/// were edited, and [beforePlay] before it plays (Search closes).
Future<void> showLibraryItemMenu(
  BuildContext anchor,
  LibraryItem item, {
  String? folderLabel,
  VoidCallback? beforePlay,
  VoidCallback? onChanged,
  VoidCallback? onGone,
}) async {
  final container = ProviderScope.containerOf(anchor, listen: false);
  final library = container.read(libraryRepositoryProvider);
  final notices = container.read(appNoticesProvider);
  final progress = container.read(watchProgressProvider);
  final favorites = container.read(libraryFavoritesProvider);
  final mark = await progress.watch(libraryVodRef(item)).first;
  final favorite = await favorites.isFavorite(item);
  if (!anchor.mounted) return;
  final resumable = mark != null && mark.resumable;
  final watched = mark?.completed ?? false;
  void choose(Future<void> Function() action) => unawaited(action());

  void play({Duration? from}) => choose(() async {
    if (!item.available) {
      notices.show(AppNotice(driveAwayNotice(folderLabel)));
      return;
    }
    beforePlay?.call();
    await container.read(vodLauncherProvider).playLibraryItem(item, from: from);
  });

  void failed(String what, AppFailure failure) => notices.show(
    AppNotice('$what ${failureMessage(failure)}', tone: NoticeTone.error),
  );

  await showAppMenu(
    anchor,
    items: [
      AppMenuItem(
        label: resumable ? 'Resume' : 'Play',
        icon: AppIcons.play,
        shortcut: 'Enter',
        onPressed: () => play(from: resumable ? mark.position : null),
      ),
      if (resumable)
        AppMenuItem(
          label: 'Play from the start',
          icon: AppIcons.retry,
          onPressed: play,
        ),
      AppMenuItem(
        label: favorite ? 'Remove from favorites' : 'Add to favorites',
        icon: favorite ? AppIcons.starFilled : AppIcons.star,
        shortcut: 'F',
        onPressed: () => choose(() => favorites.toggle(item)),
      ),
      AppMenuItem(
        label: watched ? 'Mark as unwatched' : 'Mark as watched',
        icon: AppIcons.check,
        onPressed: () => choose(
          () => progress.setWatched(libraryVodRef(item), watched: !watched),
        ),
      ),
      AppMenuItem(
        label: 'Show in folder',
        icon: AppIcons.folder,
        onPressed: () => choose(() async {
          final path = item.path;
          if (path == null ||
              !await container.read(fileRevealProvider).showInFolder(path)) {
            notices.show(
              AppNotice("Couldn't open the folder.", tone: NoticeTone.error),
            );
          }
        }),
      ),
      AppMenuItem(
        label: 'Edit details…',
        icon: AppIcons.edit,
        onPressed: () => choose(() async {
          final answer = await showEditDetails(anchor, item);
          if (answer == null) return;
          final saved = await library.editItem(
            item.id,
            answer.useFileName ? null : answer.edit,
          );
          switch (saved) {
            case Ok():
              onChanged?.call();
            case Err(:final failure):
              failed("Couldn't save the details.", failure);
          }
        }),
      ),
      AppMenuItem(
        label: 'Hide',
        icon: AppIcons.eye,
        onPressed: () => choose(() async {
          switch (await library.setHidden(item.id, hidden: true)) {
            case Ok():
              onGone?.call();
              notices.show(
                AppNotice.undoable(
                  'Hidden · ${item.title}',
                  onUndo: () =>
                      unawaited(library.setHidden(item.id, hidden: false)),
                ),
              );
            case Err(:final failure):
              failed("Couldn't hide it.", failure);
          }
        }),
      ),
      AppMenuItem(
        label: 'Remove from library',
        icon: AppIcons.close,
        onPressed: () => choose(() async {
          switch (await library.removeItem(item.id)) {
            case Ok():
              onGone?.call();
              notices.show(
                AppNotice(
                  'Removed ${item.title} from the library. The file stays '
                  'where it is.',
                ),
              );
            case Err(:final failure):
              failed("Couldn't remove it.", failure);
          }
        }),
      ),
      AppMenuItem(
        label: 'Delete file…',
        icon: AppIcons.trash,
        destructive: true,
        onPressed: () => choose(() async {
          if (await confirmDeleteFile(anchor, item)) onGone?.call();
        }),
      ),
    ],
  );
}
