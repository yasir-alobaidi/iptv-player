import 'dart:async';

import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:iptv_player/design/focus/app_intents.dart';

/// A TV remote's OK, the Android TV way (docs/07): a press activates what
/// has the focus when it is let go, and holding it opens that item's menu
/// ([AppMenuIntent], the keyboard's Menu key). The remote has no Menu key
/// and no F, so the hold is how a channel becomes a favorite there.
///
/// Above everything the router draws (it sees OK only when nothing under
/// the focus took it), and only on a TV: a keyboard's Enter is untouched.
class TvSelectKey extends StatefulWidget {
  const new({required this.child, super.key});

  final Widget child;

  /// How long OK is held for the menu.
  static const hold = Duration(milliseconds: 500);

  @override
  State<TvSelectKey> createState() => _TvSelectKeyState();
}

class _TvSelectKeyState extends State<TvSelectKey> {
  Timer? _hold;
  bool _down = false;
  bool _held = false;

  KeyEventResult _onKey(FocusNode node, KeyEvent event) {
    // Guide's key-down opened the Guide (the app's shortcuts); its key-up
    // left to Android would be acted on again.
    if (event.logicalKey == LogicalKeyboardKey.guide) {
      return event is KeyDownEvent
          ? KeyEventResult.ignored
          : KeyEventResult.handled;
    }
    if (event.logicalKey != LogicalKeyboardKey.select) {
      return KeyEventResult.ignored;
    }
    switch (event) {
      case KeyDownEvent():
        _down = true;
        _held = false;
        _hold?.cancel();
        _hold = Timer(TvSelectKey.hold, () {
          _held = true;
          _invoke(const AppMenuIntent());
        });
      case KeyUpEvent():
        _hold?.cancel();
        if (_down && !_held) _invoke(const ActivateIntent());
        _down = false;
      case KeyRepeatEvent():
        break;
    }
    return KeyEventResult.handled;
  }

  static void _invoke(Intent intent) {
    final context = FocusManager.instance.primaryFocus?.context;
    if (context != null) Actions.maybeInvoke(context, intent);
  }

  @override
  void dispose() {
    _hold?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Focus(
    canRequestFocus: false,
    skipTraversal: true,
    onKeyEvent: _onKey,
    child: widget.child,
  );
}
