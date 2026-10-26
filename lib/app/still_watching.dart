import 'dart:async';

import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:iptv_player/app/router.dart';
import 'package:iptv_player/design/components.dart';
import 'package:iptv_player/design/tokens.dart';
import 'package:iptv_player/features/playback/data/playback_providers.dart';
import 'package:iptv_player/features/playback/domain/playback_state.dart';

/// On a TV, playback that has gone on [after] with no key from the remote
/// asks "Still watching?", and stops after [answerWithin] with no answer
/// (ADR-025). How long is Settings → Playback's Ask if still watching
/// (ADR-064, 4 hours unless chosen).
///
/// Why: a Google TV doesn't always learn that its TV was switched off.
/// The Bedroom TV's Roku TV went dark and the Chromecast stayed awake,
/// the player keeping its screen on, so Bijou went on reading the stream
/// with nobody watching, holding a one-connection source until stopped.
class StillWatching extends ConsumerStatefulWidget {
  const new({required this.child, this.after, super.key});

  final Widget child;

  /// Playback with no key for this long asks; null is the time Settings
  /// → Playback chose, read at each tick, so a change counts at once.
  final Duration? after;

  /// The question waits this long, then playback stops.
  static const answerWithin = Duration(seconds: 60);

  static const _tick = Duration(minutes: 1);

  @override
  ConsumerState<StillWatching> createState() => _StillWatchingState();
}

class _StillWatchingState extends ConsumerState<StillWatching> {
  late final Timer _ticker;
  Duration _quiet = Duration.zero;
  bool _asking = false;

  @override
  void initState() {
    super.initState();
    HardwareKeyboard.instance.addHandler(_onKey);
    _ticker = Timer.periodic(StillWatching._tick, (_) => _onTick());
  }

  @override
  void dispose() {
    HardwareKeyboard.instance.removeHandler(_onKey);
    _ticker.cancel();
    super.dispose();
  }

  /// Any key is someone there; the key itself goes on as usual.
  bool _onKey(KeyEvent event) {
    _quiet = Duration.zero;
    return false;
  }

  void _onTick() {
    // A paused film counts: the player keeps its connection open.
    if (ref.read(playbackCoordinatorProvider).state is! PlaybackPlaying) {
      _quiet = Duration.zero;
      return;
    }
    _quiet += StillWatching._tick;
    final after =
        widget.after ??
        ref.read(playbackSettingsControllerProvider).stillWatchingAfter.after;
    if (_quiet >= after && !_asking) unawaited(_ask());
  }

  Future<void> _ask() async {
    final router = ref.read(routerProvider);
    final context = router.routerDelegate.navigatorKey.currentContext;
    if (context == null) return;
    _asking = true;
    final answer = await showAppDialog<bool>(
      context,
      builder: (_) => const _StillWatchingDialog(),
    );
    _asking = false;
    _quiet = Duration.zero;
    // Back or a click outside is someone there too: only Stop, or no
    // answer at all, stops.
    if (answer != false || !mounted) return;
    await ref.read(playbackCoordinatorProvider).stop();
    router.go('/');
  }

  @override
  Widget build(BuildContext context) => widget.child;
}

class _StillWatchingDialog extends StatefulWidget {
  const new();

  @override
  State<_StillWatchingDialog> createState() => _StillWatchingDialogState();
}

class _StillWatchingDialogState extends State<_StillWatchingDialog> {
  late final Timer _timeout;

  @override
  void initState() {
    super.initState();
    _timeout = Timer(StillWatching.answerWithin, () {
      if (mounted) Navigator.of(context).pop(false);
    });
  }

  @override
  void dispose() {
    _timeout.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final tokens = context.tokens;
    return AppDialog(
      title: 'Still watching?',
      primaryLabel: 'Keep watching',
      onPrimary: () => Navigator.of(context).pop(true),
      secondaryLabel: 'Stop',
      onSecondary: () => Navigator.of(context).pop(false),
      child: Text(
        "Playback stops in a minute, so the TV doesn't keep using your "
        'connection while nobody watches.',
        style: tokens.text.body.copyWith(color: tokens.colors.textSecondary),
      ),
    );
  }
}
