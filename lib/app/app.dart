import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:iptv_player/app/router.dart';
import 'package:iptv_player/app/shell/app_toasts.dart';
import 'package:iptv_player/app/shortcuts.dart';
import 'package:iptv_player/core/app_identity.dart';
import 'package:iptv_player/core/images/artwork_providers.dart';
import 'package:iptv_player/core/images/artwork_scope.dart';
import 'package:iptv_player/design/text_scale.dart';
import 'package:iptv_player/design/theme.dart';
import 'package:iptv_player/features/settings/data/appearance_providers.dart';

/// Root widget: the theme, the router, and the shortcuts that work
/// everywhere.
///
/// The look comes from Settings → Appearance (Phase 9): the accent, the
/// density, reduce motion and the clock through the theme's tokens, the
/// text size through [AppTextScale] above everything the router draws.
///
/// The shortcuts wrap the router's navigator rather than the shell, so
/// they also fire on top of the search overlay and the gallery.
class IptvPlayerApp extends ConsumerWidget {
  const new({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final look = ref.watch(appearanceProvider);
    return ArtworkScope(
      images: ref.watch(artworkImagesProvider),
      child: MaterialApp.router(
        title: appName,
        debugShowCheckedModeBanner: false,
        theme: buildAppTheme(
          accent: look.accent,
          density: look.density,
          reduceMotion: look.reduceMotion,
          timeStyle: look.timeStyle,
        ),
        // The theme changes at once: an accent that fades in over
        // Material's 200 ms is motion nobody asked for.
        themeAnimationDuration: Duration.zero,
        routerConfig: ref.watch(routerProvider),
        builder: (context, child) => AppTextScale(
          scale: look.textScale,
          child: AppGlobalShortcuts(
            child: AppToasts(child: child ?? const SizedBox.shrink()),
          ),
        ),
      ),
    );
  }
}
