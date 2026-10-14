import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:iptv_player/core/app_identity.dart';
import 'package:iptv_player/core/core_providers.dart';
import 'package:iptv_player/core/platform/app_version.dart';
import 'package:iptv_player/design/components.dart';
import 'package:iptv_player/design/tokens.dart';
import 'package:iptv_player/features/diagnostics/presentation/log_view.dart';
import 'package:iptv_player/features/diagnostics/presentation/report_view.dart';
import 'package:iptv_player/features/settings/presentation/licenses_dialog.dart';
import 'package:iptv_player/features/settings/presentation/settings_screen.dart';

/// Which of the two the lower part of the page shows.
enum _View { report, log }

/// Settings → About & diagnostics (Phase 9 steps 2 and 4, sketch D): the
/// name, the version this build was made as and the system, the
/// licences, and under them the diagnostics report or the log.
///
/// The sketch stacks the report over the log. Here they are two views of
/// the same space, chosen with one control: stacked, each got about a
/// hundred pixels of height in the smallest window (ADR-016, step 4).
class AboutSection extends ConsumerStatefulWidget {
  const new({super.key});

  @override
  ConsumerState<AboutSection> createState() => _AboutSectionState();
}

class _AboutSectionState extends ConsumerState<AboutSection> {
  _View _view = _View.report;

  @override
  Widget build(BuildContext context) {
    final tokens = context.tokens;
    final colors = tokens.colors;
    // The version file is a few bytes in the bundle: until it is read,
    // and if it can't be, the line says so rather than showing nothing.
    final version = ref.watch(appVersionProvider).value;

    return SettingsPanel(
      title: 'About & diagnostics',
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
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
                      appDescription,
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
          SizedBox(height: tokens.spacing.s20),
          Align(
            alignment: Alignment.centerLeft,
            child: SegmentedControl<_View>(
              options: const [
                SegmentOption(value: _View.report, label: 'Diagnostics'),
                SegmentOption(value: _View.log, label: 'Log'),
              ],
              value: _view,
              onChanged: (view) => setState(() => _view = view),
            ),
          ),
          SizedBox(height: tokens.spacing.s12),
          Expanded(
            child: switch (_view) {
              _View.report => const ReportView(),
              _View.log => const LogView(),
            },
          ),
        ],
      ),
    );
  }
}

/// "Bijou 0.1.0 (build 1) · Linux". [version] null is still being
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
