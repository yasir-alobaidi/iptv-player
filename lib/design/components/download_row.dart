import 'package:flutter/material.dart';
import 'package:iptv_player/design/app_icon.dart';
import 'package:iptv_player/design/components/channel_logo.dart';
import 'package:iptv_player/design/components/download_button.dart';
import 'package:iptv_player/design/components/progress_bar.dart';
import 'package:iptv_player/design/focus/focusable_surface.dart';
import 'package:iptv_player/design/tokens.dart';

/// One download in Library → Downloads: artwork, title, progress, speed,
/// time left, size, and its controls (docs/05, docs/09).
class DownloadRow extends StatelessWidget {
  const new({
    required this.title,
    required this.state,
    this.subtitle,
    this.image,
    this.progress,
    this.speed,
    this.timeLeft,
    this.size,
    this.errorMessage,
    this.onPressed,
    this.onMenu,
    this.onPrimaryAction,
    this.reorderable = false,
    super.key,
  });

  final String title;
  final DownloadState state;

  /// "S1 · E3", a year, a source name.
  final String? subtitle;
  final ImageProvider? image;
  final double? progress;

  /// Already formatted, e.g. "4.2 MB/s" — formatting is not the design
  /// system's job.
  final String? speed;
  final String? timeLeft;
  final String? size;

  /// Human message for a failed download (never raw exception text).
  final String? errorMessage;
  final VoidCallback? onPressed;
  final VoidCallback? onMenu;
  final VoidCallback? onPrimaryAction;

  /// Shows the drag handle used to reorder the queue.
  final bool reorderable;

  @override
  Widget build(BuildContext context) {
    final tokens = context.tokens;
    final colors = tokens.colors;
    final failed = state == DownloadState.failed;

    final meta = [
      ?speed,
      if (timeLeft != null) '$timeLeft left',
      ?size,
    ].join(' · ');

    return FocusableSurface(
      onPressed: onPressed,
      onMenu: onMenu,
      hoverBackground: colors.surface3,
      borderRadius: tokens.radii.controlAll,
      semanticLabel: title,
      builder: (context, states) => Padding(
        padding: EdgeInsets.symmetric(
          horizontal: tokens.spacing.s12,
          vertical: tokens.spacing.s12,
        ),
        child: Row(
          children: [
            if (reorderable) ...[
              AppIcon(
                AppIcons.dragHandle,
                size: 16,
                color: colors.textTertiary,
              ),
              SizedBox(width: tokens.spacing.s8),
            ],
            ChannelLogo(name: title, image: image, size: 44),
            SizedBox(width: tokens.spacing.s12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Row(
                    children: [
                      Flexible(
                        child: Text(
                          title,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: tokens.text.bodyStrong.copyWith(
                            color: colors.textPrimary,
                          ),
                        ),
                      ),
                      if (subtitle != null) ...[
                        SizedBox(width: tokens.spacing.s8),
                        Text(
                          subtitle!,
                          style: tokens.text.labelSmall.copyWith(
                            color: colors.textTertiary,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ],
                  ),
                  SizedBox(height: tokens.spacing.s8 - 2),
                  if (progress != null && !failed)
                    ProgressBar(
                      value: state == DownloadState.queued ? 0 : progress,
                      height: 4,
                      color: state == DownloadState.paused
                          ? colors.warning
                          : null,
                    ),
                  SizedBox(height: tokens.spacing.s4 + 2),
                  Text(
                    failed
                        ? (errorMessage ?? 'Download failed')
                        : (meta.isEmpty ? _stateText(state) : meta),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: tokens.text.labelSmall.copyWith(
                      color: failed ? colors.danger : colors.textSecondary,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ),
            SizedBox(width: tokens.spacing.s12),
            DownloadButton(
              state: state,
              progress: progress,
              onPressed: onPrimaryAction,
              onMenu: onMenu,
            ),
          ],
        ),
      ),
    );
  }

  static String _stateText(DownloadState state) => switch (state) {
    DownloadState.none => 'Not downloaded',
    DownloadState.queued => 'Queued',
    DownloadState.downloading => 'Downloading',
    DownloadState.paused => 'Paused',
    DownloadState.failed => 'Failed',
    DownloadState.done => 'Downloaded',
  };
}

/// Downloads size against free disk space, at the bottom of the
/// Downloads tab (docs/05).
class StorageMeter extends StatelessWidget {
  const new({
    required this.usedLabel,
    required this.freeLabel,
    required this.usedFraction,
    this.warning = false,
    super.key,
  });

  /// Already formatted, e.g. "Downloads 42.3 GB".
  final String usedLabel;
  final String freeLabel;

  /// How much of the disk the downloads take, 0..1.
  final double usedFraction;

  /// Turns the bar amber when the disk is nearly full.
  final bool warning;

  @override
  Widget build(BuildContext context) {
    final tokens = context.tokens;
    final colors = tokens.colors;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        Row(
          children: [
            AppIcon(AppIcons.storage, size: 14, color: colors.textTertiary),
            SizedBox(width: tokens.spacing.s8),
            Text(
              usedLabel,
              style: tokens.text.labelSmall.copyWith(
                color: colors.textSecondary,
                fontWeight: FontWeight.w600,
              ),
            ),
            const Spacer(),
            Text(
              freeLabel,
              style: tokens.text.labelSmall.copyWith(
                color: warning ? colors.warning : colors.textTertiary,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
        SizedBox(height: tokens.spacing.s8),
        ProgressBar(
          value: usedFraction.clamp(0, 1),
          height: 4,
          color: warning ? colors.warning : colors.accentBase,
          semanticLabel: usedLabel,
        ),
      ],
    );
  }
}
