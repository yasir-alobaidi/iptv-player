import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:iptv_player/app/destinations.dart';
import 'package:iptv_player/app/placeholder_screen.dart';
import 'package:iptv_player/design/app_icon.dart';

/// Movies: the poster grid and details (docs/05).
class MoviesScreen extends StatelessWidget {
  const new({super.key});

  @override
  Widget build(BuildContext context) => PlaceholderScreen(
    title: 'Movies',
    phase: 5,
    icon: AppIcons.movies,
    summary:
        'A poster grid of the movies your provider offers, with '
        'details and playback.',
    actionLabel: 'Add a source',
    onAction: () => context.go(AppDestination.settings.path),
  );
}
