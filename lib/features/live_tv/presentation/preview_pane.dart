import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:iptv_player/core/core_providers.dart';
import 'package:iptv_player/core/text/format.dart';
import 'package:iptv_player/design/components.dart';
import 'package:iptv_player/design/tokens.dart';
import 'package:iptv_player/features/live_tv/data/live_tv_providers.dart';
import 'package:iptv_player/features/live_tv/domain/channels.dart';
import 'package:iptv_player/features/live_tv/domain/now_next.dart';
import 'package:iptv_player/features/live_tv/presentation/live_tv_state.dart';
import 'package:iptv_player/features/playback/data/playback_providers.dart';
import 'package:iptv_player/features/playback/presentation/player_surface.dart';

/// The canvas's preview pane (540 px): the selected channel playing in a
/// rounded 16:9 frame, what's on now and next, and the actions. A new
/// selection plays after [debounce] (docs/05), so moving through the list
/// doesn't open a stream per row.
class PreviewPane extends ConsumerStatefulWidget {
  const new({
    required this.controller,
    this.onBack,
    this.onFullscreen,
    this.onNextChannel,
    super.key,
  });

  final FocusPaneController controller;

  /// ← goes back to the channel list.
  final VoidCallback? onBack;
  final void Function(ChannelItem channel)? onFullscreen;
  final VoidCallback? onNextChannel;

  static const width = 540.0;
  static const debounce = Duration(milliseconds: 350);

  @override
  ConsumerState<PreviewPane> createState() => _PreviewPaneState();
}

class _PreviewPaneState extends ConsumerState<PreviewPane> {
  Timer? _debounce;

  @override
  void dispose() {
    _debounce?.cancel();
    super.dispose();
  }

  void _schedule(ChannelItem? channel) {
    _debounce?.cancel();
    if (channel == null) return;
    _debounce = Timer(PreviewPane.debounce, () {
      final coordinator = ref.read(playbackCoordinatorProvider);
      if (coordinator.current?.id == channel.id &&
          coordinator.current?.sourceId == channel.sourceId) {
        return;
      }
      unawaited(coordinator.playLive(channel));
    });
  }

  @override
  Widget build(BuildContext context) {
    final tokens = context.tokens;
    final colors = tokens.colors;
    ref.listen(
      liveTvControllerProvider.select((view) => view?.selected),
      (_, channel) => _schedule(channel),
    );
    final selected = ref.watch(liveTvControllerProvider)?.selected;
    // The row may be stale (a favorite toggled since): read it fresh.
    final fresh = selected == null
        ? null
        : ref.watch(freshChannelProvider(selected)).value ?? selected;
    final guide = fresh == null ? null : ref.watch(nowNextProvider(fresh));

    return Container(
      decoration: BoxDecoration(
        color: colors.surface1,
        borderRadius: tokens.radii.lgAll,
        border: Border.all(color: colors.borderSubtle),
      ),
      padding: EdgeInsets.all(tokens.spacing.s16),
      child: CallbackShortcuts(
        bindings: {
          const SingleActivator(LogicalKeyboardKey.arrowLeft): ?widget.onBack,
        },
        child: FocusPane(
          debugLabel: 'live-preview',
          controller: widget.controller,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              AspectRatio(
                aspectRatio: 16 / 9,
                child: ClipRRect(
                  borderRadius: tokens.radii.mdAll,
                  child: fresh == null
                      ? ColoredBox(
                          color: colors.video,
                          child: const EmptyState(
                            compact: true,
                            icon: AppIcons.liveTv,
                            title: 'Pick a channel',
                            message: 'It plays here.',
                          ),
                        )
                      : GestureDetector(
                          onDoubleTap: () => widget.onFullscreen?.call(fresh),
                          child: PlayerSurface(
                            compact: true,
                            onNextChannel: widget.onNextChannel,
                          ),
                        ),
                ),
              ),
              if (fresh != null) ...[
                SizedBox(height: tokens.spacing.s16 + 2),
                Expanded(
                  child: _Details(
                    channel: fresh,
                    guide: guide?.value,
                    // Only the first lookup: a refresh (the guide
                    // changed, a programme ended) keeps what it shows.
                    loading: (guide?.isLoading ?? false) && !guide!.hasValue,
                  ),
                ),
                SizedBox(height: tokens.spacing.s12),
                Row(
                  children: [
                    Expanded(
                      child: AppButton(
                        label: 'Watch full screen',
                        icon: AppIcons.fullscreen,
                        size: AppButtonSize.l,
                        onPressed: widget.onFullscreen == null
                            ? null
                            : () => widget.onFullscreen!(fresh),
                      ),
                    ),
                    SizedBox(width: tokens.spacing.s8 + 2),
                    AppIconButton(
                      icon: fresh.isFavorite
                          ? AppIcons.starFilled
                          : AppIcons.star,
                      tooltip: fresh.isFavorite
                          ? 'Remove from favorites'
                          : 'Add to favorites',
                      shortcut: 'F',
                      bordered: true,
                      size: 44,
                      selected: fresh.isFavorite,
                      onPressed: () => unawaited(
                        ref
                            .read(channelRepositoryProvider)
                            .setFavorite(fresh, on: !fresh.isFavorite),
                      ),
                    ),
                  ],
                ),
              ] else
                const Spacer(),
            ],
          ),
        ),
      ),
    );
  }
}

class _Details extends ConsumerWidget {
  const new({
    required this.channel,
    required this.guide,
    required this.loading,
  });

  final ChannelItem channel;
  final NowNext? guide;
  final bool loading;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tokens = context.tokens;
    final colors = tokens.colors;
    final now = ref.watch(appClockProvider)();
    final current = guide?.now;
    final next = guide?.next;

    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              ChannelLogo(
                name: channel.name,
                size: 22,
                image: _logo(channel.logoUrl),
              ),
              SizedBox(width: tokens.spacing.s8),
              Expanded(
                child: Text(
                  [
                    if (channel.number case final number?) '$number',
                    channel.name,
                  ].join(' · '),
                  overflow: TextOverflow.ellipsis,
                  style: tokens.text.caption
                      .withWeight(600)
                      .copyWith(color: colors.textSecondary),
                ),
              ),
            ],
          ),
          SizedBox(height: tokens.spacing.s8 + 2),
          Text(
            current?.title ?? channel.name,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: tokens.text.h1
                .withWeight(800)
                .copyWith(color: colors.textPrimary),
          ),
          SizedBox(height: tokens.spacing.s8 + 2),
          if (current != null) ...[
            Row(
              children: [
                Text(
                  formatTimeRange(current.start, current.end),
                  style: tokens.text.caption.copyWith(
                    color: colors.textSecondary,
                  ),
                ),
                SizedBox(width: tokens.spacing.s12),
                Expanded(child: ProgressBar(value: current.progressAt(now))),
                SizedBox(width: tokens.spacing.s12),
                Text(
                  formatTimeLeft(current.end.difference(now)),
                  style: tokens.text.caption.copyWith(
                    color: colors.textSecondary,
                  ),
                ),
              ],
            ),
            if (current.description case final description?
                when description.trim().isNotEmpty) ...[
              SizedBox(height: tokens.spacing.s8 + 2),
              Text(
                description.trim(),
                maxLines: 3,
                overflow: TextOverflow.ellipsis,
                style: tokens.text.label
                    .withWeight(400)
                    .copyWith(color: colors.textSecondary),
              ),
            ],
          ] else
            Text(
              switch (next) {
                _ when loading => 'Looking up what’s on…',
                null => 'No guide information',
                _ => 'Nothing on right now',
              },
              style: tokens.text.caption.copyWith(
                color: colors.textTertiary,
                fontStyle: FontStyle.italic,
              ),
            ),
          if (next != null) ...[
            SizedBox(height: tokens.spacing.s16 + 2),
            Container(
              padding: EdgeInsets.symmetric(
                horizontal: tokens.spacing.s12 + 2,
                vertical: tokens.spacing.s12,
              ),
              decoration: BoxDecoration(
                color: colors.surface2,
                borderRadius: tokens.radii.controlAll,
                border: Border.all(color: colors.surface3),
              ),
              child: Row(
                children: [
                  Text(
                    'NEXT · ${formatClock(next.start)}',
                    style: tokens.text.micro
                        .withWeight(800)
                        .copyWith(color: colors.textTertiary),
                  ),
                  SizedBox(width: tokens.spacing.s12),
                  Expanded(
                    child: Text(
                      next.title,
                      overflow: TextOverflow.ellipsis,
                      style: tokens.text.label.copyWith(
                        color: colors.textEmphasis,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  static ImageProvider? _logo(String? url) {
    final uri = url == null ? null : Uri.tryParse(url);
    if (uri == null || !uri.scheme.startsWith('http')) return null;
    return NetworkImage(url!);
  }
}
