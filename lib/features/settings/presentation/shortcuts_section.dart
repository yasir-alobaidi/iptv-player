import 'package:flutter/material.dart';
import 'package:iptv_player/app/shell/shortcut_list.dart';
import 'package:iptv_player/design/components.dart';
import 'package:iptv_player/design/tokens.dart';
import 'package:iptv_player/features/settings/presentation/settings_screen.dart';

/// Settings → Keyboard shortcuts (Phase 9 decision 5, sketch B): a list
/// to read, the same one F1 shows anywhere. One Tab stop, scrolled by
/// the keyboard.
class ShortcutsSection extends StatelessWidget {
  const new({super.key});

  @override
  Widget build(BuildContext context) {
    final tokens = context.tokens;
    return SettingsPanel(
      title: 'Keyboard shortcuts',
      subtitle: 'F1 shows this list anywhere.',
      body: ScrollPane.child(
        semanticLabel: 'Keyboard shortcuts',
        padding: EdgeInsets.all(tokens.spacing.s4),
        child: const ShortcutList(),
      ),
    );
  }
}
