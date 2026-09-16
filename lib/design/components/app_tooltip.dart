import 'package:flutter/material.dart';
import 'package:iptv_player/design/components/kbd.dart';
import 'package:iptv_player/design/tokens.dart';

/// Tooltip with an optional shortcut keycap. The surface styling comes
/// from the theme's [TooltipThemeData]; only the content is built here.
class AppTooltip extends StatelessWidget {
  const new({
    required this.message,
    required this.child,
    this.shortcut,
    super.key,
  });

  final String message;
  final Widget child;

  /// Key hint shown after the message, e.g. `Ctrl K`.
  final String? shortcut;

  @override
  Widget build(BuildContext context) {
    final hint = shortcut;
    if (hint == null) {
      return Tooltip(message: message, child: child);
    }

    final tokens = context.tokens;
    return Tooltip(
      richMessage: WidgetSpan(
        alignment: PlaceholderAlignment.middle,
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              message,
              style: tokens.text.caption.copyWith(
                color: tokens.colors.textPrimary,
              ),
            ),
            SizedBox(width: tokens.spacing.s8),
            Kbd(hint),
          ],
        ),
      ),
      child: child,
    );
  }
}
