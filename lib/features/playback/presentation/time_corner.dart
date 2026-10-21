import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:iptv_player/core/core_providers.dart';
import 'package:iptv_player/core/text/format.dart';
import 'package:iptv_player/design/tokens.dart';
import 'package:iptv_player/features/live_tv/data/live_tv_providers.dart';
import 'package:iptv_player/features/live_tv/domain/channels.dart';
import 'package:iptv_player/features/playback/presentation/vod_player_controller.dart';

/// What the time corner says: the clock, and the time left when there is
/// one to say.
typedef TimeCornerWords = ({String clock, String? left});

/// The corner's words at [now]: the clock in [style], and [left] rounded
/// up to the minute, so the two add up to the end: at 9:22 PM a
/// programme that ends at 10:00 PM has "38 min left" all minute long, not
/// "37" for most of it. Nothing left (or not known) says nothing.
TimeCornerWords timeCornerWords(
  DateTime now,
  TimeStyle style, {
  Duration? left,
}) => (
  clock: formatClock(now, style),
  left: left == null || left <= Duration.zero
      ? null
      : formatTimeLeft(
          Duration(
            minutes: (left.inMicroseconds / Duration.microsecondsPerMinute)
                .ceil(),
          ),
        ),
);

/// How long from [now] until the corner's words may change: the clock's
/// next minute, or sooner the next whole minute left before [end] (a
/// programme's, which runs down with the clock). Never nothing, so a
/// timer on it never spins.
Duration timeCornerWait(DateTime now, {DateTime? end}) {
  const minute = Duration.microsecondsPerMinute;
  var wait = minute - now.microsecondsSinceEpoch % minute;
  if (end != null && end.isAfter(now)) {
    final turn = end.difference(now).inMicroseconds % minute;
    if (turn > 0 && turn < wait) wait = turn;
  }
  return Duration(microseconds: wait);
}

/// The clock and the time left, top right of the full-screen player while
/// its controls are hidden (Settings → Playback → Time on screen): where
/// the OSD's clock is, so the clock seems to stay when the OSD goes, with
/// the time left under it — a file's ([vod]), or the programme's on a
/// [channel] when the guide knows it. It fades in as the OSD fades out
/// and out as it comes back, and takes no clicks and no focus.
///
/// The picture under it is on a layer of its own and Flutter draws
/// nothing while the OSD is hidden: this is drawn again only when its
/// words change, at most once a minute each (the clock's minute, the time
/// left's), never as a file plays. Gone, it holds nothing: no timer, no
/// listener, no text.
class PlayerTimeCorner extends ConsumerStatefulWidget {
  const new({required this.shown, this.vod, this.channel, super.key});

  /// Up; false fades it out.
  final bool shown;

  /// A movie's or an episode's controller: its time left.
  final VodPlayerController? vod;

  /// A channel: its programme's time left.
  final ChannelItem? channel;

  @override
  ConsumerState<PlayerTimeCorner> createState() => _PlayerTimeCornerState();
}

class _PlayerTimeCornerState extends ConsumerState<PlayerTimeCorner> {
  /// Up, or still fading out.
  late bool _present = widget.shown;

  /// What it says, and its face for that: kept, so the player building
  /// again around it (the next-episode card counts once a second) doesn't
  /// build it again.
  TimeCornerWords? _words;
  Widget? _face;

  /// From the last build: how the clock is written, and when the
  /// programme on now ends.
  TimeStyle? _style;
  DateTime? _end;

  /// Wakes it when its words may change; null while it isn't up.
  Timer? _tick;

  @override
  void initState() {
    super.initState();
    if (widget.shown) _follow();
  }

  @override
  void didUpdateWidget(PlayerTimeCorner oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.shown == widget.shown && oldWidget.vod == widget.vod) return;
    _unfollow(oldWidget.vod);
    if (widget.shown) {
      _present = true;
      _follow();
    }
  }

  @override
  void dispose() {
    _unfollow(widget.vod);
    super.dispose();
  }

  /// A file's time is heard 4 times a second, and only a change of words
  /// (a minute gone, a seek) builds it again.
  void _follow() {
    widget.vod?.addListener(_check);
    _schedule();
  }

  void _unfollow(VodPlayerController? vod) {
    vod?.removeListener(_check);
    _tick?.cancel();
    _tick = null;
  }

  void _schedule() {
    _tick?.cancel();
    final now = ref.read(appClockProvider)();
    _tick = Timer(timeCornerWait(now, end: _end), () {
      _check();
      _schedule();
    });
  }

  TimeCornerWords? _wordsAt(DateTime now) {
    final style = _style;
    if (style == null) return null;
    final left = switch (widget.vod) {
      final vod? => vod.timeline.remaining,
      null => _end?.difference(now),
    };
    return timeCornerWords(now, style, left: left);
  }

  void _check() {
    if (!mounted) return;
    final words = _wordsAt(ref.read(appClockProvider)());
    if (words != null && words != _words) setState(() {});
  }

  void _onFaded() {
    if (mounted && !widget.shown && _present) {
      setState(() => _present = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final tokens = context.tokens;
    _style = tokens.timeStyle;
    final end = switch (widget.channel) {
      final channel? => ref.watch(nowNextProvider(channel)).value?.now?.end,
      null => null,
    };
    if (end != _end) {
      _end = end;
      // A new programme: its own minutes.
      if (_tick != null) _schedule();
    }
    final words = _wordsAt(ref.watch(appClockProvider)())!;
    if (words != _words || _face == null) {
      _words = words;
      _face = RepaintBoundary(child: _TimeCornerFace(words));
    }
    return IgnorePointer(
      child: ExcludeFocus(
        child: AnimatedOpacity(
          opacity: widget.shown ? 1 : 0,
          // The OSD's own timing, the other way round.
          duration: widget.shown ? tokens.motion.osdOut : tokens.motion.osdIn,
          onEnd: _onFaded,
          child: _present ? _face : null,
        ),
      ),
    );
  }
}

/// The two lines, right-aligned on the shade badges have over the
/// picture, which keeps them legible over a bright one and all but
/// vanishes over a dark one: the clock as the OSD draws it, the time left
/// under it. No border: it is something to read, not to press.
class _TimeCornerFace extends StatelessWidget {
  const new(this.words);

  final TimeCornerWords words;

  @override
  Widget build(BuildContext context) {
    final tokens = context.tokens;
    final colors = tokens.colors;
    return DecoratedBox(
      decoration: BoxDecoration(
        color: colors.videoChip,
        borderRadius: tokens.radii.mdAll,
      ),
      child: Padding(
        padding: EdgeInsets.symmetric(
          horizontal: tokens.spacing.s12,
          vertical: tokens.spacing.s8,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Text(
              words.clock,
              style: tokens.text.h2.copyWith(color: colors.textPrimary),
            ),
            if (words.left case final left?)
              Text(
                left,
                style: tokens.text.bodyStrong.copyWith(
                  color: colors.textEmphasis,
                ),
              ),
          ],
        ),
      ),
    );
  }
}
