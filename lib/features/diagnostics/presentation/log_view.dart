import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:iptv_player/app/failure_message.dart';
import 'package:iptv_player/core/core_providers.dart';
import 'package:iptv_player/core/notices/app_notices.dart';
import 'package:iptv_player/core/platform/file_reveal.dart';
import 'package:iptv_player/core/result.dart';
import 'package:iptv_player/core/text/format.dart';
import 'package:iptv_player/design/components.dart';
import 'package:iptv_player/design/tokens.dart';
import 'package:iptv_player/features/diagnostics/data/diagnostics_providers.dart';
import 'package:iptv_player/features/diagnostics/domain/log_lines.dart';

/// The log, read inside the app (Phase 9 decision 8, sketch D): the
/// newest lines at once and older ones as you scroll up; All or only
/// warnings and errors; a text filter; it follows new lines while you
/// are at the bottom and holds still when you have scrolled up.
class LogView extends ConsumerStatefulWidget {
  const new({super.key});

  /// How often the file is looked at for new lines.
  static const pollEvery = Duration(seconds: 1);

  /// A line's height, at the canvas's text size.
  static const rowHeight = 24.0;

  /// Narrower than this (a phone, ADR-068) a line's time, level and tag
  /// go above its message, which then has the width to itself.
  static const stackedBelow = 560.0;

  @override
  ConsumerState<LogView> createState() => _LogViewState();
}

class _LogViewState extends ConsumerState<LogView> {
  /// The lines are drawn two to a row (a phone's width): see
  /// [LogView.stackedBelow].
  var _stacked = false;

  /// How high [row] is drawn, at the text size in use.
  double _extentOf(LogRow row) =>
      context.scaled(LogView.rowHeight) *
      (_stacked && !row.continuation ? 2 : 1);
  final _scroll = ScrollController();
  final GlobalKey _list = GlobalKey();
  final _filter = TextEditingController();
  Timer? _typing;
  Timer? _poll;

  var _query = const LogQuery();

  /// Oldest first.
  List<LogRow> _rows = const [];
  LogCursor? _older;
  LogCursor? _end;
  AppFailure? _failure;
  var _loading = true;
  var _loadingOlder = false;

  /// Bumped by every fresh read: an answer to an older one is dropped.
  var _generation = 0;

  LogReader get _reader => ref.read(logReaderProvider);

  @override
  void initState() {
    super.initState();
    _scroll.addListener(_onScroll);
    unawaited(_load());
    _poll = Timer.periodic(LogView.pollEvery, (_) => unawaited(_follow()));
  }

  @override
  void dispose() {
    _typing?.cancel();
    _poll?.cancel();
    _scroll.dispose();
    _filter.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    final generation = ++_generation;
    setState(() {
      _loading = true;
      _failure = null;
    });
    final page = await _reader.page(_query);
    if (!mounted || generation != _generation) return;
    setState(() {
      _loading = false;
      switch (page) {
        case Ok(:final value):
          _rows = value.rows;
          _older = value.older;
          _end = value.end;
        case Err(:final failure):
          _rows = const [];
          _older = null;
          _end = null;
          _failure = failure;
      }
    });
    if (_scroll.hasClients) _scroll.jumpTo(0);
  }

  /// Lays the list out again after its lines changed. Rows of a fixed
  /// height are updated in place when lines are added, and that alone
  /// doesn't lay the list out: how far it scrolls would stay as it was
  /// until the next scroll, and a key press at the old top would find
  /// nowhere to go.
  void _layOutList() {
    RenderObject? viewport;
    void find(RenderObject object) {
      if (viewport != null) return;
      if (object is RenderViewportBase) {
        viewport = object;
      } else {
        object.visitChildren(find);
      }
    }

    _list.currentContext?.findRenderObject()?.visitChildren(find);
    viewport?.markNeedsLayout();
  }

  /// Older lines, when the top is near.
  void _onScroll() {
    if (!_scroll.hasClients || _loadingOlder || _older == null) return;
    final position = _scroll.position;
    if (position.maxScrollExtent - position.pixels > 600) return;
    unawaited(_loadOlder());
  }

  Future<void> _loadOlder() async {
    final before = _older;
    if (before == null || _loadingOlder) return;
    final generation = _generation;
    _loadingOlder = true;
    final page = await _reader.page(_query, before: before);
    _loadingOlder = false;
    if (!mounted || generation != _generation) return;
    if (page case Ok(:final value)) {
      // At the far end of a list drawn from the bottom: nothing on
      // screen moves.
      setState(() {
        _rows = [...value.rows, ..._rows];
        _older = value.older;
      });
      _layOutList();
    }
  }

  /// What was written since the last look.
  Future<void> _follow() async {
    final end = _end;
    if (end == null || _loading) return;
    final generation = _generation;
    final page = await _reader.since(end, _query);
    if (!mounted || generation != _generation) return;
    final value = page.valueOrNull;
    if (value == null) return;
    if (value.rotated) {
      // The file filled up and a new one was started: from the end again.
      unawaited(_load());
      return;
    }
    _end = value.end;
    if (value.rows.isEmpty) return;
    // Scrolled up: the lines on screen stay where they are, the new ones
    // arrive below them, out of sight. At the bottom: they come into
    // view.
    if (_scroll.hasClients && _scroll.offset > 0) {
      _scroll.position.correctBy(
        value.rows.fold<double>(0, (sum, row) => sum + _extentOf(row)),
      );
    }
    setState(() => _rows = [..._rows, ...value.rows]);
    _layOutList();
  }

  void _setProblemsOnly(bool only) {
    if (only == _query.problemsOnly) return;
    _query = LogQuery(problemsOnly: only, text: _query.text);
    unawaited(_load());
  }

  void _onFilterChanged(String text) {
    _typing?.cancel();
    _typing = Timer(const Duration(milliseconds: 250), () {
      if (!mounted || text.trim() == _query.text) return;
      _query = LogQuery(problemsOnly: _query.problemsOnly, text: text.trim());
      unawaited(_load());
    });
  }

  void _clearFilter() {
    _typing?.cancel();
    _filter.clear();
    _query = const LogQuery();
    unawaited(_load());
  }

  Future<void> _copyShown() async {
    final text = [for (final row in _rows) row.raw].join('\n');
    final notices = ref.read(appNoticesProvider);
    try {
      await Clipboard.setData(ClipboardData(text: text));
    } on Object {
      notices.show(
        AppNotice("Couldn't reach the clipboard", tone: NoticeTone.error),
      );
      return;
    }
    final lines = _rows.length;
    notices.show(
      AppNotice(
        'Copied ${formatCount(lines)} ${lines == 1 ? 'line' : 'lines'}',
        tone: NoticeTone.success,
      ),
    );
  }

  Future<void> _openFolder(String file) async {
    final opened = await ref.read(fileRevealProvider).showInFolder(file);
    if (!opened && mounted) {
      ref
          .read(appNoticesProvider)
          .show(
            AppNotice("Couldn't open the log folder", tone: NoticeTone.error),
          );
    }
  }

  @override
  Widget build(BuildContext context) {
    final tokens = context.tokens;
    final file = ref.watch(logReaderProvider).currentFile;
    final filter = AppTextField(
      controller: _filter,
      hint: 'Filter…',
      onChanged: _onFilterChanged,
    );
    final kind = SegmentedControl<bool>(
      options: const [
        SegmentOption(value: false, label: 'All'),
        SegmentOption(value: true, label: 'Warnings and errors'),
      ],
      value: _query.problemsOnly,
      onChanged: _setProblemsOnly,
    );
    final copy = AppButton(
      label: 'Copy shown',
      variant: AppButtonVariant.secondary,
      size: AppButtonSize.s,
      onPressed: _rows.isEmpty ? null : () => unawaited(_copyShown()),
    );

    return LayoutBuilder(
      builder: (context, constraints) {
        _stacked = constraints.maxWidth < LogView.stackedBelow;
        if (!_stacked) return _wide(context, file, filter, kind, copy);
        // A phone (ADR-068): the kinds across the width, then the filter
        // with Copy shown beside it. It has no folder of its own to show.
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            kind,
            SizedBox(height: tokens.spacing.s8),
            Row(
              children: [
                Expanded(child: filter),
                SizedBox(width: tokens.spacing.s8),
                copy,
              ],
            ),
            SizedBox(height: tokens.spacing.s12),
            Expanded(child: _body(context, hasFile: file != null)),
          ],
        );
      },
    );
  }

  Widget _wide(
    BuildContext context,
    String? file,
    Widget filter,
    Widget kind,
    Widget copy,
  ) {
    final tokens = context.tokens;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Wrap(
          alignment: WrapAlignment.spaceBetween,
          crossAxisAlignment: WrapCrossAlignment.center,
          spacing: tokens.spacing.s12,
          runSpacing: tokens.spacing.s8,
          children: [
            Wrap(
              crossAxisAlignment: WrapCrossAlignment.center,
              spacing: tokens.spacing.s12,
              runSpacing: tokens.spacing.s8,
              children: [
                kind,
                SizedBox(width: context.scaled(220), child: filter),
              ],
            ),
            Wrap(
              spacing: tokens.spacing.s8,
              runSpacing: tokens.spacing.s8,
              children: [
                copy,
                AppButton(
                  label: 'Open log folder',
                  variant: AppButtonVariant.secondary,
                  size: AppButtonSize.s,
                  onPressed: file == null
                      ? null
                      : () => unawaited(_openFolder(file)),
                ),
              ],
            ),
          ],
        ),
        SizedBox(height: tokens.spacing.s12),
        Expanded(child: _body(context, hasFile: file != null)),
      ],
    );
  }

  Widget _body(BuildContext context, {required bool hasFile}) {
    final tokens = context.tokens;
    final colors = tokens.colors;
    if (!hasFile) {
      return const EmptyState(
        icon: AppIcons.info,
        title: 'This run keeps no log file',
        message:
            "The app couldn't make its folder when it started, so "
            'nothing is being written.',
        compact: true,
      );
    }
    if (_failure case final failure?) {
      return ErrorState(
        title: "The log couldn't be read",
        message: failureMessage(failure),
        details: failure.detail,
        retryLabel: 'Try again',
        onRetry: () => unawaited(_load()),
        compact: true,
      );
    }
    if (_loading && _rows.isEmpty) {
      return Semantics(
        label: 'Reading the log',
        container: true,
        // Cut off by a short box, not past it.
        child: ClipRect(
          child: OverflowBox(
            alignment: Alignment.topLeft,
            maxHeight: double.infinity,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                for (final width in const [560.0, 420.0, 500.0, 380.0, 460.0])
                  Padding(
                    padding: EdgeInsets.only(bottom: tokens.spacing.s8),
                    child: Skeleton(width: width),
                  ),
              ],
            ),
          ),
        ),
      );
    }
    if (_rows.isEmpty) {
      return _query.isEmpty
          ? const EmptyState(
              icon: AppIcons.info,
              title: 'The log is empty',
              message: 'Nothing has been written yet.',
              compact: true,
            )
          : EmptyState(
              icon: AppIcons.search,
              title: 'Nothing in the log matches',
              message: _query.problemsOnly && _query.text.isEmpty
                  ? 'No warnings or errors are in the log.'
                  : 'No line holds what you typed.',
              actionLabel: 'Show everything',
              onAction: _clearFilter,
              compact: true,
            );
    }
    final extent = context.scaled(LogView.rowHeight);
    final rows = _rows;
    return DecoratedBox(
      decoration: BoxDecoration(
        color: colors.bg,
        borderRadius: tokens.radii.controlAll,
        border: Border.all(color: colors.border),
      ),
      child: ScrollPane(
        semanticLabel: 'The log, newest line last',
        controller: _scroll,
        reverse: true,
        // A log shorter than its box starts at the top of it, as a page
        // does; a longer one fills it.
        builder: (context, controller) => Align(
          alignment: Alignment.topCenter,
          child: ListView.builder(
            key: _list,
            controller: controller,
            // From the bottom: the newest line is where a log is read,
            // and older lines added at the far end move nothing on
            // screen.
            reverse: true,
            shrinkWrap: true,
            padding: EdgeInsets.symmetric(vertical: tokens.spacing.s8),
            itemExtent: _stacked ? null : extent,
            itemExtentBuilder: _stacked
                ? (index, _) => index < rows.length
                      ? _extentOf(rows[rows.length - 1 - index])
                      : null
                : null,
            itemCount: rows.length,
            itemBuilder: (context, index) => _LogRowView(
              row: rows[rows.length - 1 - index],
              stacked: _stacked,
            ),
          ),
        ),
      ),
    );
  }
}

class _LogRowView extends StatelessWidget {
  const new({required this.row, this.stacked = false});

  final LogRow row;

  /// The time, level and tag on a line above the message (a phone).
  final bool stacked;

  /// `20:14:03.412`, in local time: a log is read against a clock on the
  /// wall, and always to the millisecond.
  static String _time(DateTime at) {
    final local = at.toLocal();
    String pad(int value, [int width = 2]) => '$value'.padLeft(width, '0');
    return '${pad(local.hour)}:${pad(local.minute)}:${pad(local.second)}.'
        '${pad(local.millisecond, 3)}';
  }

  @override
  Widget build(BuildContext context) {
    final tokens = context.tokens;
    final colors = tokens.colors;
    final mono = tokens.text.mono;
    final tone = switch (row.level) {
      LogLevel.warning => colors.warning,
      LogLevel.error || LogLevel.fatal => colors.danger,
      _ => colors.textTertiary,
    };
    final message = Text(
      row.text,
      maxLines: 1,
      softWrap: false,
      overflow: TextOverflow.ellipsis,
      style: mono.copyWith(
        color: row.continuation
            ? colors.textTertiary
            : row.level.isProblem
            ? colors.textPrimary
            : colors.textSecondary,
      ),
    );
    if (stacked) {
      final extent = context.scaled(LogView.rowHeight);
      return Semantics(
        label: row.raw,
        excludeSemantics: true,
        child: Padding(
          padding: EdgeInsets.symmetric(horizontal: tokens.spacing.s12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (!row.continuation)
                SizedBox(
                  height: extent,
                  child: Row(
                    children: [
                      if (row.time case final time?) ...[
                        Text(
                          _time(time),
                          maxLines: 1,
                          softWrap: false,
                          style: mono.copyWith(color: colors.textTertiary),
                        ),
                        SizedBox(width: tokens.spacing.s8),
                      ],
                      Text(
                        row.level.label,
                        maxLines: 1,
                        softWrap: false,
                        style: mono.withWeight(700).copyWith(color: tone),
                      ),
                      SizedBox(width: tokens.spacing.s8),
                      Expanded(
                        child: Text(
                          row.tag,
                          maxLines: 1,
                          softWrap: false,
                          overflow: TextOverflow.ellipsis,
                          style: mono.copyWith(color: colors.textTertiary),
                        ),
                      ),
                    ],
                  ),
                ),
              SizedBox(
                height: extent,
                child: Padding(
                  padding: EdgeInsets.only(
                    left: row.continuation ? tokens.spacing.s16 : 0,
                  ),
                  child: Align(
                    alignment: AlignmentDirectional.centerStart,
                    child: message,
                  ),
                ),
              ),
            ],
          ),
        ),
      );
    }
    return Semantics(
      label: row.raw,
      excludeSemantics: true,
      child: Padding(
        padding: EdgeInsets.symmetric(horizontal: tokens.spacing.s12),
        child: Row(
          children: [
            SizedBox(
              width: context.scaled(104),
              child: row.time == null
                  ? null
                  : Text(
                      _time(row.time!),
                      maxLines: 1,
                      softWrap: false,
                      style: mono.copyWith(color: colors.textTertiary),
                    ),
            ),
            SizedBox(
              width: context.scaled(52),
              child: row.continuation
                  ? null
                  : Text(
                      row.level.label,
                      maxLines: 1,
                      softWrap: false,
                      style: mono.withWeight(700).copyWith(color: tone),
                    ),
            ),
            if (!row.continuation)
              SizedBox(
                width: context.scaled(128),
                child: Text(
                  row.tag,
                  maxLines: 1,
                  softWrap: false,
                  overflow: TextOverflow.ellipsis,
                  style: mono.copyWith(color: colors.textTertiary),
                ),
              ),
            Expanded(child: message),
          ],
        ),
      ),
    );
  }
}
