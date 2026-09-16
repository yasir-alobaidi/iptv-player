import 'package:flutter/material.dart';

/// Remembers which item a [FocusPane] last had focused, so Left/Right
/// between panes returns to where the user was (docs/05). The shell holds
/// one of these per pane.
class FocusPaneController extends ChangeNotifier {
  FocusNode? _lastFocused;

  /// The item that had focus when the pane was last left, if it is still
  /// in the tree.
  FocusNode? get lastFocused {
    final node = _lastFocused;
    if (node == null || node.context == null) return null;
    return node;
  }

  /// Focuses the remembered item. Returns false when there is nothing to
  /// return to, so the caller can fall back to the first item.
  bool focusLast() {
    final node = lastFocused;
    if (node == null || !node.canRequestFocus) return false;
    node.requestFocus();
    return true;
  }

  void _remember(FocusNode? node) {
    if (node == null || node == _lastFocused) return;
    _lastFocused = node;
    notifyListeners();
  }
}

/// A region of the UI that traverses as one group and remembers its last
/// focused item: the nav rail, the category list, the channel list.
///
/// This is deliberately *not* a [FocusScope]. A scope remembers its
/// focused child for free, but it also traps Tab: focus cycles inside the
/// scope and never reaches the rest of the screen, which would strand the
/// user in the nav rail. The memory is kept explicitly instead.
class FocusPane extends StatefulWidget {
  const new({
    required this.child,
    this.controller,
    this.debugLabel,
    this.policy,
    super.key,
  });

  final Widget child;

  /// Supply one to move focus back into this pane later (step 4's
  /// Left/Right between panes).
  final FocusPaneController? controller;
  final String? debugLabel;

  /// Defaults to reading order, which matches how these panes are laid
  /// out; a grid pane can pass its own.
  final FocusTraversalPolicy? policy;

  @override
  State<FocusPane> createState() => _FocusPaneState();
}

class _FocusPaneState extends State<FocusPane> {
  final _marker = FocusNode(
    debugLabel: 'FocusPane marker',
    canRequestFocus: false,
    skipTraversal: true,
  );

  @override
  void initState() {
    super.initState();
    // Listening to the manager rather than the marker's onFocusChange:
    // that only fires when the pane is entered or left, so it would
    // remember the first item instead of the one focus left from.
    FocusManager.instance.addListener(_onFocusChanged);
  }

  @override
  void dispose() {
    FocusManager.instance.removeListener(_onFocusChanged);
    _marker.dispose();
    super.dispose();
  }

  void _onFocusChanged() {
    final controller = widget.controller;
    if (controller == null) return;
    final focused = FocusManager.instance.primaryFocus;
    if (focused == null) return;
    if (focused.ancestors.contains(_marker)) controller._remember(focused);
  }

  @override
  Widget build(BuildContext context) {
    return FocusTraversalGroup(
      policy: widget.policy ?? ReadingOrderTraversalPolicy(),
      child: Focus(
        focusNode: _marker,
        debugLabel: widget.debugLabel,
        child: widget.child,
      ),
    );
  }
}
