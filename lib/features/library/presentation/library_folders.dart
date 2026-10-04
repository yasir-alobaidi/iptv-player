import 'dart:async';

import 'package:file_selector/file_selector.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:iptv_player/app/failure_message.dart';
import 'package:iptv_player/core/core_providers.dart';
import 'package:iptv_player/core/library/library_item.dart';
import 'package:iptv_player/core/library/library_repository.dart';
import 'package:iptv_player/core/notices/app_notices.dart';
import 'package:iptv_player/core/platform/file_reveal.dart';
import 'package:iptv_player/core/result.dart';
import 'package:iptv_player/core/text/format.dart';
import 'package:iptv_player/design/components.dart';
import 'package:iptv_player/design/tokens.dart';
import 'package:iptv_player/features/favorites/presentation/group_name_dialog.dart';
import 'package:iptv_player/features/library/data/library_providers.dart';
import 'package:iptv_player/features/library/presentation/library_state.dart';
import 'package:iptv_player/features/library/presentation/library_text.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'library_folders.g.dart';

/// Asks the user for a folder; null when they close the dialog.
typedef FolderPicker = Future<String?> Function();

/// The system's folder dialog. Tests override it.
@Riverpod(keepAlive: true)
FolderPicker folderPicker(Ref ref) =>
    () => getDirectoryPath(confirmButtonText: 'Add folder');

/// Add folder (the Library, Settings): the dialog, or a folder dropped on
/// the window ([path]); the library scans it, and a toast says how it
/// went.
Future<void> addLibraryFolder(WidgetRef ref, {String? path}) async {
  final notices = ref.read(appNoticesProvider);
  final library = ref.read(libraryRepositoryProvider);
  final chosen = path ?? await ref.read(folderPickerProvider)();
  if (chosen == null) return;
  switch (await library.addFolder(chosen)) {
    case Ok(:final value):
      notices.show(
        AppNotice('Added ${value.label}. Its videos appear as it is scanned.'),
      );
    case Err(:final failure):
      notices.show(
        AppNotice(
          // Our own words, written for the screen ("Movies HDD is already
          // in the library."); anything else in the usual ones.
          failure is InvalidInputFailure && failure.detail != null
              ? "Couldn't add that folder. ${failure.detail}"
              : "Couldn't add that folder. ${failureMessage(failure)}",
          tone: NoticeTone.error,
        ),
      );
  }
}

/// The library's folders (canvas `Settings · Downloads and library`,
/// LIBRARY FOLDERS; the Library's Folders tab): the download folder
/// first, each with its videos and when it was scanned, Rescan and Remove;
/// the menu key adds Rename and Show in folder. A folder whose drive is
/// away says its videos stay listed for 30 days.
class LibraryFolderList extends ConsumerWidget {
  const new({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tokens = context.tokens;
    final folders = ref.watch(libraryFoldersProvider);
    final totals = ref.watch(libraryFolderTotalsProvider).value ?? const {};
    return switch (folders) {
      AsyncData(:final value) when value.isEmpty => EmptyState(
        compact: true,
        icon: AppIcons.folder,
        title: 'No folders yet',
        message: 'Add a folder with your own movies and shows.',
        actionLabel: 'Add folder',
        onAction: () => unawaited(addLibraryFolder(ref)),
      ),
      AsyncData(:final value) => FocusTraversalGroup(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            for (final folder in value) ...[
              _FolderRow(folder: folder, totals: totals[folder.id]),
              SizedBox(height: tokens.spacing.s8),
            ],
          ],
        ),
      ),
      AsyncError(:final error) => ErrorState(
        compact: true,
        title: "Couldn't read your folders",
        details: '$error',
        onRetry: () => ref.invalidate(libraryFoldersProvider),
      ),
      _ => const SizedBox.shrink(),
    };
  }
}

class _FolderRow extends ConsumerWidget {
  const new({required this.folder, required this.totals});

  final LibraryFolder folder;
  final LibraryFolderTotals? totals;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tokens = context.tokens;
    final colors = tokens.colors;
    final layout = tokens.library;
    final watched = ref.watch(libraryFolderWatchedProvider(folder.id)).value;
    final home = ref.watch(homeFolderProvider);
    final now = ref.watch(appClockProvider)();
    final videos = totals?.items ?? 0;
    final away = !folder.isAvailable;
    final line = folderLine(folder, totals, now);

    return FocusableSurface(
      onMenu: () => unawaited(_menu(context, ref)),
      borderRadius: tokens.radii.controlAll,
      semanticLabel: '${folder.label}, $line',
      builder: (context, states) => Container(
        height: layout.folderRowHeight,
        padding: EdgeInsets.symmetric(horizontal: tokens.spacing.s12 + 2),
        decoration: BoxDecoration(
          color: states.highlighted ? colors.surface3 : colors.surface2,
          borderRadius: tokens.radii.controlAll,
        ),
        child: Row(
          children: [
            Container(
              width: layout.folderIconSize,
              height: layout.folderIconSize,
              decoration: BoxDecoration(
                color: colors.surface3,
                borderRadius: tokens.radii.smAll,
              ),
              alignment: Alignment.center,
              child: AppIcon(
                away ? AppIcons.alertTriangle : AppIcons.folder,
                size: 18,
                color: away
                    ? colors.warning
                    : folder.isDownloadFolder
                    ? colors.accentBase
                    : colors.textSecondary,
              ),
            ),
            SizedBox(width: tokens.spacing.s12 + 2),
            Expanded(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    displayFolderPath(folder.path, home),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: tokens.text.mono.copyWith(
                      color: away ? colors.textSecondary : colors.textPrimary,
                    ),
                  ),
                  SizedBox(height: tokens.spacing.s4 - 1),
                  Text(
                    line,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: away
                        ? tokens.text.labelSmall
                              .withWeight(700)
                              .copyWith(color: colors.warning)
                        : tokens.text.labelSmall.copyWith(
                            color: colors.textTertiary,
                          ),
                  ),
                ],
              ),
            ),
            SizedBox(width: tokens.spacing.s12),
            if (away)
              AppButton(
                label: 'Remove',
                variant: AppButtonVariant.ghost,
                size: AppButtonSize.s,
                onPressed: folder.isDownloadFolder
                    ? null
                    : () => unawaited(_remove(context, ref, videos)),
              )
            else ...[
              if (watched != null) ...[
                Text(
                  watched ? 'Updates automatically' : 'Updates when rescanned',
                  style: tokens.text.labelSmall.copyWith(
                    color: colors.textTertiary,
                  ),
                ),
                SizedBox(width: tokens.spacing.s12),
              ],
              AppButton(
                label: 'Rescan',
                icon: AppIcons.rescan,
                variant: AppButtonVariant.secondary,
                size: AppButtonSize.s,
                onPressed: () => unawaited(
                  ref
                      .read(libraryRepositoryProvider)
                      .rescan(folderId: folder.id),
                ),
              ),
              if (!folder.isDownloadFolder) ...[
                SizedBox(width: tokens.spacing.s4),
                AppIconButton(
                  icon: AppIcons.close,
                  tooltip: 'Remove folder',
                  onPressed: () => unawaited(_remove(context, ref, videos)),
                ),
              ],
            ],
          ],
        ),
      ),
    );
  }

  Future<void> _menu(BuildContext anchor, WidgetRef ref) => showAppMenu(
    anchor,
    items: [
      AppMenuItem(
        label: 'Rename…',
        icon: AppIcons.edit,
        onPressed: () => unawaited(_rename(anchor, ref)),
      ),
      if (folder.isAvailable) ...[
        AppMenuItem(
          label: 'Rescan',
          icon: AppIcons.rescan,
          onPressed: () => unawaited(
            ref.read(libraryRepositoryProvider).rescan(folderId: folder.id),
          ),
        ),
        AppMenuItem(
          label: 'Show in folder',
          icon: AppIcons.folder,
          onPressed: () =>
              unawaited(ref.read(fileRevealProvider).showInFolder(folder.path)),
        ),
      ],
      if (!folder.isDownloadFolder)
        AppMenuItem(
          label: 'Remove from library',
          icon: AppIcons.close,
          onPressed: () => unawaited(
            _remove(
              anchor,
              ref,
              ref.read(libraryFolderTotalsProvider).value?[folder.id]?.items ??
                  0,
            ),
          ),
        ),
    ],
  );

  Future<void> _rename(BuildContext anchor, WidgetRef ref) async {
    final library = ref.read(libraryRepositoryProvider);
    final name = await showGroupNameDialog(
      anchor,
      title: 'Rename folder',
      initial: folder.label,
    );
    if (name == null || name == folder.label) return;
    await library.renameFolder(folder.id, name);
  }

  /// Remove asks first: the folder's videos leave the Library, though
  /// none of its files is touched (hard rule 11).
  Future<void> _remove(BuildContext context, WidgetRef ref, int videos) async {
    final library = ref.read(libraryRepositoryProvider);
    final notices = ref.read(appNoticesProvider);
    final confirmed = await showAppDialog<bool>(
      context,
      builder: (context) => AppDialog(
        title: 'Remove ${folder.label} from the library?',
        primaryLabel: 'Remove',
        onPrimary: () => Navigator.of(context).pop(true),
        secondaryLabel: 'Keep',
        onSecondary: () => Navigator.of(context).pop(false),
        child: Text(
          '${videos == 1 ? 'Its video leaves' : 'Its ${formatCount(videos)} '
                    'videos leave'} the Library. The files stay where they '
          'are.',
          style: context.tokens.text.body.copyWith(
            color: context.tokens.colors.textSecondary,
          ),
        ),
      ),
    );
    if (confirmed != true) return;
    if (await library.removeFolder(folder.id) case Err(:final failure)) {
      notices.show(
        AppNotice(
          "Couldn't remove ${folder.label}. ${failureMessage(failure)}",
          tone: NoticeTone.error,
        ),
      );
    }
  }
}
