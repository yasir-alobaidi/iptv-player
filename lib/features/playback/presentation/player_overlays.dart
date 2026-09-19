import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:iptv_player/core/core_providers.dart';
import 'package:iptv_player/core/player/player_engine.dart';
import 'package:iptv_player/core/player/player_providers.dart';
import 'package:iptv_player/core/text/format.dart';
import 'package:iptv_player/design/components.dart';
import 'package:iptv_player/design/tokens.dart';
import 'package:iptv_player/features/live_tv/data/live_tv_providers.dart';
import 'package:iptv_player/features/live_tv/domain/channels.dart';
import 'package:iptv_player/features/playback/data/playback_providers.dart';
import 'package:iptv_player/features/playback/presentation/playback_text.dart';

ImageProvider? logoImage(String? url) {
  final uri = url == null ? null : Uri.tryParse(url);
  if (uri == null || !uri.scheme.startsWith('http')) return null;
  return NetworkImage(url!);
}

/// The top of the OSD (canvas `Full-screen player`): logo, number, name,
/// LIVE, the resolution, and the clock.
class OsdTop extends ConsumerWidget {
  const new({required this.channel, super.key});

  final ChannelItem channel;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tokens = context.tokens;
    final colors = tokens.colors;
    final size = ref.watch(videoSizeProvider).value;
    final now = ref.watch(appClockProvider)();
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
          children: [
            ChannelLogo(
              name: channel.name,
              size: 48,
              image: logoImage(channel.logoUrl),
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
              formatClock(now),
              style: tokens.text.h3.copyWith(color: colors.textPrimary),
            ),
          ],
        ),
      ),
    );
  }
}

/// The bottom of the OSD: what's on now and next, and the controls.
class OsdBottom extends ConsumerWidget {
  const new({required this.channel, required this.controls, super.key});

  final ChannelItem channel;
  final List<Widget> controls;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tokens = context.tokens;
    final colors = tokens.colors;
    final guide = ref.watch(nowNextProvider(channel)).value;
    final now = ref.watch(appClockProvider)();
    final current = guide?.now;
    final next = guide?.next;
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
            Text(
              current?.title ?? 'No guide information',
              overflow: TextOverflow.ellipsis,
              style: tokens.text.h1.copyWith(
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
                    formatClock(current.start),
                    style: tokens.text.caption.copyWith(
                      color: colors.textSecondary,
                    ),
                  ),
                  SizedBox(width: tokens.spacing.s12),
                  Expanded(child: ProgressBar(value: current.progressAt(now))),
                  SizedBox(width: tokens.spacing.s12),
                  Text(
                    formatClock(current.end),
                    style: tokens.text.caption.copyWith(
                      color: colors.textSecondary,
                    ),
                  ),
                ],
              ),
            ],
            SizedBox(height: tokens.spacing.s12),
            Row(
              children: [
                if (next != null)
                  Expanded(
                    child: Text.rich(
                      TextSpan(
                        children: [
                          TextSpan(
                            text: 'NEXT  ',
                            style: tokens.text.micro
                                .withWeight(800)
                                .copyWith(color: colors.textTertiary),
                          ),
                          TextSpan(
                            text: '${formatClock(next.start)} · ${next.title}',
                          ),
                        ],
                      ),
                      overflow: TextOverflow.ellipsis,
                      style: tokens.text.label.copyWith(
                        color: colors.textEmphasis,
                      ),
                    ),
                  )
                else
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
          ChannelLogo(name: channel.name, image: logoImage(channel.logoUrl)),
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
                      ((_currentIndex ?? 0) - 3).clamp(0, 1 << 30) * 64.0,
                ),
                itemExtent: 64,
                itemCount: _channels.length,
                itemBuilder: (context, i) {
                  final channel = _channels[i];
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 4),
                    child: ChannelRow(
                      name: channel.name,
                      number: channel.number,
                      image: logoImage(channel.logoUrl),
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

/// The stream-info overlay (I; approved sketch), read once a second.
class StreamInfoOverlay extends ConsumerStatefulWidget {
  const new({super.key});

  @override
  ConsumerState<StreamInfoOverlay> createState() => _StreamInfoOverlayState();
}

class _StreamInfoOverlayState extends ConsumerState<StreamInfoOverlay> {
  StreamInfo? _info;
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
    if (mounted) setState(() => _info = info);
  }

  @override
  Widget build(BuildContext context) {
    final tokens = context.tokens;
    final colors = tokens.colors;
    final info = _info;
    final url = ref.read(playbackCoordinatorProvider).redactedUrl;
    String fps(double? v) => v == null ? '' : ' · ${v.toStringAsFixed(0)} fps';
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
      ('Dropped', '${info?.droppedFrames ?? 0}'),
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
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          for (final (label, value) in rows)
            Padding(
              padding: EdgeInsets.symmetric(vertical: tokens.spacing.s4 - 2),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  SizedBox(
                    width: 72,
                    child: Text(
                      label,
                      style: tokens.text.mono.copyWith(
                        color: colors.textTertiary,
                      ),
                    ),
                  ),
                  Expanded(
                    child: Text(
                      value.isEmpty ? '—' : value,
                      style: tokens.text.mono.copyWith(
                        color: colors.textPrimary,
                      ),
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}
