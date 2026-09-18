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
    super.key,
  });

  static const collapsedWidth = 72.0;
  static const expandedWidth = 240.0;
  static const itemHeight = 48.0;

  final AppDestination current;
  final ValueChanged<AppDestination> onSelect;
  final bool expanded;
  final VoidCallback onToggleExpanded;

  /// Lets the rest of the shell bring focus back to the item the user
  /// left from.
  final FocusPaneController? paneController;

  /// Right arrow at the rail's edge hands focus to the content.
  final VoidCallback? onLeaveRight;

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
                for (final destination in AppDestination.primary) ...[
                  _RailItem(
                    destination: destination,
                    selected: destination == current,
                    expanded: expanded,
                    onPressed: () => onSelect(destination),
                  ),
                  SizedBox(height: tokens.spacing.s8),
                ],
                const Spacer(),
                _ToggleItem(expanded: expanded, onPressed: onToggleExpanded),
                SizedBox(height: tokens.spacing.s8),
                _RailItem(
                  destination: AppDestination.settings,
                  selected: current == AppDestination.settings,
                  expanded: expanded,
                  onPressed: () => onSelect(AppDestination.settings),
                ),
              ],
            ),
          ),
        ),
      ),
    );
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
class _RailItem extends StatelessWidget {
  const new({
    required this.destination,
    required this.selected,
    required this.expanded,
    required this.onPressed,
  });

  final AppDestination destination;
  final bool selected;
  final bool expanded;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) => _RailSlot(
    selected: selected,
    child: _RailButton(
      icon: destination.icon,
      label: destination.label,
      tooltip: destination.label,
      shortcut: destination.shortcut,
      selected: selected,
      expanded: expanded,
      onPressed: onPressed,
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
