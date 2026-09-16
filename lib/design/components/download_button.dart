import 'package:flutter/material.dart';
import 'package:iptv_player/design/app_icon.dart';
import 'package:iptv_player/design/focus/focusable_surface.dart';
import 'package:iptv_player/design/tokens.dart';

/// Where a download is (docs/09). The button shows one of these.
enum DownloadState { none, queued, downloading, paused, failed, done }

/// Download → Queued → progress ring with % → Downloaded ✓, plus Paused
/// and Failed (docs/05). Presentational: the caller owns the state.
class DownloadButton extends StatelessWidget {
  const new({
    required this.state,
    this.progress,
    this.onPressed,
    this.onMenu,
    this.size = 36,
    this.showLabel = false,
    this.focusNode,
    super.key,
  });

  final DownloadState state;

  /// 0..1 while [DownloadState.downloading] or paused.
  final double? progress;
  final VoidCallback? onPressed;
  final VoidCallback? onMenu;
  final double size;

  /// Shows the state as text next to the icon (details screens).
  final bool showLabel;
  final FocusNode? focusNode;

  String get label => switch (state) {
    DownloadState.none => 'Download',
    DownloadState.queued => 'Queued',
    DownloadState.downloading =>
      progress == null
          ? 'Downloading'
          : 'Downloading ${(progress! * 100).round()}%',
    DownloadState.paused => 'Paused',
    DownloadState.failed => 'Failed — retry',
    DownloadState.done => 'Downloaded',
  };

  @override
  Widget build(BuildContext context) {
    final tokens = context.tokens;
    final colors = tokens.colors;

    final tint = switch (state) {
      DownloadState.none || DownloadState.queued => colors.textSecondary,
      DownloadState.downloading => colors.accentBase,
      DownloadState.paused => colors.warning,
      DownloadState.failed => colors.danger,
      DownloadState.done => colors.success,
    };

    final icon = switch (state) {
      DownloadState.none => AppIcons.download,
      DownloadState.queued => AppIcons.clock,
      DownloadState.downloading => AppIcons.pause,
      DownloadState.paused => AppIcons.play,
      DownloadState.failed => AppIcons.retry,
      DownloadState.done => AppIcons.check,
    };

    return FocusableSurface(
      onPressed: onPressed,
      onMenu: onMenu,
      focusNode: focusNode,
      hoverBackground: colors.surface3,
      borderRadius: tokens.radii.controlAll,
      semanticLabel: label,
      builder: (context, states) => Padding(
        padding: EdgeInsets.symmetric(
          horizontal: showLabel ? tokens.spacing.s8 : 0,
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            SizedBox(
              width: size,
              height: size,
              child: Stack(
                alignment: Alignment.center,
                children: [
                  if (state == DownloadState.downloading ||
                      state == DownloadState.paused)
                    SizedBox(
                      width: size - 6,
                      height: size - 6,
                      child: CircularProgressIndicator(
                        value: progress,
                        strokeWidth: 2,
                        backgroundColor: colors.border,
                        valueColor: AlwaysStoppedAnimation(tint),
                      ),
                    ),
                  AppIcon(icon, size: 16, color: tint),
                ],
              ),
            ),
            if (showLabel) ...[
              SizedBox(width: tokens.spacing.s4 + 2),
              Text(
                label,
                style: tokens.text.caption.copyWith(
                  color: tint,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
