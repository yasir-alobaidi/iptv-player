import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:iptv_player/core/core_providers.dart';
import 'package:iptv_player/core/images/artwork_scope.dart';
import 'package:iptv_player/core/result.dart';
import 'package:iptv_player/core/text/format.dart';
import 'package:iptv_player/design/components.dart';
import 'package:iptv_player/design/tokens.dart';
import 'package:iptv_player/features/guide/data/guide_providers.dart';
import 'package:iptv_player/features/guide/domain/epg.dart';
import 'package:iptv_player/features/guide/domain/guide_timeline.dart';
import 'package:iptv_player/features/guide/domain/guide_window_cache.dart';
import 'package:iptv_player/features/guide/presentation/guide_match_picker.dart';
import 'package:iptv_player/features/guide/presentation/guide_programme_sheet.dart';
import 'package:iptv_player/features/guide/presentation/guide_text.dart';
import 'package:iptv_player/features/live_tv/data/live_tv_providers.dart';
import 'package:iptv_player/features/live_tv/domain/channels.dart';

/// What the Guide's toolbar asks of the grid, and the day the grid shows
/// (the selected day pill).
class GuideGridController extends ChangeNotifier {
  _GuideGridState? _grid;
  DateTime? _day;

  /// The local day at the view's left edge.
  DateTime? get day => _day;

  /// Home, and the toolbar's Jump to now.
  void jumpToNow() => _grid?._jumpToNow();

  /// A day pill: [day] at the hours the view shows today.
  void showDay(DateTime day) => _grid?._showDay(day);

  /// A programme search opened (Phase 6 decision 4): the cursor on it —
  /// its channel's row, its start or now — and its detail sheet open.
  /// Waits for the grid, and its rows, when they aren't there yet.
  void showProgramme(ChannelItem channel, EpgProgramme programme) {
    _pending = (channel: channel, programme: programme);
    _grid?._showPending();
  }

  ({ChannelItem channel, EpgProgramme programme})? _pending;

  void _setDay(DateTime day) {
    if (day == _day) return;
    _day = day;
    notifyListeners();
  }
}

/// The Guide grid (canvas `Guide`, docs/05 §5): a 44 px time ruler, then
/// one 72 px row per channel — the pinned 220 px channel column and the
/// channel's programmes, 240 px to the hour — and the red now line.
///
/// Scrolling (ADR-011 decision 6): the rows are one vertical list, and
/// every row and the ruler draw the same horizontal offset, so moving
/// through time redraws the cells on screen and lays nothing else out.
/// The channel column lives in each row, which keeps it pinned without a
/// second list to keep in step. Data (decision 7): the channels come in
/// pages from the same `ChannelRepository` Live TV uses; their programmes
/// from a [GuideWindowCache] asked for the rows on screen and a screen
/// either side, the hours on screen and one either side.
///
/// Keyboard: one Tab stop. ←/→ move between programmes on a channel,
/// moving the time window when it leaves the screen; ↑/↓ between
/// channels at the same time; PageUp/PageDown by a screen; Home to now;
/// Enter or Space opens the programme's detail sheet, or the Match…
/// picker on a channel with no guide. A click does the same as Enter.
class GuideGrid extends ConsumerStatefulWidget {
  const new({
    required this.query,
    required this.timeline,
    required this.controller,
    required this.onWatch,
    this.onError,
    this.importing = false,
    this.importFraction,
    super.key,
  });

  final ChannelQuery query;
  final GuideTimeline timeline;
  final GuideGridController controller;

  /// Watch channel in a programme's sheet.
  final void Function(ChannelItem channel) onWatch;

  /// Something the grid did for the user failed (a match that couldn't be
  /// saved): what to tell them.
  final ValueChanged<String>? onError;

  /// An import is running: a thin line along the card's top edge, the
  /// guide in use still drawn.
  final bool importing;
  final double? importFraction;

  static const pageSize = 100;

  /// How many rows scrolled into view build their cells in one frame; the
  /// rest show a placeholder until the next. A page of new rows (PageDown)
  /// then fills in over a few frames instead of taking one long one.
  static const rowsPerFrame = 4;

  /// A gap in a channel's guide shorter than this is left empty; a longer
  /// one is a cell of its own ("No information"), so the keyboard can
  /// stand on it.
  static const minGap = Duration(minutes: 5);

  @override
  ConsumerState<GuideGrid> createState() => _GuideGridState();
}

class _GuideGridState extends ConsumerState<GuideGrid>
    with SingleTickerProviderStateMixin {
  final _focus = FocusNode(debugLabel: 'guide grid');
  final _vertical = ScrollController();

  /// Pixels from the timeline's origin to the view's left edge; always
  /// inside the timeline.
  final _x = ValueNotifier<double>(0);
  late final AnimationController _xMotion = AnimationController.unbounded(
    vsync: this,
  )..addListener(() => _x.value = _xMotion.value);
  late GuideWindowCache _cache;
  bool _failed = false;

  /// New rows' cells, a few a frame.
  final _budget = _BuildBudget(GuideGrid.rowsPerFrame);

  final _pages = <int, List<ChannelItem>>{};
  final _loading = <int>{};
  AppFailure? _pageError;
  ChannelQuery? _query;
  int? _total;

  /// The strip's size: the grid less the channel column, and the rows'
  /// viewport.
  double _viewWidth = 0;
  double _viewHeight = 0;
  bool _placed = false;

  /// The keyboard's place: a row, and the moment it stands on. ↑/↓ keep
  /// the moment, so they land on what is on at that time.
  var _row = 0;
  DateTime? _anchor;

  late DateTime _now;
  Timer? _tick;
  bool _requestScheduled = false;

  /// Whether the rows have shown once: see [_claimFocus].
  bool _shown = false;

  GuideTimeline get _timeline => widget.timeline;
  DateTime get _viewStart => _timeline.timeAt(_x.value);
  DateTime get _viewEnd => _timeline.timeAt(_x.value + _viewWidth);

  @override
  void initState() {
    super.initState();
    widget.controller._grid = this;
    _cache = GuideWindowCache(ref.read(epgRepositoryProvider))
      ..addListener(_onCache);
    _now = ref.read(appClockProvider)();
    _scheduleTick();
    _vertical.addListener(_scheduleRequest);
    _x.addListener(_onX);
    _focus.addListener(_onFocus);
  }

  @override
  void didUpdateWidget(GuideGrid oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.controller != widget.controller) {
      if (oldWidget.controller._grid == this) oldWidget.controller._grid = null;
      widget.controller._grid = this;
    }
    if (oldWidget.timeline != widget.timeline && _placed) {
      // A new guide moved the axis: keep the same moment at the left.
      final start = oldWidget.timeline.timeAt(_x.value);
      _xMotion.stop();
      _x.value = _timeline.clampX(_timeline.xOf(start), _viewWidth);
    }
  }

  @override
  void dispose() {
    if (widget.controller._grid == this) widget.controller._grid = null;
    _tick?.cancel();
    _cache
      ..removeListener(_onCache)
      ..dispose();
    _xMotion.dispose();
    _x.dispose();
    _vertical.dispose();
    _focus.dispose();
    super.dispose();
  }

  /// Redraws on the minute, so the now line moves and programmes turn
  /// past as they end.
  void _scheduleTick() {
    final clock = ref.read(appClockProvider);
    const minute = Duration.millisecondsPerMinute;
    final wait = minute - clock().millisecondsSinceEpoch % minute;
    _tick = Timer(Duration(milliseconds: wait), () {
      if (!mounted) return;
      setState(() => _now = clock());
      _scheduleTick();
    });
  }

  /// The rows redraw themselves from the cache; the grid only when a load
  /// failed or a retry cleared the failure.
  void _onCache() {
    final failed = _cache.failure != null;
    if (failed != _failed && mounted) setState(() => _failed = failed);
  }

  void _onX() => _scheduleRequest();

  void _onFocus() {
    if (_focus.hasFocus) _placeCursor();
    setState(() {});
  }

  void _onGuideChanged() {
    _cache.reset();
    _scheduleRequest();
  }

  void _resetQuery(ChannelQuery query) {
    _query = query;
    _pages.clear();
    _loading.clear();
    _pageError = null;
    _row = 0;
    if (_vertical.hasClients) _vertical.jumpTo(0);
  }

  /// The channels changed (a favorite, a rename, a sync): read the pages
  /// again in place, the rows on screen staying until their new ones come.
  void _refreshPages() {
    if (!mounted) return;
    _loading.clear();
    for (final page in _pages.keys.toList()) {
      unawaited(_loadPage(page));
    }
  }

  // Channels.

  ChannelItem? _channelAt(int index) {
    final page = index ~/ GuideGrid.pageSize;
    final rows = _pages[page];
    if (rows == null) {
      unawaited(_loadPage(page));
      return null;
    }
    final offset = index % GuideGrid.pageSize;
    return offset < rows.length ? rows[offset] : null;
  }

  Future<void> _loadPage(int page) async {
    final query = _query;
    if (query == null || !_loading.add(page)) return;
    final result = await ref
        .read(channelRepositoryProvider)
        .range(query, page * GuideGrid.pageSize, GuideGrid.pageSize);
    if (!mounted || query != _query) return;
    setState(() {
      _loading.remove(page);
      switch (result) {
        case Ok(:final value):
          _pages[page] = value;
        case Err(:final failure):
          _pageError = failure;
      }
    });
    _scheduleRequest();
  }

  // The data on screen.

  /// Asks the cache for what the screen shows and its margins, once a
  /// frame at most.
  void _scheduleRequest() {
    if (_requestScheduled) return;
    _requestScheduled = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _requestScheduled = false;
      if (mounted) _request();
    });
    WidgetsBinding.instance.ensureVisualUpdate();
  }

  void _request() {
    // After the frame: the pills are another widget.
    if (_placed) widget.controller._setDay(startOfDay(_viewStart));
    _showPending();
    final total = _total;
    if (total == null || total == 0 || _viewHeight <= 0) return;
    final rowHeight = context.tokens.guide.rowHeight;
    final offset = _vertical.hasClients ? _vertical.offset : 0.0;
    final screen = (_viewHeight / rowHeight).ceil();
    final first = math.max(0, (offset / rowHeight).floor() - screen);
    final last = math.min(total - 1, first + screen * 3 + 1);
    final ids = <int>[];
    for (var index = first; index <= last; index++) {
      final channel = _channelAt(index);
      if (channel != null) ids.add(channel.id);
    }
    // The stretch every row builds around the view, and an hour more.
    final margin = _Strip.margin + const Duration(hours: 1);
    _cache.request(ids, _viewStart.subtract(margin), _viewEnd.add(margin));
  }

  /// A channel's cells over `[from, to)`: programmes, the gaps between
  /// them, or the one "no guide" cell. Null until the cache has read it.
  List<GuideCell>? _cells(int channelId, DateTime from, DateTime to) =>
      guideCells(_cache.row(channelId, from, to), from, to);

  /// The cells around the view the keyboard can reach: the view and the
  /// hour either side when read, else the view alone.
  List<GuideCell>? _reachable(int channelId) {
    const margin = Duration(hours: 1);
    return _cells(
          channelId,
          _viewStart.subtract(margin),
          _viewEnd.add(margin),
        ) ??
        _cells(channelId, _viewStart, _viewEnd);
  }

  // Moving through time.

  void _setX(double x, {bool animate = true}) {
    final target = _timeline.clampX(x, _viewWidth);
    final motion = context.tokens.motion;
    if (!animate || motion.reduceMotion || !mounted) {
      _xMotion.stop();
      _x.value = target;
      return;
    }
    _xMotion
      ..value = _x.value
      ..animateTo(target, duration: motion.base, curve: motion.baseCurve);
  }

  /// The view start for [at] (the half hour before its own), clamped.
  double _xFor(DateTime at) => _timeline.clampX(
    _timeline.xOf(GuideTimeline.viewStartFor(at)),
    _viewWidth,
  );

  void _jumpToNow() {
    _now = ref.read(appClockProvider)();
    _anchor = _now;
    _setX(_xFor(_now));
    setState(() {});
  }

  /// [GuideGridController.showProgramme], once the grid is laid out and
  /// knows its rows.
  void _showPending() {
    final pending = widget.controller._pending;
    if (pending == null || !mounted || !_placed || (_total ?? 0) == 0) return;
    widget.controller._pending = null;
    unawaited(_showProgramme(pending.channel, pending.programme));
  }

  Future<void> _showProgramme(
    ChannelItem channel,
    EpgProgramme programme,
  ) async {
    final found = await ref
        .read(channelRepositoryProvider)
        .indexOf(widget.query, channel.id);
    if (!mounted) return;
    _now = ref.read(appClockProvider)();
    final at = programme.start.isAfter(_now) ? programme.start : _now;
    if (found.valueOrNull case final row?) {
      _row = row;
      _anchor = at;
      _setX(_xFor(at), animate: false);
      if (_vertical.hasClients) {
        final rowHeight = context.tokens.guide.rowHeight;
        final position = _vertical.position;
        // The row a little way down the screen, not at its edge.
        _vertical.jumpTo(
          (row * rowHeight - _viewHeight / 3).clamp(
            position.minScrollExtent,
            position.maxScrollExtent,
          ),
        );
      }
      setState(() {});
    }
    _focus.requestFocus();
    // The sheet once the grid has been laid out where it now is: a route
    // pushed in the frame that moved the grid leaves the semantics tree
    // half built (a debug assertion in the widget tests).
    await WidgetsBinding.instance.endOfFrame;
    if (!mounted) return;
    await showGuideProgrammeSheet(
      context,
      channel: channel,
      programme: programme,
      now: _now,
      onWatch: () => widget.onWatch(channel),
    );
  }

  void _showDay(DateTime day) {
    _now = ref.read(appClockProvider)();
    if (startOfDay(day) == startOfDay(_now)) {
      _jumpToNow();
      return;
    }
    final at = onDay(day, _now);
    _anchor = at;
    _setX(_xFor(at));
    setState(() {});
  }

  /// A jump to the Guide (G, Ctrl+3) places the focus as the screen
  /// opens, which can be before its rows are read: then nothing had the
  /// focus but the route's scope, and the grid takes it once its rows
  /// show. It never takes it from a control (the rail, the toolbar).
  void _claimFocus() {
    if (_shown) return;
    _shown = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || !TickerMode.valuesOf(context).enabled) return;
      final primary = FocusManager.instance.primaryFocus;
      if (primary == null || primary is FocusScopeNode) _focus.requestFocus();
    });
  }

  /// Puts the cursor where the user can see it: its row on screen, its
  /// moment in the view (now, when now is in it).
  void _placeCursor() {
    final total = _total ?? 0;
    if (total == 0) return;
    final rowHeight = context.tokens.guide.rowHeight;
    if (_vertical.hasClients && _viewHeight > 0) {
      final first = (_vertical.offset / rowHeight).ceil();
      final last = ((_vertical.offset + _viewHeight) / rowHeight).floor() - 1;
      if (_row < first || _row > last) {
        _row = first.clamp(0, total - 1);
      }
    }
    _row = _row.clamp(0, total - 1);
    final anchor = _anchor;
    final start = _viewStart;
    final end = _viewEnd;
    if (anchor == null || anchor.isBefore(start) || !anchor.isBefore(end)) {
      final inView = !_now.isBefore(start) && _now.isBefore(end);
      _anchor = inView ? _now : start;
    }
  }

  // The keyboard.

  KeyEventResult _onKey(FocusNode node, KeyEvent event) {
    if (event is KeyUpEvent) return KeyEventResult.ignored;
    final total = _total ?? 0;
    if (total == 0) return KeyEventResult.ignored;
    final key = event.logicalKey;
    final repeat = event is KeyRepeatEvent;
    _placeCursor();
    switch (key) {
      case LogicalKeyboardKey.arrowLeft:
        return _across(forward: false)
            ? KeyEventResult.handled
            : KeyEventResult.ignored;
      case LogicalKeyboardKey.arrowRight:
        _across(forward: true);
      case LogicalKeyboardKey.arrowUp:
        if (_row == 0) return KeyEventResult.ignored;
        _toRow(_row - 1);
      case LogicalKeyboardKey.arrowDown:
        _toRow(_row + 1);
      case LogicalKeyboardKey.pageUp:
        _page(-1);
      case LogicalKeyboardKey.pageDown:
        _page(1);
      case LogicalKeyboardKey.home when !repeat:
        _jumpToNow();
      case LogicalKeyboardKey.enter ||
              LogicalKeyboardKey.numpadEnter ||
              LogicalKeyboardKey.space
          when !repeat:
        _activate();
      case LogicalKeyboardKey.home ||
          LogicalKeyboardKey.enter ||
          LogicalKeyboardKey.numpadEnter ||
          LogicalKeyboardKey.space:
        break;
      default:
        return KeyEventResult.ignored;
    }
    return KeyEventResult.handled;
  }

  /// ←/→. False at the timeline's left edge, so ← goes on to the rail.
  bool _across({required bool forward}) {
    final channel = _channelAt(_row);
    final anchor = _anchor;
    if (channel == null || anchor == null) return true;
    final cells = _reachable(channel.id);
    final current = cells == null ? null : cellAt(cells, anchor);
    if (current == null || current.noGuide) return true;
    final start = _viewStart;
    final step = context.tokens.guide.rulerStep;
    if (forward) {
      if (!current.end.isBefore(_timeline.end)) return true;
      // The next cell starts where this one ends.
      final target = current.end;
      _anchor = target;
      if (!target.isBefore(_viewEnd.subtract(step))) {
        _setX(_timeline.xOf(floorToHalfHour(target).subtract(step)));
      }
    } else {
      if (!current.start.isAfter(_timeline.origin)) return false;
      final target = current.start.subtract(const Duration(milliseconds: 1));
      final before = cellAt(cells!, target);
      final known = before != null && before.contains(target);
      if (known && before.end.isAfter(start)) {
        // Partly in view already: no scroll.
        _anchor = before.start.isBefore(start) ? start : before.start;
      } else {
        // Back to its start, a screen at most, so a long programme
        // doesn't throw the view hours back.
        final span = _timeline.durationOf(_viewWidth);
        final limit = floorToHalfHour(start.subtract(span));
        var from = floorToHalfHour(known ? before.start : target);
        if (from.isBefore(limit)) from = limit;
        final x = _timeline.clampX(_timeline.xOf(from), _viewWidth);
        _setX(x);
        final shown = _timeline.timeAt(x);
        _anchor = known && before.start.isAfter(shown) ? before.start : shown;
        if (!known) _anchor = target;
      }
    }
    setState(() {});
    return true;
  }

  void _toRow(int row) {
    final total = _total ?? 0;
    if (total == 0) return;
    setState(() => _row = row.clamp(0, total - 1));
    _revealRow(_row);
  }

  void _page(int direction) {
    final total = _total ?? 0;
    if (total == 0 || !_vertical.hasClients) return;
    final rowHeight = context.tokens.guide.rowHeight;
    final rows = math.max(1, (_viewHeight / rowHeight).floor());
    final row = (_row + direction * rows).clamp(0, total - 1);
    final position = _vertical.position;
    _vertical.jumpTo(
      (_vertical.offset + direction * rows * rowHeight).clamp(
        position.minScrollExtent,
        position.maxScrollExtent,
      ),
    );
    setState(() => _row = row);
    _revealRow(row);
  }

  void _revealRow(int row) {
    if (!_vertical.hasClients) return;
    final rowHeight = context.tokens.guide.rowHeight;
    final top = row * rowHeight;
    final offset = _vertical.offset;
    if (top < offset) {
      _vertical.jumpTo(top);
    } else if (top + rowHeight > offset + _viewHeight) {
      final position = _vertical.position;
      _vertical.jumpTo(
        (top + rowHeight - _viewHeight).clamp(
          position.minScrollExtent,
          position.maxScrollExtent,
        ),
      );
    }
  }

  void _activate() {
    final channel = _channelAt(_row);
    final anchor = _anchor;
    if (channel == null || anchor == null) return;
    final cells = _cells(channel.id, _viewStart, _viewEnd);
    final cell = cells == null ? null : cellAt(cells, anchor);
    if (cell == null) return;
    _open(channel, cell);
  }

  void _open(ChannelItem channel, GuideCell cell) {
    if (cell.noGuide) {
      unawaited(_match(channel));
      return;
    }
    final programme = cell.programme;
    if (programme == null) return;
    unawaited(
      showGuideProgrammeSheet(
        context,
        channel: channel,
        programme: programme,
        now: ref.read(appClockProvider)(),
        onWatch: () => widget.onWatch(channel),
      ),
    );
  }

  /// A click on a cell: the cursor goes there, then as Enter.
  void _tap(int row, ChannelItem channel, GuideCell cell) {
    final start = _viewStart;
    setState(() {
      _row = row;
      _anchor = cell.start.isBefore(start) ? start : cell.start;
    });
    _focus.requestFocus();
    _open(channel, cell);
  }

  /// The Match… picker, over the grid; the row fills in once the source
  /// has been matched again (the guide's change resets the cache).
  Future<void> _match(ChannelItem channel) async {
    final guide = ref.read(epgRepositoryProvider);
    final matching = ref.read(guideMatchingProvider);
    final found = await guide.channelMatch(channel.id);
    final match = found.valueOrNull;
    if (match == null || !mounted) return;
    final choice = await showGuideMatchPicker(context, channel: match);
    if (choice == null) return;
    final error = await saveGuideMatch(guide, matching, match, choice);
    if (error != null && mounted) widget.onError?.call(error);
  }

  // Pointers: a horizontal wheel, Shift + the wheel, and a drag move
  // through time; the vertical wheel scrolls the list.

  void _onPointerSignal(PointerSignalEvent event) {
    if (event is! PointerScrollEvent) return;
    var delta = event.scrollDelta.dx;
    if (delta == 0 && HardwareKeyboard.instance.isShiftPressed) {
      delta = event.scrollDelta.dy;
    }
    if (delta == 0) return;
    GestureBinding.instance.pointerSignalResolver.register(event, (_) {
      _setX(_x.value + delta, animate: false);
    });
  }

  @override
  Widget build(BuildContext context) {
    final tokens = context.tokens;
    final colors = tokens.colors;
    final guide = tokens.guide;
    final query = widget.query;
    if (query != _query) _resetQuery(query);
    ref
      ..listen(channelRevisionProvider(query), (_, _) => _refreshPages())
      ..listen(guideChangesProvider, (_, _) => _onGuideChanged());
    final count = ref.watch(channelCountProvider(query));
    _total = count.value;

    return DecoratedBox(
      decoration: BoxDecoration(
        color: colors.surface1,
        borderRadius: tokens.radii.lgAll,
        border: Border.all(color: colors.borderSubtle),
      ),
      child: ClipRRect(
        borderRadius: tokens.radii.lgAll,
        child: LayoutBuilder(
          builder: (context, constraints) {
            _viewWidth = math.max(
              0,
              constraints.maxWidth - guide.channelColumnWidth,
            );
            _viewHeight = math.max(
              0,
              constraints.maxHeight - guide.rulerHeight,
            );
            if (!_placed && _viewWidth > 0) {
              // Nothing listens yet: the rows and the ruler are built
              // below.
              _x.value = _xFor(_now);
              _placed = true;
            }
            _scheduleRequest();
            return Stack(
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    _Ruler(
                      timeline: _timeline,
                      x: _x,
                      viewWidth: _viewWidth,
                      now: _now,
                    ),
                    Expanded(child: _body(context, count)),
                  ],
                ),
                if ((_total ?? 0) > 0 &&
                    _pageError == null &&
                    _cache.failure == null)
                  Positioned(
                    left: guide.channelColumnWidth,
                    top: guide.rulerHeight,
                    right: 0,
                    bottom: 0,
                    child: IgnorePointer(
                      child: _NowLine(
                        timeline: _timeline,
                        x: _x,
                        viewWidth: _viewWidth,
                        now: _now,
                      ),
                    ),
                  ),
                if (widget.importing)
                  Positioned(
                    left: 0,
                    top: 0,
                    right: 0,
                    child: ProgressBar(
                      value: widget.importFraction,
                      height: 2,
                      trackColor: colors.surface1,
                      semanticLabel: 'Updating the guide',
                    ),
                  ),
              ],
            );
          },
        ),
      ),
    );
  }

  Widget _body(BuildContext context, AsyncValue<int> count) {
    final guide = context.tokens.guide;
    final error = _pageError ?? _cache.failure;
    if (count.hasError || error != null) {
      return ErrorState(
        compact: true,
        title: "Couldn't load the guide",
        message: 'The channels or their programmes could not be read.',
        details: '${error ?? count.error}',
        onRetry: () {
          ref.invalidate(channelCountProvider(widget.query));
          _cache.retry();
          setState(() => _pageError = null);
          _refreshPages();
        },
      );
    }
    final total = count.value;
    if (total == null) return const GuideSkeletonRows();
    if (total == 0) {
      return EmptyState(
        compact: true,
        icon: AppIcons.guide,
        title: switch (widget.query.filter) {
          FavoriteChannels() => 'No favorites yet',
          _ => 'No channels in this category.',
        },
        message: switch (widget.query.filter) {
          FavoriteChannels() =>
            'Press F on a channel in Live TV to add it here.',
          _ => 'Choose another category above.',
        },
      );
    }
    _claimFocus();
    final hasFocus = _focus.hasFocus;
    return Focus(
      focusNode: _focus,
      onKeyEvent: _onKey,
      child: Listener(
        onPointerSignal: _onPointerSignal,
        child: GestureDetector(
          supportedDevices: const {
            PointerDeviceKind.touch,
            PointerDeviceKind.stylus,
            PointerDeviceKind.trackpad,
          },
          onHorizontalDragUpdate: (details) =>
              _setX(_x.value - details.delta.dx, animate: false),
          child: ListView.builder(
            controller: _vertical,
            itemExtent: guide.rowHeight,
            itemCount: total,
            itemBuilder: (context, index) {
              final channel = _channelAt(index);
              return _GuideRowView(
                channel: channel,
                timeline: _timeline,
                cache: _cache,
                budget: _budget,
                x: _x,
                viewWidth: _viewWidth,
                now: _now,
                cells: (from, to) =>
                    channel == null ? null : _cells(channel.id, from, to),
                cursor: hasFocus && index == _row ? _anchor : null,
                onTap: channel == null
                    ? null
                    : (cell) => _tap(index, channel, cell),
              );
            },
          ),
        ),
      ),
    );
  }
}

/// One cell of a channel's row: a programme, a gap in its guide, or the
/// whole row of a channel with no guide.
@immutable
final class GuideCell {
  const new({
    required this.start,
    required this.end,
    this.programme,
    this.noGuide = false,
  });

  final DateTime start;
  final DateTime end;

  /// Null for a gap and for the no-guide cell.
  final EpgProgramme? programme;
  final bool noGuide;

  bool contains(DateTime at) => !start.isAfter(at) && end.isAfter(at);
}

/// [row]'s cells over `[from, to)`: its programmes, a gap cell wherever
/// the guide has nothing for [GuideGrid.minGap] or more (at the edges
/// too), or one no-guide cell for a channel the guide doesn't cover.
/// Null while [row] is.
List<GuideCell>? guideCells(GuideRow? row, DateTime from, DateTime to) {
  if (row == null) return null;
  if (!row.hasGuide) return [GuideCell(start: from, end: to, noGuide: true)];
  final cells = <GuideCell>[];
  var cursor = from;
  for (final programme in row.programmes) {
    if (programme.start.difference(cursor) >= GuideGrid.minGap) {
      cells.add(GuideCell(start: cursor, end: programme.start));
    }
    cells.add(
      GuideCell(
        start: programme.start,
        end: programme.end,
        programme: programme,
      ),
    );
    if (programme.end.isAfter(cursor)) cursor = programme.end;
  }
  if (to.difference(cursor) >= GuideGrid.minGap) {
    cells.add(GuideCell(start: cursor, end: to));
  }
  return cells;
}

/// The cell at [at]; in a gap too short to be a cell, the one after it,
/// else the last.
GuideCell? cellAt(List<GuideCell> cells, DateTime at) {
  for (final cell in cells) {
    if (cell.contains(at)) return cell;
  }
  for (final cell in cells) {
    if (cell.start.isAfter(at)) return cell;
  }
  return cells.isEmpty ? null : cells.last;
}

/// Skeleton rows in the grid's shape, while the channels load.
class GuideSkeletonRows extends StatelessWidget {
  const new({super.key});

  @override
  Widget build(BuildContext context) {
    final guide = context.tokens.guide;
    return ClipRect(
      child: OverflowBox(
        alignment: Alignment.topCenter,
        maxHeight: double.infinity,
        child: Column(
          children: [
            for (var i = 0; i < 12; i++)
              SizedBox(height: guide.rowHeight, child: const _SkeletonRow()),
          ],
        ),
      ),
    );
  }
}

class _SkeletonRow extends StatelessWidget {
  const new();

  @override
  Widget build(BuildContext context) {
    final tokens = context.tokens;
    final guide = tokens.guide;
    return _RowFrame(
      channel: Row(
        children: [
          Skeleton(
            width: guide.logoSize,
            height: guide.logoSize,
            borderRadius: tokens.radii.smAll,
          ),
          SizedBox(width: guide.channelGap),
          const Expanded(child: Skeleton(height: 12)),
        ],
      ),
      strip: const _StripSkeleton(),
    );
  }
}

class _StripSkeleton extends StatelessWidget {
  const new();

  @override
  Widget build(BuildContext context) {
    final tokens = context.tokens;
    final guide = tokens.guide;
    return Padding(
      padding: EdgeInsets.symmetric(
        horizontal: guide.cellInsetX,
        vertical: guide.cellInsetY,
      ),
      child: Skeleton(
        height: double.infinity,
        borderRadius: tokens.radii.smAll,
      ),
    );
  }
}

/// A row's frame: the channel column with its right border, the strip,
/// and the divider under both.
class _RowFrame extends StatelessWidget {
  const new({required this.channel, required this.strip});

  final Widget channel;
  final Widget strip;

  @override
  Widget build(BuildContext context) {
    final tokens = context.tokens;
    final colors = tokens.colors;
    final guide = tokens.guide;
    return DecoratedBox(
      decoration: BoxDecoration(
        border: Border(bottom: BorderSide(color: colors.surface2)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Container(
            width: guide.channelColumnWidth,
            padding: EdgeInsets.symmetric(horizontal: guide.channelPadding),
            decoration: BoxDecoration(
              border: Border(right: BorderSide(color: colors.surface3)),
            ),
            alignment: Alignment.centerLeft,
            child: channel,
          ),
          Expanded(child: ClipRect(child: strip)),
        ],
      ),
    );
  }
}

/// A channel's row: its number, logo and name, and its cells.
class _GuideRowView extends StatelessWidget {
  const new({
    required this.channel,
    required this.cache,
    required this.budget,
    required this.timeline,
    required this.x,
    required this.viewWidth,
    required this.now,
    required this.cells,
    required this.cursor,
    required this.onTap,
  });

  final ChannelItem? channel;
  final GuideWindowCache cache;
  final _BuildBudget budget;
  final GuideTimeline timeline;
  final ValueListenable<double> x;
  final double viewWidth;
  final DateTime now;
  final List<GuideCell>? Function(DateTime from, DateTime to) cells;

  /// The keyboard's moment, when its cursor is on this row and the grid
  /// has the focus.
  final DateTime? cursor;
  final ValueChanged<GuideCell>? onTap;

  @override
  Widget build(BuildContext context) {
    final channel = this.channel;
    if (channel == null) return const _SkeletonRow();
    return _RowFrame(
      channel: _ChannelCell(channel: channel),
      strip: _Strip(
        channelId: channel.id,
        cache: cache,
        budget: budget,
        timeline: timeline,
        x: x,
        viewWidth: viewWidth,
        now: now,
        cells: cells,
        cursor: cursor,
        onTap: onTap,
      ),
    );
  }
}

/// A row's cells. They are built once for a stretch of about two hours
/// either side of the view and slid along with a transform as the view
/// moves, so scrolling through time rebuilds nothing but the programme
/// the view's left edge cuts (drawn again on top, from the edge, with its
/// ‹) and the focus ring; the stretch is built again when the view nears
/// its end. The row redraws for the cache only when a load for its own
/// channel lands. One mouse region and one tap handler for the whole
/// strip, not one per cell.
class _Strip extends StatefulWidget {
  const new({
    required this.channelId,
    required this.cache,
    required this.budget,
    required this.timeline,
    required this.x,
    required this.viewWidth,
    required this.now,
    required this.cells,
    required this.cursor,
    required this.onTap,
  });

  final int channelId;
  final GuideWindowCache cache;
  final _BuildBudget budget;
  final GuideTimeline timeline;
  final ValueListenable<double> x;
  final double viewWidth;
  final DateTime now;
  final List<GuideCell>? Function(DateTime from, DateTime to) cells;
  final DateTime? cursor;
  final ValueChanged<GuideCell>? onTap;

  /// The stretch built either side of the view, and how near its end the
  /// view may come before it is built again: narrow for a row just
  /// scrolled in (a page of new rows builds as little as it can), wide
  /// once the view moves through time. The wide one is built again every
  /// half hour the view moves, so each time adds a cell or so to lay out,
  /// never a screen's worth in one frame.
  static const freshMargin = Duration(minutes: 45);
  static const freshSlack = Duration(minutes: 15);
  static const margin = Duration(hours: 2);
  static const slack = Duration(minutes: 90);

  @override
  State<_Strip> createState() => _StripState();
}

class _StripState extends State<_Strip> {
  /// The stretch the cells are built for; null to work it out again.
  DateTime? _from;
  DateTime? _to;

  /// The stretch had not been read yet, so the view alone was drawn.
  var _partial = false;
  var _revision = 0;

  /// The start of the cell under the mouse.
  DateTime? _hovered;

  /// Whether the view has moved through time since this row was built:
  /// then its stretch is the wide one.
  var _wide = false;

  /// Each cell's widget as last built, reused while nothing it shows
  /// changed, so a new stretch builds only the cells new to it.
  var _made = <Object, _MadeCell>{};

  /// Whether this row has had its turn to build its cells.
  var _ready = false;

  void _retry() {
    if (mounted) setState(() {});
  }

  Duration get _margin => _wide ? _Strip.margin : _Strip.freshMargin;
  Duration get _slack => _wide ? _Strip.slack : _Strip.freshSlack;

  GuideTimeline get _timeline => widget.timeline;
  DateTime get _viewFrom => _timeline.timeAt(widget.x.value);
  DateTime get _viewTo => _timeline.timeAt(widget.x.value + widget.viewWidth);

  @override
  void initState() {
    super.initState();
    widget.x.addListener(_onX);
    widget.cache.addListener(_onCache);
    _revision = widget.cache.revisionOf(widget.channelId);
  }

  @override
  void didUpdateWidget(_Strip old) {
    super.didUpdateWidget(old);
    if (old.x != widget.x) {
      old.x.removeListener(_onX);
      widget.x.addListener(_onX);
    }
    if (old.cache != widget.cache) {
      old.cache.removeListener(_onCache);
      widget.cache.addListener(_onCache);
    }
    if (old.timeline != widget.timeline ||
        old.viewWidth != widget.viewWidth ||
        old.channelId != widget.channelId) {
      _from = null;
    }
    _revision = widget.cache.revisionOf(widget.channelId);
  }

  @override
  void dispose() {
    widget.x.removeListener(_onX);
    widget.cache.removeListener(_onCache);
    super.dispose();
  }

  /// Whether the stretch built still holds the view with room to spare.
  bool _holds(DateTime from, DateTime to) {
    final start = _from;
    final end = _to;
    if (start == null || end == null || _partial) return false;
    if (from.isBefore(start) || to.isAfter(end)) return false;
    final roomBefore =
        !start.isAfter(_timeline.origin) || from.difference(start) >= _slack;
    final roomAfter =
        !end.isBefore(_timeline.end) || end.difference(to) >= _slack;
    return roomBefore && roomAfter;
  }

  void _onX() {
    // Also called back after a frame, by the budget.
    if (!mounted) return;
    final from = _viewFrom;
    final to = _viewTo;
    if (_holds(from, to)) return;
    // Every row nears its stretch's end in the same frame (they share the
    // view): while the view is still inside it, the rows take turns.
    if (_inside(from, to) && !widget.budget.take(_onX)) return;
    setState(() {
      _from = null;
      _wide = true;
    });
  }

  /// Whether the stretch built still holds the view at all.
  bool _inside(DateTime from, DateTime to) {
    final start = _from;
    final end = _to;
    return start != null &&
        end != null &&
        !_partial &&
        !from.isBefore(start) &&
        !to.isAfter(end);
  }

  /// The cell the view's left edge at [edge] cuts, if one does: a
  /// programme, or a gap, whose words would otherwise be off screen.
  static GuideCell? _cutAt(List<GuideCell> cells, DateTime edge) {
    for (final cell in cells) {
      if (!cell.noGuide &&
          cell.start.isBefore(edge) &&
          cell.end.isAfter(edge)) {
        return cell;
      }
    }
    return null;
  }

  void _onCache() {
    final revision = widget.cache.revisionOf(widget.channelId);
    if (revision == _revision) return;
    setState(() {
      _revision = revision;
      _from = null;
    });
  }

  /// The cell under [dx] pixels from the strip's left edge.
  GuideCell? _cellAt(double dx) {
    final at = _timeline.timeAt(widget.x.value + dx);
    final found = widget.cells(_viewFrom, _viewTo);
    if (found == null) return null;
    for (final cell in found) {
      if (cell.contains(at)) return cell;
    }
    return null;
  }

  void _hover(DateTime? start) {
    if (start != _hovered) setState(() => _hovered = start);
  }

  @override
  Widget build(BuildContext context) {
    final onTap = widget.onTap;
    return MouseRegion(
      cursor: onTap == null ? MouseCursor.defer : SystemMouseCursors.click,
      onHover: (event) => _hover(_cellAt(event.localPosition.dx)?.start),
      onExit: (_) => _hover(null),
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTapUp: onTap == null
            ? null
            : (details) {
                final cell = _cellAt(details.localPosition.dx);
                if (cell != null) onTap(cell);
              },
        child: _cells(context),
      ),
    );
  }

  Widget _cells(BuildContext context) {
    final tokens = context.tokens;
    final guide = tokens.guide;
    final viewFrom = _viewFrom;
    final viewTo = _viewTo;
    if (!_holds(viewFrom, viewTo)) {
      final hour = floorToHalfHour(viewFrom);
      var from = hour.subtract(_margin);
      var to = viewTo.add(_margin);
      if (from.isBefore(_timeline.origin)) from = _timeline.origin;
      if (to.isAfter(_timeline.end)) to = _timeline.end;
      _from = from;
      _to = to;
      _partial = false;
    }
    var from = _from!;
    var to = _to!;
    var found = widget.cells(from, to);
    if (found == null) {
      // The stretch around the view isn't read yet: the view alone.
      found = widget.cells(viewFrom, viewTo);
      from = viewFrom;
      to = viewTo;
      _from = from;
      _to = to;
      _partial = true;
    }
    if (found == null) return const _StripSkeleton();
    if (!_ready) {
      if (!widget.budget.take(_retry)) return const _StripPlaceholder();
      _ready = true;
    }
    final cells = found;
    // From the stretch, not the view: the view may be sliding towards
    // the cursor (Home), and this is built once for the whole slide.
    final cursor = widget.cursor;
    final focused =
        cursor == null || cursor.isBefore(from) || !cursor.isBefore(to)
        ? null
        : cellAt(cells, cursor);
    final onTap = widget.onTap;
    if (cells.length == 1 && cells.single.noGuide) {
      return Padding(
        padding: EdgeInsets.symmetric(
          horizontal: guide.cellInsetX,
          vertical: guide.cellInsetY,
        ),
        child: _NoGuideCell(
          focused: focused != null,
          onTap: onTap == null ? null : () => onTap(cells.single),
        ),
      );
    }

    // Every cell at its own place in the stretch.
    final base = _timeline.xOf(from);
    final stretch = _timeline.xOf(to) - base;
    final made = <Object, _MadeCell>{};
    final placed = Stack(
      clipBehavior: Clip.none,
      children: [
        for (final cell in cells)
          if (_timeline.xOf(cell.end) - _timeline.xOf(cell.start) >
              guide.cellInsetX * 2)
            Positioned(
              key: ValueKey(_keyOf(cell)),
              left: _timeline.xOf(cell.start) - base + guide.cellInsetX,
              top: guide.cellInsetY,
              bottom: guide.cellInsetY,
              width:
                  _timeline.xOf(cell.end) -
                  _timeline.xOf(cell.start) -
                  guide.cellInsetX * 2,
              child: _cellWidget(
                made,
                cell,
                _timeline.xOf(cell.end) -
                    _timeline.xOf(cell.start) -
                    guide.cellInsetX * 2,
                focused: cell.start == focused?.start,
              ),
            ),
      ],
    );
    _made = made;
    return Stack(
      children: [
        Positioned.fill(
          // Nothing left of where the cut programme ends: the edge layer
          // draws that one, from the edge. Moved on every frame, never
          // rebuilt for it.
          child: ClipRect(
            clipper: _PastTheCut(
              x: widget.x,
              timeline: _timeline,
              cells: cells,
            ),
            child: ValueListenableBuilder<double>(
              valueListenable: widget.x,
              builder: (context, offset, child) => Transform.translate(
                offset: Offset(base - offset, 0),
                child: child,
              ),
              // A layer of its own: sliding it moves the layer, and the
              // cells are painted again only when the stretch is rebuilt.
              child: RepaintBoundary(
                child: OverflowBox(
                  alignment: Alignment.topLeft,
                  minWidth: stretch,
                  maxWidth: stretch,
                  child: placed,
                ),
              ),
            ),
          ),
        ),
        Positioned.fill(
          child: ValueListenableBuilder<double>(
            valueListenable: widget.x,
            builder: (context, offset, _) =>
                _edge(context, offset, cells, focused),
          ),
        ),
      ],
    );
  }

  static Object _keyOf(GuideCell cell) =>
      cell.programme?.id ?? 'gap ${cell.start.millisecondsSinceEpoch}';

  /// [cell]'s widget: the one built last time when what it shows is the
  /// same, else a new one. Recorded in [made].
  Widget _cellWidget(
    Map<Object, _MadeCell> made,
    GuideCell cell,
    double width, {
    required bool focused,
  }) {
    final key = _keyOf(cell);
    final shows = _MadeCell(
      end: cell.end,
      width: width,
      phase: _phase(cell.programme, widget.now),
      focused: focused,
      hovered: cell.start == _hovered,
    );
    final last = _made[key];
    final onTap = widget.onTap;
    final built = last != null && last.same(shows)
        ? last.widget!
        : _CellView(
            cell: cell,
            width: width,
            clipped: false,
            now: widget.now,
            focused: focused,
            ring: false,
            hovered: shows.hovered,
            onTap: onTap == null ? null : () => onTap(cell),
          );
    made[key] = shows..widget = built;
    return built;
  }

  /// Ended (0), on now (1), to come (2), or a gap (3): what the minute
  /// changes about a cell.
  static int _phase(EpgProgramme? programme, DateTime now) {
    if (programme == null) return 3;
    if (!programme.end.isAfter(now)) return 0;
    if (!programme.start.isAfter(now)) return 1;
    return 2;
  }

  /// Drawn over the sliding cells, on every frame the view moves: the
  /// programme the view's left edge cuts, again from the edge with its ‹,
  /// and the focus ring around the focused cell's visible part.
  Widget _edge(
    BuildContext context,
    double offset,
    List<GuideCell> cells,
    GuideCell? focused,
  ) {
    final tokens = context.tokens;
    final guide = tokens.guide;
    final colors = tokens.colors;
    final cut = _cutAt(cells, _timeline.timeAt(offset));
    final children = <Widget>[];
    if (cut != null) {
      final width = _timeline.xOf(cut.end) - offset - guide.cellInsetX * 2;
      if (width > 0) {
        final isFocused = cut.start == focused?.start;
        children.add(
          Positioned(
            left: guide.cellInsetX,
            top: guide.cellInsetY,
            bottom: guide.cellInsetY,
            width: width,
            // The sliding copy, clipped to what shows, speaks for it.
            child: ExcludeSemantics(
              child: _CellView(
                cell: cut,
                width: width,
                layoutWidth:
                    _timeline.xOf(cut.end) -
                    _timeline.xOf(cut.start) -
                    guide.cellInsetX * 2,
                clipped: true,
                now: widget.now,
                focused: isFocused,
                ring: isFocused,
                hovered: cut.start == _hovered,
                onTap: null,
              ),
            ),
          ),
        );
      }
    }
    if (focused != null && focused.start != cut?.start) {
      final left = math.max(_timeline.xOf(focused.start), offset);
      final width = _timeline.xOf(focused.end) - left - guide.cellInsetX * 2;
      if (width > 0) {
        children.add(
          Positioned(
            left: left - offset + guide.cellInsetX,
            top: guide.cellInsetY,
            bottom: guide.cellInsetY,
            width: width,
            child: IgnorePointer(
              child: FocusRing(
                visible: true,
                borderRadius: tokens.radii.smAll,
                ringColor: colors.accentBase,
                glowColor: colors.accentBase.withValues(
                  alpha: tokens.focus.glowOpacity,
                ),
                ringWidth: tokens.focus.ringWidth,
                glowWidth: tokens.focus.glowWidth,
                duration: Duration.zero,
                curve: tokens.motion.fastCurve,
                child: const SizedBox.expand(),
              ),
            ),
          ),
        );
      }
    }
    return Stack(clipBehavior: Clip.none, children: children);
  }
}

class _ChannelCell extends StatelessWidget {
  const new({required this.channel});

  final ChannelItem channel;

  @override
  Widget build(BuildContext context) {
    final tokens = context.tokens;
    final colors = tokens.colors;
    final guide = tokens.guide;
    final number = channel.number;
    return Row(
      children: [
        SizedBox(
          width: guide.channelNumberWidth,
          child: Text(
            number == null ? '' : '$number',
            maxLines: 1,
            overflow: TextOverflow.clip,
            style: tokens.text.small.copyWith(color: colors.textTertiary),
          ),
        ),
        SizedBox(width: guide.channelGap),
        ChannelLogo(
          name: channel.name,
          image: artworkFor(context, channel.logoUrl, width: guide.logoSize),
          size: guide.logoSize,
          borderRadius: tokens.radii.smAll,
        ),
        SizedBox(width: guide.channelGap),
        Expanded(
          child: Text(
            channel.name,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: tokens.text.label.copyWith(color: colors.textPrimary),
          ),
        ),
      ],
    );
  }
}

/// A programme (now, later or past, as the canvas colours them) or a gap
/// in the guide. Only the focused one carries a focus ring: a ring is an
/// animation, and a screen holds a hundred cells.
class _CellView extends StatelessWidget {
  const new({
    required this.cell,
    required this.width,
    required this.clipped,
    required this.now,
    required this.focused,
    required this.ring,
    required this.hovered,
    required this.onTap,
    this.layoutWidth,
  });

  final GuideCell cell;
  final double width;

  /// For the cell the view's edge cuts, which shrinks on every frame the
  /// view moves: its words are laid out once at this width (the whole
  /// programme's) and clipped, instead of again on every frame.
  final double? layoutWidth;

  /// The programme started before the view: its title gets a ‹.
  final bool clipped;
  final DateTime now;

  /// Under the keyboard's cursor: its title bolder.
  final bool focused;

  /// Draws the focus ring too (the strip draws it apart otherwise).
  final bool ring;
  final bool hovered;

  /// For assistive technology; the strip handles the pointer.
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final tokens = context.tokens;
    final colors = tokens.colors;
    final guide = tokens.guide;
    final programme = cell.programme;
    final ended = programme != null && !programme.end.isAfter(now);
    final onNow = programme != null && !ended && !programme.start.isAfter(now);

    final Color background;
    final Color title;
    final Color time;
    if (programme == null) {
      background = hovered ? colors.surface2 : Colors.transparent;
      title = colors.textTertiary;
      time = colors.textTertiary;
    } else if (ended) {
      background = hovered ? colors.surface2 : colors.surfaceSunken;
      title = colors.textTertiary;
      time = colors.textTertiary;
    } else if (onNow) {
      background = hovered ? colors.border : colors.surface3;
      title = colors.textPrimary;
      time = colors.textSecondary;
    } else {
      background = hovered ? colors.surface3 : colors.surface2;
      title = colors.textPrimary;
      time = colors.textTertiary;
    }

    final labels = programme == null ? null : _Labels.of(programme);
    final laidOut = math.max(width, layoutWidth ?? 0);
    Widget content = const SizedBox.expand();
    if (width >= guide.cellTextWidth) {
      final label = programme == null
          ? 'No information'
          : clipped
          ? labels!.clippedTitle
          : programme.title;
      final titleStyle =
          (focused ? tokens.text.label.withWeight(700) : tokens.text.label)
              .copyWith(color: title);
      Widget lines = Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(
            label,
            maxLines: 1,
            softWrap: false,
            overflow: TextOverflow.ellipsis,
            style: programme == null
                ? tokens.text.caption.copyWith(color: title)
                : titleStyle,
          ),
          if (labels != null) ...[
            SizedBox(height: guide.cellLineGap),
            // The form by the width that shows: it changes at two widths
            // only, so the text is laid out again twice at most.
            Text(
              width >= guide.cellFullTimeWidth
                  ? labels.full
                  : width >= guide.cellRangeWidth
                  ? labels.range
                  : labels.start,
              maxLines: 1,
              softWrap: false,
              overflow: TextOverflow.clip,
              style: tokens.text.small.copyWith(color: time),
            ),
          ],
        ],
      );
      if (laidOut > width) {
        final inner = laidOut - guide.cellPadding.horizontal;
        lines = ClipRect(
          child: OverflowBox(
            alignment: Alignment.centerLeft,
            minWidth: inner,
            maxWidth: inner,
            child: lines,
          ),
        );
      }
      content = Padding(padding: guide.cellPadding, child: lines);
    }

    final radius = tokens.radii.smAll;
    Widget box = DecoratedBox(
      decoration: BoxDecoration(color: background, borderRadius: radius),
      child: content,
    );
    if (programme == null) {
      box = CustomPaint(
        painter: _DashedOutline(
          color: colors.border,
          radius: tokens.radii.sm,
          dash: guide.dashLength,
          gap: guide.dashGap,
        ),
        child: box,
      );
    }
    if (ring) {
      box = FocusRing(
        visible: true,
        borderRadius: radius,
        ringColor: colors.accentBase,
        glowColor: colors.accentBase.withValues(
          alpha: tokens.focus.glowOpacity,
        ),
        ringWidth: tokens.focus.ringWidth,
        glowWidth: tokens.focus.glowWidth,
        duration: Duration.zero,
        curve: tokens.motion.fastCurve,
        child: box,
      );
    }

    return Semantics(
      button: programme != null,
      selected: focused,
      label: programme == null ? 'No information' : labels!.spoken(now),
      onTap: onTap,
      excludeSemantics: true,
      child: box,
    );
  }
}

/// A programme's words, worked out once rather than on every frame the
/// grid moves: the cache hands out the same programme objects.
final class _Labels {
  new _(EpgProgramme programme)
    : clippedTitle = '‹ ${programme.title}',
      full = guideCellTime(programme, full: true, range: true),
      range = guideCellTime(programme, full: false, range: true),
      start = guideCellTime(programme, full: false, range: false),
      _programme = programme;

  factory of(EpgProgramme programme) =>
      _cache[programme] ??= _Labels._(programme);

  static final _cache = Expando<_Labels>('guide cell labels');

  final EpgProgramme _programme;
  final String clippedTitle;
  final String full;
  final String range;
  final String start;

  /// "Title, 8:00 – 10:00 PM, on now", for screen readers.
  String spoken(DateTime now) => [
    _programme.title,
    full,
    ?guideProgrammeState(_programme, now),
  ].join(', ');
}

/// Hands out the building of new rows' cells, a few a frame: the rest
/// wait for the next frame.
final class _BuildBudget {
  new(this.perFrame);

  final int perFrame;
  var _used = 0;
  var _resetting = false;
  final _waiting = <VoidCallback>[];

  /// True when [retry]'s row may build now; otherwise [retry] is called
  /// after this frame, to ask again in the next.
  bool take(VoidCallback retry) {
    if (!_resetting) {
      _resetting = true;
      SchedulerBinding.instance.addPostFrameCallback((_) {
        _resetting = false;
        _used = 0;
        final waiting = List.of(_waiting);
        _waiting.clear();
        for (final again in waiting) {
          again();
        }
      });
    }
    if (_used < perFrame) {
      _used++;
      return true;
    }
    _waiting.add(retry);
    return false;
  }
}

/// A row waiting for its turn to build: a still block, not a shimmer, for
/// the frame or two it shows.
class _StripPlaceholder extends StatelessWidget {
  const new();

  @override
  Widget build(BuildContext context) {
    final tokens = context.tokens;
    final guide = tokens.guide;
    return Padding(
      padding: EdgeInsets.symmetric(
        horizontal: guide.cellInsetX,
        vertical: guide.cellInsetY,
      ),
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: tokens.colors.surface2,
          borderRadius: tokens.radii.smAll,
        ),
        child: const SizedBox.expand(),
      ),
    );
  }
}

/// What a cell's widget shows, to tell whether the last one can be used
/// again.
final class _MadeCell {
  new({
    required this.end,
    required this.width,
    required this.phase,
    required this.focused,
    required this.hovered,
  });

  final DateTime end;
  final double width;
  final int phase;
  final bool focused;
  final bool hovered;
  Widget? widget;

  bool same(_MadeCell other) =>
      other.end == end &&
      other.width == width &&
      other.phase == phase &&
      other.focused == focused &&
      other.hovered == hovered;
}

/// Clips a row's sliding cells to the right of the programme the view's
/// left edge cuts, halfway into the gap after it, so the edge layer's copy
/// is the only one drawn. Re-clips as the view moves.
class _PastTheCut extends CustomClipper<Rect> {
  new({required this.x, required this.timeline, required this.cells})
    : super(reclip: x);

  final ValueListenable<double> x;
  final GuideTimeline timeline;
  final List<GuideCell> cells;

  @override
  Rect getClip(Size size) {
    final offset = x.value;
    final cut = _StripState._cutAt(cells, timeline.timeAt(offset));
    final left = cut == null
        ? 0.0
        : (timeline.xOf(cut.end) - offset).clamp(0.0, size.width);
    return Rect.fromLTRB(left, 0, size.width, size.height);
  }

  @override
  bool shouldReclip(_PastTheCut old) =>
      old.x != x || old.timeline != timeline || !identical(old.cells, cells);
}

/// The dashed row of a channel the guide doesn't cover (canvas: "No
/// guide information · Match to a guide channel").
class _NoGuideCell extends StatelessWidget {
  const new({required this.focused, required this.onTap});

  final bool focused;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final tokens = context.tokens;
    final colors = tokens.colors;
    final guide = tokens.guide;
    final radius = tokens.radii.smAll;
    final outline = CustomPaint(
      painter: _DashedOutline(
        color: colors.border,
        radius: tokens.radii.sm,
        dash: guide.dashLength,
        gap: guide.dashGap,
      ),
      child: Padding(
        padding: EdgeInsets.symmetric(horizontal: guide.cellPadding.left + 2),
        child: Align(
          alignment: Alignment.centerLeft,
          child: Text.rich(
            TextSpan(
              children: [
                const TextSpan(text: 'No guide information · '),
                // The strip takes the tap, anywhere on the row.
                TextSpan(
                  text: 'Match to a guide channel',
                  style: tokens.text.caption
                      .withWeight(700)
                      .copyWith(color: colors.accentBase),
                ),
              ],
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: tokens.text.caption.copyWith(color: colors.textTertiary),
          ),
        ),
      ),
    );
    return Semantics(
      button: true,
      selected: focused,
      label: 'No guide information. Match to a guide channel',
      onTap: onTap,
      excludeSemantics: true,
      child: focused
          ? FocusRing(
              visible: true,
              borderRadius: radius,
              ringColor: colors.accentBase,
              glowColor: colors.accentBase.withValues(
                alpha: tokens.focus.glowOpacity,
              ),
              ringWidth: tokens.focus.ringWidth,
              glowWidth: tokens.focus.glowWidth,
              duration: Duration.zero,
              curve: tokens.motion.fastCurve,
              child: outline,
            )
          : outline,
    );
  }
}

/// The ruler: the day at the view's left edge over the channel column,
/// then a label each half hour, and the now pill.
class _Ruler extends StatelessWidget {
  const new({
    required this.timeline,
    required this.x,
    required this.viewWidth,
    required this.now,
  });

  final GuideTimeline timeline;
  final ValueListenable<double> x;
  final double viewWidth;
  final DateTime now;

  @override
  Widget build(BuildContext context) {
    final tokens = context.tokens;
    final colors = tokens.colors;
    final guide = tokens.guide;
    return Container(
      height: guide.rulerHeight,
      decoration: BoxDecoration(
        border: Border(bottom: BorderSide(color: colors.surface3)),
      ),
      child: ValueListenableBuilder<double>(
        valueListenable: x,
        builder: (context, offset, _) {
          final from = timeline.timeAt(offset);
          final to = timeline.timeAt(offset + viewWidth);
          return Row(
            children: [
              Container(
                width: guide.channelColumnWidth,
                padding: EdgeInsets.symmetric(horizontal: guide.channelPadding),
                alignment: Alignment.centerLeft,
                child: Text(
                  '${formatWeekday(from)} ${from.toLocal().day}'.toUpperCase(),
                  maxLines: 1,
                  overflow: TextOverflow.clip,
                  style: tokens.text.overline
                      .withWeight(700)
                      .copyWith(color: colors.textTertiary),
                ),
              ),
              Expanded(
                child: ClipRect(child: _rulerStrip(context, offset, from, to)),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _rulerStrip(
    BuildContext context,
    double offset,
    DateTime from,
    DateTime to,
  ) {
    final tokens = context.tokens;
    final colors = tokens.colors;
    final guide = tokens.guide;
    final ticks = timeline.ticks(from, to);
    final labelStyle = tokens.text.labelSmall.copyWith(
      color: colors.textTertiary,
    );
    // AM/PM on the first label wholly in view, and wherever the half of
    // the day changes.
    final first = ticks.indexWhere(
      (tick) => timeline.xOf(tick) + guide.rulerLabelInset >= offset,
    );
    final nowX = timeline.xOf(now) - offset;
    final showNow = nowX >= 0 && nowX <= viewWidth;
    return Stack(
      clipBehavior: Clip.none,
      children: [
        for (var i = 0; i < ticks.length; i++)
          Positioned(
            left: timeline.xOf(ticks[i]) - offset + guide.rulerLabelInset,
            top: 0,
            bottom: 0,
            child: Center(
              child: Text(
                i == first || (i > 0 && !sameMeridiem(ticks[i - 1], ticks[i]))
                    ? formatClock(ticks[i])
                    : formatClockShort(ticks[i]),
                style: labelStyle,
              ),
            ),
          ),
        if (showNow)
          Positioned(
            left: nowX,
            top: 0,
            bottom: 0,
            child: FractionalTranslation(
              translation: const Offset(-0.5, 0),
              child: Center(
                child: Container(
                  padding: guide.nowPillPadding,
                  decoration: BoxDecoration(
                    color: colors.live,
                    borderRadius: tokens.radii.xsAll,
                  ),
                  child: Text(
                    formatClockShort(now),
                    style: tokens.text.labelSmall
                        .withWeight(800)
                        .copyWith(color: colors.onAccent),
                  ),
                ),
              ),
            ),
          ),
      ],
    );
  }
}

/// The red now line over the rows.
class _NowLine extends StatelessWidget {
  const new({
    required this.timeline,
    required this.x,
    required this.viewWidth,
    required this.now,
  });

  final GuideTimeline timeline;
  final ValueListenable<double> x;
  final double viewWidth;
  final DateTime now;

  @override
  Widget build(BuildContext context) {
    final tokens = context.tokens;
    final guide = tokens.guide;
    return ClipRect(
      child: ValueListenableBuilder<double>(
        valueListenable: x,
        builder: (context, offset, _) {
          final left = timeline.xOf(now) - offset;
          if (left < 0 || left > viewWidth) return const SizedBox.shrink();
          return Stack(
            children: [
              Positioned(
                left: left - guide.nowLineWidth / 2,
                top: 0,
                bottom: 0,
                width: guide.nowLineWidth,
                child: ColoredBox(
                  color: tokens.colors.live.withValues(
                    alpha: guide.nowLineOpacity,
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

/// A dashed rounded outline (Flutter draws no dashed borders): dashes
/// along the four straight sides, the corners as plain arcs. Drawn as
/// lines rather than cut from a path, which a row-wide outline would make
/// cost several milliseconds a paint.
class _DashedOutline extends CustomPainter {
  const new({
    required this.color,
    required this.radius,
    required this.dash,
    required this.gap,
  });

  final Color color;
  final double radius;
  final double dash;
  final double gap;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1;
    final box = (Offset.zero & size).deflate(0.5);
    final r = math.min(radius, math.min(box.width, box.height) / 2);
    void side(Offset from, Offset to) {
      final length = (to - from).distance;
      if (length <= 0) return;
      final step = (to - from) / length;
      for (var d = 0.0; d < length; d += dash + gap) {
        canvas.drawLine(
          from + step * d,
          from + step * math.min(d + dash, length),
          paint,
        );
      }
    }

    side(Offset(box.left + r, box.top), Offset(box.right - r, box.top));
    side(Offset(box.right, box.top + r), Offset(box.right, box.bottom - r));
    side(Offset(box.right - r, box.bottom), Offset(box.left + r, box.bottom));
    side(Offset(box.left, box.bottom - r), Offset(box.left, box.top + r));
    if (r > 0) {
      const quarter = math.pi / 2;
      final d = r * 2;
      canvas
        ..drawArc(
          Rect.fromLTWH(box.left, box.top, d, d),
          math.pi,
          quarter,
          false,
          paint,
        )
        ..drawArc(
          Rect.fromLTWH(box.right - d, box.top, d, d),
          -quarter,
          quarter,
          false,
          paint,
        )
        ..drawArc(
          Rect.fromLTWH(box.right - d, box.bottom - d, d, d),
          0,
          quarter,
          false,
          paint,
        )
        ..drawArc(
          Rect.fromLTWH(box.left, box.bottom - d, d, d),
          quarter,
          quarter,
          false,
          paint,
        );
    }
  }

  @override
  bool shouldRepaint(_DashedOutline old) =>
      old.color != color ||
      old.radius != radius ||
      old.dash != dash ||
      old.gap != gap;
}
