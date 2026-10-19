import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:iptv_player/core/core_providers.dart';
import 'package:iptv_player/core/library/library_item.dart';
import 'package:iptv_player/core/notices/app_notices.dart';
import 'package:iptv_player/core/platform/file_reveal.dart';
import 'package:iptv_player/core/platform/form_factor.dart';
import 'package:iptv_player/core/player/player_providers.dart';
import 'package:iptv_player/design/components.dart';
import 'package:iptv_player/design/tokens.dart';
import 'package:iptv_player/features/library/data/library_providers.dart';
import 'package:iptv_player/features/playback/data/playback_providers.dart';
import 'package:iptv_player/features/playback/domain/playback_state.dart';
import 'package:iptv_player/features/playback/presentation/failed_file.dart';
import 'package:iptv_player/features/playback/presentation/playback_text.dart';
import 'package:iptv_player/features/playback/presentation/player_opening.dart';

/// The picture and what the playback state lays over it: a spinner while
/// opening, the reconnecting pill, and the failure card. The preview pane
/// shows it [compact]; the full-screen player at full size (step 6), where
/// what is opening has its opening screen ([PlayerOpening]) instead of
/// the bare spinner.
class PlayerSurface extends ConsumerWidget {
  const new({
    this.compact = false,
    this.onNext,
    this.nextLabel = 'Next channel',
    this.badges = true,
    this.beforeShowInFolder,
    this.onFileRemoved,
    this.onPictureTap,
    this.onPictureDoubleTap,
    super.key,
  });

  /// The preview pane's size; false is the full-screen player's, where
  /// the spinner and the failure card are larger and grow with the
  /// window as the OSD does (ADR-017).
  final bool compact;

  /// A click and a double click on the picture itself. They are heard
  /// under what is laid over it, so a button on the failure card answers
  /// at once instead of waiting to see whether a second click follows.
  final VoidCallback? onPictureTap;
  final VoidCallback? onPictureDoubleTap;

  /// A file that can't be read (Phase 8 decision 8): what happens before
  /// its folder opens (the full-screen player leaves full screen, so the
  /// file manager isn't hidden behind it), and once Remove from library
  /// took it out (the player leaves).
  final Future<void> Function()? beforeShowInFolder;
  final VoidCallback? onFileRemoved;

  /// Shown on the failure card when there is something to go on to: the
  /// next channel, or an episode's next.
  final VoidCallback? onNext;
  final String nextLabel;

  /// LIVE and the resolution, top left (the preview's; full screen draws
  /// its own OSD).
  final bool badges;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tokens = context.tokens;
    final colors = tokens.colors;
    final engine = ref.watch(playerEngineProvider);
    final state =
        ref.watch(playbackStateProvider).value ?? const PlaybackIdle();
    final size = ref.watch(videoSizeProvider).value;
    final showPicture = pictureShows(state);
    final tv = ref.watch(formFactorProvider) == FormFactor.tv;
    // Full screen, until the item's own picture comes: its opening screen
    // (a reconnect before it keeps it, under the pill). The preview has
    // no room for one: the spinner alone.
    final opening =
        !compact &&
        !showPicture &&
        (state is PlaybackOpening || state is PlaybackReconnecting);
    // Settings → Playback → Subtitle size, on what plays at once: a change
    // builds the picture again with it (ADR-038).
    final subtitleScale = tokens.player.subtitleScale(
      ref.watch(
        playbackSettingsControllerProvider.select((s) => s.subtitleSize),
      ),
      tv: tv,
    );
    final file =
        state is PlaybackFailed &&
            state.problem.kind == PlaybackProblemKind.fileUnreadable
        ? ref.watch(failedFileProvider(state.item)).value
        : null;

    final overlays = [
      if ((state is PlaybackOpening && !opening) ||
          (state is PlaybackPlaying && state.buffering))
        Center(child: PlayerSpinner(large: !compact)),
      if (badges && state is PlaybackPlaying)
        Positioned(
          top: tokens.spacing.s12,
          left: tokens.spacing.s12,
          child: Row(
            children: [
              const AppBadge('LIVE', tone: AppBadgeTone.live),
              if (resolutionLabel(size?.$2) case final label?) ...[
                SizedBox(width: tokens.spacing.s4 + 2),
                _VideoChip(label),
              ],
            ],
          ),
        ),
      if (state is PlaybackReconnecting)
        Positioned(
          top: tokens.spacing.s12,
          left: 0,
          right: 0,
          child: Center(
            child: ReconnectingPill(message: reconnectingText(state)),
          ),
        ),
      if (state is PlaybackFailed)
        Center(
          child: Padding(
            padding: EdgeInsets.all(tokens.spacing.s16),
            child: PlaybackFailureCard(
              state: state,
              compact: compact,
              onRetry: ref.read(playbackCoordinatorProvider).retry,
              onNext: onNext,
              nextLabel: nextLabel,
              onShowInFolder: file?.path == null
                  ? null
                  : () => unawaited(_showInFolder(ref, file!.path!)),
              onRemoveFromLibrary: file == null
                  ? null
                  : () => unawaited(_remove(ref, file)),
            ),
          ),
        ),
    ];

    return ValueListenableBuilder(
      valueListenable: engine.pictureBehindApp,
      builder: (context, behind, child) => ColoredBox(
        // A picture on its own layer behind the app shows where nothing
        // is painted.
        color: behind && showPicture ? Colors.transparent : colors.video,
        child: child,
      ),
      child: Stack(
        fit: StackFit.expand,
        children: [
          if (showPicture)
            engine.videoView(
              background: colors.video,
              subtitleScale: subtitleScale,
            ),
          // Under the picture's clicks, which it never takes.
          if (opening) PlayerOpening(state: state, tv: tv),
          if (onPictureTap != null || onPictureDoubleTap != null)
            GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: onPictureTap,
              onDoubleTap: onPictureDoubleTap,
            ),
          if (compact)
            ...overlays
          else
            OsdScale(
              child: Stack(fit: StackFit.expand, children: overlays),
            ),
        ],
      ),
    );
  }

  Future<void> _showInFolder(WidgetRef ref, String path) async {
    final reveal = ref.read(fileRevealProvider);
    final notices = ref.read(appNoticesProvider);
    await beforeShowInFolder?.call();
    if (!await reveal.showInFolder(path)) {
      notices.show(
        AppNotice("Couldn't open the folder", tone: NoticeTone.error),
      );
    }
  }

  Future<void> _remove(WidgetRef ref, LibraryItem file) async {
    final notices = ref.read(appNoticesProvider);
    final removed = await ref
        .read(libraryRepositoryProvider)
        .removeItem(file.id);
    if (!removed.isOk) {
      notices.show(
        AppNotice(
          "Couldn't remove it from the library",
          tone: NoticeTone.error,
        ),
      );
      return;
    }
    notices.show(
      AppNotice(
        file.isDownload
            ? 'Removed from the library. Play uses your provider again.'
            : 'Removed from the library. The file stays where it is.',
      ),
    );
    onFileRemoved?.call();
  }
}

class _VideoChip extends StatelessWidget {
  const new(this.label);

  final String label;

  @override
  Widget build(BuildContext context) {
    final tokens = context.tokens;
    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: tokens.spacing.s8,
        vertical: tokens.spacing.s4,
      ),
      decoration: BoxDecoration(
        color: tokens.colors.videoChip,
        borderRadius: tokens.radii.smAll,
      ),
      child: Text(
        label,
        style: tokens.text.micro
            .withWeight(800)
            .copyWith(color: tokens.colors.textPrimary),
      ),
    );
  }
}

/// The failure card (approved sketch): what went wrong in our words and
/// the server's, then Retry, Next channel (or Next episode) and Details;
/// for a file on this computer, Show in folder and Remove from library
/// too (Phase 8 decision 8).
class PlaybackFailureCard extends StatefulWidget {
  const new({
    required this.state,
    required this.onRetry,
    this.onNext,
    this.nextLabel = 'Next channel',
    this.compact = false,
    this.onShowInFolder,
    this.onRemoveFromLibrary,
    super.key,
  });

  final PlaybackFailed state;
  final VoidCallback onRetry;
  final VoidCallback? onNext;
  final String nextLabel;
  final bool compact;

  /// A file on this computer that can't be read (docs/09).
  final VoidCallback? onShowInFolder;
  final VoidCallback? onRemoveFromLibrary;

  @override
  State<PlaybackFailureCard> createState() => _PlaybackFailureCardState();
}

class _PlaybackFailureCardState extends State<PlaybackFailureCard> {
  var _details = false;

  @override
  Widget build(BuildContext context) {
    final tokens = context.tokens;
    final colors = tokens.colors;
    final problem = widget.state.problem;
    final text = problemText(
      problem,
      attempts: widget.state.attempts,
      item: widget.state.item,
    );
    final detail = [
      if (problem.failure case final failure?) '$failure',
      ?problem.detail,
    ].join('\n');

    // In full screen the card is read from where the picture is watched:
    // larger words, and buttons a size up (ADR-017).
    final compact = widget.compact;
    final size = compact ? AppButtonSize.s : AppButtonSize.m;
    return Container(
      constraints: BoxConstraints(
        maxWidth: compact
            ? tokens.player.previewCardWidth
            : tokens.player.cardWidth,
      ),
      padding: EdgeInsets.all(
        compact ? tokens.spacing.s16 : tokens.spacing.s24,
      ),
      decoration: BoxDecoration(
        color: colors.surface2,
        borderRadius: tokens.radii.lgAll,
        border: Border.all(color: colors.border),
      ),
      child: FocusTraversalGroup(
        policy: appTraversalPolicy(),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                AppIcon(
                  AppIcons.alertTriangle,
                  size: compact
                      ? tokens.player.previewCardIconSize
                      : tokens.player.iconSize,
                  color: colors.warning,
                ),
                SizedBox(width: tokens.spacing.s12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        text.title,
                        style:
                            (compact ? tokens.text.bodyStrong : tokens.text.h3)
                                .copyWith(color: colors.textPrimary),
                      ),
                      SizedBox(height: tokens.spacing.s4),
                      Text(
                        text.message,
                        maxLines: compact ? 3 : 5,
                        overflow: TextOverflow.ellipsis,
                        style:
                            (compact ? tokens.text.caption : tokens.text.body)
                                .copyWith(
                                  color: compact
                                      ? colors.textSecondary
                                      : colors.textEmphasis,
                                ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            SizedBox(height: tokens.spacing.s16),
            Wrap(
              spacing: tokens.spacing.s8,
              runSpacing: tokens.spacing.s8,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                AppButton(
                  label: 'Retry',
                  icon: AppIcons.retry,
                  size: size,
                  autofocus: !compact,
                  onPressed: widget.onRetry,
                ),
                if (widget.onNext != null)
                  AppButton(
                    label: widget.nextLabel,
                    variant: AppButtonVariant.secondary,
                    size: size,
                    onPressed: widget.onNext,
                  ),
                if (widget.onShowInFolder != null)
                  AppButton(
                    label: 'Show in folder',
                    icon: AppIcons.folder,
                    variant: AppButtonVariant.secondary,
                    size: size,
                    onPressed: widget.onShowInFolder,
                  ),
                if (widget.onRemoveFromLibrary != null)
                  AppButton(
                    label: 'Remove from library',
                    variant: AppButtonVariant.secondary,
                    size: size,
                    onPressed: widget.onRemoveFromLibrary,
                  ),
                if (detail.isNotEmpty)
                  AppButton(
                    label: _details ? 'Hide details' : 'Details',
                    variant: AppButtonVariant.ghost,
                    size: size,
                    onPressed: () => setState(() => _details = !_details),
                  ),
              ],
            ),
            if (_details && detail.isNotEmpty) ...[
              SizedBox(height: tokens.spacing.s8),
              SelectableText(
                detail,
                style: tokens.text.mono.copyWith(color: colors.textSecondary),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

/// Whether the picture shows in [state]: while playing, and while a
/// stream reconnects with its own last picture, never the one before it
/// (ADR-027).
bool pictureShows(PlaybackState state) => switch (state) {
  PlaybackPlaying() => true,
  PlaybackReconnecting(:final hasPicture) => hasPicture,
  _ => false,
};
