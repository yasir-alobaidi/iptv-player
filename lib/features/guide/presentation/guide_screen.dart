import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:iptv_player/app/destinations.dart';
import 'package:iptv_player/app/placeholder_screen.dart';
import 'package:iptv_player/design/app_icon.dart';

/// Guide: the EPG grid (docs/05).
class GuideScreen extends StatelessWidget {
  const new({super.key});

  @override
  Widget build(BuildContext context) => PlaceholderScreen(
    title: 'The guide',
    phase: 4,
    icon: AppIcons.guide,
    summary:
        'A time grid of what is on now and next, built from your '
        'XMLTV guide.',
    actionLabel: 'Add a source',
    onAction: () => context.go(AppDestination.settings.path),
  );
}
