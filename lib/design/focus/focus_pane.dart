import 'package:flutter/material.dart';

/// A region of the UI that traps arrow-key traversal and remembers the
/// item that was focused when the user left it (docs/05). The nav rail,
/// the category list and the channel list are each a pane; Left/Right
/// moves between panes, Up/Down moves inside one.
///
/// The memory comes from the [FocusScope]: a scope restores its
/// `focusedChild` when it is focused again.
class FocusPane extends StatelessWidget {
  const new({
    required this.child,
    this.debugLabel,
    this.canRequestFocus = true,
    super.key,
  });

  final Widget child;
  final String? debugLabel;
  final bool canRequestFocus;

  @override
  Widget build(BuildContext context) {
    return FocusTraversalGroup(
      policy: ReadingOrderTraversalPolicy(),
      child: FocusScope(
        debugLabel: debugLabel,
        canRequestFocus: canRequestFocus,
        child: child,
      ),
    );
  }
}
