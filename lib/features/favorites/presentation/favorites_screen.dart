import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:iptv_player/app/destinations.dart';
import 'package:iptv_player/app/placeholder_screen.dart';
import 'package:iptv_player/design/app_icon.dart';

/// Favorites: the channels, movies and series you starred (docs/05).
class FavoritesScreen extends StatelessWidget {
  const new({super.key});

  @override
  Widget build(BuildContext context) => PlaceholderScreen(
    title: 'Favorites',
    phase: 6,
    icon: AppIcons.starFilled,
    summary: 'The channels, movies and series you star will collect here.',
    actionLabel: 'Add a source',
    onAction: () => context.go(AppDestination.settings.path),
  );
}
