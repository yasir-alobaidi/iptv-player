import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:iptv_player/core/core_providers.dart';
import 'package:iptv_player/core/images/artwork_scope.dart';
import 'package:iptv_player/core/platform/display_modes.dart';
import 'package:iptv_player/core/player/player_engine.dart';
import 'package:iptv_player/core/player/player_providers.dart';
import 'package:iptv_player/core/text/format.dart';
import 'package:iptv_player/design/components.dart';
import 'package:iptv_player/design/tokens.dart';
import 'package:iptv_player/features/live_tv/data/live_tv_providers.dart';
import 'package:iptv_player/features/live_tv/domain/channels.dart';
import 'package:iptv_player/features/playback/data/playback_providers.dart';
import 'package:iptv_player/features/playback/presentation/playback_text.dart';

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
/// logo, number, name, LIVE, the resolution, and the clock.
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
    final now = ref.watch(appClockProvider)();
    return OsdShade(
      top: true,
      child: Padding(
        padding: EdgeInsets.fromLTRB(
          tokens.spacing.s32,
          tokens.spacing.s24,
          tokens.spacing.s32,
          tokens.spacing.s48,
        ),
        child: Row(
          children: [
            OsdBack(onPressed: onBack),
            SizedBox(width: tokens.spacing.s16),
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
            Expanded(
              child: Row(
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
                      overflow: TextOverflow.ellipsis,
                      style: tokens.text.h2.copyWith(color: colors.textPrimary),
                    ),
                  ),
                  SizedBox(width: tokens.spacing.s12),
                  const AppBadge('LIVE', tone: AppBadgeTone.live),
                  if (resolutionLabel(size?.$2) case final label?) ...[
                    SizedBox(width: tokens.spacing.s8),
                    AppBadge(label, tone: AppBadgeTone.outline),
                  ],
                ],
              ),
            ),
            SizedBox(width: tokens.spacing.s16),
            Text(
              formatClock(now, tokens.timeStyle),
              style: tokens.text.h2.copyWith(color: colors.textPrimary),
            ),
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
    return OsdShade(
      top: false,
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
            Text(
              current?.title ??
                  (next == null
                      ? 'No guide information'
                      : 'Nothing on right now'),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: tokens.text.hero.copyWith(
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
            SizedBox(height: tokens.spacing.s16),
            OsdControlRow(leading: leading, trailing: trailing),
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
    return Container(
      width: ChannelPanel.width,
      decoration: BoxDecoration(
        color: colors.surface1.withValues(alpha: 0.9),
        border: Border(right: BorderSide(color: colors.border)),
      ),
      padding: EdgeInsets.all(tokens.spacing.s12),
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
