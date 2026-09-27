import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:iptv_player/core/core_providers.dart';
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

  void _onCache() {
    if (mounted) setState(() {});
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

  void _refreshPages() {
    if (!mounted) return;
    setState(() {
      _pages.clear();
      _loading.clear();
    });
    _scheduleRequest();
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
    const margin = Duration(hours: 1);
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
      ..listen(channelCountProvider(query), (_, _) => _refreshPages())
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

/// A channel's row: its number, logo and name, and its cells for the
/// view, redrawn as the view moves.
class _GuideRowView extends StatelessWidget {
  const new({
    required this.channel,
    required this.timeline,
    required this.x,
    required this.viewWidth,
    required this.now,
    required this.cells,
    required this.cursor,
    required this.onTap,
  });

  final ChannelItem? channel;
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
      strip: ValueListenableBuilder<double>(
        valueListenable: x,
        builder: (context, offset, _) => _strip(context, offset),
      ),
    );
  }

  Widget _strip(BuildContext context, double offset) {
    final tokens = context.tokens;
    final guide = tokens.guide;
    final from = timeline.timeAt(offset);
    final to = timeline.timeAt(offset + viewWidth);
    final found = cells(from, to);
    if (found == null) return const _StripSkeleton();
    final focused = cursor == null ? null : cellAt(found, cursor!);
    if (found.length == 1 && found.single.noGuide) {
      return Padding(
        padding: EdgeInsets.symmetric(
          horizontal: guide.cellInsetX,
          vertical: guide.cellInsetY,
        ),
        child: _NoGuideCell(
          focused: focused != null,
          onTap: onTap == null ? null : () => onTap!(found.single),
        ),
      );
    }
    final children = <Widget>[];
    Widget? ringed;
    for (final cell in found) {
      final left = timeline.xOf(cell.start.isBefore(from) ? from : cell.start);
      final right = timeline.xOf(cell.end);
      final width = right - left - guide.cellInsetX * 2;
      if (width <= 0) continue;
      final isFocused = identical(cell, focused);
      final view = Positioned(
        key: ValueKey(cell.programme?.id ?? 'gap ${cell.start}'),
        left: left - offset + guide.cellInsetX,
        top: guide.cellInsetY,
        bottom: guide.cellInsetY,
        width: width,
        child: _CellView(
          cell: cell,
          width: width,
          clipped: cell.start.isBefore(from),
          now: now,
          focused: isFocused,
          onTap: onTap == null ? null : () => onTap!(cell),
        ),
      );
      if (isFocused) {
        ringed = view;
      } else {
        children.add(view);
      }
    }
    // The focused cell last, so its ring draws over its neighbours.
    return Stack(clipBehavior: Clip.none, children: [...children, ?ringed]);
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
          image: _logo(channel.logoUrl),
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

  static ImageProvider? _logo(String? url) {
    final uri = url == null ? null : Uri.tryParse(url);
    if (uri == null || !uri.hasScheme || !uri.scheme.startsWith('http')) {
      return null;
    }
    return NetworkImage(url!);
  }
}

/// A programme (now, later or past, as the canvas colours them) or a gap
/// in the guide.
class _CellView extends StatefulWidget {
  const new({
    required this.cell,
    required this.width,
    required this.clipped,
    required this.now,
    required this.focused,
    required this.onTap,
  });

  final GuideCell cell;
  final double width;

  /// The programme started before the view: its title gets a ‹.
  final bool clipped;
  final DateTime now;
  final bool focused;
  final VoidCallback? onTap;

  @override
  State<_CellView> createState() => _CellViewState();
}

class _CellViewState extends State<_CellView> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    final tokens = context.tokens;
    final colors = tokens.colors;
    final guide = tokens.guide;
    final programme = widget.cell.programme;
    final width = widget.width;
    final now = widget.now;
    final ended = programme != null && !programme.end.isAfter(now);
    final onNow = programme != null && !ended && !programme.start.isAfter(now);

    final Color background;
    final Color title;
    final Color time;
    if (programme == null) {
      background = _hovered ? colors.surface2 : Colors.transparent;
      title = colors.textTertiary;
      time = colors.textTertiary;
    } else if (ended) {
      background = _hovered ? colors.surface2 : colors.surfaceSunken;
      title = colors.textTertiary;
      time = colors.textTertiary;
    } else if (onNow) {
      background = _hovered ? colors.border : colors.surface3;
      title = colors.textPrimary;
      time = colors.textSecondary;
    } else {
      background = _hovered ? colors.surface3 : colors.surface2;
      title = colors.textPrimary;
      time = colors.textTertiary;
    }

    final showText = width >= guide.cellTextWidth;
    final label = programme == null
        ? 'No information'
        : '${widget.clipped ? '‹ ' : ''}${programme.title}';
    final titleStyle =
        (widget.focused ? tokens.text.label.withWeight(700) : tokens.text.label)
            .copyWith(color: title);
    Widget content = Padding(
      padding: guide.cellPadding,
      child: Column(
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
          if (programme != null) ...[
            SizedBox(height: guide.cellLineGap),
            Text(
              guideCellTime(
                programme,
                full: width >= guide.cellFullTimeWidth,
                range: width >= guide.cellRangeWidth,
              ),
              maxLines: 1,
              softWrap: false,
              overflow: TextOverflow.clip,
              style: tokens.text.small.copyWith(color: time),
            ),
          ],
        ],
      ),
    );
    if (!showText) content = const SizedBox.expand();

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

    final state = programme == null
        ? null
        : guideProgrammeState(programme, now);
    return Semantics(
      button: programme != null,
      selected: widget.focused,
      label: programme == null
          ? 'No information'
          : [
              programme.title,
              formatTimeRange(programme.start, programme.end),
              ?state,
            ].join(', '),
      onTap: widget.onTap,
      excludeSemantics: true,
      child: MouseRegion(
        cursor: programme == null
            ? MouseCursor.defer
            : SystemMouseCursors.click,
        onEnter: (_) => setState(() => _hovered = true),
        onExit: (_) => setState(() => _hovered = false),
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: widget.onTap,
          child: FocusRing(
            visible: widget.focused,
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
          ),
        ),
      ),
    );
  }
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
    return Semantics(
      button: true,
      selected: focused,
      label: 'No guide information. Match to a guide channel',
      onTap: onTap,
      excludeSemantics: true,
      child: FocusRing(
        visible: focused,
        borderRadius: radius,
        ringColor: colors.accentBase,
        glowColor: colors.accentBase.withValues(
          alpha: tokens.focus.glowOpacity,
        ),
        ringWidth: tokens.focus.ringWidth,
        glowWidth: tokens.focus.glowWidth,
        duration: Duration.zero,
        curve: tokens.motion.fastCurve,
        child: CustomPaint(
          painter: _DashedOutline(
            color: colors.border,
            radius: tokens.radii.sm,
            dash: guide.dashLength,
            gap: guide.dashGap,
          ),
          child: Padding(
            padding: EdgeInsets.symmetric(
              horizontal: guide.cellPadding.left + 2,
            ),
            child: Align(
              alignment: Alignment.centerLeft,
              child: Text.rich(
                TextSpan(
                  children: [
                    const TextSpan(text: 'No guide information · '),
                    TextSpan(
                      text: 'Match to a guide channel',
                      style: tokens.text.caption
                          .withWeight(700)
                          .copyWith(color: colors.accentBase),
                      recognizer: onTap == null
                          ? null
                          : (TapGestureRecognizer()..onTap = onTap),
                      mouseCursor: SystemMouseCursors.click,
                    ),
                  ],
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: tokens.text.caption.copyWith(color: colors.textTertiary),
              ),
            ),
          ),
        ),
      ),
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

/// A dashed rounded outline (Flutter draws no dashed borders).
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
    final outline = Path()
      ..addRRect(
        RRect.fromRectAndRadius(
          (Offset.zero & size).deflate(0.5),
          Radius.circular(radius),
        ),
      );
    for (final metric in outline.computeMetrics()) {
      for (var d = 0.0; d < metric.length; d += dash + gap) {
        canvas.drawPath(
          metric.extractPath(d, math.min(d + dash, metric.length)),
          paint,
        );
      }
    }
  }

  @override
  bool shouldRepaint(_DashedOutline old) =>
      old.color != color ||
      old.radius != radius ||
      old.dash != dash ||
      old.gap != gap;
}
