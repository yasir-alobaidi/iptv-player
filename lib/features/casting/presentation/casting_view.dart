import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:iptv_player/core/cast/cast_receiver.dart';
import 'package:iptv_player/core/core_providers.dart';
import 'package:iptv_player/core/images/artwork_scope.dart';
import 'package:iptv_player/core/library/library_item.dart';
import 'package:iptv_player/core/text/format.dart';
import 'package:iptv_player/design/components.dart';
import 'package:iptv_player/design/tokens.dart';
import 'package:iptv_player/features/casting/data/casting_providers.dart';
import 'package:iptv_player/features/casting/domain/casting_state.dart';
import 'package:iptv_player/features/casting/presentation/cast_plan_text.dart';
import 'package:iptv_player/features/casting/presentation/cast_text.dart';
import 'package:iptv_player/features/casting/presentation/casting_view_state.dart';
import 'package:iptv_player/features/live_tv/data/live_tv_providers.dart';
import 'package:iptv_player/features/live_tv/domain/channels.dart';
import 'package:iptv_player/features/live_tv/presentation/live_tv_state.dart';
import 'package:iptv_player/features/playback/data/playback_providers.dart';
import 'package:iptv_player/features/playback/domain/playable.dart';
import 'package:iptv_player/features/playback/domain/playback_state.dart';

/// The casting view (canvas `Casting`, sketches A and D), in place of the
/// screen while it is open: what plays on the TV, its programme or its
/// timeline, the quality badge with its details line and sentence, and
/// the controls. ↑/↓ change channel, Space and ←/→ play, pause and seek a
/// file, M mutes, Esc goes back while the cast carries on.
class CastingView extends ConsumerStatefulWidget {
  const new({super.key});

  /// How long ↑/↓ wait for the keys to rest before the TV changes
  /// channel, as the player does.
  static const zapDebounce = Duration(milliseconds: 350);

  /// How long ←/→ wait before a file is seeked (a relayed file restarts).
  static const seekDebounce = Duration(milliseconds: 600);

  /// ←/→'s step.
  static const seekStep = Duration(seconds: 10);

  @override
  ConsumerState<CastingView> createState() => _CastingViewState();
}

class _CastingViewState extends ConsumerState<CastingView> {
  final _focus = FocusNode(debugLabel: 'casting-view');
  ChannelItem? _zapTarget;
  Timer? _zapTimer;
  Duration? _seekTarget;
  Timer? _seekTimer;
  double? _volume;
  bool _details = false;

  @override
  void initState() {
    super.initState();
    // The screen under the view has just let go of the focus: the view
    // takes it, so its keys work at once (Tab moves into its controls).
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final focused = FocusManager.instance.primaryFocus;
      if (focused == null || !focused.hasFocus || !_isInside(focused)) {
        _focus.requestFocus();
      }
    });
  }

  bool _isInside(FocusNode node) =>
      node == _focus || node.ancestors.contains(_focus);

  @override
  void dispose() {
    _zapTimer?.cancel();
    _seekTimer?.cancel();
    _focus.dispose();
    super.dispose();
  }

  void _close() => ref.read(castingViewOpenProvider.notifier).close();

  Future<void> _stop() => ref.read(castCoordinatorProvider).disconnect();

  /// ↑ (-1) and ↓ (+1) in the list Live TV shows, wrapping.
  Future<void> _zap(int delta) async {
    final current =
        _zapTarget ??
        switch (ref.read(castingStateProvider).value?.item) {
          PlayableChannel(:final channel) => channel,
          _ => null,
        };
    if (current == null) return;
    final query =
        ref.read(liveTvControllerProvider)?.query ??
        ChannelQuery(sourceId: current.sourceId);
    final repository = ref.read(channelRepositoryProvider);
    final count = await repository.watchCount(query).first;
    if (count == 0) return;
    final index =
        (await repository.indexOf(query, current.id)).valueOrNull ?? -1;
    final target = ((index + delta) % count + count) % count;
    final next = (await repository.range(query, target, 1)).valueOrNull;
    if (!mounted || next == null || next.isEmpty) return;
    final channel = next.first;
    setState(() => _zapTarget = channel);
    _zapTimer?.cancel();
    _zapTimer = Timer(CastingView.zapDebounce, () {
      if (!mounted) return;
      setState(() => _zapTarget = null);
      ref.read(liveTvControllerProvider.notifier).select(channel);
      unawaited(ref.read(playbackCoordinatorProvider).playLive(channel));
    });
  }

  void _seekBy(Duration step, VodTimeline timeline) {
    final from = _seekTarget ?? timeline.position;
    var to = from + step;
    if (to < Duration.zero) to = Duration.zero;
    if (timeline.duration case final length? when to > length) to = length;
    _seekTo(to);
  }

  void _seekTo(Duration to) {
    setState(() => _seekTarget = to);
    _seekTimer?.cancel();
    _seekTimer = Timer(CastingView.seekDebounce, () {
      if (!mounted) return;
      final target = _seekTarget;
      setState(() => _seekTarget = null);
      if (target != null) {
        unawaited(ref.read(playbackCoordinatorProvider).seek(target));
      }
    });
  }

  Future<void> _togglePause(CastingState state) =>
      ref.read(playbackCoordinatorProvider).setPaused(paused: !state.paused);

  Future<void> _toggleMute(CastingState state) =>
      ref.read(castCoordinatorProvider).setMuted(muted: !state.volume.muted);

  KeyEventResult _onKey(FocusNode node, KeyEvent event) {
    if (event is KeyUpEvent) return KeyEventResult.ignored;
    final keyboard = HardwareKeyboard.instance;
    if (keyboard.isControlPressed ||
        keyboard.isAltPressed ||
        keyboard.isMetaPressed) {
      return KeyEventResult.ignored;
    }
    final state = ref.read(castingStateProvider).value;
    if (state == null || !state.active) return KeyEventResult.ignored;
    final live = state.item?.live ?? true;
    final timeline = ref.read(castTimelineProvider).value;
    final key = event.logicalKey;
    switch (key) {
      case LogicalKeyboardKey.escape when event is KeyDownEvent:
        _close();
        return KeyEventResult.handled;
      case LogicalKeyboardKey.arrowUp || LogicalKeyboardKey.pageUp when live:
        unawaited(_zap(-1));
        return KeyEventResult.handled;
      case LogicalKeyboardKey.arrowDown || LogicalKeyboardKey.pageDown
          when live:
        unawaited(_zap(1));
        return KeyEventResult.handled;
      case LogicalKeyboardKey.arrowLeft when !live && timeline != null:
        _seekBy(-CastingView.seekStep, timeline);
        return KeyEventResult.handled;
      case LogicalKeyboardKey.arrowRight when !live && timeline != null:
        _seekBy(CastingView.seekStep, timeline);
        return KeyEventResult.handled;
      case LogicalKeyboardKey.space when !live && event is KeyDownEvent:
        unawaited(_togglePause(state));
        return KeyEventResult.handled;
      case LogicalKeyboardKey.keyM when event is KeyDownEvent:
        unawaited(_toggleMute(state));
        return KeyEventResult.handled;
      default:
        return KeyEventResult.ignored;
    }
  }

  @override
  Widget build(BuildContext context) {
    final tokens = context.tokens;
    final colors = tokens.colors;
    final cast = tokens.cast;
    final state = ref.watch(castingStateProvider).value ?? const CastingState();
    final device = state.device;
    final deviceName = device?.name ?? 'the TV';
    final item = state.item;
    final shown = _zapTarget == null ? item : PlayableChannel(_zapTarget!);

    return Focus(
      focusNode: _focus,
      onKeyEvent: _onKey,
      child: Padding(
        padding: EdgeInsets.all(tokens.spacing.s16),
        child: Container(
          clipBehavior: Clip.antiAlias,
          decoration: BoxDecoration(
            color: colors.surface1,
            borderRadius: tokens.radii.lgAll,
            border: Border.all(color: colors.borderSubtle),
            gradient: RadialGradient(
              center: const Alignment(0.56, -0.2),
              radius: 0.9,
              colors: [
                colors.accentDeep.withValues(alpha: 0.45),
                colors.accentDeep.withValues(alpha: 0),
              ],
            ),
          ),
          child: Stack(
            children: [
              LayoutBuilder(
                builder: (context, constraints) {
                  // The canvas's 64 px inset and 360 px artwork, shrinking
                  // on a smaller window so the text keeps its room.
                  final inset = constraints.maxWidth < 1100
                      ? cast.viewInset / 2
                      : cast.viewInset;
                  final artwork = (constraints.maxWidth * 0.3).clamp(
                    160.0,
                    cast.artworkSize,
                  );
                  final gap = constraints.maxWidth < 1100
                      ? cast.viewGap / 2
                      : cast.viewGap;
                  // On a wide window the artwork and the text stay together
                  // in the middle of the card.
                  return SingleChildScrollView(
                    child: ConstrainedBox(
                      constraints: BoxConstraints(
                        minHeight: constraints.maxHeight,
                      ),
                      child: Padding(
                        padding: EdgeInsets.all(inset),
                        child: Center(
                          child: ConstrainedBox(
                            constraints: BoxConstraints(
                              maxWidth: artwork + gap + cast.textMaxWidth,
                            ),
                            child: Row(
                              children: [
                                _Artwork(item: shown, size: artwork),
                                SizedBox(width: gap),
                                Expanded(
                                  child: _body(state, shown, deviceName),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),
                  );
                },
              ),
              if (state.reconnecting)
                Positioned(
                  top: tokens.spacing.s16,
                  left: 0,
                  right: 0,
                  child: Center(
                    child: ReconnectingPill(
                      message: 'Reconnecting to $deviceName…',
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _body(CastingState state, Playable? item, String deviceName) {
    final tokens = context.tokens;
    final colors = tokens.colors;
    final kicker = switch (state.phase) {
      CastPhase.connecting => 'Connecting to $deviceName',
      CastPhase.idle => 'Connected to $deviceName',
      CastPhase.ended => 'Played on $deviceName',
      CastPhase.failed => 'Casting to $deviceName',
      _ => 'Playing on $deviceName',
    };
    final children = <Widget>[
      Row(
        children: [
          AppIcon(AppIcons.deviceTv, size: 18, color: colors.accentBase),
          SizedBox(width: tokens.spacing.s8 + 2),
          Flexible(
            child: Text(
              kicker.toUpperCase(),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: tokens.text.castKicker.copyWith(color: colors.accentBase),
            ),
          ),
        ],
      ),
      if (item != null) _Titles(item: item, live: _zapTarget != null),
      if (item case PlayableChannel(:final channel) when _zapTarget == null)
        _ProgrammeTimes(channel: channel)
      else if (item != null && !item.live)
        _FileTimeline(
          preparing: state.phase == CastPhase.preparing,
          seekTarget: _seekTarget,
          onSeek: _seekTo,
        ),
      _status(state, deviceName),
      _controls(state),
    ];
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (final (index, child) in children.indexed) ...[
          if (index > 0) SizedBox(height: tokens.spacing.s16 + 2),
          child,
        ],
      ],
    );
  }

  /// The quality box while it plays; what is happening otherwise.
  Widget _status(CastingState state, String deviceName) {
    final tokens = context.tokens;
    final colors = tokens.colors;
    switch (state.phase) {
      case CastPhase.failed when state.problem != null:
        return _Problem(
          problem: state.problem!,
          deviceName: deviceName,
          item: state.item,
          details: _details,
          onToggleDetails: () => setState(() => _details = !_details),
          onRetry: () => unawaited(ref.read(castCoordinatorProvider).retry()),
          onPlayHere: state.item == null
              ? null
              : () {
                  _close();
                  unawaited(ref.read(castCoordinatorProvider).playHere());
                },
        );
      case CastPhase.connecting:
        return _Working(text: 'Connecting to $deviceName…');
      case CastPhase.preparing when state.plan == null:
        return const _Working(text: 'Preparing the stream…');
      case CastPhase.idle:
        return _Note(
          text:
              'Choose a channel, a movie or an episode, and it plays on '
              '$deviceName.',
        );
      case CastPhase.ended:
        return _Note(text: 'Finished on $deviceName.');
      case _:
        final plan = state.plan;
        if (plan == null) return const SizedBox.shrink();
        return Container(
          padding: EdgeInsets.symmetric(
            horizontal: tokens.spacing.s16,
            vertical: tokens.spacing.s12 + 2,
          ),
          decoration: BoxDecoration(
            color: colors.surface2.withValues(alpha: 0.9),
            borderRadius: tokens.radii.mdAll,
            border: Border.all(color: colors.border),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Wrap(
                spacing: tokens.spacing.s8 + 2,
                runSpacing: tokens.spacing.s4,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  QualityTag(castBadge(plan)),
                  Text(
                    castDetailsLine(plan.output),
                    style: tokens.text.caption
                        .withWeight(400)
                        .copyWith(color: colors.textSecondary),
                  ),
                  if (state.phase == CastPhase.preparing)
                    Text(
                      'Preparing…',
                      style: tokens.text.caption.copyWith(
                        color: colors.textTertiary,
                      ),
                    ),
                ],
              ),
              SizedBox(height: tokens.spacing.s8 + 2),
              Text(
                castPlanSentence(plan),
                style: tokens.text.caption
                    .withWeight(400)
                    .copyWith(color: colors.textSecondary, height: 19 / 13),
              ),
            ],
          ),
        );
    }
  }

  Widget _controls(CastingState state) {
    final tokens = context.tokens;
    final cast = tokens.cast;
    final live = state.item?.live ?? true;
    final playing = state.phase == CastPhase.playing;
    final timeline = ref.watch(castTimelineProvider).value;
    final volume = state.volume;
    return Row(
      children: [
        if (state.item != null && live) ...[
          AppIconButton(
            icon: AppIcons.chevronUp,
            tooltip: 'Previous channel',
            shortcut: '↑',
            filled: true,
            bordered: true,
            size: cast.controlSize,
            autofocus: true,
            onPressed: () => unawaited(_zap(-1)),
          ),
          SizedBox(width: tokens.spacing.s12),
          AppIconButton(
            icon: AppIcons.chevronDown,
            tooltip: 'Next channel',
            shortcut: '↓',
            filled: true,
            bordered: true,
            size: cast.controlSize,
            onPressed: () => unawaited(_zap(1)),
          ),
          SizedBox(width: tokens.spacing.s12),
        ],
        if (state.item != null && !live) ...[
          AppIconButton(
            icon: state.paused ? AppIcons.play : AppIcons.pause,
            tooltip: state.paused ? 'Play' : 'Pause',
            shortcut: 'Space',
            filled: true,
            bordered: true,
            size: cast.controlSize,
            autofocus: true,
            onPressed: playing ? () => unawaited(_togglePause(state)) : null,
          ),
          SizedBox(width: tokens.spacing.s12),
          AppIconButton(
            icon: AppIcons.chevronLeft,
            tooltip: 'Back 10 s',
            shortcut: '←',
            filled: true,
            bordered: true,
            size: cast.controlSize,
            onPressed: playing && timeline != null
                ? () => _seekBy(-CastingView.seekStep, timeline)
                : null,
          ),
          SizedBox(width: tokens.spacing.s12),
          AppIconButton(
            icon: AppIcons.chevronRight,
            tooltip: 'Forward 10 s',
            shortcut: '→',
            filled: true,
            bordered: true,
            size: cast.controlSize,
            onPressed: playing && timeline != null
                ? () => _seekBy(CastingView.seekStep, timeline)
                : null,
          ),
          SizedBox(width: tokens.spacing.s12),
        ],
        _Volume(
          volume: volume,
          dragging: _volume,
          onChanged: (level) => setState(() => _volume = level),
          onChangeEnd: (level) {
            setState(() => _volume = null);
            unawaited(ref.read(castCoordinatorProvider).setVolume(level));
          },
          onMute: () => unawaited(_toggleMute(state)),
        ),
        const Spacer(),
        AppButton(
          label: 'Stop casting',
          icon: AppIcons.stop,
          variant: AppButtonVariant.dangerOutline,
          size: AppButtonSize.l,
          autofocus: state.item == null,
          onPressed: () => unawaited(_stop()),
        ),
      ],
    );
  }
}

/// The logo (a channel), the poster (a movie) or the still (an episode),
/// large; a monogram when there is none.
class _Artwork extends StatelessWidget {
  const new({required this.item, required this.size});

  final Playable? item;
  final double size;

  @override
  Widget build(BuildContext context) {
    final tokens = context.tokens;
    final radius = BorderRadius.circular(tokens.cast.artworkRadius);
    final (name, url, poster) = switch (item) {
      PlayableChannel(:final channel) => (channel.name, channel.logoUrl, false),
      PlayableMovie(:final movie) => (movie.name, movie.posterUrl, true),
      PlayableEpisode(:final series, :final episode) => (
        series.name,
        episode.stillUrl ?? series.posterUrl,
        episode.stillUrl == null,
      ),
      null => ('', null, false),
      PlayableLibraryItem(:final item) => (item.title, null, true),
    };
    final width = poster ? size * 2 / 3 : size;
    return Container(
      width: width,
      height: size,
      decoration: BoxDecoration(
        borderRadius: radius,
        boxShadow: tokens.elevation.hero,
      ),
      child: item == null
          ? Container(
              decoration: BoxDecoration(
                color: tokens.colors.surface3,
                borderRadius: radius,
              ),
              alignment: Alignment.center,
              child: AppIcon(
                AppIcons.deviceTv,
                size: size / 3,
                color: tokens.colors.textTertiary,
              ),
            )
          : ClipRRect(
              borderRadius: radius,
              child: SizedBox(
                width: width,
                height: size,
                child: ArtworkImage(
                  image: artworkFor(context, url, width: width),
                  fallback: ChannelLogo(
                    name: name,
                    size: size,
                    borderRadius: radius,
                  ),
                ),
              ),
            ),
    );
  }
}

/// "201 · Arena Sports 1" over the programme, or a title and its line.
class _Titles extends ConsumerWidget {
  const new({required this.item, required this.live});

  final Playable item;

  /// Zapping: the channel the keys reached, before it plays.
  final bool live;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tokens = context.tokens;
    final colors = tokens.colors;
    final (over, title) = switch (item) {
      PlayableChannel(:final channel) => (
        channel.number == null
            ? channel.name
            : '${channel.number} · ${channel.name}',
        live
            ? channel.name
            : ref.watch(nowNextProvider(channel)).value?.now?.title ??
                  channel.name,
      ),
      PlayableMovie(:final movie) => (movie.year?.toString(), movie.name),
      PlayableEpisode(:final series, :final episode) => (
        '${series.name} · S${episode.season} E${episode.episode}',
        episode.title,
      ),
      PlayableLibraryItem(:final item) => (
        item.kind == LibraryKind.episode
            ? '${item.showTitle ?? ''} · S${item.season} E${item.episode}'
            : item.year?.toString(),
        item.title,
      ),
    };
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (over != null)
          Text(
            over,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: tokens.text.body
                .withWeight(600)
                .copyWith(color: colors.textSecondary),
          ),
        SizedBox(height: tokens.spacing.s4 + 2),
        Text(
          title,
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
          style: tokens.text.castTitle.copyWith(color: colors.textPrimary),
        ),
      ],
    );
  }
}

/// "8:00 PM ━━━━━━──── 10:00 PM": the programme on now.
class _ProgrammeTimes extends ConsumerWidget {
  const new({required this.channel});

  final ChannelItem channel;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tokens = context.tokens;
    final colors = tokens.colors;
    final guide = ref.watch(nowNextProvider(channel)).value;
    final now = guide?.now;
    if (now == null) return const SizedBox.shrink();
    final clock = ref.watch(appClockProvider);
    final style = tokens.text.label
        .withWeight(400)
        .copyWith(color: colors.textSecondary);
    return Row(
      children: [
        Text(formatClock(now.start), style: style),
        SizedBox(width: tokens.spacing.s12 + 2),
        Expanded(
          child: ProgressBar(
            value: now.progressAt(clock()),
            height: tokens.cast.timelineHeight,
          ),
        ),
        SizedBox(width: tokens.spacing.s12 + 2),
        Text(formatClock(now.end), style: style),
      ],
    );
  }
}

/// A file's place on the TV: the seek bar with its times (sketch A), and
/// "Preparing…" while the relay starts again after a seek.
class _FileTimeline extends ConsumerWidget {
  const new({
    required this.preparing,
    required this.seekTarget,
    required this.onSeek,
  });

  final bool preparing;
  final Duration? seekTarget;
  final ValueChanged<Duration> onSeek;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tokens = context.tokens;
    final colors = tokens.colors;
    final timeline = ref.watch(castTimelineProvider).value;
    final length = timeline?.duration;
    final at = seekTarget ?? timeline?.position ?? Duration.zero;
    final style = tokens.text.label
        .withWeight(400)
        .copyWith(color: colors.textSecondary);
    double fraction(Duration d) => length == null || length == Duration.zero
        ? 0
        : (d.inMilliseconds / length.inMilliseconds).clamp(0, 1).toDouble();
    return Row(
      children: [
        Text(formatPosition(at), style: style),
        SizedBox(width: tokens.spacing.s12 + 2),
        Expanded(
          child: AppSlider(
            value: fraction(at),
            semanticLabel: 'Position',
            enabled: length != null,
            bubbleLabel: length == null
                ? null
                : (value) => formatPosition(length * value),
            onChanged: length == null
                ? null
                : (value) => onSeek(length * value),
          ),
        ),
        SizedBox(width: tokens.spacing.s12 + 2),
        Text(
          preparing
              ? 'Preparing…'
              : length == null
              ? '--:--'
              : formatPosition(length),
          style: style,
        ),
      ],
    );
  }
}

class _Volume extends StatelessWidget {
  const new({
    required this.volume,
    required this.dragging,
    required this.onChanged,
    required this.onChangeEnd,
    required this.onMute,
  });

  final CastVolume volume;
  final double? dragging;
  final ValueChanged<double> onChanged;
  final ValueChanged<double> onChangeEnd;
  final VoidCallback onMute;

  @override
  Widget build(BuildContext context) {
    final tokens = context.tokens;
    final colors = tokens.colors;
    final cast = tokens.cast;
    final level = dragging ?? volume.level;
    return Container(
      constraints: BoxConstraints(minHeight: cast.controlSize),
      padding: EdgeInsets.symmetric(horizontal: tokens.spacing.s8),
      decoration: BoxDecoration(
        color: colors.surface3,
        borderRadius: tokens.radii.mdAll,
        border: Border.all(color: colors.border),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          AppIconButton(
            icon: volume.muted || level == 0
                ? AppIcons.volumeOff
                : level < 0.5
                ? AppIcons.volumeLow
                : AppIcons.volumeHigh,
            tooltip: volume.muted ? 'Unmute' : 'Mute',
            shortcut: 'M',
            size: 36,
            onPressed: onMute,
          ),
          SizedBox(width: tokens.spacing.s4),
          SizedBox(
            width: cast.volumeWidth,
            child: AppTooltip(
              message: volume.fixed
                  ? "This TV's volume is set with its own remote"
                  : 'Volume',
              child: AppSlider(
                value: level,
                compact: true,
                enabled: !volume.fixed,
                semanticLabel: 'Volume',
                onChanged: onChanged,
                onChangeEnd: onChangeEnd,
              ),
            ),
          ),
          SizedBox(width: tokens.spacing.s8),
        ],
      ),
    );
  }
}

class _Working extends StatelessWidget {
  const new({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    final tokens = context.tokens;
    return Row(
      children: [
        const AppSpinner(size: 18),
        SizedBox(width: tokens.spacing.s12),
        Expanded(
          child: Text(
            text,
            style: tokens.text.body.copyWith(
              color: tokens.colors.textSecondary,
            ),
          ),
        ),
      ],
    );
  }
}

class _Note extends StatelessWidget {
  const new({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    final tokens = context.tokens;
    return Text(
      text,
      style: tokens.text.body.copyWith(color: tokens.colors.textSecondary),
    );
  }
}

/// Sketch D: what went wrong, Try again, Play here, Details.
class _Problem extends StatelessWidget {
  const new({
    required this.problem,
    required this.deviceName,
    required this.item,
    required this.details,
    required this.onToggleDetails,
    required this.onRetry,
    required this.onPlayHere,
  });

  final CastProblem problem;
  final String deviceName;
  final Playable? item;
  final bool details;
  final VoidCallback onToggleDetails;
  final VoidCallback onRetry;
  final VoidCallback? onPlayHere;

  @override
  Widget build(BuildContext context) {
    final tokens = context.tokens;
    final colors = tokens.colors;
    final text = castProblemText(problem, deviceName, item: item);
    final detail = [
      problem.kind.name,
      if (problem.stream case final stream?) stream.toString(),
      ?problem.detail,
    ].join('\n');
    return Container(
      padding: EdgeInsets.all(tokens.spacing.s16),
      decoration: BoxDecoration(
        color: colors.surface2.withValues(alpha: 0.9),
        borderRadius: tokens.radii.mdAll,
        border: Border.all(color: colors.danger.withValues(alpha: 0.4)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              AppIcon(AppIcons.alertCircle, size: 18, color: colors.danger),
              SizedBox(width: tokens.spacing.s8 + 2),
              Expanded(
                child: Text(
                  text.title,
                  style: tokens.text.titleSmall.copyWith(
                    color: colors.textPrimary,
                  ),
                ),
              ),
            ],
          ),
          SizedBox(height: tokens.spacing.s8),
          Text(
            text.message,
            style: tokens.text.caption
                .withWeight(400)
                .copyWith(color: colors.textSecondary, height: 19 / 13),
          ),
          SizedBox(height: tokens.spacing.s16),
          Wrap(
            spacing: tokens.spacing.s8,
            runSpacing: tokens.spacing.s8,
            children: [
              AppButton(
                label: 'Try again',
                icon: AppIcons.retry,
                size: AppButtonSize.s,
                autofocus: true,
                onPressed: onRetry,
              ),
              if (onPlayHere != null)
                AppButton(
                  label: 'Play here',
                  icon: AppIcons.play,
                  variant: AppButtonVariant.secondary,
                  size: AppButtonSize.s,
                  onPressed: onPlayHere,
                ),
              AppButton(
                label: details ? 'Hide details' : 'Details',
                variant: AppButtonVariant.ghost,
                size: AppButtonSize.s,
                onPressed: onToggleDetails,
              ),
            ],
          ),
          if (details) ...[
            SizedBox(height: tokens.spacing.s12),
            SelectableText(
              detail,
              style: tokens.text.mono.copyWith(color: colors.textTertiary),
            ),
          ],
        ],
      ),
    );
  }
}
