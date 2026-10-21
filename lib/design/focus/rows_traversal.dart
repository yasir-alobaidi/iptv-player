import 'package:flutter/widgets.dart';
import 'package:iptv_player/design/focus/focusable_surface.dart';

/// Of [candidates], the one ↓ ([down]) or ↑ goes to from [from]: in the
/// nearest row that way (a candidate whose centre is past [from]'s edge;
/// that row is every one overlapping the nearest one's height), the one
/// whose centre is closest across. Null when there is none. Exposed for
/// tests.
T? nearestInNextRow<T>(
  Rect from,
  Iterable<T> candidates,
  Rect Function(T) rectOf, {
  required bool down,
}) {
  final beyond = [
    for (final candidate in candidates)
      if (down
          ? rectOf(candidate).center.dy > from.bottom
          : rectOf(candidate).center.dy < from.top)
        candidate,
  ];
  if (beyond.isEmpty) return null;
  double ahead(T candidate) {
    final rect = rectOf(candidate);
    return down ? rect.top - from.bottom : from.top - rect.bottom;
  }

  final nearest = beyond.reduce((a, b) => ahead(b) < ahead(a) ? b : a);
  final row = rectOf(nearest);
  double across(T candidate) =>
      (rectOf(candidate).center.dx - from.center.dx).abs();
  return beyond
      .where((candidate) {
        final rect = rectOf(candidate);
        return rect.top < row.bottom && rect.bottom > row.top;
      })
      .reduce((a, b) => across(b) < across(a) ? b : a);
}

/// A form's focus (Settings' sections): ↑/↓ go to the nearest row above
/// or below, onto its control closest across, however wide or narrow the
/// controls are; ←/→ and Tab are the app's reading order. Flutter's own
/// ↑/↓ keep to what overlaps the focused control's width, so from a wide
/// row's left-hand segment ↓ skipped every narrow switch on the right
/// down to the next wide field (Settings → Playback on the TV: Low
/// latency to Preferred audio, past three rows; ADR-050). With no row
/// that way inside, ↑/↓ go on as everywhere else (out to the top bar).
class RowsTraversalGroup extends StatefulWidget {
  const new({required this.child, super.key});

  final Widget child;

  @override
  State<RowsTraversalGroup> createState() => _RowsTraversalGroupState();
}

class _RowsTraversalGroupState extends State<RowsTraversalGroup> {
  final _within = FocusNode(
    debugLabel: 'rows',
    canRequestFocus: false,
    skipTraversal: true,
  );
  late final _policy = _RowsPolicy(_within);

  @override
  void dispose() {
    _within.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Focus(
    focusNode: _within,
    canRequestFocus: false,
    skipTraversal: true,
    child: FocusTraversalGroup(policy: _policy, child: widget.child),
  );
}

class _RowsPolicy extends ReadingOrderTraversalPolicy {
  new(this._within) : super(requestFocusCallback: revealingFocus);

  final FocusNode _within;

  @override
  bool inDirection(FocusNode currentNode, TraversalDirection direction) {
    final down = direction == TraversalDirection.down;
    if (!down && direction != TraversalDirection.up) {
      return super.inDirection(currentNode, direction);
    }
    final target = nearestInNextRow(
      currentNode.rect,
      _within.traversalDescendants.where(
        (node) => node != currentNode && node.context != null,
      ),
      (node) => node.rect,
      down: down,
    );
    if (target == null) return super.inDirection(currentNode, direction);
    // Flutter's own ↑/↓ remember the way they came and turn back along
    // it; these moves are not on that way.
    if (currentNode.nearestScope case final scope?) invalidateScopeData(scope);
    requestFocusCallback(
      target,
      alignmentPolicy: down
          ? ScrollPositionAlignmentPolicy.keepVisibleAtEnd
          : ScrollPositionAlignmentPolicy.keepVisibleAtStart,
    );
    return true;
  }
}
