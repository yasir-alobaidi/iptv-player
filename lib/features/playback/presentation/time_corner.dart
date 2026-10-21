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

/// The clock, small, top right of the full-screen player while its
/// controls are hidden (Settings → Playback → Time on screen): where the
/// OSD's clock is, so the time stays when the OSD goes. No box and no time
/// left (ADR-051: the user found the first, a shaded box with the time
/// left under the clock, too big and too much to look at while
/// watching); the time left is on the controls a key away. It fades in
/// as the OSD fades out and out as it comes back, and takes no clicks and
/// no focus.
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
    final clock = formatClock(ref.watch(appClockProvider)(), tokens.timeStyle);
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

/// The clock straight on the picture: small and heavy (17 px at 800), in
/// the muted text colour over a soft dark halo, which keeps it legible
/// over a bright scene without a box around it.
class _TimeCornerFace extends StatelessWidget {
  const new(this.clock);

  final String clock;

  @override
  Widget build(BuildContext context) {
    final tokens = context.tokens;
    return Text(
      clock,
      style: tokens.text.titleSmall.copyWith(
        color: tokens.colors.textEmphasis,
        shadows: tokens.elevation.textOverPicture,
      ),
    );
  }
}
