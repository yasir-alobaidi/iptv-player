import 'dart:async';
import 'dart:collection';

import 'package:flutter/material.dart';
import 'package:iptv_player/design/components.dart';
import 'package:iptv_player/design/tokens.dart';

/// One message queued for the shell's toast area.
@immutable
class ShellToast {
  const new({
    required this.message,
    this.tone = ToastTone.neutral,
    this.actionLabel,
    this.onAction,
  });

  final String message;
  final ToastTone tone;
  final String? actionLabel;
  final VoidCallback? onAction;
}

/// Shows toasts bottom-centre, one at a time, three seconds each
/// (docs/05). The shell feeds it from `ErrorReporter`; later phases push
/// their own ("Download finished · <title>").
///
/// Repeats are dropped while the same message is on screen, so a failure
/// that fires in a loop can't bury the UI under a stack of toasts.
class ToastHost extends StatefulWidget {
  const new({required this.controller, super.key});

  final ToastHostController controller;

  @override
  State<ToastHost> createState() => _ToastHostState();
}

/// Pushes toasts into a [ToastHost].
class ToastHostController extends ChangeNotifier {
  final _queue = Queue<ShellToast>();

  /// At most this many wait their turn; anything beyond is dropped.
  static const maxQueued = 3;

  ShellToast? _current;
  ShellToast? get current => _current;

  void show(ShellToast toast) {
    if (_current?.message == toast.message) return;
    if (_queue.any((queued) => queued.message == toast.message)) return;
    if (_queue.length >= maxQueued) _queue.removeFirst();
    _queue.add(toast);
    if (_current == null) _advance();
  }

  void dismissCurrent() => _advance();

  void _advance() {
    _current = _queue.isEmpty ? null : _queue.removeFirst();
    notifyListeners();
  }

  @override
  void dispose() {
    _queue.clear();
    super.dispose();
  }
}

class _ToastHostState extends State<ToastHost> {
  Timer? _timer;
  ShellToast? _shown;

  @override
  void initState() {
    super.initState();
    widget.controller.addListener(_onChanged);
    _shown = widget.controller.current;
    _restartTimer();
  }

  @override
  void didUpdateWidget(ToastHost oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.controller != widget.controller) {
      oldWidget.controller.removeListener(_onChanged);
      widget.controller.addListener(_onChanged);
      _onChanged();
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    widget.controller.removeListener(_onChanged);
    super.dispose();
  }

  void _onChanged() {
    setState(() => _shown = widget.controller.current);
    _restartTimer();
  }

  void _restartTimer() {
    _timer?.cancel();
    if (_shown == null) return;
    _timer = Timer(AppToast.defaultDuration, widget.controller.dismissCurrent);
  }

  @override
  Widget build(BuildContext context) {
    final tokens = context.tokens;
    final toast = _shown;

    return IgnorePointer(
      ignoring: toast == null,
      child: Align(
        alignment: Alignment.bottomCenter,
        child: Padding(
          padding: EdgeInsets.only(bottom: tokens.spacing.s24),
          child: AnimatedSwitcher(
            duration: tokens.motion.base,
            switchInCurve: tokens.motion.baseCurve,
            child: toast == null
                ? const SizedBox.shrink()
                : AppToast(
                    key: ValueKey(toast.message),
                    message: toast.message,
                    tone: toast.tone,
                    actionLabel: toast.actionLabel,
                    onAction: toast.onAction,
                  ),
          ),
        ),
      ),
    );
  }
}
