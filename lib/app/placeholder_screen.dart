import 'package:flutter/material.dart';
import 'package:iptv_player/design/components.dart';
import 'package:iptv_player/design/tokens.dart';

/// A destination that has no screen yet. Every route exists from step 4 on
/// so the shell, the shortcuts and the keyboard path can be used and
/// tested in full; the phase that builds the screen replaces this.
///
/// It is still an [EmptyState] with a focusable action, so hard rules 4
/// and 5 hold on every route from the start.
class PlaceholderScreen extends StatelessWidget {
  const new({
    required this.title,
    required this.phase,
    required this.icon,
    required this.summary,
    this.actionLabel,
    this.onAction,
    super.key,
  });

  final String title;

  /// The phase in docs/08 that builds this screen.
  final int phase;
  final AppIcons icon;

  /// One line about what will be here, so the screen is not a dead end.
  final String summary;

  /// The next thing the user can actually do today. Until a source
  /// exists every screen would be empty anyway, so most of these point at
  /// Settings → Sources.
  final String? actionLabel;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) {
    final tokens = context.tokens;

    return FocusPane(
      debugLabel: 'screen-$title',
      child: Padding(
        padding: EdgeInsets.all(tokens.spacing.s16),
        child: DecoratedBox(
          decoration: BoxDecoration(
            color: tokens.colors.surface1,
            borderRadius: tokens.radii.lgAll,
            border: Border.all(color: tokens.colors.borderSubtle),
          ),
          child: EmptyState(
            icon: icon,
            title: '$title comes in Phase $phase',
            message: summary,
            actionLabel: actionLabel,
            onAction: onAction,
          ),
        ),
      ),
    );
  }
}
