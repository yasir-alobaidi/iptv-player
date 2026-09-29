import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:iptv_player/app/failure_message.dart';
import 'package:iptv_player/app/shell/shell_state.dart';
import 'package:iptv_player/app/shell/toast_host.dart';
import 'package:iptv_player/core/notices/app_notices.dart';
import 'package:iptv_player/design/components.dart';

/// The app's toasts (docs/05: bottom centre, three seconds, an optional
/// action), over every route: what just happened shows wherever the user
/// is — over the search overlay, a dialog or the full-screen player — and
/// its Undo can be clicked there. Inside the shell, a toast sat under the
/// search overlay's scrim, out of reach.
///
/// **Ctrl+Z** runs the Undo of the toast shown, so it is reachable from
/// the keyboard (hard rule 5); a text field's own Ctrl+Z comes first.
///
/// Fed by non-fatal errors (`ErrorReporter`) and [AppNotices].
class AppToasts extends ConsumerStatefulWidget {
  const new({required this.child, super.key});

  /// The router's navigator.
  final Widget child;

  @override
  ConsumerState<AppToasts> createState() => _AppToastsState();
}

class _AppToastsState extends ConsumerState<AppToasts> {
  final _toasts = ToastHostController();

  @override
  void dispose() {
    _toasts.dispose();
    super.dispose();
  }

  KeyEventResult _onKey(FocusNode node, KeyEvent event) {
    if (event is! KeyDownEvent ||
        event.logicalKey != LogicalKeyboardKey.keyZ ||
        !HardwareKeyboard.instance.isControlPressed) {
      return KeyEventResult.ignored;
    }
    return _toasts.undo() ? KeyEventResult.handled : KeyEventResult.ignored;
  }

  @override
  Widget build(BuildContext context) {
    ref
      ..listen(nonFatalErrorsProvider, (previous, next) {
        final failure = next.value;
        if (failure == null) return;
        _toasts.show(
          ShellToast(
            message: failureWithAnswer(failure),
            tone: ToastTone.error,
          ),
        );
      })
      ..listen(backgroundNoticesProvider, (previous, next) {
        final notice = next.value;
        if (notice == null) return;
        _toasts.show(
          ShellToast(
            message: notice.message,
            tone: switch (notice.tone) {
              NoticeTone.neutral => ToastTone.neutral,
              NoticeTone.success => ToastTone.success,
              NoticeTone.error => ToastTone.error,
            },
            actionLabel: notice.actionLabel,
            onAction: notice.onAction,
            undo: notice.isUndo,
          ),
        );
      });

    return Focus(
      canRequestFocus: false,
      skipTraversal: true,
      onKeyEvent: _onKey,
      child: Stack(
        children: [
          widget.child,
          // Outside the navigator: no route's Material above it.
          Positioned.fill(
            child: Material(
              type: MaterialType.transparency,
              child: ToastHost(controller: _toasts),
            ),
          ),
        ],
      ),
    );
  }
}
