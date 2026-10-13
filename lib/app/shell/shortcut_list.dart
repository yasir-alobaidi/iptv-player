import 'dart:async';

import 'package:flutter/material.dart';
import 'package:iptv_player/app/shortcut_table.dart';
import 'package:iptv_player/design/components.dart';
import 'package:iptv_player/design/tokens.dart';

/// The keyboard shortcuts, grouped by where they work (sketch B): each
/// row an action and its keycaps. Two columns of groups where there is
/// room, one where there isn't. Not scrollable itself: its owner puts it
/// in a [ScrollPane].
class ShortcutList extends StatelessWidget {
  const new({this.groups = shortcutTable, super.key});

  final List<ShortcutGroup> groups;

  /// Two columns from this width, at the canvas's text size.
  static const _twoColumnsFrom = 760.0;

  @override
  Widget build(BuildContext context) {
    final tokens = context.tokens;
    return LayoutBuilder(
      builder: (context, constraints) {
        if (constraints.maxWidth < context.scaled(_twoColumnsFrom)) {
          return _column(context, groups);
        }
        final (left, right) = _halves(groups);
        return Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(child: _column(context, left)),
            SizedBox(width: tokens.spacing.s40),
            Expanded(child: _column(context, right)),
          ],
        );
      },
    );
  }

  /// The split that leaves the two columns nearest the same length, the
  /// groups kept in order.
  static (List<ShortcutGroup>, List<ShortcutGroup>) _halves(
    List<ShortcutGroup> groups,
  ) {
    // A heading takes about as much room as two rows.
    int rows(Iterable<ShortcutGroup> part) =>
        part.fold(0, (sum, group) => sum + group.entries.length + 2);
    var best = 1;
    var bestGap = 1 << 30;
    for (var i = 1; i < groups.length; i++) {
      final gap = (rows(groups.take(i)) - rows(groups.skip(i))).abs();
      if (gap < bestGap) {
        bestGap = gap;
        best = i;
      }
    }
    return (groups.sublist(0, best), groups.sublist(best));
  }

  Widget _column(BuildContext context, List<ShortcutGroup> groups) {
    final tokens = context.tokens;
    final colors = tokens.colors;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        for (final group in groups) ...[
          Padding(
            padding: EdgeInsets.only(
              top: group == groups.first ? 0 : tokens.spacing.s20,
              bottom: tokens.spacing.s8,
            ),
            child: Semantics(
              header: true,
              child: Text(
                group.title.toUpperCase(),
                style: tokens.text.overline.copyWith(
                  color: colors.textTertiary,
                ),
              ),
            ),
          ),
          for (final entry in group.entries) _Row(entry: entry),
        ],
      ],
    );
  }
}

class _Row extends StatelessWidget {
  const new({required this.entry});

  final ShortcutEntry entry;

  @override
  Widget build(BuildContext context) {
    final tokens = context.tokens;
    final colors = tokens.colors;
    final word = tokens.text.caption.copyWith(color: colors.textTertiary);
    return MergeSemantics(
      child: Semantics(
        label: '${entry.action}: ${entry.keysText}',
        child: ExcludeSemantics(
          child: Container(
            padding: EdgeInsets.symmetric(vertical: tokens.spacing.s8 - 2),
            decoration: BoxDecoration(
              border: Border(bottom: BorderSide(color: colors.surface3)),
            ),
            child: Row(
              children: [
                // Two columns, as a table reads: the words, then the
                // keys from one edge. Keys that don't fit wrap under
                // themselves.
                Expanded(
                  flex: 5,
                  child: Text(
                    entry.action,
                    style: tokens.text.label
                        .withWeight(500)
                        .copyWith(color: colors.textEmphasis),
                  ),
                ),
                SizedBox(width: tokens.spacing.s16),
                Expanded(
                  flex: 4,
                  child: Wrap(
                    crossAxisAlignment: WrapCrossAlignment.center,
                    spacing: tokens.spacing.s4,
                    runSpacing: tokens.spacing.s4,
                    children: [
                      for (final (index, combo) in entry.keys.indexed) ...[
                        if (index > 0 && entry.between.isNotEmpty)
                          Padding(
                            padding: EdgeInsets.symmetric(
                              horizontal: tokens.spacing.s4,
                            ),
                            child: Text(entry.between, style: word),
                          ),
                        for (final key in combo) Kbd(key),
                      ],
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// The F1 panel: the same list over whatever is on screen, the player
/// included. Esc closes it; nothing under it stops.
Future<void> showShortcutsPanel(BuildContext context) => showAppDialog<void>(
  context,
  builder: (context) => AppDialog(
    title: 'Keyboard shortcuts',
    subtitle: 'Esc closes this list. It is also in Settings.',
    width: 640,
    onClose: () => Navigator.of(context).pop(),
    child: Padding(
      padding: EdgeInsets.only(bottom: context.tokens.spacing.s20),
      child: ScrollPane.child(
        semanticLabel: 'Keyboard shortcuts',
        autofocus: true,
        padding: EdgeInsets.all(context.tokens.spacing.s4),
        child: const ShortcutList(),
      ),
    ),
  ),
);

/// Whether the F1 panel is showing, so a second F1 doesn't stack one on
/// another.
final class ShortcutsPanelGate {
  bool _open = false;

  bool get isOpen => _open;

  /// Shows the panel unless it already shows.
  void show(BuildContext context) {
    if (_open) return;
    _open = true;
    unawaited(showShortcutsPanel(context).whenComplete(() => _open = false));
  }
}
