import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:iptv_player/app/destinations.dart';
import 'package:iptv_player/app/placeholder_screen.dart';
import 'package:iptv_player/design/app_icon.dart';

/// Home: the rows of continue watching, favorites and recently added (docs/05).
class HomeScreen extends StatelessWidget {
  const new({super.key});

  @override
  Widget build(BuildContext context) => PlaceholderScreen(
    title: 'Home',
    phase: 5,
    icon: AppIcons.home,
    summary:
        'Rows of what you were watching and what is new. Add a '
        'provider to fill them.',
    actionLabel: 'Add a source',
    onAction: () => context.go(AppDestination.settings.path),
  );
}
