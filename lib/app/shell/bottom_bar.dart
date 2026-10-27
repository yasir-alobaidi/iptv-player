import 'package:flutter/material.dart';
import 'package:iptv_player/app/destinations.dart';
import 'package:iptv_player/design/components.dart';
import 'package:iptv_player/design/tokens.dart';

/// A phone's navigation, held upright (ADR-068): the destinations along
/// the bottom, where a thumb reaches, in the rail's order. Each is the
/// rail's icon over its label; the one shown in the accent, on the rail's
/// selected surface. Above the system's gesture bar or buttons.
///
/// Keyboard-first as everything (hard rule 5): the items are a focus pane
/// the arrows cross and Enter opens.
class ShellBottomBar extends StatelessWidget {
  const new({
    required this.current,
    required this.destinations,
    required this.onSelect,
    this.paneController,
    super.key,
  });

  /// The bar's own height, above the system's inset.
  static const height = 64.0;

  /// The most a phone's bar holds: more and the labels no longer fit at
  /// 360 px (Material's rule too).
  static const maxItems = 5;

  final AppDestination current;
  final List<AppDestination> destinations;
  final ValueChanged<AppDestination> onSelect;
  final FocusPaneController? paneController;

  @override
  Widget build(BuildContext context) {
    final tokens = context.tokens;
    final colors = tokens.colors;
    final inset = MediaQuery.paddingOf(context).bottom;

    return Container(
      padding: EdgeInsets.only(bottom: inset),
      decoration: BoxDecoration(
        color: colors.surface1,
        border: Border(top: BorderSide(color: colors.border)),
      ),
      child: FocusPane(
        controller: paneController,
        debugLabel: 'bottom-bar',
        child: SizedBox(
          height: context.scaled(height),
          child: Row(
            children: [
              for (final destination in destinations.take(maxItems))
                Expanded(
                  child: _BottomItem(
                    destination: destination,
                    selected: destination == current,
                    onPressed: () => onSelect(destination),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _BottomItem extends StatelessWidget {
  const new({
    required this.destination,
    required this.selected,
    required this.onPressed,
  });

  final AppDestination destination;
  final bool selected;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final tokens = context.tokens;
    final colors = tokens.colors;
    final foreground = selected ? colors.accentBase : colors.textSecondary;

    return FocusLanding(
      on: selected,
      child: Padding(
        padding: EdgeInsets.symmetric(
          horizontal: tokens.spacing.s4,
          vertical: tokens.spacing.s8,
        ),
        child: FocusableSurface(
          onPressed: onPressed,
          background: selected ? colors.surface3 : null,
          hoverBackground: colors.surface3,
          borderRadius: tokens.radii.mdAll,
          semanticLabel: destination.label,
          builder: (context, states) => Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              AppIcon(destination.icon, size: 22, color: foreground),
              Text(
                destination.label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: tokens.text.caption.copyWith(
                  color: selected ? colors.textPrimary : foreground,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
