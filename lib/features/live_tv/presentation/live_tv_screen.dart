import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:iptv_player/app/destinations.dart';
import 'package:iptv_player/app/placeholder_screen.dart';
import 'package:iptv_player/design/app_icon.dart';

/// Live TV: categories, channels and the preview pane (docs/05).
class LiveTvScreen extends StatelessWidget {
  const new({super.key});

  @override
  Widget build(BuildContext context) => PlaceholderScreen(
    title: 'Live TV',
    phase: 3,
    icon: AppIcons.liveTv,
    summary:
        'Categories, channels and a live preview. Add a provider to '
        'see your channels.',
    actionLabel: 'Add a source',
    onAction: () => context.go(AppDestination.settings.path),
  );
}
