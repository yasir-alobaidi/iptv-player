import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:iptv_player/app/destinations.dart';
import 'package:iptv_player/design/components.dart';
import 'package:iptv_player/design/tokens.dart';

/// The shell's left rail (docs/05, canvas): 72 px collapsed, 240 px
/// expanded, with the app mark on top, the destinations, a spacer and
/// Settings at the bottom.
///
/// The canvas draws only the collapsed rail, so the expanded one keeps
/// the same 48 px items and adds the labels.
class NavRail extends StatelessWidget {
  const new({
    required this.current,
    required this.onSelect,
    required this.expanded,
    required this.onToggleExpanded,
    this.paneController,
    this.onLeaveRight,
    this.onRest,
    this.showToggle = true,
    this.destinations,
    super.key,
  });

  static const collapsedWidth = 72.0;
  static const expandedWidth = 240.0;
  static const itemHeight = 48.0;

  /// How long the focus rests on an item before [onRest] opens it: long
  /// enough that a press passing over an item opens nothing (a remote's
  /// held arrow moves about every 50 ms), short enough to feel at once.
  static const openAfter = Duration(milliseconds: 300);

  final AppDestination current;
  final ValueChanged<AppDestination> onSelect;
  final bool expanded;
  final VoidCallback onToggleExpanded;

  /// Lets the rest of the shell bring focus back to the item the user
  /// left from.
  final FocusPaneController? paneController;

  /// Right arrow at the rail's edge hands focus to the content.
  final VoidCallback? onLeaveRight;

  /// The focus rested on an item for [openAfter]: open it, as OK does. A
  /// TV's (the user: "when I move it will take me to the page"); null on
  /// the desktop, where only Enter or a click opens one. Never called for
  /// the destination shown, so a rest never takes it back to its root.
  final ValueChanged<AppDestination>? onRest;

  /// The expand/collapse toggle; not on a TV, whose 960-wide screen is
  /// too narrow for the expanded rail (docs/05: under 1280 it collapses).
  final bool showToggle;

  /// The destinations above the spacer; [AppDestination.primary] when
  /// null.
  final List<AppDestination>? destinations;

  @override
  Widget build(BuildContext context) {
    final tokens = context.tokens;
    final colors = tokens.colors;

    return Container(
      width: expanded ? expandedWidth : collapsedWidth,
      padding: EdgeInsets.symmetric(vertical: tokens.spacing.s16),
      decoration: BoxDecoration(
        color: colors.surface1,
        border: Border(right: BorderSide(color: colors.border)),
      ),
      child: FocusPane(
        controller: paneController,
        debugLabel: 'nav-rail',
        child: Shortcuts(
          shortcuts: const {
            SingleActivator(LogicalKeyboardKey.arrowRight): _LeaveRailIntent(),
          },
          child: Actions(
            actions: {
              _LeaveRailIntent: CallbackAction<_LeaveRailIntent>(
                onInvoke: (_) {
                  onLeaveRight?.call();
                  return null;
                },
              ),
            },
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _AppMark(expanded: expanded),
                SizedBox(height: tokens.spacing.s16),
                for (final destination
                    in destinations ?? AppDestination.primary) ...[
                  _RailItem(
                    destination: destination,
                    selected: destination == current,
                    expanded: expanded,
                    onPressed: () => onSelect(destination),
                    onRest: _restOn(destination),
                  ),
                  SizedBox(height: tokens.spacing.s8),
                ],
                const Spacer(),
                if (showToggle) ...[
                  _ToggleItem(expanded: expanded, onPressed: onToggleExpanded),
                  SizedBox(height: tokens.spacing.s8),
                ],
                _RailItem(
                  destination: AppDestination.settings,
                  selected: current == AppDestination.settings,
                  expanded: expanded,
                  onPressed: () => onSelect(AppDestination.settings),
                  onRest: _restOn(AppDestination.settings),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  VoidCallback? _restOn(AppDestination destination) {
    final rest = onRest;
    return rest == null ? null : () => rest(destination);
  }
}

/// Right arrow inside the rail: leave it for the content pane.
class _LeaveRailIntent extends Intent {
  const new();
}

/// The app mark from the canvas: a 40 px accent tile with a play glyph,
/// plus the app name once the rail is expanded.
class _AppMark extends StatelessWidget {
  const new({required this.expanded});

  final bool expanded;

  @override
  Widget build(BuildContext context) {
    final tokens = context.tokens;

    // The same 12 px gutter the items use, so the mark lines up with
    // the icons below it. The rail's 1 px border eats into the 72 px, so
    // a 16 px gutter would leave the 40 px mark one pixel short.
    return Padding(
      padding: EdgeInsets.symmetric(horizontal: tokens.spacing.s12),
      child: Row(
        mainAxisAlignment: expanded
            ? MainAxisAlignment.start
            : MainAxisAlignment.center,
        children: [
          if (expanded)
            const Expanded(child: AppMark(showName: true))
          else
            const AppMark(),
        ],
      ),
    );
  }
}

/// One destination. The active item gets the canvas's 3 px accent bar on
/// the rail's outer edge and an accent icon on [AppColors.surface3].
class _RailItem extends StatefulWidget {
  const new({
    required this.destination,
    required this.selected,
    required this.expanded,
    required this.onPressed,
    this.onRest,
  });

  final AppDestination destination;
  final bool selected;
  final bool expanded;
  final VoidCallback onPressed;

  /// The focus rested here for [NavRail.openAfter]; null: a rest opens
  /// nothing.
  final VoidCallback? onRest;

  @override
  State<_RailItem> createState() => _RailItemState();
}

class _RailItemState extends State<_RailItem> {
  Timer? _rest;

  @override
  void didUpdateWidget(_RailItem oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.onRest == null) _stopResting();
  }

  @override
  void dispose() {
    _stopResting();
    super.dispose();
  }

  void _stopResting() {
    _rest?.cancel();
    _rest = null;
  }

  /// Each arrival starts the wait over and each departure ends it, so
  /// quick presses or a held arrow open only the item the focus stops on.
  void _onFocusChange(bool focused) {
    _stopResting();
    if (!focused || widget.onRest == null) return;
    _rest = Timer(NavRail.openAfter, () {
      _rest = null;
      // The screen shown already: nothing to open. OK on it goes back to
      // its root, which a rest must not do: the focus passes over Movies
      // on its way up the rail from a film's page under it.
      if (mounted && !widget.selected) widget.onRest?.call();
    });
  }

  // The rail's first stop when it is entered with nothing to return to:
  // the screen shown.
  @override
  Widget build(BuildContext context) => FocusLanding(
    on: widget.selected,
    // Always in the tree, the desktop's too: a wrapper only on a TV would
    // change the item's place in the tree, and its focus node with it.
    child: Focus(
      canRequestFocus: false,
      skipTraversal: true,
      // The button below says what it is and whether it has the focus.
      includeSemantics: false,
      onFocusChange: _onFocusChange,
      child: _RailSlot(
        selected: widget.selected,
        child: _RailButton(
          icon: widget.destination.icon,
          label: widget.destination.label,
          tooltip: widget.destination.label,
          shortcut: widget.destination.shortcut,
          selected: widget.selected,
          expanded: widget.expanded,
          onPressed: widget.onPressed,
        ),
      ),
    ),
  );
}

/// Collapses and expands the rail. docs/05 asks for a toggle; the canvas
/// has none, so it sits above Settings where it disturbs the drawn layout
/// least.
class _ToggleItem extends StatelessWidget {
  const new({required this.expanded, required this.onPressed});

  final bool expanded;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final label = expanded ? 'Collapse menu' : 'Expand menu';
    return _RailSlot(
      selected: false,
      child: _RailButton(
        icon: expanded ? AppIcons.chevronLeft : AppIcons.chevronRight,
        label: label,
        tooltip: label,
        selected: false,
        expanded: expanded,
        onPressed: onPressed,
      ),
    );
  }
}

/// A full-width row that holds the indicator bar and the item itself, so
/// the bar can sit at the rail's edge outside the item's box.
class _RailSlot extends StatelessWidget {
  const new({required this.selected, required this.child});

  final bool selected;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final tokens = context.tokens;

    return SizedBox(
      height: NavRail.itemHeight,
      child: Stack(
        children: [
          // The indicator is always in the tree, transparent when the
          // item is not selected, and never `if (selected)`. A
          // conditional child changes the Stack's child count, so the
          // item below it moves index, its element is rebuilt and its
          // focus node — with the keyboard focus — is thrown away on
          // every destination change. Animating the colour also lets the
          // bar slide in rather than appear.
          Positioned(
            left: 0,
            top: tokens.spacing.s12,
            bottom: tokens.spacing.s12,
            child: AnimatedContainer(
              duration: tokens.motion.fast,
              curve: tokens.motion.fastCurve,
              width: 3,
              decoration: BoxDecoration(
                color: selected ? tokens.colors.accentBase : Colors.transparent,
                borderRadius: BorderRadius.circular(3),
              ),
            ),
          ),
          Padding(
            padding: EdgeInsets.symmetric(horizontal: tokens.spacing.s12),
            child: child,
          ),
        ],
      ),
    );
  }
}

class _RailButton extends StatelessWidget {
  const new({
    required this.icon,
    required this.label,
    required this.tooltip,
    required this.selected,
    required this.expanded,
    required this.onPressed,
    this.shortcut,
  });

  final AppIcons icon;
  final String label;
  final String tooltip;
  final bool selected;
  final bool expanded;
  final VoidCallback onPressed;
  final String? shortcut;

  @override
  Widget build(BuildContext context) {
    final tokens = context.tokens;
    final colors = tokens.colors;
    final foreground = selected ? colors.accentBase : colors.textSecondary;

    return AppTooltip(
      message: tooltip,
      shortcut: shortcut,
      child: FocusableSurface(
        onPressed: onPressed,
        background: selected ? colors.surface3 : null,
        hoverBackground: colors.surface3,
        borderRadius: tokens.radii.mdAll,
        semanticLabel: label,
        builder: (context, states) => Container(
          height: NavRail.itemHeight,
          padding: expanded
              ? EdgeInsets.symmetric(horizontal: tokens.spacing.s12)
              : EdgeInsets.zero,
          alignment: expanded ? Alignment.centerLeft : Alignment.center,
          child: Row(
            mainAxisSize: expanded ? MainAxisSize.max : MainAxisSize.min,
            children: [
              AppIcon(icon, size: 22, color: foreground),
              if (expanded) ...[
                SizedBox(width: tokens.spacing.s12),
                Expanded(
                  child: Text(
                    label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    // Variable fonts take their weight from
                    // fontVariations, so a selected label is marked by
                    // colour rather than by a heavier copyWith weight.
                    style: tokens.text.label.copyWith(
                      color: selected ? colors.textPrimary : foreground,
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
