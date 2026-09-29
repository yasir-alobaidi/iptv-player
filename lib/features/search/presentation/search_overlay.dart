import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:iptv_player/app/failure_message.dart';
import 'package:iptv_player/core/core_providers.dart';
import 'package:iptv_player/core/images/artwork_scope.dart';
import 'package:iptv_player/design/components.dart';
import 'package:iptv_player/design/tokens.dart';
import 'package:iptv_player/features/live_tv/data/live_tv_providers.dart';
import 'package:iptv_player/features/live_tv/domain/channels.dart';
import 'package:iptv_player/features/live_tv/domain/now_next.dart';
import 'package:iptv_player/features/live_tv/presentation/channel_menu.dart';
import 'package:iptv_player/features/search/domain/search.dart';
import 'package:iptv_player/features/search/domain/search_words.dart';
import 'package:iptv_player/features/search/presentation/search_actions.dart';
import 'package:iptv_player/features/search/presentation/search_state.dart';
import 'package:iptv_player/features/search/presentation/search_text.dart';
import 'package:iptv_player/features/sources/data/source_providers.dart';
import 'package:iptv_player/features/sources/domain/sync.dart';
import 'package:iptv_player/features/sources/presentation/current_source.dart';

/// The Ctrl+K / `/` search overlay (canvas `Search`, Phase 6 step 4): a
/// scrim over the shell and a 760 px panel — the query, the results in
/// four groups, and a footer of keys.
///
/// **The keyboard's focus stays in the field** (as in the Match… picker):
/// ↑/↓ move a cursor through every result, PageUp/PageDown by a screen,
/// Tab and Shift+Tab to the next or previous group, Enter opens, the Menu
/// key opens the result's menu, Esc closes. The mouse highlights on hover
/// and opens on a click.
class SearchOverlay extends ConsumerStatefulWidget {
  const new({this.onClose, super.key});

  /// Esc and the scrim call this; the router pops the overlay.
  final VoidCallback? onClose;

  @override
  ConsumerState<SearchOverlay> createState() => _SearchOverlayState();
}

class _SearchOverlayState extends ConsumerState<SearchOverlay> {
  final _query = TextEditingController();
  final _field = FocusNode(debugLabel: 'search field');
  final _scroll = ScrollController();
  final GlobalKey _cursorRow = GlobalKey(debugLabel: 'search cursor row');

  /// The cursor, over the entries that can be opened.
  var _cursor = 0;

  /// The results the cursor was placed in: new ones put it back on the
  /// first.
  SearchResults? _placedIn;

  /// What the body lists, rebuilt with it.
  List<_Entry> _entries = const [];

  /// How many rows a page is, from the body's height.
  var _pageRows = 8;

  @override
  void dispose() {
    _query.dispose();
    _field.dispose();
    _scroll.dispose();
    super.dispose();
  }

  SearchSession get _session => ref.read(searchSessionProvider.notifier);

  SearchActions _actions() =>
      SearchActions(ProviderScope.containerOf(context), GoRouter.of(context));

  List<_Entry> get _selectable => [
    for (final entry in _entries)
      if (entry.selectable) entry,
  ];

  // The keyboard.

  KeyEventResult _onKey(FocusNode node, KeyEvent event) {
    if (event is KeyUpEvent) return KeyEventResult.ignored;
    final key = event.logicalKey;
    final shift = HardwareKeyboard.instance.isShiftPressed;
    final selectable = _selectable;
    switch (key) {
      case LogicalKeyboardKey.arrowDown:
        return _moveBy(1, selectable);
      case LogicalKeyboardKey.arrowUp:
        return _moveBy(-1, selectable);
      case LogicalKeyboardKey.pageDown:
        return _moveBy(_pageRows, selectable);
      case LogicalKeyboardKey.pageUp:
        return _moveBy(-_pageRows, selectable);
      case LogicalKeyboardKey.tab:
        return _jumpGroup(forward: !shift, selectable: selectable);
      case LogicalKeyboardKey.contextMenu:
        return _menu(selectable);
      case LogicalKeyboardKey.f10 when shift:
        return _menu(selectable);
      case LogicalKeyboardKey.delete:
        // Only in the recent searches: in the text, Delete deletes.
        final entry = _at(selectable);
        if (entry is! _RecentEntry || !ref.read(searchSessionProvider).idle) {
          return KeyEventResult.ignored;
        }
        unawaited(_session.forget(entry.text));
        return KeyEventResult.handled;
    }
    return KeyEventResult.ignored;
  }

  _Entry? _at(List<_Entry> selectable) => selectable.isEmpty
      ? null
      : selectable[_cursor.clamp(0, selectable.length - 1)];

  KeyEventResult _moveBy(int delta, List<_Entry> selectable) {
    if (selectable.isEmpty) return KeyEventResult.ignored;
    _setCursor((_cursor + delta).clamp(0, selectable.length - 1));
    return KeyEventResult.handled;
  }

  /// Tab: the first result of the next group; Shift+Tab: of this group,
  /// or of the one before when already there. Nothing to jump between
  /// (the recent searches), and Tab moves on to Clear as usual.
  KeyEventResult _jumpGroup({
    required bool forward,
    required List<_Entry> selectable,
  }) {
    final groups = [
      for (final (i, entry) in selectable.indexed)
        if (i == 0 || selectable[i - 1].group != entry.group) i,
    ];
    if (groups.length < 2 && selectable.firstOrNull is! _HitEntry) {
      return KeyEventResult.ignored;
    }
    final current = groups.lastWhere((i) => i <= _cursor, orElse: () => 0);
    final int target;
    if (forward) {
      target = groups.firstWhere((i) => i > _cursor, orElse: () => _cursor);
    } else {
      final at = groups.indexOf(current);
      target = _cursor > current ? current : groups[math.max(0, at - 1)];
    }
    _setCursor(target);
    return KeyEventResult.handled;
  }

  void _setCursor(int index) {
    setState(() => _cursor = index);
    _reveal(index);
  }

  /// Scrolls the body so the cursor's row shows: every entry has a fixed
  /// height, so its place is a sum.
  void _reveal(int index) {
    if (!_scroll.hasClients) return;
    final heights = context.tokens.search;
    var top = 0.0;
    var seen = -1;
    var height = heights.rowHeight;
    for (final entry in _entries) {
      height = entry.height(heights);
      if (entry.selectable) seen++;
      if (seen == index) break;
      top += height + _Entry.gap;
    }
    final view = _scroll.position.viewportDimension;
    final offset = _scroll.offset;
    final target = top < offset
        ? top
        : top + height > offset + view
        ? top + height - view
        : null;
    if (target != null) {
      _scroll.jumpTo(
        target.clamp(0, _scroll.position.maxScrollExtent).toDouble(),
      );
    }
  }

  // Opening.

  void _submit() {
    final entry = _at(_selectable);
    if (entry != null) unawaited(_open(entry));
  }

  Future<void> _open(_Entry entry) async {
    final view = ref.read(searchSessionProvider);
    switch (entry) {
      case _RecentEntry(:final text):
        _query.value = TextEditingValue(
          text: text,
          selection: TextSelection.collapsed(offset: text.length),
        );
        _session.setText(text);
        return;
      case _HitEntry(:final hit):
        final actions = _actions();
        final now = ref.read(appClockProvider)();
        await _session.rememberText();
        switch (hit) {
          case ChannelHit(:final channel):
            await actions.watch(channel);
          case final ProgrammeHit programme:
            await actions.openProgramme(programme, now);
          case MovieHit(:final movie):
            actions.openMovie(movie);
          case SeriesHit(:final series):
            actions.openSeries(series);
        }
      case _ShowAllEntry(:final kind):
        final actions = _actions();
        await _session.rememberText();
        actions.showAll(kind, view.text.trim());
      case _HeadingEntry():
        return;
    }
  }

  KeyEventResult _menu(List<_Entry> selectable) {
    final entry = _at(selectable);
    final anchor = _cursorRow.currentContext;
    if (entry is! _HitEntry || anchor == null) return KeyEventResult.ignored;
    unawaited(_showMenu(anchor, entry.hit));
    return KeyEventResult.handled;
  }

  Future<void> _showMenu(BuildContext anchor, Object hit) {
    final actions = _actions();
    void searchAgain() {
      if (mounted) unawaited(_session.retry());
    }

    switch (hit) {
      case ChannelHit(:final channel) || ProgrammeHit(:final channel):
        // The one channel menu (step 7), and search's own way to Live TV.
        return showChannelMenu(
          anchor,
          ref,
          channel,
          onWatch: () => unawaited(() async {
            await _session.rememberText();
            await actions.watch(channel);
          }()),
          onChanged: searchAgain,
          after: [
            const AppMenuItem.separator(),
            AppMenuItem(
              label: 'Show in Live TV',
              icon: AppIcons.liveTv,
              onPressed: () => actions.showInLiveTv(channel),
            ),
          ],
        );
    }
    final favorite = switch (hit) {
      MovieHit(:final movie) => movie.isFavorite,
      SeriesHit(:final series) => series.isFavorite,
      _ => false,
    };
    return showAppMenu(
      anchor,
      items: [
        AppMenuItem(
          label: favorite ? 'Remove from favorites' : 'Add to favorites',
          icon: favorite ? AppIcons.starFilled : AppIcons.star,
          onPressed: () => unawaited(() async {
            await actions.toggleFavorite(hit);
            searchAgain();
          }()),
        ),
      ],
    );
  }

  // Building.

  @override
  Widget build(BuildContext context) {
    final tokens = context.tokens;
    final colors = tokens.colors;
    final search = tokens.search;
    final view = ref.watch(searchSessionProvider);
    final source = ref.watch(currentSourceProvider);
    final results = view.idle ? null : view.results;
    if (!identical(results, _placedIn)) {
      _placedIn = results;
      _cursor = 0;
      if (_scroll.hasClients) _scroll.jumpTo(0);
      final channels = results?.channels.hits ?? const <ChannelHit>[];
      if (channels.isNotEmpty) {
        unawaited(
          ref.read(guideServiceProvider).warm([
            for (final hit in channels) hit.channel,
          ]),
        );
      }
    }
    final syncing =
        source != null &&
        source.lastSyncedAt == null &&
        ref.watch(syncStatusProvider(source.id)).value is SyncRunning;

    // The overlay is its own route with no Scaffold, and Material's
    // text field needs a Material ancestor; transparency adds nothing
    // visible.
    return Material(
      type: MaterialType.transparency,
      child: Semantics(
        label: 'Search',
        explicitChildNodes: true,
        child: LayoutBuilder(
          builder: (context, constraints) {
            final maxHeight = math.max(
              search.queryBarHeight + search.footerHeight + search.rowHeight,
              constraints.maxHeight - search.panelTop - search.panelBottom,
            );
            final bodyHeight =
                maxHeight - search.queryBarHeight - search.footerHeight;
            _pageRows = math.max(
              1,
              (bodyHeight / search.rowHeight).floor() - 1,
            );
            return Stack(
              children: [
                // The scrim closes on a click but is not a focus stop:
                // Esc is the keyboard way out.
                Positioned.fill(
                  child: GestureDetector(
                    behavior: HitTestBehavior.opaque,
                    onTap: widget.onClose,
                    child: ColoredBox(
                      color: colors.video.withValues(
                        alpha: search.scrimOpacity,
                      ),
                    ),
                  ),
                ),
                Align(
                  alignment: Alignment.topCenter,
                  child: Padding(
                    padding: EdgeInsets.only(top: search.panelTop),
                    child: ConstrainedBox(
                      constraints: BoxConstraints(
                        maxWidth: search.panelWidth,
                        maxHeight: maxHeight,
                      ),
                      child: Container(
                        margin: EdgeInsets.symmetric(
                          horizontal: tokens.spacing.s24,
                        ),
                        decoration: BoxDecoration(
                          color: colors.surface2,
                          borderRadius: tokens.radii.lgAll,
                          border: Border.all(color: colors.border),
                          boxShadow: tokens.elevation.overlay,
                        ),
                        clipBehavior: Clip.antiAlias,
                        child: FocusPane(
                          debugLabel: 'search-overlay',
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              Focus(
                                canRequestFocus: false,
                                skipTraversal: true,
                                onKeyEvent: _onKey,
                                child: _QueryBar(
                                  controller: _query,
                                  focusNode: _field,
                                  count: results == null || results.isEmpty
                                      ? null
                                      : results.count,
                                  onChanged: _session.setText,
                                  onSubmitted: _submit,
                                ),
                              ),
                              if (syncing) const _StillArriving(),
                              Flexible(
                                child: _hug(
                                  _body(context, view, results, source),
                                ),
                              ),
                              _Footer(
                                idle: view.idle || source == null,
                                recent: view.recent,
                                hasRecent: view.idle && view.recent.isNotEmpty,
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }

  Widget _body(
    BuildContext context,
    SearchView view,
    SearchResults? results,
    Object? source,
  ) {
    final tokens = context.tokens;
    final padding = EdgeInsets.all(tokens.spacing.s8);
    if (source == null) {
      _entries = const [];
      return Padding(
        padding: EdgeInsets.symmetric(vertical: tokens.spacing.s24),
        child: EmptyState(
          compact: true,
          icon: AppIcons.search,
          title: 'Nothing to search yet',
          message:
              'Add your provider, and its channels, guide, movies and '
              'series are searchable here.',
          actionLabel: 'Add a source',
          onAction: () => _actions().addSource(),
        ),
      );
    }
    if (view.idle) {
      _entries = [
        if (view.recent.isNotEmpty) const _HeadingEntry.recent(),
        for (final text in view.recent) _RecentEntry(text),
      ];
      if (_entries.isEmpty) {
        return Padding(
          padding: EdgeInsets.symmetric(
            horizontal: tokens.spacing.s24,
            vertical: tokens.spacing.s24,
          ),
          child: Text(
            searchCoverage,
            textAlign: TextAlign.center,
            style: tokens.text.caption.copyWith(
              color: tokens.colors.textTertiary,
            ),
          ),
        );
      }
      return _list(context, padding);
    }
    if (view.failure != null && results == null) {
      _entries = const [];
      return Padding(
        padding: EdgeInsets.symmetric(vertical: tokens.spacing.s16),
        child: ErrorState(
          compact: true,
          title: "Couldn't search",
          message: failureMessage(view.failure!),
          onRetry: () => unawaited(_session.retry()),
        ),
      );
    }
    if (results == null) {
      _entries = const [];
      return Padding(
        padding: padding,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            for (var i = 0; i < 3; i++)
              SkeletonRow(height: tokens.search.rowHeight),
          ],
        ),
      );
    }
    if (results.isEmpty) {
      _entries = const [];
      return _NoResults(
        text: results.text,
        hidden: results.hiddenChannels,
        onShowHidden: () => _actions().showHidden(),
      );
    }
    _entries = [
      ..._group(SearchGroupKind.channels, results.channels),
      ..._group(SearchGroupKind.programmes, results.programmes),
      ..._group(SearchGroupKind.movies, results.movies),
      ..._group(SearchGroupKind.series, results.series),
    ];
    return _list(context, padding);
  }

  /// A body other than the list is as tall as it needs, not the window:
  /// the empty and error states center themselves in whatever they get.
  Widget _hug(Widget body) => body is ListView
      ? body
      : Column(mainAxisSize: MainAxisSize.min, children: [body]);

  static List<_Entry> _group(SearchGroupKind kind, SearchGroup<Object> group) {
    if (group.isEmpty) return const [];
    return [
      _HeadingEntry(kind),
      for (final hit in group.hits) _HitEntry(kind, hit),
      if (group.hasMore && showAllLabel(kind) != null) _ShowAllEntry(kind),
    ];
  }

  Widget _list(BuildContext context, EdgeInsets padding) {
    final view = ref.watch(searchSessionProvider);
    final results = view.idle ? null : view.results;
    final words = searchWords(view.text);
    final now = ref.watch(appClockProvider)();
    final guide = ref.watch(guideServiceProvider);
    ref.watch(guideRevisionProvider);
    final channelNames = <String, int>{};
    for (final hit in results?.channels.hits ?? const <ChannelHit>[]) {
      channelNames.update(hit.channel.name, (n) => n + 1, ifAbsent: () => 1);
    }
    final sources = results?.sourceCount ?? 1;
    final cursor = _cursor.clamp(0, math.max(0, _selectable.length - 1));
    var index = -1;
    return ListView(
      controller: _scroll,
      padding: padding,
      shrinkWrap: true,
      children: [
        for (final (i, entry) in _entries.indexed) ...[
          if (i > 0) const SizedBox(height: _Entry.gap),
          switch (entry) {
            _HeadingEntry() => _Heading(
              entry: entry,
              onClear: () => unawaited(_session.clearRecent()),
            ),
            _ => () {
              index++;
              final at = index;
              final selected = at == cursor;
              return _EntryRow(
                key: selected ? _cursorRow : null,
                entry: entry,
                selected: selected,
                words: words,
                now: now,
                sources: sources,
                guide: guide,
                sameName: switch (entry) {
                  _HitEntry(hit: ChannelHit(:final channel)) =>
                    (channelNames[channel.name] ?? 0) > 1,
                  _ => false,
                },
                onOpen: () {
                  setState(() => _cursor = at);
                  unawaited(_open(entry));
                },
              );
            }(),
          },
        ],
      ],
    );
  }
}

// ------------------------------------------------------------- entries

/// One line of the body: a heading, a result, "Show all", or a recent
/// search. Each has a fixed height, so the cursor's place is a sum.
sealed class _Entry {
  const new(this.group);

  final SearchGroupKind? group;

  /// Between two entries (canvas: 2).
  static const double gap = 2;

  bool get selectable => true;

  double height(AppSearchTokens search) => search.rowHeight;
}

final class _HeadingEntry extends _Entry {
  const new(SearchGroupKind super.group) : recent = false;

  const new recent() : recent = true, super(null);

  final bool recent;

  @override
  bool get selectable => false;

  @override
  double height(AppSearchTokens search) => 30;

  String get label => recent
      ? 'RECENT SEARCHES'
      : switch (group!) {
          SearchGroupKind.channels => channelsHeading,
          SearchGroupKind.programmes => programmesHeading,
          SearchGroupKind.movies => moviesHeading,
          SearchGroupKind.series => seriesHeading,
        };
}

final class _HitEntry extends _Entry {
  const new(SearchGroupKind super.group, this.hit);

  /// A [ChannelHit], [ProgrammeHit], [MovieHit] or [SeriesHit].
  final Object hit;
}

final class _ShowAllEntry extends _Entry {
  const new(SearchGroupKind super.group) : kind = group;

  final SearchGroupKind kind;

  @override
  double height(AppSearchTokens search) => 40;
}

final class _RecentEntry extends _Entry {
  const new(this.text) : super(null);

  final String text;

  @override
  double height(AppSearchTokens search) => 40;
}

// ---------------------------------------------------------------- parts

/// The 64 px header from the canvas: magnifier, the query, the number of
/// results, and an Esc keycap that says how to get out.
class _QueryBar extends StatelessWidget {
  const new({
    required this.controller,
    required this.focusNode,
    required this.count,
    required this.onChanged,
    required this.onSubmitted,
  });

  final TextEditingController controller;
  final FocusNode focusNode;
  final int? count;
  final ValueChanged<String> onChanged;
  final VoidCallback onSubmitted;

  @override
  Widget build(BuildContext context) {
    final tokens = context.tokens;
    final colors = tokens.colors;
    final search = tokens.search;

    return Container(
      height: search.queryBarHeight,
      padding: EdgeInsets.only(
        left: tokens.spacing.s20,
        right: tokens.spacing.s16,
      ),
      decoration: BoxDecoration(
        border: Border(bottom: BorderSide(color: colors.border)),
      ),
      child: Row(
        children: [
          AppIcon(
            AppIcons.search,
            size: search.queryIconSize,
            color: colors.textSecondary,
          ),
          SizedBox(width: tokens.spacing.s12),
          Expanded(
            child: TextField(
              controller: controller,
              focusNode: focusNode,
              autofocus: true,
              cursorColor: colors.accentBase,
              style: tokens.text.searchQuery.copyWith(
                color: colors.textPrimary,
              ),
              textInputAction: TextInputAction.search,
              onChanged: onChanged,
              onSubmitted: (_) {
                onSubmitted();
                // Enter keeps the keyboard in the field.
                focusNode.requestFocus();
              },
              decoration: InputDecoration(
                isCollapsed: true,
                border: InputBorder.none,
                hintText: searchHint,
                hintStyle: tokens.text.searchQuery.copyWith(
                  color: colors.textTertiary,
                ),
              ),
            ),
          ),
          if (count case final count?) ...[
            SizedBox(width: tokens.spacing.s12),
            Text(
              resultCountLabel(count),
              style: tokens.text.small.copyWith(color: colors.textTertiary),
            ),
          ],
          SizedBox(width: tokens.spacing.s12),
          // A hint, not a control: Esc closes the overlay and a click
          // on the scrim does the same.
          const ExcludeSemantics(child: Kbd('Esc')),
        ],
      ),
    );
  }
}

/// A first sync still under way: results grow as it goes.
class _StillArriving extends StatelessWidget {
  const new();

  @override
  Widget build(BuildContext context) {
    final tokens = context.tokens;
    return Padding(
      padding: EdgeInsets.fromLTRB(
        tokens.spacing.s20,
        tokens.spacing.s12,
        tokens.spacing.s20,
        0,
      ),
      child: Text(
        'Your catalogue is still arriving: results fill in as it does.',
        style: tokens.text.small.copyWith(color: tokens.colors.textTertiary),
      ),
    );
  }
}

class _Heading extends StatelessWidget {
  const new({required this.entry, required this.onClear});

  final _HeadingEntry entry;
  final VoidCallback onClear;

  @override
  Widget build(BuildContext context) {
    final tokens = context.tokens;
    final colors = tokens.colors;
    return SizedBox(
      height: entry.height(tokens.search),
      child: Padding(
        padding: EdgeInsets.fromLTRB(
          tokens.spacing.s12,
          tokens.spacing.s8 + 2,
          tokens.spacing.s4,
          0,
        ),
        child: Row(
          children: [
            Expanded(
              child: Semantics(
                header: true,
                child: Text(
                  entry.label,
                  style: tokens.text.searchHeading.copyWith(
                    color: colors.textTertiary,
                  ),
                ),
              ),
            ),
            if (entry.recent)
              AppButton(
                label: 'Clear',
                variant: AppButtonVariant.ghost,
                size: AppButtonSize.s,
                onPressed: onClear,
              ),
          ],
        ),
      ),
    );
  }
}

/// A result, "Show all", or a recent search: highlighted on hover, drawn
/// with the focus ring where the cursor is, opened by a click.
class _EntryRow extends StatefulWidget {
  const new({
    required this.entry,
    required this.selected,
    required this.words,
    required this.now,
    required this.sources,
    required this.guide,
    required this.sameName,
    required this.onOpen,
    super.key,
  });

  final _Entry entry;
  final bool selected;
  final List<String> words;
  final DateTime now;
  final int sources;
  final GuideService guide;
  final bool sameName;
  final VoidCallback onOpen;

  @override
  State<_EntryRow> createState() => _EntryRowState();
}

class _EntryRowState extends State<_EntryRow> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    final tokens = context.tokens;
    final colors = tokens.colors;
    final focus = tokens.focus;
    final entry = widget.entry;
    final selected = widget.selected;
    final radius = tokens.radii.controlAll;
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: widget.onOpen,
        child: Semantics(
          button: true,
          selected: selected,
          child: FocusRing(
            visible: selected,
            borderRadius: radius,
            ringColor: colors.accentBase,
            glowColor: colors.accentBase.withValues(alpha: focus.glowOpacity),
            ringWidth: focus.ringWidth,
            glowWidth: focus.glowWidth,
            duration: tokens.motion.fast,
            curve: tokens.motion.fastCurve,
            child: AnimatedContainer(
              duration: tokens.motion.fast,
              curve: tokens.motion.fastCurve,
              height: entry.height(tokens.search),
              padding: EdgeInsets.symmetric(horizontal: tokens.spacing.s12),
              decoration: BoxDecoration(
                color: selected || _hovered ? colors.surface3 : null,
                borderRadius: radius,
              ),
              child: switch (entry) {
                _HitEntry(:final hit) => _hitRow(context, hit),
                _ShowAllEntry(:final kind) => _showAll(context, kind),
                _RecentEntry(:final text) => _recent(context, text),
                _HeadingEntry() => const SizedBox.shrink(),
              },
            ),
          ),
        ),
      ),
    );
  }

  Widget _hitRow(BuildContext context, Object hit) {
    final tokens = context.tokens;
    final colors = tokens.colors;
    final search = tokens.search;
    final selected = widget.selected;
    final (
      String title,
      String line,
      Widget picture,
      Widget? trailing,
    ) = switch (hit) {
      ChannelHit(:final channel) => (
        channel.name,
        channelHitLine(
          hit,
          guide: widget.guide.cached(channel),
          sameName: widget.sameName,
          sources: widget.sources,
        ),
        _logo(context, channel),
        null,
      ),
      final ProgrammeHit programme => (
        programmeHitTitle(programme),
        programmeHitLine(programme, now: widget.now, sources: widget.sources),
        _logo(context, programme.channel),
        programme.isOnAt(widget.now)
            ? const AppBadge('LIVE', tone: AppBadgeTone.live)
            : null,
      ),
      MovieHit(:final movie) => (
        movie.name,
        movieHitLine(hit, sources: widget.sources),
        _poster(context, movie.name, movie.posterUrl),
        null,
      ),
      SeriesHit(:final series) => (
        series.name,
        seriesHitLine(hit, sources: widget.sources),
        _poster(context, series.name, series.posterUrl),
        null,
      ),
      _ => ('', '', const SizedBox.shrink(), null),
    };
    final nameStyle = tokens.text.label.copyWith(color: colors.textEmphasis);
    final ranges = highlightRanges(title, widget.words);
    return Row(
      children: [
        SizedBox(
          width: search.pictureSlot,
          child: Center(child: picture),
        ),
        SizedBox(width: tokens.spacing.s12),
        Expanded(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text.rich(
                TextSpan(
                  children: [
                    for (final (text, bold) in _spans(title, ranges))
                      TextSpan(
                        text: text,
                        style: bold
                            ? nameStyle
                                  .withWeight(800)
                                  .copyWith(color: colors.textPrimary)
                            : nameStyle,
                      ),
                  ],
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              if (line.isNotEmpty) ...[
                SizedBox(height: tokens.spacing.s4 - 2),
                Text(
                  line,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: tokens.text.small.copyWith(
                    color: selected
                        ? colors.textSecondary
                        : colors.textTertiary,
                  ),
                ),
              ],
            ],
          ),
        ),
        if (trailing != null) ...[
          SizedBox(width: tokens.spacing.s12),
          trailing,
        ],
        ..._enterKey(context),
      ],
    );
  }

  Widget _logo(BuildContext context, ChannelItem channel) {
    final search = context.tokens.search;
    return ChannelLogo(
      name: channel.name,
      size: search.logoSize,
      image: artworkFor(context, channel.logoUrl, width: search.logoSize),
    );
  }

  Widget _poster(BuildContext context, String title, String? url) {
    final tokens = context.tokens;
    final size = tokens.search.posterSize;
    return ClipRRect(
      borderRadius: tokens.radii.xsAll,
      child: SizedBox(
        width: size.width,
        height: size.height,
        child: PosterArtwork(
          title: title,
          showTitle: false,
          image: artworkFor(context, url, width: size.width),
        ),
      ),
    );
  }

  Widget _showAll(BuildContext context, SearchGroupKind kind) {
    final tokens = context.tokens;
    final colors = tokens.colors;
    return Row(
      children: [
        SizedBox(width: tokens.search.pictureSlot + tokens.spacing.s12),
        Expanded(
          child: Text(
            showAllLabel(kind) ?? '',
            style: tokens.text.label.copyWith(color: colors.accentBase),
          ),
        ),
        AppIcon(AppIcons.chevronRight, size: 16, color: colors.accentBase),
        ..._enterKey(context),
      ],
    );
  }

  /// The Enter keycap on the cursor's row (canvas).
  List<Widget> _enterKey(BuildContext context) => [
    if (widget.selected) ...[
      SizedBox(width: context.tokens.spacing.s12),
      const ExcludeSemantics(child: Kbd('Enter')),
    ],
  ];

  Widget _recent(BuildContext context, String text) {
    final tokens = context.tokens;
    final colors = tokens.colors;
    return Row(
      children: [
        AppIcon(AppIcons.retry, size: 16, color: colors.textTertiary),
        SizedBox(width: tokens.spacing.s12),
        Expanded(
          child: Text(
            text,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: tokens.text.label.copyWith(color: colors.textEmphasis),
          ),
        ),
        ..._enterKey(context),
      ],
    );
  }

  /// [text] cut at [ranges], each piece and whether it is bold.
  static List<(String, bool)> _spans(String text, List<(int, int)> ranges) {
    final spans = <(String, bool)>[];
    var at = 0;
    for (final (start, end) in ranges) {
      if (start > at) spans.add((text.substring(at, start), false));
      spans.add((text.substring(start, end), true));
      at = end;
    }
    if (at < text.length) spans.add((text.substring(at), false));
    return spans;
  }
}

/// "No results for "harbour"", and the hidden channels that match
/// (sketch C).
class _NoResults extends StatelessWidget {
  const new({
    required this.text,
    required this.hidden,
    required this.onShowHidden,
  });

  final String text;
  final int hidden;
  final VoidCallback onShowHidden;

  @override
  Widget build(BuildContext context) {
    final tokens = context.tokens;
    return Padding(
      padding: EdgeInsets.symmetric(vertical: tokens.spacing.s24),
      child: EmptyState(
        compact: true,
        icon: AppIcons.search,
        title: noResultsTitle(text),
        message: hidden > 0
            ? hiddenMatchesLine(hidden)
            : 'Try fewer letters, or another word.',
        actionLabel: hidden > 0 ? 'Show in Settings' : null,
        onAction: hidden > 0 ? onShowHidden : null,
      ),
    );
  }
}

/// The keys, and the recent searches (canvas): "↑↓ Move · Enter Open ·
/// Esc Close · Recent: tennis open · cup final".
class _Footer extends StatelessWidget {
  const new({
    required this.idle,
    required this.recent,
    required this.hasRecent,
  });

  final bool idle;
  final List<String> recent;

  /// The body lists the recent searches: Enter searches again, Delete
  /// removes one.
  final bool hasRecent;

  @override
  Widget build(BuildContext context) {
    final tokens = context.tokens;
    final colors = tokens.colors;
    final style = tokens.text.small.copyWith(color: colors.textTertiary);
    Widget key(Widget cap, String label) => Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        cap,
        SizedBox(width: tokens.spacing.s4 + 2),
        Text(label, style: style),
      ],
    );
    Widget arrow(AppIcons icon) => Container(
      width: 22,
      height: 20,
      decoration: BoxDecoration(
        color: colors.surface2,
        borderRadius: tokens.radii.xsAll,
        border: Border.all(color: colors.border),
      ),
      child: Center(
        child: AppIcon(icon, size: 12, color: colors.textSecondary),
      ),
    );
    return ExcludeSemantics(
      child: Container(
        height: tokens.search.footerHeight,
        padding: EdgeInsets.symmetric(horizontal: tokens.spacing.s20),
        decoration: BoxDecoration(
          color: colors.surface1,
          border: Border(top: BorderSide(color: colors.border)),
        ),
        child: Row(
          children: [
            key(
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  arrow(AppIcons.arrowUp),
                  SizedBox(width: tokens.spacing.s4),
                  arrow(AppIcons.arrowDown),
                ],
              ),
              'Move',
            ),
            SizedBox(width: tokens.spacing.s16 + 2),
            key(const Kbd('Enter'), hasRecent ? 'Search again' : 'Open'),
            if (hasRecent) ...[
              SizedBox(width: tokens.spacing.s16 + 2),
              key(const Kbd('Del'), 'Remove'),
            ],
            SizedBox(width: tokens.spacing.s16 + 2),
            key(const Kbd('Esc'), 'Close'),
            SizedBox(width: tokens.spacing.s16),
            Expanded(
              child: idle
                  ? const SizedBox.shrink()
                  : Text(
                      recentLine(recent),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      textAlign: TextAlign.right,
                      style: style,
                    ),
            ),
          ],
        ),
      ),
    );
  }
}
