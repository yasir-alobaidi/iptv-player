import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:iptv_player/design/components.dart';
import 'package:iptv_player/design/tokens.dart';

/// One of Home's rows as the keyboard sees it: its cards' focus nodes by
/// index and the rail's scroll position, so ←/→ move by card within it and
/// ↑/↓ land on the nearest card of the row above or below.
///
/// A card's node is its item's, wherever the row puts it ([HomeRow.ids]):
/// back from playing the third card, which is first now, the focus is on
/// it, not on the third place (ADR-039).
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

  /// The card the keyboard is on, or comes back to: the one with the
  /// focus, or the one its page gives the focus back to (from the rail, a
  /// menu, the player). Null when that is no card of this row.
  int? get held {
    for (final MapEntry(:key, :value) in _nodes.entries) {
      if (value.hasFocus || value.enclosingScope?.focusedChild == value) {
        return key;
      }
    }
    return null;
  }

  /// Whether one of the row's cards has the focus.
  bool get hasFocus => _nodes.values.any((node) => node.hasFocus);

  /// The focus has been in the row a while ([_toFirstFor]): the user is
  /// at work there, so a change that didn't come from them (a sync adding
  /// a newer movie to Recently added) doesn't take the focus away. Coming
  /// back to Home, or into the row, starts the clock again.
  bool get settled => hasFocus && _settled;
  var _settled = false;

  /// Runs while the focus is in the row and not yet [settled]: a timer,
  /// which a test's clock moves (a stopwatch it doesn't).
  Timer? _settling;

  /// The held card moved from [from] to [to] (its row re-sorted): the
  /// rail scrolls with it, so the card stays where it was on screen. Its
  /// node lives only while the rail builds it: moved far out of view, it
  /// went with the focus (the seventh card played, now first, the rail
  /// still scrolled to the seventh place). Played from the third place it
  /// is first now, and the rail is back at its start.
  ///
  /// Called while the row is built, before the rail is laid out with the
  /// cards in their new places, as TabBarView moves its pages.
  void follow(int from, int to) {
    if (!scroll.hasClients) return;
    final position = scroll.position;
    final offset = (position.pixels + (to - from) * stride).clamp(
      position.minScrollExtent,
      position.maxScrollExtent,
    );
    if (offset != position.pixels) scroll.jumpTo(offset);
  }

  /// The row's first card takes the focus, not the card it had or would
  /// go back to: the held card's item left the row (a film watched into
  /// its credits: out of Continue watching), or something new came first
  /// (played here, or elsewhere: vod_walk left the focus on a card, went
  /// to Series by Ctrl+4 and played an episode, and back by Ctrl+1 the
  /// focus followed the card it had left, now second). Home's rows change
  /// only once it shows again (its providers rest while it is hidden): with
  /// the focus in the row, at once; else when a card of it takes the focus
  /// back, within [_toFirstFor], not a row returned to much later.
  void toFirst() {
    if (hasFocus) {
      _toFirst();
      return;
    }
    _toFirstAsked
      ..reset()
      ..start();
  }

  static const _toFirstFor = Duration(seconds: 2);
  final _toFirstAsked = Stopwatch();

  void _toFirst() {
    _toFirstAsked
      ..stop()
      ..reset();
    WidgetsBinding.instance
      ..addPostFrameCallback((_) => focus(0))
      ..scheduleFrame();
  }

  /// One of the row's cards took the focus.
  void _cardFocused() {
    if (!_settled && _settling == null) {
      _settling = Timer(_toFirstFor, () {
        _settling = null;
        _settled = true;
      });
    }
    if (!_toFirstAsked.isRunning) return;
    if (_toFirstAsked.elapsed <= _toFirstFor) {
      _toFirst();
    } else {
      _toFirstAsked
        ..stop()
        ..reset();
    }
  }

  /// One of the row's cards let the focus go: out of the row, unless
  /// another card of it has it now (focus changes are told once made).
  void _cardLeft() {
    if (hasFocus) return;
    _settling?.cancel();
    _settling = null;
    _settled = false;
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
      revealingFocus(node);
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
          revealingFocus(built);
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

  void dispose() {
    _settling?.cancel();
    scroll.dispose();
  }
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
/// in a rail that scrolls sideways past what fits. One Tab stop. On a TV
/// See all is also the row's last card, where → at its end lands (the
/// header's link is out of a remote's reach; Google TV's rows end so).
class HomeRow extends StatefulWidget {
  const new({
    required this.title,
    required this.controller,
    required this.ids,
    required this.cardWidth,
    required this.cardHeight,
    required this.gap,
    required this.card,
    required this.inset,
    this.onSeeAll,
    super.key,
  });

  final String title;
  final HomeRowController controller;

  /// The cards' items, in the row's order, each by an id of its own (a
  /// channel's or a title's source and key): a card keeps its focus node
  /// by it, so when the row re-sorts — what was just played comes first —
  /// the focus is on the same item, not on the place it had (ADR-039).
  final List<Object> ids;
  final double cardWidth;

  /// The card with what is under it.
  final double cardHeight;
  final double gap;

  /// Builds card `index` with the node the keyboard moves between.
  final Widget Function(BuildContext context, int index, FocusNode focus) card;
  final VoidCallback? onSeeAll;

  /// Room round the cards for a focused card's growth and ring: [insetFor].
  final double inset;

  /// The room a focused card [longest] px at its longest side needs round
  /// it, so the row's edge never cuts its ring (ADR-029); 8 px at least.
  static double insetFor(AppTokens tokens, double longest) => math.max(
    tokens.spacing.s8,
    tokens.focus.tileReach(longest).ceilToDouble(),
  );

  @override
  State<HomeRow> createState() => _HomeRowState();
}

class _HomeRowState extends State<HomeRow> {
  /// The cards' keys: their ids, one repeated told apart by its place (a
  /// key twice in a list loses a card).
  late List<Object> _keys = _keysOf(widget.ids);

  /// Where each key is.
  late Map<Object, int> _places = _placesOf(_keys);

  static List<Object> _keysOf(List<Object> ids) {
    final seen = <Object>{};
    return [
      for (final (i, id) in ids.indexed)
        if (seen.add(id)) id else _Repeated(id, i),
    ];
  }

  static Map<Object, int> _placesOf(List<Object> keys) => {
    for (final (i, key) in keys.indexed) key: i,
  };

  @override
  void didUpdateWidget(HomeRow oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (listEquals(oldWidget.ids, widget.ids)) return;
    final before = _keys;
    _keys = _keysOf(widget.ids);
    _places = _placesOf(_keys);
    // The card the keyboard is on, or comes back to, goes where its item
    // went; the cards are still at their old places here.
    final controller = widget.controller;
    final held = controller.held;
    if (held == null || held >= before.length) return;
    final to = _places[before[held]];
    // Something new first: the focus on it, the newest. The held card
    // itself first (played from further along): it follows (ADR-039). Not
    // while the user is at work in the row: what came first wasn't theirs.
    final newFirst =
        before.isNotEmpty && _keys.isNotEmpty && _keys.first != before.first;
    if (to == null || (newFirst && to != 0 && !controller.settled)) {
      controller.toFirst();
    } else if (to != held) {
      controller.follow(held, to);
    }
  }

  @override
  Widget build(BuildContext context) {
    final inset = widget.inset;
    final onSeeAll = widget.onSeeAll;
    final seeAllCard = TvMode.of(context) && onSeeAll != null;
    final items = _keys.length;
    final count = items + (seeAllCard ? 1 : 0);
    widget.controller
      ..count = count
      ..stride = widget.cardWidth + widget.gap;
    // A card scrolled into view brings its heading.
    return RevealArea(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
          Padding(
            padding: EdgeInsets.symmetric(horizontal: inset),
            child: SectionHeader(
              title: widget.title,
              onSeeAll: widget.onSeeAll,
            ),
          ),
          FocusPane(
            debugLabel: 'home row ${widget.title}',
            tabStop: true,
            child: HorizontalRail(
              controller: widget.controller.scroll,
              height: widget.cardHeight + inset * 2,
              spacing: widget.gap,
              padding: EdgeInsets.all(inset),
              itemCount: count,
              findItemIndexCallback: (key) => switch (key) {
                ValueKey<Object>(value: _seeAll) => seeAllCard ? items : null,
                ValueKey<Object>(:final value) => _places[value],
                _ => null,
              },
              itemBuilder: (context, index) => _RowCard(
                key: ValueKey<Object>(index < items ? _keys[index] : _seeAll),
                index: index,
                controller: widget.controller,
                builder: (context, focus) => index == items
                    ? _SeeAllCard(
                        focus: focus,
                        width: widget.cardWidth,
                        height: widget.cardHeight,
                        onPressed: onSeeAll!,
                      )
                    : widget.card(context, index, focus),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// The See all card's key, beside the items' ids.
const _seeAll = #seeAll;

/// A key a row has twice, the second time by its place.
@immutable
final class _Repeated {
  const new(this.id, this.index);

  final Object id;
  final int index;

  @override
  bool operator ==(Object other) =>
      other is _Repeated && other.id == id && other.index == index;

  @override
  int get hashCode => Object.hash(id, index);
}

/// See all as a row's last card (a TV).
class _SeeAllCard extends StatelessWidget {
  const new({
    required this.focus,
    required this.width,
    required this.height,
    required this.onPressed,
  });

  final FocusNode focus;
  final double width;
  final double height;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final tokens = context.tokens;
    final colors = tokens.colors;
    return SizedBox(
      width: width,
      height: height,
      child: FocusableSurface(
        focusNode: focus,
        onPressed: onPressed,
        growth: FocusGrowth.tile,
        borderRadius: tokens.radii.mdAll,
        background: colors.surface2,
        hoverBackground: colors.surface3,
        semanticLabel: 'See all',
        builder: (context, states) => Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            AppIcon(
              AppIcons.arrowRight,
              size: tokens.spacing.s32,
              color: states.highlighted
                  ? colors.accentBase
                  : colors.textSecondary,
            ),
            SizedBox(height: tokens.spacing.s8),
            Text(
              'See all',
              style: tokens.text.titleSmall.copyWith(color: colors.textPrimary),
            ),
          ],
        ),
      ),
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
    _focus.addListener(_onFocus);
  }

  void _onFocus() {
    if (_focus.hasFocus) {
      widget.controller._cardFocused();
    } else {
      widget.controller._cardLeft();
    }
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
