import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:iptv_player/app/router.dart';
import 'package:iptv_player/app/shell/app_toasts.dart';
import 'package:iptv_player/app/shell/shell_state.dart';
import 'package:iptv_player/app/shortcuts.dart';
import 'package:iptv_player/app/still_watching.dart';
import 'package:iptv_player/core/app_identity.dart';
import 'package:iptv_player/core/core_providers.dart';
import 'package:iptv_player/core/images/artwork_providers.dart';
import 'package:iptv_player/core/images/artwork_scope.dart';
import 'package:iptv_player/core/platform/form_factor.dart';
import 'package:iptv_player/design/components.dart';
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
    final onTv = ref.watch(formFactorProvider) == FormFactor.tv;
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
          tv: onTv,
        ),
        // The theme changes at once: an accent that fades in over
        // Material's 200 ms is motion nobody asked for.
        themeAnimationDuration: Duration.zero,
        routerConfig: ref.watch(routerProvider),
        builder: (context, child) {
          final app = AppTextScale(
            // A TV's text is larger, to read from across a room (ADR-026).
            scale: look.textScale * (onTv ? TvCanvas.textScale : 1),
            child: AppGlobalShortcuts(
              child: AppToasts(child: child ?? const SizedBox.shrink()),
            ),
          );
          final tv = TvMode(
            on: onTv,
            child: KeyHints(
              shown: !onTv,
              child: onTv
                  ? TvCanvas(
                      child: StillWatching(child: TvSelectKey(child: app)),
                    )
                  : app,
            ),
          );
          // The keyboard's language, kept (ADR-027); only its own
          // dependents rebuild when it changes.
          return Consumer(
            child: tv,
            builder: (context, ref, tv) => RemoteKeyboardLanguage(
              language: ref.watch(remoteKeyboardChoiceProvider),
              onChanged: ref.read(remoteKeyboardChoiceProvider.notifier).choose,
              child: tv!,
            ),
          );
        },
      ),
    );
  }
}
