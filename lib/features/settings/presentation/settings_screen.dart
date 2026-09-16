import 'package:flutter/material.dart';
import 'package:iptv_player/app/placeholder_screen.dart';
import 'package:iptv_player/design/app_icon.dart';

/// Settings: sources, playback, casting, downloads, appearance and
/// diagnostics (docs/05). Phase 2 adds the Sources page first.
class SettingsScreen extends StatelessWidget {
  const new({super.key});

  @override
  Widget build(BuildContext context) => const PlaceholderScreen(
    title: 'Settings',
    phase: 9,
    icon: AppIcons.settings,
    summary:
        'Sources, playback, casting, downloads, the guide and diagnostics. '
        'Phase 2 adds adding a provider.',
  );
}
