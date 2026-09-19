import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:iptv_player/core/player/player_providers.dart';
import 'package:iptv_player/design/components.dart';
import 'package:iptv_player/design/tokens.dart';
import 'package:iptv_player/features/playback/data/playback_providers.dart';
import 'package:iptv_player/features/playback/domain/playback_state.dart';
import 'package:iptv_player/features/playback/presentation/playback_text.dart';

/// The picture and what the playback state lays over it: a spinner while
/// opening, the reconnecting pill, and the failure card. The preview pane
/// shows it [compact]; the full-screen player at full size (step 6).
class PlayerSurface extends ConsumerWidget {
  const new({
    this.compact = false,
    this.onNextChannel,
    this.badges = true,
    super.key,
  });

  final bool compact;

  /// Shown on the failure card when there is a next channel.
  final VoidCallback? onNextChannel;

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
    final showPicture =
        state is PlaybackPlaying || state is PlaybackReconnecting;

    return ColoredBox(
      color: colors.video,
      child: Stack(
        fit: StackFit.expand,
        children: [
          if (showPicture) engine.videoView(background: colors.video),
          if (state is PlaybackOpening ||
              (state is PlaybackPlaying && state.buffering))
            const Center(child: _Spinner()),
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
                  onNextChannel: onNextChannel,
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _Spinner extends StatelessWidget {
  const new();

  @override
  Widget build(BuildContext context) => SizedBox.square(
    dimension: 28,
    child: CircularProgressIndicator(
      strokeWidth: 3,
      color: context.tokens.colors.textPrimary,
    ),
  );
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
/// the server's, then Retry, Next channel and Details.
class PlaybackFailureCard extends StatefulWidget {
  const new({
    required this.state,
    required this.onRetry,
    this.onNextChannel,
    this.compact = false,
    super.key,
  });

  final PlaybackFailed state;
  final VoidCallback onRetry;
  final VoidCallback? onNextChannel;
  final bool compact;

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
    final text = problemText(problem, attempts: widget.state.attempts);
    final detail = [
      if (problem.failure case final failure?) '$failure',
      ?problem.detail,
    ].join('\n');

    return Container(
      constraints: BoxConstraints(maxWidth: widget.compact ? 420 : 480),
      padding: EdgeInsets.all(
        widget.compact ? tokens.spacing.s16 : tokens.spacing.s20,
      ),
      decoration: BoxDecoration(
        color: colors.surface2,
        borderRadius: tokens.radii.lgAll,
        border: Border.all(color: colors.border),
      ),
      child: FocusTraversalGroup(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                AppIcon(AppIcons.alertTriangle, color: colors.warning),
                SizedBox(width: tokens.spacing.s12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        text.title,
                        style: tokens.text.bodyStrong.copyWith(
                          color: colors.textPrimary,
                        ),
                      ),
                      SizedBox(height: tokens.spacing.s4),
                      Text(
                        text.message,
                        maxLines: widget.compact ? 3 : 5,
                        overflow: TextOverflow.ellipsis,
                        style: tokens.text.caption.copyWith(
                          color: colors.textSecondary,
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
                  size: AppButtonSize.s,
                  autofocus: !widget.compact,
                  onPressed: widget.onRetry,
                ),
                if (widget.onNextChannel != null)
                  AppButton(
                    label: 'Next channel',
                    variant: AppButtonVariant.secondary,
                    size: AppButtonSize.s,
                    onPressed: widget.onNextChannel,
                  ),
                if (detail.isNotEmpty)
                  AppButton(
                    label: _details ? 'Hide details' : 'Details',
                    variant: AppButtonVariant.ghost,
                    size: AppButtonSize.s,
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
