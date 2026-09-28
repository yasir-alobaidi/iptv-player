import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:iptv_player/design/components.dart';
import 'package:iptv_player/design/tokens.dart';

/// One of Home's rows as the keyboard sees it: its cards' focus nodes by
/// index and the rail's scroll position, so ←/→ move by card within it and
/// ↑/↓ land on the nearest card of the row above or below.
final class HomeRowController {
  final scroll = ScrollController();
  final _nodes = <int, FocusNode>{};

  /// How many cards the row has.
  int count = 0;

  /// A card's width plus the gap after it.
  double stride = 1;

  /// The index of [node] in this row; null when it isn't one of its cards.
  int? indexOf(FocusNode? node) {
    if (node == null) return null;
    for (final MapEntry(:key, :value) in _nodes.entries) {
      if (identical(value, node)) return key;
    }
    return null;
  }

  void register(int index, FocusNode node, {required bool add}) {
    if (add) {
      _nodes[index] = node;
    } else if (identical(_nodes[index], node)) {
      _nodes.remove(index);
    }
  }

  /// Focuses card [index], scrolling it into view — first, when the rail
  /// hasn't built it yet.
  void focus(int index) {
    if (count == 0) return;
    final target = index.clamp(0, count - 1);
    final node = _nodes[target];
    if (node != null && node.context != null) {
      FocusTraversalPolicy.defaultTraversalRequestFocusCallback(node);
      return;
    }
    if (scroll.hasClients) {
      final position = scroll.position;
      scroll.jumpTo(
        (target * stride).clamp(
          position.minScrollExtent,
          position.maxScrollExtent,
        ),
      );
    }
    // The card is built in the next frame; a jump that didn't move asks
    // for none, so one is asked for here.
    WidgetsBinding.instance
      ..addPostFrameCallback((_) {
        final built = _nodes[target];
        if (built != null && built.context != null) {
          FocusTraversalPolicy.defaultTraversalRequestFocusCallback(built);
        }
      })
      ..scheduleFrame();
  }

  /// The built card whose middle is nearest [dx] on screen.
  int? nearest(double dx) {
    int? best;
    var distance = double.infinity;
    for (final MapEntry(:key, :value) in _nodes.entries) {
      if (value.context == null) continue;
      final gap = (value.rect.center.dx - dx).abs();
      if (gap < distance) {
        distance = gap;
        best = key;
      }
    }
    return best;
  }

  void dispose() => scroll.dispose();
}

/// Moves the keyboard's focus between Home's [rows], top to bottom:
/// ←/→ by card within a row, stopping at its right end (← at the first
/// card goes on to the nav rail); ↑/↓ to the nearest card of the next row
/// that has any. Anywhere else — the hero, a See all — the arrows do what
/// they do everywhere.
KeyEventResult homeArrowKey(
  KeyEvent event,
  List<HomeRowController> rows, {
  FocusNode? above,
}) {
  if (event is KeyUpEvent) return KeyEventResult.ignored;
  final focused = FocusManager.instance.primaryFocus;
  final key = event.logicalKey;
  final at = rows.indexWhere((row) => row.indexOf(focused) != null);
  if (at < 0) {
    // From above the rows (the hero), ↓ goes to the first row's card
    // nearest where it was.
    if (key == LogicalKeyboardKey.arrowDown &&
        above != null &&
        focused != null &&
        (focused == above || focused.ancestors.contains(above)) &&
        rows.isNotEmpty) {
      rows.first.focus(rows.first.nearest(focused.rect.center.dx) ?? 0);
      return KeyEventResult.handled;
    }
    return KeyEventResult.ignored;
  }
  final row = rows[at];
  final index = row.indexOf(focused)!;
  switch (key) {
    case LogicalKeyboardKey.arrowLeft:
      if (index == 0) return KeyEventResult.ignored;
      row.focus(index - 1);
    case LogicalKeyboardKey.arrowRight:
      if (index + 1 < row.count) row.focus(index + 1);
    case LogicalKeyboardKey.arrowDown || LogicalKeyboardKey.arrowUp:
      final down = key == LogicalKeyboardKey.arrowDown;
      final next = at + (down ? 1 : -1);
      if (next < 0) return KeyEventResult.ignored;
      if (next >= rows.length) return KeyEventResult.handled;
      final dx = focused!.rect.center.dx;
      rows[next].focus(rows[next].nearest(dx) ?? 0);
    default:
      return KeyEventResult.ignored;
  }
  return KeyEventResult.handled;
}

/// A row of Home (canvas `Home`): its title with See all, and its cards
/// in a rail that scrolls sideways past what fits. One Tab stop.
class HomeRow extends StatefulWidget {
  const new({
    required this.title,
    required this.controller,
    required this.count,
    required this.cardWidth,
    required this.cardHeight,
    required this.gap,
    required this.card,
    this.onSeeAll,
    super.key,
  });

  final String title;
  final HomeRowController controller;
  final int count;
  final double cardWidth;

  /// The card with what is under it.
  final double cardHeight;
  final double gap;

  /// Builds card `index` with the node the keyboard moves between.
  final Widget Function(BuildContext context, int index, FocusNode focus) card;
  final VoidCallback? onSeeAll;

  /// Room round the cards for a focused card's growth and ring.
  static double inset(AppTokens tokens) => tokens.spacing.s8;

  @override
  State<HomeRow> createState() => _HomeRowState();
}

class _HomeRowState extends State<HomeRow> {
  @override
  Widget build(BuildContext context) {
    final tokens = context.tokens;
    final inset = HomeRow.inset(tokens);
    widget.controller
      ..count = widget.count
      ..stride = widget.cardWidth + widget.gap;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        Padding(
          padding: EdgeInsets.symmetric(horizontal: inset),
          child: SectionHeader(title: widget.title, onSeeAll: widget.onSeeAll),
        ),
        FocusPane(
          debugLabel: 'home row ${widget.title}',
          tabStop: true,
          child: HorizontalRail(
            controller: widget.controller.scroll,
            height: widget.cardHeight + inset * 2,
            spacing: widget.gap,
            padding: EdgeInsets.all(inset),
            itemCount: widget.count,
            itemBuilder: (context, index) => _RowCard(
              key: ValueKey(index),
              index: index,
              controller: widget.controller,
              builder: (context, focus) => widget.card(context, index, focus),
            ),
          ),
        ),
      ],
    );
  }
}

/// One card and the focus node its row finds it by.
class _RowCard extends StatefulWidget {
  const new({
    required this.index,
    required this.controller,
    required this.builder,
    super.key,
  });

  final int index;
  final HomeRowController controller;
  final Widget Function(BuildContext context, FocusNode focus) builder;

  @override
  State<_RowCard> createState() => _RowCardState();
}

class _RowCardState extends State<_RowCard> {
  final _focus = FocusNode(debugLabel: 'home card');

  @override
  void initState() {
    super.initState();
    widget.controller.register(widget.index, _focus, add: true);
  }

  @override
  void didUpdateWidget(_RowCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.index != widget.index ||
        oldWidget.controller != widget.controller) {
      oldWidget.controller.register(oldWidget.index, _focus, add: false);
      widget.controller.register(widget.index, _focus, add: true);
    }
  }

  @override
  void dispose() {
    widget.controller.register(widget.index, _focus, add: false);
    _focus.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => widget.builder(context, _focus);
}

/// Rebuilds its child once a minute: the channel tiles' progress moves.
class MinuteTicker extends StatefulWidget {
  const new({required this.builder, super.key});

  final WidgetBuilder builder;

  @override
  State<MinuteTicker> createState() => _MinuteTickerState();
}

class _MinuteTickerState extends State<MinuteTicker> {
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _timer = Timer.periodic(const Duration(minutes: 1), (_) {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => widget.builder(context);
}
