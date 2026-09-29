import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart' show ScrollCacheExtent;
import 'package:flutter/services.dart';
import 'package:iptv_player/core/result.dart';
import 'package:iptv_player/design/components.dart';
import 'package:iptv_player/design/tokens.dart';

/// Builds one card of a [TitleGrid]: [item] at [width], with the [focus]
/// node the grid moves between.
typedef TitleCardBuilder<T> = Widget Function(
  BuildContext context,
  T item,
  FocusNode focus,
  double width,
);

/// The poster grid Movies and Series share (canvas `Movies`): columns from
/// the width at [minCardWidth] and more (7 at 1440 px), windowed like Live
/// TV's list — [total] from a count, then pages of [pageSize] read on
/// demand (hard rule 2), skeleton cards until a page arrives.
///
/// One Tab stop: the arrows move by card, PageUp/PageDown by a screen,
/// Home/End to the ends, F toggles the focused title's favorite. Coming
/// back to it finds the card it was left on.
class TitleGrid<T extends Object> extends StatefulWidget {
  const new({
    required this.total,
    required this.load,
    required this.card,
    required this.identity,
    required this.controller,
    required this.query,
    required this.revision,
    this.onFavorite,
    this.pageSize = 120,
    super.key,
  });

  final int total;

  /// Reads `limit` titles from `offset`.
  final Future<Result<List<T>>> Function(int offset, int limit) load;
  final TitleCardBuilder<T> card;

  /// What makes a title the same title after its data moved (its source
  /// and key): its card, and the keyboard's focus in it, stay.
  final Object Function(T item) identity;
  final FocusPaneController controller;

  /// Another query starts the grid over, from the top.
  final Object query;

  /// The data moved (a favorite, a watch mark, a sync): the pages read are
  /// read again in place, the cards on screen staying until then.
  final Object revision;
  final void Function(T item)? onFavorite;
  final int pageSize;

  static const minCardWidth = 160.0;

  /// The canvas's gaps: 20 across, 24 down.
  static const columnGap = 20.0;
  static const rowGap = 24.0;

  /// Under the poster: the gap, the title and the line under it.
  static const captionHeight = 56.0;

  @override
  State<TitleGrid<T>> createState() => _TitleGridState<T>();
}

class _TitleGridState<T extends Object> extends State<TitleGrid<T>> {
  final _scroll = ScrollController();
  final _pages = <int, List<T>>{};
  final _loading = <int>{};
  final _nodes = <int, FocusNode>{};
  AppFailure? _error;

  /// The card that has, or last had, the focus.
  int _focused = 0;

  /// Laid out: what [_move] needs to jump by rows.
  int _columns = 1;
  double _stride = 1;
  double _inset = 0;

  /// Holds the keyboard's focus while the focused card is gone: the mouse
  /// scrolled it away and it is no longer built. Without it the focus
  /// would leave the grid, and the grid's keys with it.
  final _holder = FocusNode(debugLabel: 'title grid', skipTraversal: true);

  /// A key's move is on its way to its card (after the next frame).
  bool _moving = false;

  /// The card a key went to before it was built (End, before its page
  /// was read): it takes the focus as soon as it is.
  int? _pendingFocus;

  @override
  void didUpdateWidget(TitleGrid<T> oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.query != widget.query) {
      _pages.clear();
      _loading.clear();
      _nodes.clear();
      _error = null;
      _focused = 0;
      _pendingFocus = null;
      if (_scroll.hasClients) _scroll.jumpTo(0);
    } else if (oldWidget.revision != widget.revision) {
      _loading.clear();
      for (final page in _pages.keys.toList()) {
        unawaited(_load(page));
      }
    }
  }

  @override
  void dispose() {
    _scroll.dispose();
    _holder.dispose();
    super.dispose();
  }

  T? _itemAt(int index) {
    final page = index ~/ widget.pageSize;
    final items = _pages[page];
    if (items == null) {
      unawaited(_load(page));
      return null;
    }
    final at = index % widget.pageSize;
    return at < items.length ? items[at] : null;
  }

  Future<void> _load(int page) async {
    final query = widget.query;
    if (!_loading.add(page)) return;
    final result = await widget.load(page * widget.pageSize, widget.pageSize);
    if (!mounted || query != widget.query) return;
    setState(() {
      _loading.remove(page);
      switch (result) {
        case Ok(:final value):
          _pages[page] = value;
        case Err(:final failure):
          _error = failure;
      }
    });
  }

  /// Moves the focus by [delta] cards, keeping its row where it was on
  /// screen; [to] instead goes to one card.
  void _move({int delta = 0, int? to}) {
    final total = widget.total;
    if (total == 0 || !_scroll.hasClients) return;
    _pendingFocus = null;
    // From what is on screen when the mouse took the view elsewhere.
    if (!_rowOnScreen(_focused ~/ _columns)) _focused = _firstOnScreen();
    final target = (to ?? _focused + delta).clamp(0, total - 1);
    final fromRow = _focused ~/ _columns;
    final toRow = target ~/ _columns;
    final position = _scroll.position;
    final onScreen = fromRow * _stride - position.pixels;
    final offset = (toRow * _stride - onScreen).clamp(
      position.minScrollExtent,
      position.maxScrollExtent,
    );
    _moving = true;
    _scroll.jumpTo(offset);
    _focused = target;
    // The card may only be built in the next frame. A jump that didn't
    // scroll asks for no frame, so one is asked for here.
    WidgetsBinding.instance
      ..addPostFrameCallback((_) {
        _moving = false;
        if (mounted) _focusCard(target);
      })
      ..scheduleFrame();
  }

  /// Focuses card [index]; the grid holds the focus until it is built.
  void _focusCard(int index) {
    _focused = index;
    final node = _nodes[index];
    if (node != null && node.context != null) {
      _pendingFocus = null;
      node.requestFocus();
    } else {
      _pendingFocus = index;
      _holder.requestFocus();
    }
  }

  bool _rowOnScreen(int row) {
    final position = _scroll.position;
    final top = _inset + row * _stride;
    return top + _stride > position.pixels &&
        top < position.pixels + position.viewportDimension;
  }

  /// The card in [_focused]'s column in the first row wholly on screen.
  int _firstOnScreen() {
    final pixels = _scroll.position.pixels;
    final row = math.max(0, ((pixels - _inset) / _stride).ceil());
    return math.min(row * _columns + _focused % _columns, widget.total - 1);
  }

  /// The mouse scrolled the focused card away. After the frame, once the
  /// card's own node has let go: a card on screen takes the focus, or,
  /// while the view still moves, the grid holds it until the scroll ends.
  void _onFocusedCardGone() {
    if (_moving) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || _moving || !_scroll.hasClients) return;
      if (_scroll.position.isScrollingNotifier.value) {
        _holder.requestFocus();
      } else {
        _focusOnScreen();
      }
    });
  }

  void _focusOnScreen() {
    if (!_scroll.hasClients || widget.total == 0) return;
    _focusCard(_firstOnScreen());
  }

  /// With the holder focused, an arrow or Enter lands on a card on screen
  /// first; PageUp, PageDown, Home and End go on to the grid's shortcuts,
  /// which count from the view.
  KeyEventResult _holderKey(FocusNode node, KeyEvent event) {
    if (!_holder.hasPrimaryFocus || event is KeyUpEvent) {
      return KeyEventResult.ignored;
    }
    final key = event.logicalKey;
    if (key == LogicalKeyboardKey.arrowUp ||
        key == LogicalKeyboardKey.arrowDown ||
        key == LogicalKeyboardKey.arrowLeft ||
        key == LogicalKeyboardKey.arrowRight ||
        key == LogicalKeyboardKey.enter ||
        key == LogicalKeyboardKey.space) {
      _focusOnScreen();
      return KeyEventResult.handled;
    }
    return KeyEventResult.ignored;
  }

  /// Keeps [_nodes] to the cards built now: a card that moves to another
  /// index, or goes, takes its old entry with it.
  void _register(int index, FocusNode node, {required bool add}) {
    if (add) {
      _nodes[index] = node;
      if (index == _pendingFocus) {
        _pendingFocus = null;
        // Once its own `Focus` is built.
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted && _holder.hasPrimaryFocus && node.context != null) {
            node.requestFocus();
          }
        });
      }
    } else if (identical(_nodes[index], node)) {
      _nodes.remove(index);
    }
  }

  int get _rowsOnScreen => _scroll.hasClients
      ? math.max(1, (_scroll.position.viewportDimension / _stride).floor())
      : 1;

  @override
  Widget build(BuildContext context) {
    final tokens = context.tokens;
    final error = _error;
    if (error != null) {
      return ErrorState(
        compact: true,
        title: "Couldn't load these",
        message: 'The list could not be read.',
        details: '$error',
        onRetry: () => setState(() {
          _error = null;
          _pages.clear();
          _loading.clear();
        }),
      );
    }
    return CallbackShortcuts(
      bindings: {
        const SingleActivator(LogicalKeyboardKey.pageDown): () =>
            _move(delta: _columns * _rowsOnScreen),
        const SingleActivator(LogicalKeyboardKey.pageUp): () =>
            _move(delta: -_columns * _rowsOnScreen),
        const SingleActivator(LogicalKeyboardKey.home): () => _move(to: 0),
        const SingleActivator(LogicalKeyboardKey.end): () =>
            _move(to: widget.total - 1),
        const SingleActivator(LogicalKeyboardKey.keyF): () {
          final item = _itemAt(_focused);
          if (item != null) widget.onFavorite?.call(item);
        },
      },
      child: FocusPane(
        debugLabel: 'title grid',
        controller: widget.controller,
        tabStop: true,
        child: LayoutBuilder(
          builder: (context, constraints) {
            // Room for a focused card's growth and ring at the edges.
            final inset = tokens.spacing.s8;
            final width = constraints.maxWidth - inset * 2;
            _columns = math.max(
              1,
              ((width + TitleGrid.columnGap) /
                      (TitleGrid.minCardWidth + TitleGrid.columnGap))
                  .floor(),
            );
            final cardWidth =
                (width - TitleGrid.columnGap * (_columns - 1)) / _columns;
            final extent = cardWidth * 3 / 2 + TitleGrid.captionHeight;
            _stride = extent + TitleGrid.rowGap;
            _inset = inset;
            final grid = GridView.builder(
              controller: _scroll,
              padding: EdgeInsets.all(inset),
              // A row beyond the screen is built, so ↓ always has a card
              // to go to.
              scrollCacheExtent: ScrollCacheExtent.pixels(_stride * 1.5),
              gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: _columns,
                crossAxisSpacing: TitleGrid.columnGap,
                mainAxisSpacing: TitleGrid.rowGap,
                mainAxisExtent: extent,
              ),
              itemCount: widget.total,
              itemBuilder: (context, index) {
                final item = _itemAt(index);
                if (item == null) {
                  return Align(
                    alignment: Alignment.topLeft,
                    child: SkeletonPoster(width: cardWidth),
                  );
                }
                return _Card(
                  key: ValueKey(widget.identity(item)),
                  index: index,
                  onFocus: (index) => _focused = index,
                  onFocusedGone: _onFocusedCardGone,
                  register: _register,
                  builder: (context, focus) =>
                      widget.card(context, item, focus, cardWidth),
                );
              },
            );
            return NotificationListener<ScrollEndNotification>(
              onNotification: (_) {
                if (_holder.hasPrimaryFocus && !_moving) _focusOnScreen();
                return false;
              },
              child: Focus(
                focusNode: _holder,
                onKeyEvent: _holderKey,
                child: grid,
              ),
            );
          },
        ),
      ),
    );
  }
}

/// One card and the focus node the grid finds it by.
class _Card extends StatefulWidget {
  const new({
    required this.index,
    required this.onFocus,
    required this.onFocusedGone,
    required this.register,
    required this.builder,
    super.key,
  });

  final int index;
  final void Function(int index) onFocus;

  /// This card goes while it has the focus: scrolled out of what is built.
  final VoidCallback onFocusedGone;
  final void Function(int index, FocusNode node, {required bool add}) register;
  final Widget Function(BuildContext context, FocusNode focus) builder;

  @override
  State<_Card> createState() => _CardState();
}

class _CardState extends State<_Card> {
  final _focus = FocusNode(debugLabel: 'title card');

  @override
  void initState() {
    super.initState();
    widget.register(widget.index, _focus, add: true);
    _focus.addListener(_onFocus);
  }

  @override
  void didUpdateWidget(_Card oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.index != widget.index) {
      oldWidget.register(oldWidget.index, _focus, add: false);
      widget.register(widget.index, _focus, add: true);
    }
  }

  @override
  void deactivate() {
    // Before the card's `Focus` goes: it lets go of the focus then.
    if (_focus.hasFocus) widget.onFocusedGone();
    super.deactivate();
  }

  @override
  void dispose() {
    widget.register(widget.index, _focus, add: false);
    _focus
      ..removeListener(_onFocus)
      ..dispose();
    super.dispose();
  }

  void _onFocus() {
    if (_focus.hasFocus) widget.onFocus(widget.index);
  }

  @override
  Widget build(BuildContext context) => widget.builder(context, _focus);
}
