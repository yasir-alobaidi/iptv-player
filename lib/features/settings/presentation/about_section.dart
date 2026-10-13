import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:iptv_player/core/core_providers.dart';
import 'package:iptv_player/core/platform/app_version.dart';
import 'package:iptv_player/design/components.dart';
import 'package:iptv_player/design/tokens.dart';
import 'package:iptv_player/features/settings/presentation/licenses_dialog.dart';
import 'package:iptv_player/features/settings/presentation/settings_screen.dart';

/// Settings → About & diagnostics (Phase 9, sketch D). Step 2 builds
/// About: the name, the version this build was made as, the system, and
/// the licences. The diagnostics and the log viewer join it in step 4.
class AboutSection extends ConsumerWidget {
  const new({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tokens = context.tokens;
    final colors = tokens.colors;
    // The version file is a few bytes in the bundle: until it is read,
    // and if it can't be, the line says so rather than showing nothing.
    final version = ref.watch(appVersionProvider).value;

    return SettingsPanel(
      title: 'About & diagnostics',
      body: ListView(
        children: [
          Row(
            children: [
              const AppMark(),
              SizedBox(width: tokens.spacing.s16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      aboutLine(version, defaultTargetPlatform),
                      style: tokens.text.bodyStrong.copyWith(
                        color: colors.textPrimary,
                      ),
                    ),
                    SizedBox(height: tokens.spacing.s4),
                    Text(
                      'A player for your own IPTV subscription. It comes '
                      'with no channels, movies or series of its own.',
                      style: tokens.text.caption.copyWith(
                        color: colors.textTertiary,
                      ),
                    ),
                  ],
                ),
              ),
              SizedBox(width: tokens.spacing.s16),
              AppButton(
                label: 'Licences',
                variant: AppButtonVariant.secondary,
                size: AppButtonSize.s,
                onPressed: () => unawaited(showLicensesDialog(context)),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

/// "IPTV Player 0.1.0 (build 1) · Linux". [version] null is still being
/// read.
String aboutLine(AppVersion? version, TargetPlatform platform) => [
  if (version == null)
    AppMark.appName
  else
    '${AppMark.appName} ${version.label}',
  systemName(platform),
].join(' · ');

/// The system the app runs on, as its users call it.
String systemName(TargetPlatform platform) => switch (platform) {
  TargetPlatform.linux => 'Linux',
  TargetPlatform.windows => 'Windows',
  TargetPlatform.macOS => 'macOS',
  TargetPlatform.android => 'Android',
  TargetPlatform.iOS => 'iOS',
  TargetPlatform.fuchsia => 'Fuchsia',
};
