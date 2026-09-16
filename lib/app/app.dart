import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:iptv_player/app/router.dart';
import 'package:iptv_player/app/shortcuts.dart';
import 'package:iptv_player/design/theme.dart';

/// Root widget: the theme, the router, and the shortcuts that work
/// everywhere.
///
/// The shortcuts wrap the router's navigator rather than the shell, so
/// they also fire on top of the search overlay and the gallery.
class IptvPlayerApp extends ConsumerWidget {
  const new({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return MaterialApp.router(
      title: 'IPTV Player',
      debugShowCheckedModeBanner: false,
      theme: buildAppTheme(),
      routerConfig: ref.watch(routerProvider),
      builder: (context, child) =>
          AppGlobalShortcuts(child: child ?? const SizedBox.shrink()),
    );
  }
}
