import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:iptv_player/design/focus/focus_ring.dart';
import 'package:iptv_player/design/focus/focus_visibility.dart';
import 'package:iptv_player/design/text_scale.dart';
import 'package:iptv_player/design/tokens.dart';

/// Something to read that is longer than its box: one Tab stop with the
/// focus ring, scrolled by the keyboard as well as the wheel.
///
/// ↑ and ↓ move a line, PageUp and PageDown a boxful, Home and End to
/// the ends. At an end the arrow isn't taken, so the focus can leave the
/// way it came (hard rule 5: no trap).
class ScrollPane extends StatefulWidget {
  /// [builder] makes the scrolling child and must give it the controller
  /// it is handed (a `ListView.builder` for something long).
  const new({
    required this.builder,
    required this.semanticLabel,
    this.controller,
    this.focusNode,
    this.autofocus = false,
    this.borderRadius,
    this.reverse = false,
    super.key,
  });

  /// A fixed [child], scrolled as a whole.
  factory child({
    required Widget child,
    required String semanticLabel,
    ScrollController? controller,
    FocusNode? focusNode,
    bool autofocus = false,
    BorderRadius? borderRadius,
    EdgeInsetsGeometry? padding,
    Key? key,
  }) => ScrollPane(
    key: key,
    semanticLabel: semanticLabel,
    controller: controller,
    focusNode: focusNode,
    autofocus: autofocus,
    borderRadius: borderRadius,
    builder: (context, controller) => SingleChildScrollView(
      controller: controller,
      padding: padding,
      child: child,
    ),
  );

  final Widget Function(BuildContext context, ScrollController controller)
  builder;

  /// What it is, for assistive technology: "Keyboard shortcuts".
  final String semanticLabel;
  final ScrollController? controller;
  final FocusNode? focusNode;
  final bool autofocus;
  final BorderRadius? borderRadius;

  /// The scrolling child starts at the bottom (`reverse: true`, as a log
  /// does): ↑ still shows what is above, Home the top, End the bottom.
  final bool reverse;

  /// One press of ↑ or ↓, at the canvas's text size.
  static const lineStep = 48.0;

  /// What a page keeps in view of the page before it.
  static const pageOverlap = 48.0;

  @override
  State<ScrollPane> createState() => _ScrollPaneState();
}

class _ScrollPaneState extends State<ScrollPane> {
  ScrollController? _own;
  bool _focused = false;

  ScrollController get _controller =>
      widget.controller ?? (_own ??= ScrollController());

  @override
  void dispose() {
    FocusVisibility.shown.removeListener(_onShown);
    _own?.dispose();
    super.dispose();
  }

  /// The rings came or went ([FocusVisibility]) while the pane has the
  /// focus: a click elsewhere hides its ring too.
  void _onShown() {
    if (mounted) setState(() {});
  }

  KeyEventResult _onKey(FocusNode node, KeyEvent event) {
    if (event is KeyUpEvent || !_controller.hasClients) {
      return KeyEventResult.ignored;
    }
    final position = _controller.position;
    final page = (position.viewportDimension - ScrollPane.pageOverlap).clamp(
      ScrollPane.lineStep,
      double.infinity,
    );
    final line = context.scaled(ScrollPane.lineStep);
    // In a reversed list the offset counts up from the bottom.
    final up = widget.reverse ? 1 : -1;
    final top = widget.reverse
        ? position.maxScrollExtent
        : position.minScrollExtent;
    final bottom = widget.reverse
        ? position.minScrollExtent
        : position.maxScrollExtent;
    final double target;
    switch (event.logicalKey) {
      case LogicalKeyboardKey.arrowUp:
        target = position.pixels + up * line;
      case LogicalKeyboardKey.arrowDown:
        target = position.pixels - up * line;
      case LogicalKeyboardKey.pageUp:
        target = position.pixels + up * page;
      case LogicalKeyboardKey.pageDown:
        target = position.pixels - up * page;
      case LogicalKeyboardKey.home:
        target = top;
      case LogicalKeyboardKey.end:
        target = bottom;
      default:
        return KeyEventResult.ignored;
    }
    final clamped = target.clamp(
      position.minScrollExtent,
      position.maxScrollExtent,
    );
    // Nowhere further to go: the key is the focus's, to leave with.
    if (clamped == position.pixels) return KeyEventResult.ignored;
    _controller.jumpTo(clamped);
    return KeyEventResult.handled;
  }

  @override
  Widget build(BuildContext context) {
    final tokens = context.tokens;
    final radius = widget.borderRadius ?? tokens.radii.controlAll;
    return Focus(
      canRequestFocus: false,
      skipTraversal: true,
      onKeyEvent: _onKey,
      child: FocusableActionDetector(
        focusNode: widget.focusNode,
        autofocus: widget.autofocus,
        onShowFocusHighlight: (value) {
          if (value == _focused) return;
          setState(() => _focused = value);
          if (value) {
            FocusVisibility.shown.addListener(_onShown);
          } else {
            FocusVisibility.shown.removeListener(_onShown);
          }
        },
        child: Semantics(
          label: widget.semanticLabel,
          container: true,
          child: AppFocusRing(
            visible: _focused && FocusVisibility.shown.value,
            borderRadius: radius,
            child: ClipRRect(
              borderRadius: radius,
              // Nothing inside is a stop of its own: the pane is.
              child: ExcludeFocus(child: widget.builder(context, _controller)),
            ),
          ),
        ),
      ),
    );
  }
}
