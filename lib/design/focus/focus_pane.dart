import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:iptv_player/design/focus/focusable_surface.dart';

/// Remembers which item a [FocusPane] last had focused, so Left/Right
/// between panes returns to where the user was (docs/05). The shell holds
/// one of these per pane.
class FocusPaneController extends ChangeNotifier {
  FocusNode? _lastFocused;
  FocusNode? _pane;

  /// The item that had focus when the pane was last left, if it is still
  /// in the tree.
  FocusNode? get lastFocused {
    final node = _lastFocused;
    if (node == null || node.context == null) return null;
    // Gone with its item (a card a filter dropped): its node may keep a
    // context, but it is no longer in the pane, and asking it for the
    // focus does nothing. The user, on the Bedroom TV: ↓ to the grid
    // after a filter stayed on the chips.
    final pane = _pane;
    if (pane != null && !node.ancestors.contains(pane)) return null;
    if (_rectOf(node) == null) return null;
    return node;
  }

  /// The pane's focusable items, in tree order. Empty until the
  /// [FocusPane] is built.
  Iterable<FocusNode> get items =>
      _pane?.traversalDescendants ?? const <FocusNode>[];

  /// True while focus is somewhere inside the pane.
  bool get hasFocus => _pane?.hasFocus ?? false;

  /// Focuses the remembered item. Returns false when there is nothing to
  /// return to, so the caller can fall back to the first item.
  bool focusLast() {
    final node = lastFocused;
    if (node == null || !node.canRequestFocus) return false;
    node.requestFocus();
    return true;
  }

  /// Focuses the pane's first item in reading order, as Tab would reach
  /// it. Returns false when the pane has nothing to focus, so the caller
  /// can leave focus where it is.
  ///
  /// Not [items]' first: the focus tree keeps nodes in the order they
  /// were attached, so a row that appeared above the others (Home's
  /// Continue watching) would come after them.
  bool focusFirst() {
    final placed = [
      for (final node in items)
        // A route's scope is in the list too, as big as its screen.
        if (node is! FocusScopeNode && node.canRequestFocus)
          if (_rectOf(node) case final rect?) (node, rect),
    ]..sort((a, b) => _readingOrder(a.$2, b.$2));
    final first =
        placed
            .where((e) => e.$1.ancestors.any((a) => a is _LandingNode && a.on))
            .firstOrNull
            ?.$1 ??
        placed.firstOrNull?.$1;
    first?.requestFocus();
    return first != null;
  }

  /// Focuses the remembered item, or the first one. Left/Right between
  /// panes uses this (docs/05).
  bool focusPane() => focusLast() || focusFirst();

  /// Focuses the item nearest above [from], a control under the pane (in
  /// global coordinates), as an arrow Up picks one inside a screen: of
  /// the items across its width, the nearest; with none, the one with an
  /// edge nearest its middle. Returns false when the pane has nothing
  /// above it, so the caller can fall back to [focusPane].
  ///
  /// Not the remembered item: Up from Movies' sort went to the top bar's
  /// source switcher, not the search right above it (the user, on the
  /// Bedroom TV).
  bool focusAbove(Rect from) {
    final middle = from.center;
    final above = [
      for (final node in items)
        if (node is! FocusScopeNode && node.canRequestFocus)
          if (_rectOf(node) case final rect? when rect.center.dy <= from.top)
            (node, rect),
    ];
    double up(Rect rect) => (rect.center.dy - middle.dy).abs();
    double aside(Rect rect) => (rect.center.dx - middle.dx).abs();
    double edgeAside(Rect rect) =>
        math.min((rect.left - middle.dx).abs(), (rect.right - middle.dx).abs());
    final across = [
      for (final item in above)
        if (item.$2.left < from.right && item.$2.right > from.left) item,
    ];
    final nearest = across.isNotEmpty
        ? (across..sort((a, b) => _closer(a.$2, b.$2, up, aside)))
        : (above..sort((a, b) => _closer(a.$2, b.$2, edgeAside, up)));
    final node = nearest.firstOrNull?.$1;
    node?.requestFocus();
    return node != null;
  }

  /// Drops the pane reference when that [FocusPane] goes away.
  void _forget(FocusNode pane) {
    if (identical(_pane, pane)) _pane = null;
  }

  /// Makes [node] the item [focusPane] returns to, before the user was
  /// ever in the pane: a series' list lands on the episode to continue.
  void remember(FocusNode node) => _remember(node);

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
    this.tabStop = false,
    super.key,
  });

  final Widget child;

  /// Makes the pane one Tab stop, for lists that can be hundreds of items
  /// long (a provider's categories): arrows move inside it, and Tab and
  /// Shift+Tab leave it for the stop after and before it in the screen's
  /// own order, as if the whole pane were one control (docs/05, "each
  /// pane is a group"). Tab into it lands on the item it was left from,
  /// or on its first.
  final bool tabStop;

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
    widget.controller?._pane = _marker;
    // Listening to the manager rather than the marker's onFocusChange:
    // that only fires when the pane is entered or left, so it would
    // remember the first item instead of the one focus left from.
    FocusManager.instance.addListener(_onFocusChanged);
  }

  @override
  void didUpdateWidget(FocusPane oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.controller != widget.controller) {
      oldWidget.controller?._forget(_marker);
      widget.controller?._pane = _marker;
    }
  }

  @override
  void dispose() {
    FocusManager.instance.removeListener(_onFocusChanged);
    widget.controller?._forget(_marker);
    _marker.dispose();
    super.dispose();
  }

  /// The item the focus was last on in here, whoever asks: a pane with
  /// no controller remembers it too, for Tab coming back in.
  FocusNode? _last;

  /// Whether the focus was inside the pane at its last change.
  bool _inside = false;

  /// The item Tab comes back to: the one the pane was left from (or the
  /// one its controller was told to remember), while it is still there.
  FocusNode? get _remembered {
    final node = widget.controller?.lastFocused ?? _last;
    if (node == null || !node.canRequestFocus || _rectOf(node) == null) {
      return null;
    }
    return node.ancestors.contains(_marker) ? node : null;
  }

  /// The pane's items in reading order, as [FocusPaneController.focusFirst]
  /// has them.
  List<FocusNode> get _items => [
    for (final (node, _) in [
      for (final node in _marker.traversalDescendants)
        if (node is! FocusScopeNode && node.canRequestFocus)
          if (_rectOf(node) case final rect?) (node, rect),
    ]..sort((a, b) => _readingOrder(a.$2, b.$2)))
      node,
  ];

  void _onFocusChanged() {
    final focused = FocusManager.instance.primaryFocus;
    if (focused == null) return;
    final inside = focused.ancestors.contains(_marker);
    final entered = inside && !_inside;
    _inside = inside;
    if (!inside) return;
    // Tab came in from outside: a one-stop pane is entered where it was
    // left, not at whichever end is nearer. A click, an arrow or a screen
    // placing the focus says exactly which item, and is left alone.
    if (entered && widget.tabStop && _tabHeld) {
      final wanted = _remembered ?? _items.firstOrNull;
      if (wanted != null && wanted != focused) {
        revealingFocus(wanted);
        return;
      }
    }
    _last = focused;
    widget.controller?._remember(focused);
  }

  static bool get _tabHeld => HardwareKeyboard.instance.logicalKeysPressed
      .contains(LogicalKeyboardKey.tab);

  /// Tab or Shift+Tab out of the pane: to the stop after it ([forward])
  /// or before it in the screen's traversal order, in which the pane is
  /// one stop. False when the pane has nothing to leave from.
  ///
  /// The order is Flutter's own, groups taken as units — the one Tab
  /// follows between plain controls — so a pane sits in the walk where
  /// the eye puts it. (It used to be "the nearest control below", which
  /// on a page of two columns skipped everything beside the pane: Tab
  /// never came back to a series' Play.)
  bool _leave({required bool forward}) {
    final items = _items;
    if (items.isEmpty) return false;
    // The walk goes on from the scope's focused child: for a moment that
    // is the pane's edge. The focus itself only moves once, to where the
    // walk lands.
    final edge = (forward ? items.last : items.first)..requestFocus();
    final walk = widget.policy ?? appTraversalPolicy();
    return forward ? walk.next(edge) : walk.previous(edge);
  }

  @override
  Widget build(BuildContext context) {
    Widget pane = Focus(
      focusNode: _marker,
      debugLabel: widget.debugLabel,
      child: widget.child,
    );
    if (widget.tabStop) {
      pane = Actions(
        actions: {
          NextFocusIntent: CallbackAction<NextFocusIntent>(
            onInvoke: (_) => _leave(forward: true),
          ),
          PreviousFocusIntent: CallbackAction<PreviousFocusIntent>(
            onInvoke: (_) => _leave(forward: false),
          ),
        },
        child: pane,
      );
    }
    return FocusTraversalGroup(
      policy: widget.policy ?? appTraversalPolicy(),
      child: pane,
    );
  }
}

/// Where a pane's [FocusPaneController.focusFirst] lands when [on]: the
/// first control inside this, rather than the screen's first. With
/// nothing focusable inside (still loading, empty), the screen's first
/// control as before. On a TV, Movies' and Series' posters: their filter
/// field above them is a keyboard away, and a remote comes for the
/// titles (the user, on the Bedroom TV: two Downs to reach the grid).
class FocusLanding extends StatefulWidget {
  const new({required this.child, this.on = true, super.key});

  final Widget child;
  final bool on;

  @override
  State<FocusLanding> createState() => _FocusLandingState();
}

class _FocusLandingState extends State<FocusLanding> {
  final _marker = _LandingNode();

  @override
  void dispose() {
    _marker.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    _marker.on = widget.on;
    return Focus(focusNode: _marker, child: widget.child);
  }
}

class _LandingNode extends FocusNode {
  new()
    : super(
        debugLabel: 'FocusLanding',
        canRequestFocus: false,
        skipTraversal: true,
      );

  bool on = true;
}

/// Where [node] is on screen; null before it is laid out, and for an
/// item that has just left the tree: a row removed in this frame keeps
/// its focus node until the frame ends, and nothing may be asked of its
/// element by then.
Rect? _rectOf(FocusNode node) {
  final context = node.context;
  if (context is! Element) return null;
  final box = context.renderObject;
  if (box == null || !box.attached) return null;
  if (box is RenderBox && !box.hasSize) return null;
  return node.rect;
}

/// Which of [a] and [b] is nearer by [first], [then] breaking a tie.
int _closer(
  Rect a,
  Rect b,
  double Function(Rect rect) first,
  double Function(Rect rect) then,
) {
  final order = first(a).compareTo(first(b));
  return order != 0 ? order : then(a).compareTo(then(b));
}

/// Top to bottom, then left to right among controls on one line.
int _readingOrder(Rect a, Rect b) {
  final dy = a.center.dy - b.center.dy;
  if (dy.abs() > a.height / 2 && dy.abs() > b.height / 2) {
    return dy.sign.toInt();
  }
  return a.left.compareTo(b.left);
}
