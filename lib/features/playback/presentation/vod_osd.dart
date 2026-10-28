import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:iptv_player/core/images/artwork_scope.dart';
import 'package:iptv_player/core/library/library_item.dart';
import 'package:iptv_player/core/text/format.dart';
import 'package:iptv_player/design/components.dart';
import 'package:iptv_player/design/tokens.dart';
import 'package:iptv_player/features/playback/data/playback_providers.dart';
import 'package:iptv_player/features/playback/domain/playable.dart';
import 'package:iptv_player/features/playback/domain/playback_state.dart';
import 'package:iptv_player/features/playback/presentation/player_overlays.dart';
import 'package:iptv_player/features/playback/presentation/time_corner.dart';
import 'package:iptv_player/features/playback/presentation/vod_player_controller.dart';
import 'package:iptv_player/features/vod/domain/titles.dart';
import 'package:iptv_player/features/vod/presentation/vod_text.dart';

/// The top of a movie's or an episode's OSD (the approved sketch): the
/// title, "S2 · E4 · Undertow" for an episode, the picture's and sound's
/// badges, and the clock with the time it ends.
class VodOsdTop extends ConsumerWidget {
  const new({
    required this.item,
    required this.onBack,
    this.remaining,
    this.speed = 1,
    super.key,
  });

  final Playable item;
  final VoidCallback onBack;

  /// What is left to play, for the clock's "Ends 10:42 PM" ([OsdClock]);
  /// null while it isn't known or isn't worth saying (the file opening,
  /// its end card).
  final Duration? remaining;
  final double speed;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tokens = context.tokens;
    final colors = tokens.colors;
    final size = ref.watch(videoSizeProvider).value;
    final tracks = ref.watch(playerTracksProvider).value;
    final sound = tracks?.audio
        .where((t) => t.id == tracks.audioId)
        .firstOrNull
        ?.channels;
    final badges = [?pictureBadge(size?.$2), ?soundBadge(channelCount(sound))];
    final (title, line) = playableTitleLines(item);
    // A phone held upright: the badges under the title, which keeps the
    // room (ADR-068).
    final narrow = OsdRoom.of(context).narrow;
    final badgeRow = [
      for (final (i, badge) in badges.indexed) ...[
        if (i > 0 || !narrow) SizedBox(width: tokens.spacing.s8),
        AppBadge(badge, tone: AppBadgeTone.outline),
      ],
    ];
    return OsdShade(
      top: true,
      child: Padding(
        padding: OsdRoom.of(context).topPadding(context),
        child: Row(
          children: [
            OsdBack(onPressed: onBack),
            SizedBox(width: tokens.spacing.s16),
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
                  if (narrow && badgeRow.isNotEmpty) ...[
                    SizedBox(height: tokens.spacing.s4),
                    Row(children: badgeRow),
                  ],
                ],
              ),
            ),
            if (!narrow) ...badgeRow,
            SizedBox(width: tokens.spacing.s16),
            OsdClock(remaining: remaining, speed: speed),
          ],
        ),
      ),
    );
  }
}

/// What the player calls [item]: a title, and for an episode "S2 · E4 ·
/// Undertow" under its show's name (the OSD's top, the opening screen).
(String, String?) playableTitleLines(Playable item) => switch (item) {
  PlayableMovie(:final movie) => (movie.name, null),
  PlayableEpisode(:final series, :final episode) => (
    series.name,
    episodeLine(episode),
  ),
  PlayableLibraryItem(item: final file) => libraryTitleLines(file),
  PlayableChannel(:final channel) => (channel.name, null),
};

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

/// The bottom of a movie's or an episode's OSD (ADR-017): the "Resumed
/// from" line, the seek bar with the time on each side, and the controls
/// — Play or Pause, back and forward 10 s, Start over, the next episode
/// when there is one, then [leading] (the volume) from the left;
/// [trailing] at the right.
class VodOsdBottom extends StatelessWidget {
  const new({
    required this.timeline,
    required this.seeking,
    required this.resumedFrom,
    required this.onTogglePause,
    required this.onNudge,
    required this.onDrag,
    required this.onStartOver,
    required this.leading,
    required this.trailing,
    this.onNext,
    this.preparing = false,
    this.playFocusNode,
    this.seekFocusNode,
    this.rowFocusNode,
    this.homeKey = true,
    super.key,
  });

  final VodTimeline timeline;

  /// The keys or a drag are moving the bar: the bubble shows.
  final bool seeking;
  final Duration? resumedFrom;

  /// No picture yet: the opening screen under the OSD says how it goes
  /// (player_opening.dart), so nothing is said here, and not "Resumed
  /// from" before it has.
  final bool preparing;
  final VoidCallback onTogglePause;
  final void Function(Duration delta) onNudge;
  final void Function(Duration position, {bool commit}) onDrag;

  /// Back to the very start (Home): always there, not only after a
  /// resume, and after the seek buttons, where a stray press beside Play
  /// can't lose the place.
  final VoidCallback onStartOver;

  /// An episode with one after it: Next episode, after the seek buttons.
  final VoidCallback? onNext;
  final List<Widget> leading;
  final List<Widget> trailing;

  /// Play's focus, for the remote to land on (a TV).
  final FocusNode? playFocusNode;

  /// A TV's: the seek bar is a stop of its own, above Play, whose ←/→
  /// the player hears and seeks with. Null on the desktop, where ←/→
  /// seek from anywhere and the bar is the mouse's.
  final FocusNode? seekFocusNode;

  /// A TV's: the row of controls as one node, so the player knows the
  /// remote is on one of them (↑ from any of them is the seek bar).
  final FocusNode? rowFocusNode;

  /// "Resumed from 24:10" names the Home key that starts over; false
  /// where nobody has one to press (a phone, a tablet: Start over is the
  /// button beside the seek buttons).
  final bool homeKey;

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
    final time = tokens.text.timecode.copyWith(color: colors.textPrimary);
    // The bar keeps room above it for its bubble: the times sit beside
    // the bar itself.
    Widget beside(Widget text) => Padding(
      padding: EdgeInsets.only(top: AppSlider.bubbleRoom(context)),
      child: text,
    );
    Widget bar({required bool focused}) => AppSlider(
      value: fraction(timeline.position),
      bufferedValue: timeline.buffered > Duration.zero
          ? fraction(timeline.position + timeline.buffered)
          : null,
      enabled: ms > 0,
      overVideo: true,
      showBubble: seeking,
      focused: focused,
      bubbleLabel: (v) => formatPosition(at(v)),
      semanticLabel: 'Position',
      onChanged: (v) => onDrag(at(v)),
      onChangeEnd: (v) => onDrag(at(v), commit: true),
    );
    return OsdShade(
      top: false,
      child: Padding(
        padding: OsdRoom.of(context).bottomPadding(context),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (resumedFrom case final from? when !preparing)
              Padding(
                padding: EdgeInsets.only(bottom: tokens.spacing.s8),
                child: Text(
                  'Resumed from ${formatPosition(from)}'
                  '${homeKey ? ' · Home starts over' : ''}',
                  style: tokens.text.body.copyWith(color: colors.textEmphasis),
                ),
              ),
            Row(
              children: [
                beside(Text(formatPosition(timeline.position), style: time)),
                SizedBox(width: tokens.spacing.s12),
                Expanded(
                  child: switch (seekFocusNode) {
                    // ←/→ seek from anywhere in the player: the bar is for
                    // the mouse, not a Tab stop of its own.
                    null => ExcludeFocus(child: bar(focused: false)),
                    // A TV's stop: the slider's own keys stay out of it.
                    final node => Focus(
                      focusNode: node,
                      child: ListenableBuilder(
                        listenable: node,
                        builder: (context, _) =>
                            ExcludeFocus(child: bar(focused: node.hasFocus)),
                      ),
                    ),
                  },
                ),
                SizedBox(width: tokens.spacing.s12),
                beside(
                  Text(switch (timeline.remaining) {
                    final left? => '−${formatPosition(left)}',
                    null => '',
                  }, style: time),
                ),
              ],
            ),
            SizedBox(height: tokens.spacing.s8),
            _row(
              OsdControls(
                leading: [
                  OsdButton(
                    icon: timeline.paused ? AppIcons.play : AppIcons.pause,
                    tooltip: timeline.paused ? 'Play' : 'Pause',
                    shortcut: 'Space',
                    primary: true,
                    focusNode: playFocusNode,
                    onPressed: onTogglePause,
                  ),
                  OsdButton(
                    icon: AppIcons.replay10,
                    tooltip: 'Back 10 seconds',
                    shortcut: '←',
                    onPressed: () => onNudge(-step),
                  ),
                  OsdButton(
                    icon: AppIcons.forward10,
                    tooltip: 'Forward 10 seconds',
                    shortcut: '→',
                    onPressed: () => onNudge(step),
                  ),
                  OsdButton(
                    icon: AppIcons.startOver,
                    tooltip: 'Start over',
                    shortcut: 'Home',
                    onPressed: onStartOver,
                  ),
                  if (onNext != null)
                    OsdButton(
                      icon: AppIcons.skipNext,
                      tooltip: 'Next episode',
                      onPressed: onNext,
                    ),
                  ...leading,
                ],
                trailing: trailing,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _row(Widget row) => switch (rowFocusNode) {
    null => row,
    final node => Focus(
      focusNode: node,
      canRequestFocus: false,
      skipTraversal: true,
      child: row,
    ),
  };
}

/// The next-episode card (decision 4, ADR-033; the approved sketch),
/// bottom right above the seek bar. It stands on its own: the OSD shows
/// and hides around it. Its first button takes the focus when it comes
/// if [autofocus]; with [arrowsMove] (a TV remote's) ←/→ move between its
/// two buttons and never seek from here. Counting: "Next episode · N",
/// which plays it at once, its bar running down with the count out of
/// [countdownLength], and Hide. At the end after a Hide: Play next
/// episode and Back to series.
class NextEpisodeCard extends StatefulWidget {
  const new({
    required this.next,
    required this.phase,
    required this.onPlay,
    required this.onSecondary,
    this.countdown,
    this.countdownLength = VodPlayerController.countdownFrom,
    this.playFocusNode,
    this.autofocus = true,
    this.arrowsMove = true,
    this.compact = false,
    this.touch = false,
    super.key,
  });

  final NextEpisode next;
  final NextCardPhase phase;

  /// The seconds until the next episode plays by itself, while counting.
  final int? countdown;

  /// What [countdown] counts from (50, or 10 for a short episode).
  final int countdownLength;
  final VoidCallback onPlay;

  /// Hide while counting, Back to series at the end.
  final VoidCallback onSecondary;

  /// The first button's focus, for the player to hand it back; the card's
  /// own when null.
  final FocusNode? playFocusNode;

  /// The first button takes the focus when the card comes.
  final bool autofocus;

  /// ←/→ move between the two buttons (a TV's); otherwise they are the
  /// player's, which seeks with them.
  final bool arrowsMove;

  /// A phone on its side (ADR-068): one row, the words beside the
  /// buttons and no still, low enough to sit between the OSD's bars.
  final bool compact;

  /// Pressed with a finger (a phone, a tablet): buttons a size up, 44 px.
  final bool touch;

  static const width = 440.0;

  @override
  State<NextEpisodeCard> createState() => _NextEpisodeCardState();
}

class _NextEpisodeCardState extends State<NextEpisodeCard> {
  FocusNode? _ownPlay;
  final _secondary = FocusNode(debugLabel: 'next episode card, second');

  FocusNode get _play =>
      widget.playFocusNode ??
      (_ownPlay ??= FocusNode(debugLabel: 'next episode'));

  @override
  void initState() {
    super.initState();
    // The player holds the focus in this scope, so autofocus can't take
    // it: ask once the card is in.
    if (widget.autofocus) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _play.requestFocus();
      });
    }
  }

  @override
  void dispose() {
    _ownPlay?.dispose();
    _secondary.dispose();
    super.dispose();
  }

  /// ←/→ with [NextEpisodeCard.arrowsMove]: from one button to the other.
  KeyEventResult _onKey(FocusNode node, KeyEvent event) {
    if (!widget.arrowsMove || event is KeyUpEvent) {
      return KeyEventResult.ignored;
    }
    final keyboard = HardwareKeyboard.instance;
    if (keyboard.isControlPressed ||
        keyboard.isAltPressed ||
        keyboard.isMetaPressed) {
      return KeyEventResult.ignored;
    }
    final to = switch (event.logicalKey) {
      LogicalKeyboardKey.arrowLeft => _play,
      LogicalKeyboardKey.arrowRight => _secondary,
      _ => null,
    };
    if (to == null) return KeyEventResult.ignored;
    if (!to.hasPrimaryFocus) to.requestFocus();
    return KeyEventResult.handled;
  }

  @override
  Widget build(BuildContext context) {
    final tokens = context.tokens;
    final colors = tokens.colors;
    final episode = widget.next;
    final countdown = widget.countdown;
    final (play, secondary) = switch (widget.phase) {
      NextCardPhase.end => ('Play next episode', 'Back to series'),
      NextCardPhase.count || NextCardPhase.none => (
        countdown == null ? 'Next episode' : 'Next episode · $countdown',
        'Hide',
      ),
    };
    final size = widget.touch ? AppButtonSize.m : AppButtonSize.s;
    final buttons = Focus(
      canRequestFocus: false,
      skipTraversal: true,
      onKeyEvent: _onKey,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        // The two buttons on one line, the count's bar under the first.
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // The count's bar is as wide as the button above it.
          IntrinsicWidth(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                AppButton(
                  label: play,
                  icon: AppIcons.play,
                  size: size,
                  focusNode: _play,
                  onPressed: widget.onPlay,
                ),
                if (widget.phase != NextCardPhase.end) ...[
                  SizedBox(height: tokens.spacing.s4),
                  // The bar's room is kept: the card never changes size.
                  Visibility.maintain(
                    visible: countdown != null,
                    child: TweenAnimationBuilder<double>(
                      tween: Tween(
                        end:
                            (countdown ?? widget.countdownLength) /
                            widget.countdownLength,
                      ),
                      duration: const Duration(seconds: 1),
                      builder: (context, value, _) => ProgressBar(value: value),
                    ),
                  ),
                ],
              ],
            ),
          ),
          SizedBox(width: tokens.spacing.s8),
          AppButton(
            label: secondary,
            variant: AppButtonVariant.secondary,
            size: size,
            focusNode: _secondary,
            onPressed: widget.onSecondary,
          ),
        ],
      ),
    );
    final title = episode.title.isEmpty
        ? 'Episode ${episode.episode ?? ''}'.trim()
        : episode.title;
    final decoration = BoxDecoration(
      color: colors.surface2.withValues(alpha: 0.92),
      borderRadius: tokens.radii.lgAll,
      border: Border.all(color: colors.border),
    );
    if (widget.compact) {
      return Container(
        constraints: const BoxConstraints(maxWidth: NextEpisodeCard.width),
        padding: EdgeInsets.all(tokens.spacing.s12),
        decoration: decoration,
        child: FocusTraversalGroup(
          policy: appTraversalPolicy(),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Flexible(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'NEXT EPISODE',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: tokens.text.overline.copyWith(
                        color: colors.textTertiary,
                      ),
                    ),
                    SizedBox(height: tokens.spacing.s4),
                    // "S1 · E2 · Ledger": the episode's place, then its
                    // name, on the one line there is.
                    Text(
                      [
                        if (episode.season != null && episode.episode != null)
                          'S${episode.season} · E${episode.episode}',
                        title,
                      ].join(' · '),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: tokens.text.bodyStrong.copyWith(
                        color: colors.textPrimary,
                      ),
                    ),
                  ],
                ),
              ),
              SizedBox(width: tokens.spacing.s12),
              buttons,
            ],
          ),
        ),
      );
    }
    const still = Size(144, 81);
    return Container(
      width: NextEpisodeCard.width,
      padding: EdgeInsets.all(tokens.spacing.s16),
      decoration: decoration,
      child: FocusTraversalGroup(
        policy: appTraversalPolicy(),
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
                        title,
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
            buttons,
          ],
        ),
      ),
    );
  }
}
