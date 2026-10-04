import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:iptv_player/core/core_providers.dart';
import 'package:iptv_player/core/images/artwork_scope.dart';
import 'package:iptv_player/core/library/library_item.dart';
import 'package:iptv_player/core/text/format.dart';
import 'package:iptv_player/design/components.dart';
import 'package:iptv_player/design/tokens.dart';
import 'package:iptv_player/features/playback/data/playback_providers.dart';
import 'package:iptv_player/features/playback/domain/playable.dart';
import 'package:iptv_player/features/playback/domain/playback_state.dart';
import 'package:iptv_player/features/playback/presentation/vod_player_controller.dart';
import 'package:iptv_player/features/vod/domain/titles.dart';
import 'package:iptv_player/features/vod/presentation/vod_text.dart';

/// The top of a movie's or an episode's OSD (the approved sketch): the
/// title, "S2 · E4 · Undertow" for an episode, the picture's and sound's
/// badges, and the clock.
class VodOsdTop extends ConsumerWidget {
  const new({required this.item, super.key});

  final Playable item;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tokens = context.tokens;
    final colors = tokens.colors;
    final size = ref.watch(videoSizeProvider).value;
    final tracks = ref.watch(playerTracksProvider).value;
    final now = ref.watch(appClockProvider)();
    final sound = tracks?.audio
        .where((t) => t.id == tracks.audioId)
        .firstOrNull
        ?.channels;
    final badges = [?pictureBadge(size?.$2), ?soundBadge(channelCount(sound))];
    final (title, line) = switch (item) {
      PlayableMovie(:final movie) => (movie.name, null),
      PlayableEpisode(:final series, :final episode) => (
        series.name,
        episodeLine(episode),
      ),
      PlayableLibraryItem(item: final file) => libraryTitleLines(file),
      PlayableChannel(:final channel) => (channel.name, null),
    };
    return DecoratedBox(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [colors.scrim, colors.scrim.withValues(alpha: 0)],
        ),
      ),
      child: Padding(
        padding: EdgeInsets.fromLTRB(
          tokens.spacing.s32,
          tokens.spacing.s24,
          tokens.spacing.s32,
          tokens.spacing.s48,
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: tokens.text.h2.copyWith(color: colors.textPrimary),
                  ),
                  if (line != null) ...[
                    SizedBox(height: tokens.spacing.s4),
                    Text(
                      line,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: tokens.text.bodyStrong.copyWith(
                        color: colors.textSecondary,
                      ),
                    ),
                  ],
                ],
              ),
            ),
            for (final badge in badges) ...[
              SizedBox(width: tokens.spacing.s8),
              AppBadge(badge, tone: AppBadgeTone.outline),
            ],
            SizedBox(width: tokens.spacing.s16),
            Text(
              formatClock(now),
              style: tokens.text.h3.copyWith(color: colors.textPrimary),
            ),
          ],
        ),
      ),
    );
  }
}

/// A library file's title and line: a show's name over "S2 · E4 ·
/// Undertow", else its own title and year.
(String, String?) libraryTitleLines(LibraryItem file) {
  if (file.kind == LibraryKind.episode && file.showTitle != null) {
    final title = file.title.trim();
    return (
      file.showTitle!,
      'S${file.season ?? 1} · E${file.episode ?? 1}'
          '${title.isEmpty ? '' : ' · $title'}',
    );
  }
  return (file.title, file.year?.toString());
}

/// "S2 · E4 · Undertow".
String episodeLine(EpisodeItem episode) =>
    'S${episode.season} · E${episode.episode}'
    '${episode.title.trim().isEmpty ? '' : ' · ${episode.title.trim()}'}';

/// mpv's channel layout (`5.1(side)`, `7.1`, `stereo`) as a count.
int? channelCount(String? layout) {
  if (layout == null) return null;
  final match = RegExp(r'^(\d+)\.(\d+)').firstMatch(layout.trim());
  if (match != null) {
    return int.parse(match.group(1)!) + int.parse(match.group(2)!);
  }
  return switch (layout.trim().toLowerCase()) {
    'stereo' => 2,
    'mono' => 1,
    _ => int.tryParse(layout.trim()),
  };
}

/// The bottom of a movie's or an episode's OSD: the "Resumed from" line,
/// the seek bar with the time on each side, and the controls — Play or
/// Pause, −10 and +10, then [controls] (the live player's).
class VodOsdBottom extends StatelessWidget {
  const new({
    required this.timeline,
    required this.seeking,
    required this.resumedFrom,
    required this.onTogglePause,
    required this.onNudge,
    required this.onDrag,
    required this.controls,
    this.preparing = false,
    super.key,
  });

  final VodTimeline timeline;

  /// The keys or a drag are moving the bar: the bubble shows.
  final bool seeking;
  final Duration? resumedFrom;

  /// No picture yet: "Preparing…" where "Resumed from" goes.
  final bool preparing;
  final VoidCallback onTogglePause;
  final void Function(Duration delta) onNudge;
  final void Function(Duration position, {bool commit}) onDrag;
  final List<Widget> controls;

  static const step = Duration(seconds: 10);

  @override
  Widget build(BuildContext context) {
    final tokens = context.tokens;
    final colors = tokens.colors;
    final length = timeline.duration;
    final ms = length?.inMilliseconds ?? 0;
    double fraction(Duration at) =>
        ms <= 0 ? 0 : (at.inMilliseconds / ms).clamp(0.0, 1.0);
    Duration at(double value) => Duration(milliseconds: (value * ms).round());
    final time = tokens.text.mono.copyWith(color: colors.textSecondary);
    return DecoratedBox(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.bottomCenter,
          end: Alignment.topCenter,
          colors: [colors.scrim, colors.scrim.withValues(alpha: 0)],
        ),
      ),
      child: Padding(
        padding: EdgeInsets.fromLTRB(
          tokens.spacing.s32,
          tokens.spacing.s48,
          tokens.spacing.s32,
          tokens.spacing.s24,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (preparing || resumedFrom != null)
              Padding(
                padding: EdgeInsets.only(bottom: tokens.spacing.s8),
                child: Text(
                  switch (resumedFrom) {
                    _ when preparing => 'Preparing…',
                    final from? =>
                      'Resumed from ${formatPosition(from)} · Home starts over',
                    null => '',
                  },
                  style: tokens.text.label.copyWith(color: colors.textEmphasis),
                ),
              ),
            Row(
              children: [
                Text(formatPosition(timeline.position), style: time),
                SizedBox(width: tokens.spacing.s12),
                Expanded(
                  // ←/→ seek from anywhere in the player: the bar is for
                  // the mouse, not a Tab stop of its own.
                  child: ExcludeFocus(
                    child: AppSlider(
                      value: fraction(timeline.position),
                      bufferedValue: timeline.buffered > Duration.zero
                          ? fraction(timeline.position + timeline.buffered)
                          : null,
                      enabled: ms > 0,
                      showBubble: seeking,
                      bubbleLabel: (v) => formatPosition(at(v)),
                      semanticLabel: 'Position',
                      onChanged: (v) => onDrag(at(v)),
                      onChangeEnd: (v) => onDrag(at(v), commit: true),
                    ),
                  ),
                ),
                SizedBox(width: tokens.spacing.s12),
                Text(switch (timeline.remaining) {
                  final left? => '−${formatPosition(left)}',
                  null => '',
                }, style: time),
              ],
            ),
            SizedBox(height: tokens.spacing.s8),
            Row(
              children: [
                AppIconButton(
                  icon: timeline.paused ? AppIcons.play : AppIcons.pause,
                  tooltip: timeline.paused ? 'Play' : 'Pause',
                  shortcut: 'Space',
                  onPressed: onTogglePause,
                ),
                SizedBox(width: tokens.spacing.s4),
                AppButton(
                  label: '−10',
                  variant: AppButtonVariant.ghost,
                  size: AppButtonSize.s,
                  onPressed: () => onNudge(-step),
                ),
                AppButton(
                  label: '+10',
                  variant: AppButtonVariant.ghost,
                  size: AppButtonSize.s,
                  onPressed: () => onNudge(step),
                ),
                const Spacer(),
                ...controls,
              ],
            ),
          ],
        ),
      ),
    );
  }
}

/// The next-episode card (decision 4; the approved sketch), bottom right
/// above the seek bar. Counting ([countdown] set): Play now, focused, its
/// bar running down with the count, and Cancel. At the end after a cancel
/// ([countdown] null): Play next episode and Back to series.
class NextEpisodeCard extends StatefulWidget {
  const new({
    required this.next,
    required this.countdown,
    required this.onPlay,
    required this.onSecondary,
    super.key,
  });

  final NextEpisode next;
  final int? countdown;
  final VoidCallback onPlay;

  /// Cancel while counting; Back to series at the end.
  final VoidCallback onSecondary;

  static const width = 440.0;

  @override
  State<NextEpisodeCard> createState() => _NextEpisodeCardState();
}

class _NextEpisodeCardState extends State<NextEpisodeCard> {
  final _play = FocusNode(debugLabel: 'next episode');

  @override
  void initState() {
    super.initState();
    // The player holds the focus in this scope, so autofocus can't take
    // it: ask once the card is in.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _play.requestFocus();
    });
  }

  @override
  void dispose() {
    _play.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final tokens = context.tokens;
    final colors = tokens.colors;
    final episode = widget.next;
    final countdown = widget.countdown;
    const still = Size(144, 81);
    return Container(
      width: NextEpisodeCard.width,
      padding: EdgeInsets.all(tokens.spacing.s16),
      decoration: BoxDecoration(
        color: colors.surface2.withValues(alpha: 0.92),
        borderRadius: tokens.radii.lgAll,
        border: Border.all(color: colors.border),
      ),
      child: FocusTraversalGroup(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'NEXT EPISODE',
              style: tokens.text.overline.copyWith(color: colors.textTertiary),
            ),
            SizedBox(height: tokens.spacing.s12),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                ClipRRect(
                  borderRadius: tokens.radii.smAll,
                  child: SizedBox.fromSize(
                    size: still,
                    child: PosterArtwork(
                      title: '',
                      image: artworkFor(
                        context,
                        episode.stillUrl,
                        width: still.width,
                      ),
                    ),
                  ),
                ),
                SizedBox(width: tokens.spacing.s12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (episode.season != null && episode.episode != null)
                        Text(
                          'S${episode.season} · E${episode.episode}',
                          style: tokens.text.caption.copyWith(
                            color: colors.textSecondary,
                          ),
                        ),
                      Text(
                        episode.title.isEmpty
                            ? 'Episode ${episode.episode ?? ''}'.trim()
                            : episode.title,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: tokens.text.bodyStrong.copyWith(
                          color: colors.textPrimary,
                        ),
                      ),
                      if (episode.duration case final length?)
                        Text(
                          formatRuntime(length),
                          style: tokens.text.caption.copyWith(
                            color: colors.textTertiary,
                          ),
                        ),
                    ],
                  ),
                ),
              ],
            ),
            SizedBox(height: tokens.spacing.s16),
            Row(
              children: [
                // The count's bar is as wide as the button above it.
                IntrinsicWidth(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      AppButton(
                        label: countdown == null
                            ? 'Play next episode'
                            : 'Play now · $countdown',
                        icon: AppIcons.play,
                        size: AppButtonSize.s,
                        focusNode: _play,
                        onPressed: widget.onPlay,
                      ),
                      if (countdown != null) ...[
                        SizedBox(height: tokens.spacing.s4),
                        TweenAnimationBuilder<double>(
                          tween: Tween(
                            end: countdown / VodPlayerController.countdownFrom,
                          ),
                          duration: const Duration(seconds: 1),
                          builder: (context, value, _) =>
                              ProgressBar(value: value),
                        ),
                      ],
                    ],
                  ),
                ),
                SizedBox(width: tokens.spacing.s8),
                AppButton(
                  label: countdown == null ? 'Back to series' : 'Cancel',
                  variant: AppButtonVariant.secondary,
                  size: AppButtonSize.s,
                  onPressed: widget.onSecondary,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
