import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:iptv_player/core/core_providers.dart';
import 'package:iptv_player/core/images/artwork_scope.dart';
import 'package:iptv_player/core/platform/display_modes.dart';
import 'package:iptv_player/core/platform/window_bounds.dart';
import 'package:iptv_player/core/player/player_engine.dart';
import 'package:iptv_player/core/player/player_providers.dart';
import 'package:iptv_player/core/text/format.dart';
import 'package:iptv_player/design/components.dart';
import 'package:iptv_player/design/tokens.dart';
import 'package:iptv_player/features/live_tv/data/live_tv_providers.dart';
import 'package:iptv_player/features/live_tv/domain/channels.dart';
import 'package:iptv_player/features/playback/data/playback_providers.dart';
import 'package:iptv_player/features/playback/presentation/playback_text.dart';
import 'package:iptv_player/features/playback/presentation/time_corner.dart';

/// The room the OSD has (ADR-068), from its own box: a phone's screen is
/// [narrow] held upright and [short] on its side, and either is
/// [compact]. A desktop's window (1024 × 640 at the least) and a TV's
/// canvas are neither, and keep the OSD as ADR-017 draws it.
@immutable
final class OsdRoom {
  const new({this.narrow = false, this.short = false});

  /// The OSD's room where [context] is (inside [OsdScale], its own box).
  factory of(BuildContext context) {
    final size = MediaQuery.sizeOf(context);
    return OsdRoom(
      narrow: size.width < WindowSizes.phoneWidth,
      short: size.height < shortHeight,
    );
  }

  /// Lower than this is a phone on its side (a large one is 412 dp).
  static const shortHeight = 480.0;

  /// Narrower than [WindowSizes.phoneWidth]: a phone held upright. The
  /// controls take two rows, spread across, and the badges go under the
  /// title.
  final bool narrow;

  /// Lower than [shortHeight]: a phone on its side. The next-episode card
  /// is its one-row self.
  final bool short;

  /// Either: a phone's screen. Less air round the bars, which keep clear
  /// of the system's bars, a programme's title a size down, and the
  /// card and the stream info laid between the bars ([OsdFrame]).
  bool get compact => narrow || short;

  /// From the screen's side edges to the controls.
  double side(AppTokens tokens) =>
      compact ? tokens.spacing.s16 : tokens.spacing.s32;

  /// From the top edge to the top bar's controls, and from the bottom
  /// edge to the bottom's.
  double edge(AppTokens tokens) =>
      compact ? tokens.spacing.s12 : tokens.spacing.s24;

  /// The shade's room toward the picture, beyond each bar's controls: a
  /// gradient and nothing else.
  double room(AppTokens tokens) =>
      compact ? tokens.spacing.s24 : tokens.spacing.s48;

  /// The top bar's padding: [room] below it, and the system's bars and a
  /// camera's cutout kept clear (nothing on a desktop or a TV).
  EdgeInsets topPadding(BuildContext context) {
    final tokens = context.tokens;
    final safe = MediaQuery.paddingOf(context);
    return EdgeInsets.fromLTRB(
      side(tokens) + safe.left,
      edge(tokens) + safe.top,
      side(tokens) + safe.right,
      room(tokens),
    );
  }

  /// The bottom's padding, as [topPadding]'s the other way up.
  EdgeInsets bottomPadding(BuildContext context) {
    final tokens = context.tokens;
    final safe = MediaQuery.paddingOf(context);
    return EdgeInsets.fromLTRB(
      side(tokens) + safe.left,
      room(tokens),
      side(tokens) + safe.right,
      edge(tokens) + safe.bottom,
    );
  }
}

/// The OSD's controls under the picture (ADR-017): one row, [leading]
/// from the left and [trailing] at the right ([OsdControlRow]); on a
/// [OsdRoom.narrow] screen, a phone held upright, two rows, each spread
/// across it, where one row would shrink the controls past a finger's
/// size (ADR-068).
class OsdControls extends StatelessWidget {
  const new({required this.leading, required this.trailing, super.key});

  final List<Widget> leading;
  final List<Widget> trailing;

  @override
  Widget build(BuildContext context) {
    if (!OsdRoom.of(context).narrow) {
      return OsdControlRow(leading: leading, trailing: trailing);
    }
    final gap = context.tokens.player.controlGap;
    // A row that can't fit goes on to another, never past the edge.
    Widget row(List<Widget> controls) => Wrap(
      alignment: WrapAlignment.spaceBetween,
      crossAxisAlignment: WrapCrossAlignment.center,
      spacing: gap,
      runSpacing: gap,
      children: controls,
    );
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        row(leading),
        if (leading.isNotEmpty && trailing.isNotEmpty) SizedBox(height: gap),
        row(trailing),
      ],
    );
  }
}

/// The OSD on a phone's screen ([OsdRoom.compact], ADR-068): [top] and
/// [bottom] at their edges and, between their controls (over their
/// shades' room, which is only a gradient), the next-episode [card] at
/// the right, just above the bottom's controls, and the stream [info]
/// at the left under the top's, scrolling in what room there is. Nothing
/// goes past the screen, however little room a phone on its side leaves.
class OsdFrame extends StatelessWidget {
  const new({
    required this.top,
    required this.bottom,
    this.card,
    this.info,
    super.key,
  });

  final Widget top;
  final Widget bottom;
  final Widget? card;
  final Widget? info;

  @override
  Widget build(BuildContext context) {
    final card = this.card;
    final info = this.info;
    return CustomMultiChildLayout(
      delegate: _OsdFrameLayout(OsdRoom.of(context).room(context.tokens)),
      children: [
        LayoutId(id: _OsdSlot.top, child: top),
        LayoutId(id: _OsdSlot.bottom, child: bottom),
        if (info != null)
          LayoutId(
            id: _OsdSlot.info,
            child: SingleChildScrollView(child: info),
          ),
        if (card != null) LayoutId(id: _OsdSlot.card, child: card),
      ],
    );
  }
}

enum _OsdSlot { top, bottom, card, info }

class _OsdFrameLayout extends MultiChildLayoutDelegate {
  new(this.room);

  /// The shades' room toward the picture, which the card and the info
  /// may cover.
  final double room;

  @override
  void performLayout(Size size) {
    // As tall as they make themselves, as in a column.
    final across = BoxConstraints.tightFor(width: size.width);
    final top = layoutChild(_OsdSlot.top, across);
    positionChild(_OsdSlot.top, Offset.zero);
    final bottom = layoutChild(_OsdSlot.bottom, across);
    positionChild(_OsdSlot.bottom, Offset(0, size.height - bottom.height));
    // Where the top's controls end and the bottom's begin.
    final double above = math.max(0, top.height - room);
    final double below = math.max(above, size.height - bottom.height + room);
    if (hasChild(_OsdSlot.info)) {
      layoutChild(
        _OsdSlot.info,
        BoxConstraints(maxWidth: size.width, maxHeight: below - above),
      );
      positionChild(_OsdSlot.info, Offset(0, above));
    }
    if (hasChild(_OsdSlot.card)) {
      final card = layoutChild(_OsdSlot.card, BoxConstraints.loose(size));
      // Just above the bottom's controls, and never off the screen: with
      // no room between the bars it covers the bottom's.
      final double lowest = math.max(0, size.height - card.height);
      positionChild(
        _OsdSlot.card,
        Offset(size.width - card.width, (below - card.height).clamp(0, lowest)),
      );
    }
  }

  @override
  bool shouldRelayout(_OsdFrameLayout oldDelegate) => oldDelegate.room != room;
}

/// A word or two straight on the picture, as the corner's clock is drawn
/// (ADR-053): a touch's answer on a phone (ADR-068) — "+10 s" where a
/// double tap seeks, the picture's size after a pinch. One line, no box,
/// a soft dark halo for a bright scene; it fades in and out, takes no
/// touch and no focus. [text] null fades it out (with its last words).
class PictureNote extends StatefulWidget {
  const new({required this.text, super.key});

  final String? text;

  @override
  State<PictureNote> createState() => _PictureNoteState();
}

class _PictureNoteState extends State<PictureNote> {
  late String? _shown = widget.text;

  @override
  void didUpdateWidget(PictureNote oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.text != null) _shown = widget.text;
  }

  @override
  Widget build(BuildContext context) {
    final tokens = context.tokens;
    final shown = _shown;
    return IgnorePointer(
      child: ExcludeFocus(
        child: AnimatedOpacity(
          opacity: widget.text == null ? 0 : 1,
          duration: widget.text == null
              ? tokens.motion.osdOut
              : tokens.motion.osdIn,
          onEnd: () {
            if (mounted && widget.text == null && _shown != null) {
              setState(() => _shown = null);
            }
          },
          child: shown == null
              ? const SizedBox.shrink()
              : Text(
                  shown,
                  maxLines: 1,
                  style: tokens.text.h3.copyWith(
                    color: tokens.colors.textPrimary,
                    shadows: tokens.elevation.textOverPicture,
                  ),
                ),
        ),
      ),
    );
  }
}

/// The scrim behind one edge of the OSD, fading into the picture. It
/// takes no clicks: one on it is a click on the picture.
class OsdShade extends StatelessWidget {
  const new({required this.top, required this.child, super.key});

  /// At the top of the picture; false at its bottom.
  final bool top;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final colors = context.tokens.colors;
    return Stack(
      children: [
        Positioned.fill(
          child: IgnorePointer(
            child: DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: top ? Alignment.topCenter : Alignment.bottomCenter,
                  end: top ? Alignment.bottomCenter : Alignment.topCenter,
                  colors: [
                    colors.osdShade,
                    colors.osdShadeMid,
                    colors.osdShade.withValues(alpha: 0),
                  ],
                  stops: const [0, 0.55, 1],
                ),
              ),
            ),
          ),
        ),
        child,
      ],
    );
  }
}

/// Back, at the top left of every face of the player (ADR-017): out of
/// the player, as Esc.
class OsdBack extends StatelessWidget {
  const new({required this.onPressed, super.key});

  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) => OsdButton(
    icon: AppIcons.arrowLeft,
    tooltip: 'Back',
    shortcut: 'Esc',
    onPressed: onPressed,
  );
}

/// The top of the OSD (canvas `Full-screen player`; ADR-017): Back, the
/// logo, number, name, LIVE, the resolution, and the clock. On a phone
/// held upright ([OsdRoom.narrow]) the badges go under the name and the
/// logo is left out, so the name has room (ADR-068).
class OsdTop extends ConsumerWidget {
  const new({required this.channel, required this.onBack, super.key});

  final ChannelItem channel;
  final VoidCallback onBack;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tokens = context.tokens;
    final colors = tokens.colors;
    final player = tokens.player;
    final size = ref.watch(videoSizeProvider).value;
    final narrow = OsdRoom.of(context).narrow;
    final badges = [
      const AppBadge('LIVE', tone: AppBadgeTone.live),
      if (resolutionLabel(size?.$2) case final label?) ...[
        SizedBox(width: tokens.spacing.s8),
        AppBadge(label, tone: AppBadgeTone.outline),
      ],
    ];
    final name = Row(
      children: [
        if (channel.number case final number?) ...[
          Text(
            '$number',
            style: tokens.text.h2.copyWith(color: colors.accentBase),
          ),
          SizedBox(width: tokens.spacing.s12),
        ],
        Flexible(
          child: Text(
            channel.name,
            maxLines: narrow ? 1 : null,
            overflow: TextOverflow.ellipsis,
            style: tokens.text.h2.copyWith(color: colors.textPrimary),
          ),
        ),
        if (!narrow) ...[SizedBox(width: tokens.spacing.s12), ...badges],
      ],
    );
    return OsdShade(
      top: true,
      child: Padding(
        padding: OsdRoom.of(context).topPadding(context),
        child: Row(
          children: [
            OsdBack(onPressed: onBack),
            SizedBox(width: tokens.spacing.s16),
            if (!narrow) ...[
              ChannelLogo(
                name: channel.name,
                size: player.logoSize,
                image: artworkFor(
                  context,
                  channel.logoUrl,
                  width: player.logoSize,
                ),
              ),
              SizedBox(width: tokens.spacing.s16),
            ],
            Expanded(
              child: narrow
                  ? Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        name,
                        SizedBox(height: tokens.spacing.s4),
                        Row(children: badges),
                      ],
                    )
                  : name,
            ),
            SizedBox(width: tokens.spacing.s16),
            const OsdClock(),
          ],
        ),
      ),
    );
  }
}

/// The bottom of the OSD: what's on now and next, and the controls —
/// [leading] from the left (the channels and the volume), [trailing] at
/// the right.
class OsdBottom extends ConsumerWidget {
  const new({
    required this.channel,
    required this.leading,
    required this.trailing,
    super.key,
  });

  final ChannelItem channel;
  final List<Widget> leading;
  final List<Widget> trailing;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tokens = context.tokens;
    final colors = tokens.colors;
    final player = tokens.player;
    final guide = ref.watch(nowNextProvider(channel)).value;
    final now = ref.watch(appClockProvider)();
    final current = guide?.now;
    final next = guide?.next;
    final time = tokens.text.body.copyWith(color: colors.textEmphasis);
    final room = OsdRoom.of(context);
    return OsdShade(
      top: false,
      child: Padding(
        padding: room.bottomPadding(context),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              current?.title ??
                  (next == null
                      ? 'No guide information'
                      : 'Nothing on right now'),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              // A phone's screen: a size down, for the picture's sake.
              style: (room.compact ? tokens.text.h2 : tokens.text.hero)
                  .copyWith(
                    color: current == null
                        ? colors.textSecondary
                        : colors.textPrimary,
                  ),
            ),
            if (current != null) ...[
              SizedBox(height: tokens.spacing.s8),
              Row(
                children: [
                  Text(
                    formatClock(current.start, tokens.timeStyle),
                    style: time,
                  ),
                  SizedBox(width: tokens.spacing.s16),
                  Expanded(
                    child: ProgressBar(
                      value: current.progressAt(now),
                      height: player.timelineHeight,
                      trackColor: colors.textPrimary.withValues(
                        alpha: player.tileOpacity * 2,
                      ),
                    ),
                  ),
                  SizedBox(width: tokens.spacing.s16),
                  Text(formatClock(current.end, tokens.timeStyle), style: time),
                ],
              ),
            ],
            if (next != null) ...[
              SizedBox(height: tokens.spacing.s8),
              Text.rich(
                TextSpan(
                  children: [
                    TextSpan(
                      text: 'NEXT  ',
                      style: tokens.text.overline.copyWith(
                        color: colors.textSecondary,
                      ),
                    ),
                    TextSpan(
                      text: [
                        formatClock(next.start, tokens.timeStyle),
                        next.title,
                      ].join(' · '),
                    ),
                  ],
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: tokens.text.body.copyWith(color: colors.textEmphasis),
              ),
            ],
            SizedBox(
              height: room.compact ? tokens.spacing.s12 : tokens.spacing.s16,
            ),
            OsdControls(leading: leading, trailing: trailing),
          ],
        ),
      ),
    );
  }
}

/// The top banner a zap shows at once, before the stream opens.
class ChannelBanner extends ConsumerWidget {
  const new({required this.channel, super.key});

  final ChannelItem channel;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tokens = context.tokens;
    final colors = tokens.colors;
    final guide = ref.watch(guideServiceProvider).cached(channel);
    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: tokens.spacing.s20,
        vertical: tokens.spacing.s12,
      ),
      decoration: BoxDecoration(
        color: colors.surface2.withValues(alpha: 0.92),
        borderRadius: tokens.radii.lgAll,
        border: Border.all(color: colors.border),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          ChannelLogo(
            name: channel.name,
            image: artworkFor(context, channel.logoUrl, width: 40),
          ),
          SizedBox(width: tokens.spacing.s12),
          Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                [
                  if (channel.number case final number?) '$number',
                  channel.name,
                ].join('  '),
                style: tokens.text.titleSmall.copyWith(
                  color: colors.textPrimary,
                ),
              ),
              if (guide?.now case final now?)
                Text(
                  now.title,
                  style: tokens.text.caption.copyWith(
                    color: colors.textSecondary,
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }
}

/// The number overlay (approved sketch): the digits typed so far and the
/// channel they reach, if any.
class NumberEntry extends StatelessWidget {
  const new({required this.digits, this.match, super.key});

  final String digits;
  final ChannelItem? match;

  @override
  Widget build(BuildContext context) {
    final tokens = context.tokens;
    final colors = tokens.colors;
    return Container(
      width: 200,
      padding: EdgeInsets.all(tokens.spacing.s16),
      decoration: BoxDecoration(
        color: colors.surface2.withValues(alpha: 0.92),
        borderRadius: tokens.radii.lgAll,
        border: Border.all(color: colors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.end,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            '${digits}_',
            style: tokens.text.display.copyWith(color: colors.textPrimary),
          ),
          Text(
            match?.name ?? 'No channel',
            overflow: TextOverflow.ellipsis,
            style: tokens.text.caption.copyWith(
              color: match == null ? colors.textTertiary : colors.textSecondary,
            ),
          ),
        ],
      ),
    );
  }
}

/// The channel panel (← in full screen; approved sketch): the list being
/// zapped through, translucent, on the left edge. ↑↓ move, Enter plays,
/// → or Esc closes.
class ChannelPanel extends ConsumerStatefulWidget {
  const new({
    required this.query,
    required this.current,
    required this.onPlay,
    required this.onClose,
    super.key,
  });

  final ChannelQuery query;
  final ChannelItem? current;
  final void Function(ChannelItem channel) onPlay;
  final VoidCallback onClose;

  static const width = 360.0;

  @override
  ConsumerState<ChannelPanel> createState() => _ChannelPanelState();
}

class _ChannelPanelState extends ConsumerState<ChannelPanel> {
  List<ChannelItem> _channels = const [];
  int? _currentIndex;

  /// The playing channel's row takes the focus once the rows are in:
  /// `autofocus` can't, since the player holds the focus in this scope.
  final _currentRow = FocusNode(debugLabel: 'panel current');

  @override
  void dispose() {
    _currentRow.dispose();
    super.dispose();
  }

  @override
  void initState() {
    super.initState();
    unawaited(_load());
  }

  /// A window of channels around the one playing: enough to zap through
  /// without loading a 50,000-channel list.
  Future<void> _load() async {
    final repository = ref.read(channelRepositoryProvider);
    final current = widget.current;
    final index = current == null
        ? 0
        : (await repository.indexOf(widget.query, current.id)).valueOrNull ?? 0;
    final start = index < 100 ? 0 : index - 100;
    final rows =
        (await repository.range(widget.query, start, 200)).valueOrNull ??
        const <ChannelItem>[];
    if (!mounted) return;
    setState(() {
      _channels = rows;
      _currentIndex = index - start;
    });
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _currentRow.requestFocus();
    });
  }

  @override
  Widget build(BuildContext context) {
    final tokens = context.tokens;
    final colors = tokens.colors;
    // A channel row in the chosen density, as tall as its text makes it,
    // and 8 px of air: 64 at the canvas's sizes.
    final extent = context.scaled(tokens.density.rowHeight) + 8;
    // A phone's bars and a camera's cutout: the panel runs under them, its
    // rows clear of them (ADR-068).
    final safe = MediaQuery.paddingOf(context);
    return Container(
      width: ChannelPanel.width + safe.left,
      decoration: BoxDecoration(
        color: colors.surface1.withValues(alpha: 0.9),
        border: Border(right: BorderSide(color: colors.border)),
      ),
      padding: EdgeInsets.fromLTRB(
        tokens.spacing.s12 + safe.left,
        tokens.spacing.s12 + safe.top,
        tokens.spacing.s12,
        tokens.spacing.s12 + safe.bottom,
      ),
      child: FocusPane(
        debugLabel: 'player-channel-panel',
        tabStop: true,
        child: _channels.isEmpty
            ? const Center(child: SkeletonRow())
            : ListView.builder(
                controller: ScrollController(
                  initialScrollOffset:
                      ((_currentIndex ?? 0) - 3).clamp(0, 1 << 30) * extent,
                ),
                itemExtent: extent,
                itemCount: _channels.length,
                itemBuilder: (context, i) {
                  final channel = _channels[i];
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 4),
                    child: ChannelRow(
                      name: channel.name,
                      quality: channel.quality?.label,
                      number: channel.number,
                      image: artworkFor(context, channel.logoUrl, width: 40),
                      guideKnown: false,
                      selected: channel.id == widget.current?.id,
                      focusNode: i == _currentIndex ? _currentRow : null,
                      onPressed: () => widget.onPlay(channel),
                    ),
                  );
                },
              ),
      ),
    );
  }
}

/// mpv's A/V sync to the millisecond, signed: `+4 ms`, `-12 ms`, `0 ms`.
String _syncText(Duration sync) {
  final ms = (sync.inMicroseconds / 1000).round();
  return '${ms > 0 ? '+' : ''}$ms ms';
}

/// The stream-info overlay (I; approved sketch), read once a second. On
/// a TV it names the display's mode too (Match frame rate, ADR-035).
class StreamInfoOverlay extends ConsumerStatefulWidget {
  const new({super.key});

  @override
  ConsumerState<StreamInfoOverlay> createState() => _StreamInfoOverlayState();
}

class _StreamInfoOverlayState extends ConsumerState<StreamInfoOverlay> {
  StreamInfo? _info;

  /// The display's mode; null where there is none to read (the desktop).
  DisplayMode? _display;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    unawaited(_read());
    _timer = Timer.periodic(const Duration(seconds: 1), (_) => _read());
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  Future<void> _read() async {
    final info = await ref.read(playerEngineProvider).streamInfo();
    if (!mounted) return;
    final display = ref.read(displayModesProvider);
    final mode = display.available ? (await display.read())?.current : null;
    if (!mounted) return;
    setState(() {
      _info = info;
      _display = mode;
    });
  }

  @override
  Widget build(BuildContext context) {
    final tokens = context.tokens;
    final colors = tokens.colors;
    final info = _info;
    final coordinator = ref.read(playbackCoordinatorProvider);
    final url = coordinator.redactedUrl;
    final display = _display;
    // 23.976 as it is: a film's rate is never rounded to 24.
    String fps(double? v) => v == null ? '' : ' · ${formatRate(v)} fps';
    final rows = <(String, String)>[
      (
        'Video',
        info?.width == null
            ? '—'
            : '${info!.width}×${info.height}${fps(info.fps)}'
                  '${info.videoCodec == null ? '' : ' · ${info.videoCodec}'}',
      ),
      (
        'Decode',
        info?.hardwareDecoder == null
            ? 'software'
            : '${info!.hardwareDecoder} (hardware)',
      ),
      // HDR's check (the TV's picture layer): what the decoder reports.
      if (info?.transfer != null || info?.primaries != null)
        (
          'Colour',
          [info!.hdr ?? 'SDR', ?info.transfer, ?info.primaries].join(' · '),
        ),
      (
        'Audio',
        [
          ?info?.audioCodec,
          if (info?.audioChannels case final n?) '$n ch',
        ].join(' · '),
      ),
      (
        'Bitrate',
        [
          if (info?.videoBitrate case final b?)
            '~${(b / 1e6).toStringAsFixed(1)} Mb/s',
          if (info?.buffered case final d?)
            'cache ${(d.inMilliseconds / 1000).toStringAsFixed(1)} s',
        ].join(' · '),
      ),
      if (info?.interlaced == true) ('Scan', 'interlaced'),
      if (display != null)
        (
          'Display',
          displayInfoText(
            display,
            fps: info?.fps,
            film: coordinator.item?.live == false,
          ),
        ),
      ('Dropped', '${info?.droppedFrames ?? 0}'),
      if (info?.avSync case final sync?) ('A/V sync', _syncText(sync)),
      ('Source', url ?? '—'),
    ];
    return Container(
      constraints: const BoxConstraints(maxWidth: 520),
      padding: EdgeInsets.all(tokens.spacing.s16),
      decoration: BoxDecoration(
        color: colors.surface1.withValues(alpha: 0.9),
        borderRadius: tokens.radii.lgAll,
        border: Border.all(color: colors.border),
      ),
      // The labels' column as wide as the longest of them, at any text
      // size: a fixed 72 px had Bitrate and Display touching their values
      // at a TV's 1.2× (the Bedroom TV).
      child: Table(
        columnWidths: const {0: IntrinsicColumnWidth(), 1: FlexColumnWidth()},
        children: [
          for (final (label, value) in rows)
            TableRow(
              children: [
                Padding(
                  padding: EdgeInsets.only(
                    top: tokens.spacing.s4 - 2,
                    bottom: tokens.spacing.s4 - 2,
                    right: tokens.spacing.s12,
                  ),
                  child: Text(
                    label,
                    style: tokens.text.mono.copyWith(
                      color: colors.textTertiary,
                    ),
                  ),
                ),
                Padding(
                  padding: EdgeInsets.symmetric(
                    vertical: tokens.spacing.s4 - 2,
                  ),
                  child: Text(
                    value.isEmpty ? '—' : value,
                    style: tokens.text.mono.copyWith(color: colors.textPrimary),
                  ),
                ),
              ],
            ),
        ],
      ),
    );
  }
}
