import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:iptv_player/core/core_providers.dart';
import 'package:iptv_player/core/text/format.dart';
import 'package:iptv_player/design/tokens.dart';

/// How long from [now] until the clock's next minute: never nothing, so
/// a timer on it never spins.
Duration timeCornerWait(DateTime now) {
  const minute = Duration.microsecondsPerMinute;
  return Duration(microseconds: minute - now.microsecondsSinceEpoch % minute);
}

/// The clock, top left of the full-screen player while its controls are
/// hidden (Settings → Playback → Time on screen), as large and heavy as
/// the OSD's own clock and without AM/PM (ADR-053: the user's words, after
/// a shaded box with the time left, ADR-047, and then a small clock,
/// ADR-051). No box and no time left; the time left is on the controls a
/// key away. It fades in as the OSD fades out and out as it comes back,
/// and takes no clicks and no focus.
///
/// The picture under it is on a layer of its own and Flutter draws
/// nothing while the OSD is hidden: this is drawn again only when its
/// minute changes. Gone, it holds nothing: no timer, no text.
class PlayerTimeCorner extends ConsumerStatefulWidget {
  const new({required this.shown, super.key});

  /// Up; false fades it out.
  final bool shown;

  @override
  ConsumerState<PlayerTimeCorner> createState() => _PlayerTimeCornerState();
}

class _PlayerTimeCornerState extends ConsumerState<PlayerTimeCorner> {
  /// Up, or still fading out.
  late bool _present = widget.shown;

  /// What it says, and its face for that: kept, so the player building
  /// again around it (the next-episode card counts once a second) doesn't
  /// build it again.
  String? _clock;
  Widget? _face;

  /// Wakes it at the next minute; null while it isn't up.
  Timer? _tick;

  @override
  void initState() {
    super.initState();
    if (widget.shown) _schedule();
  }

  @override
  void didUpdateWidget(PlayerTimeCorner oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.shown == widget.shown) return;
    _tick?.cancel();
    _tick = null;
    if (widget.shown) {
      _present = true;
      _schedule();
    }
  }

  @override
  void dispose() {
    _tick?.cancel();
    super.dispose();
  }

  void _schedule() {
    _tick?.cancel();
    final now = ref.read(appClockProvider)();
    _tick = Timer(timeCornerWait(now), () {
      if (!mounted) return;
      setState(() {});
      _schedule();
    });
  }

  void _onFaded() {
    if (mounted && !widget.shown && _present) {
      setState(() => _present = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final tokens = context.tokens;
    final clock = formatClockShort(
      ref.watch(appClockProvider)(),
      tokens.timeStyle,
    );
    if (clock != _clock || _face == null) {
      _clock = clock;
      _face = RepaintBoundary(child: _TimeCornerFace(clock));
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

/// The clock straight on the picture, as the OSD draws its own (22 px at
/// 700, the primary text colour), over a soft dark halo, which keeps it
/// legible over a bright scene without a box around it.
class _TimeCornerFace extends StatelessWidget {
  const new(this.clock);

  final String clock;

  @override
  Widget build(BuildContext context) {
    final tokens = context.tokens;
    return Text(
      clock,
      style: tokens.text.h2.copyWith(
        color: tokens.colors.textPrimary,
        shadows: tokens.elevation.textOverPicture,
      ),
    );
  }
}

/// When a file with [remaining] left to play ends at [speed], from [now]
/// (ADR-065); null for a channel, a file whose length isn't known, or one
/// with under a minute left. [held], the end shown before, is kept while
/// the new one is within half a minute of it, so the position's and the
/// clock's steps never flip the minute back and forth; a seek or a new
/// speed moves it at once.
DateTime? osdEndsAt(
  DateTime now,
  Duration? remaining,
  double speed, {
  DateTime? held,
}) {
  if (remaining == null || remaining < const Duration(minutes: 1)) {
    return null;
  }
  if (speed <= 0) return null;
  final ends = now.add(remaining * (1 / speed));
  if (held != null && ends.difference(held).abs() < osdEndsSlack) {
    return held;
  }
  return ends;
}

/// How far a file's end moves before the OSD says so: less than a
/// minute's step, more than the position's and the clock's jitter.
const osdEndsSlack = Duration(seconds: 30);

/// The OSD's clock, top right (ADR-017), and under it, for a file whose
/// length is known, the time it ends at the speed it plays: "Ends 10:42
/// PM" (ADR-065), which keeps its AM/PM, since an end can be past noon or
/// midnight. The end hangs below the clock without moving it, so the
/// clock stays where the corner's clock shrinks to (ADR-053).
///
/// It turns with the minute on its own: a paused picture rebuilds
/// nothing, yet the clock goes on and a paused file's end moves later
/// with it.
class OsdClock extends ConsumerStatefulWidget {
  const new({this.remaining, this.speed = 1, super.key});

  /// What is left to play; null for a channel (the programme's times are
  /// on the bottom bar) or while it isn't known.
  final Duration? remaining;
  final double speed;

  @override
  ConsumerState<OsdClock> createState() => _OsdClockState();
}

class _OsdClockState extends ConsumerState<OsdClock> {
  Timer? _tick;

  /// The end last shown ([osdEndsAt]'s held).
  DateTime? _ends;

  @override
  void initState() {
    super.initState();
    _schedule();
  }

  @override
  void dispose() {
    _tick?.cancel();
    super.dispose();
  }

  void _schedule() {
    final now = ref.read(appClockProvider)();
    _tick = Timer(timeCornerWait(now), () {
      if (!mounted) return;
      // The minute's turn works the end out afresh.
      setState(() => _ends = null);
      _schedule();
    });
  }

  @override
  Widget build(BuildContext context) {
    final tokens = context.tokens;
    final colors = tokens.colors;
    final now = ref.watch(appClockProvider)();
    final ends = _ends = osdEndsAt(
      now,
      widget.remaining,
      widget.speed,
      held: _ends,
    );
    final style = tokens.text.h2;
    final clock = Text(
      formatClock(now, tokens.timeStyle),
      style: style.copyWith(color: colors.textPrimary),
    );
    if (ends == null) return clock;
    final line =
        MediaQuery.textScalerOf(context).scale(style.fontSize!) * style.height!;
    return Stack(
      clipBehavior: Clip.none,
      children: [
        clock,
        Positioned(
          top: line + tokens.spacing.s4,
          right: 0,
          child: Text(
            // To the nearest minute.
            'Ends ${formatClock(ends.add(osdEndsSlack), tokens.timeStyle)}',
            maxLines: 1,
            style: tokens.text.bodyStrong.copyWith(color: colors.textSecondary),
          ),
        ),
      ],
    );
  }
}
