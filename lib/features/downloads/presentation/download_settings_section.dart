import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:iptv_player/app/failure_message.dart';
import 'package:iptv_player/core/core_providers.dart';
import 'package:iptv_player/core/downloads/download_settings.dart';
import 'package:iptv_player/core/images/artwork_images.dart';
import 'package:iptv_player/core/images/artwork_scope.dart';
import 'package:iptv_player/core/library/library_item.dart';
import 'package:iptv_player/core/library/library_repository.dart';
import 'package:iptv_player/core/notices/app_notices.dart';
import 'package:iptv_player/core/result.dart';
import 'package:iptv_player/core/text/format.dart';
import 'package:iptv_player/design/components.dart';
import 'package:iptv_player/design/tokens.dart';
import 'package:iptv_player/features/downloads/data/download_providers.dart';
import 'package:iptv_player/features/downloads/presentation/download_actions.dart';
import 'package:iptv_player/features/library/data/library_providers.dart';
import 'package:iptv_player/features/library/presentation/library_folders.dart';
import 'package:iptv_player/features/library/presentation/library_state.dart';
import 'package:iptv_player/features/library/presentation/library_text.dart';
import 'package:iptv_player/features/settings/presentation/settings_screen.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'download_settings_section.g.dart';

/// The videos hidden from the Library, Search and Home (sketch H).
@riverpod
Stream<List<LibraryItem>> hiddenLibraryItems(Ref ref) => ref
    .watch(libraryRepositoryProvider)
    .watch(const LibraryQuery(hidden: true));

/// Settings → Downloads & library (canvas `Settings · Downloads and
/// library`): where downloads go, how many at a time and how fast,
/// whether they pick up at launch and keep the computer awake; the
/// library's folders; and the hidden videos (sketch H).
class DownloadSettingsSection extends ConsumerStatefulWidget {
  const new({super.key});

  @override
  ConsumerState<DownloadSettingsSection> createState() =>
      _DownloadSettingsSectionState();
}

class _DownloadSettingsSectionState
    extends ConsumerState<DownloadSettingsSection> {
  String? _error;
  bool _showHidden = false;

  /// Changes what is stored now, not what the last frame showed: two
  /// changes in a row both hold.
  Future<void> _save(
    DownloadSettings Function(DownloadSettings now) change,
  ) async {
    final result = await ref
        .read(downloadSettingsControllerProvider.notifier)
        .update(change(ref.read(downloadSettingsControllerProvider)));
    if (!mounted) return;
    setState(() {
      _error = switch (result) {
        Err(:final failure) =>
          "Couldn't save that change. ${failureMessage(failure)}",
        Ok() => null,
      };
    });
  }

  @override
  Widget build(BuildContext context) {
    final tokens = context.tokens;
    final colors = tokens.colors;
    final settings = ref.watch(downloadSettingsControllerProvider);
    final folder = ref.watch(downloadFolderProvider).value;
    final disk = ref.watch(downloadDiskSpaceProvider).value;
    final home = ref.watch(homeFolderProvider);
    final hidden = ref.watch(hiddenLibraryItemsProvider).value ?? const [];
    final folders = ref.watch(libraryFoldersProvider).value ?? const [];
    final labels = {for (final each in folders) each.id: each.label};

    Widget heading(String label) => Padding(
      padding: EdgeInsets.only(bottom: tokens.spacing.s4),
      child: Text(
        label,
        style: tokens.text.overline.copyWith(color: colors.textTertiary),
      ),
    );

    return SettingsPanel(
      title: 'Downloads & library',
      body: ListView(
        children: [
          if (_error case final error?) ...[
            AppBanner(message: error, tone: BannerTone.error),
            SizedBox(height: tokens.spacing.s16),
          ],
          heading('DOWNLOADS'),
          _Row(
            title: 'Download folder',
            description: [
              if (folder != null) displayFolderPath(folder, home),
              if (disk != null) '${librarySize(disk.free)} free',
            ].join(' · '),
            mono: true,
            control: AppButton(
              label: 'Change…',
              variant: AppButtonVariant.secondary,
              size: AppButtonSize.s,
              onPressed: () => unawaited(
                pickDownloadFolder(ProviderScope.containerOf(context)),
              ),
            ),
          ),
          _Row(
            title: 'Downloads at a time',
            description:
                "Never more than your provider's free connections. "
                'Watching always comes first.',
            control: SegmentedControl<int>(
              options: [
                for (var n = 1; n <= DownloadSettings.maxAtATime; n++)
                  SegmentOption(value: n, label: '$n'),
              ],
              value: settings.atATime,
              onChanged: (n) =>
                  unawaited(_save((now) => now.copyWith(atATime: n))),
            ),
          ),
          _Row(
            title: 'Speed limit',
            description: 'Leaves room for streaming on the same network.',
            control: SegmentedControl<DownloadSpeedLimit>(
              options: [
                for (final limit in DownloadSpeedLimit.values)
                  SegmentOption(
                    value: limit,
                    label: switch (limit.megabits) {
                      null => 'Unlimited',
                      final megabits => '$megabits Mbps',
                    },
                  ),
              ],
              value: settings.speedLimit,
              onChanged: (limit) =>
                  unawaited(_save((now) => now.copyWith(speedLimit: limit))),
            ),
          ),
          _Row(
            title: 'Resume downloads when the app opens',
            description: 'Unfinished downloads pick up where they stopped.',
            control: _OnOff(
              value: settings.resumeOnLaunch,
              onChanged: (on) =>
                  unawaited(_save((now) => now.copyWith(resumeOnLaunch: on))),
            ),
          ),
          _Row(
            title: 'Keep the computer awake while downloading',
            description: 'Sleep is allowed again when the queue is empty.',
            control: _OnOff(
              value: settings.keepAwake,
              onChanged: (on) =>
                  unawaited(_save((now) => now.copyWith(keepAwake: on))),
            ),
          ),
          SizedBox(height: tokens.spacing.s20 + 2),
          Row(
            children: [
              Expanded(child: heading('LIBRARY FOLDERS')),
              AppButton(
                label: 'Add folder',
                icon: AppIcons.plus,
                variant: AppButtonVariant.secondary,
                size: AppButtonSize.s,
                onPressed: () => unawaited(addLibraryFolder(ref)),
              ),
            ],
          ),
          SizedBox(height: tokens.spacing.s8 + 2),
          const LibraryFolderList(),
          SizedBox(height: tokens.spacing.s12),
          _Row(
            title: hidden.isEmpty
                ? 'Hidden videos'
                : 'Hidden videos · ${formatCount(hidden.length)}',
            description:
                'Hidden videos are left out of the Library, Search and '
                'Home.',
            control: AppButton(
              label: _showHidden ? 'Close' : 'Show',
              variant: AppButtonVariant.secondary,
              size: AppButtonSize.s,
              onPressed: hidden.isEmpty
                  ? null
                  : () => setState(() => _showHidden = !_showHidden),
            ),
          ),
          if (_showHidden)
            for (final item in hidden)
              _HiddenRow(item: item, folderLabel: labels[item.folderId]),
        ],
      ),
    );
  }
}

/// A setting: its name and what it does on the left, the control on the
/// right (as the other sections lay them out).
class _Row extends StatelessWidget {
  const new({
    required this.title,
    required this.description,
    required this.control,
    this.mono = false,
  });

  final String title;
  final String description;
  final Widget control;

  /// The description is a path.
  final bool mono;

  @override
  Widget build(BuildContext context) {
    final tokens = context.tokens;
    final colors = tokens.colors;
    return Container(
      padding: EdgeInsets.symmetric(vertical: tokens.spacing.s16),
      decoration: BoxDecoration(
        border: Border(bottom: BorderSide(color: colors.surface3)),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: tokens.text.label.copyWith(color: colors.textPrimary),
                ),
                SizedBox(height: tokens.spacing.s4),
                Text(
                  description,
                  style: (mono ? tokens.text.mono : tokens.text.caption)
                      .copyWith(
                        color: mono
                            ? colors.textSecondary
                            : colors.textTertiary,
                      ),
                ),
              ],
            ),
          ),
          SizedBox(width: tokens.spacing.s24),
          control,
        ],
      ),
    );
  }
}

class _OnOff extends StatelessWidget {
  const new({required this.value, required this.onChanged});

  final bool value;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) => SegmentedControl<bool>(
    options: const [
      SegmentOption(value: false, label: 'Off'),
      SegmentOption(value: true, label: 'On'),
    ],
    value: value,
    onChanged: onChanged,
  );
}

/// A hidden video (sketch H): its frame, name and folder, and Show,
/// which puts it back in the Library.
class _HiddenRow extends ConsumerWidget {
  const new({required this.item, required this.folderLabel});

  final LibraryItem item;
  final String? folderLabel;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tokens = context.tokens;
    final colors = tokens.colors;
    final frame = item.available
        ? ref.watch(libraryThumbnailProvider(item.id)).value
        : null;
    final picture = frame ?? item.artworkPath;
    final width = tokens.library.rowArtBox;
    final place = libraryFileLine(item, folderLabel);

    Future<void> show() async {
      final notices = ref.read(appNoticesProvider);
      final shown = await ref
          .read(libraryRepositoryProvider)
          .setHidden(item.id, hidden: false);
      if (shown case Err(:final failure)) {
        notices.show(
          AppNotice(
            "Couldn't show ${item.title}. ${failureMessage(failure)}",
            tone: NoticeTone.error,
          ),
        );
      }
    }

    return Padding(
      padding: EdgeInsets.only(top: tokens.spacing.s8),
      child: Row(
        children: [
          ClipRRect(
            borderRadius: tokens.radii.smAll,
            child: SizedBox(
              width: width,
              height: tokens.library.rowStillHeight,
              child: PosterArtwork(
                title: item.title,
                showTitle: false,
                image: picture == null
                    ? null
                    : artworkFor(
                        context,
                        localArtworkUrl(picture),
                        width: width,
                      ),
              ),
            ),
          ),
          SizedBox(width: tokens.spacing.s16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  item.kind == LibraryKind.movie
                      ? libraryMovieTitle(item)
                      : item.title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: tokens.text.label.copyWith(color: colors.textPrimary),
                ),
                SizedBox(height: tokens.spacing.s4),
                Text(
                  place,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: tokens.text.caption.copyWith(
                    color: colors.textTertiary,
                  ),
                ),
              ],
            ),
          ),
          SizedBox(width: tokens.spacing.s16),
          AppButton(
            label: 'Show',
            variant: AppButtonVariant.ghost,
            size: AppButtonSize.s,
            onPressed: () => unawaited(show()),
          ),
        ],
      ),
    );
  }
}
