import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:iptv_player/app/failure_message.dart';
import 'package:iptv_player/core/core_providers.dart';
import 'package:iptv_player/core/result.dart';
import 'package:iptv_player/core/text/format.dart';
import 'package:iptv_player/design/appearance.dart';
import 'package:iptv_player/design/components.dart';
import 'package:iptv_player/design/tokens.dart';
import 'package:iptv_player/features/settings/data/appearance_providers.dart';
import 'package:iptv_player/features/settings/presentation/setting_row.dart';
import 'package:iptv_player/features/settings/presentation/settings_screen.dart';

/// Settings → Appearance (Phase 9 decision 2, sketch A): the accent, the
/// text size, the density, reduce motion and the clock. Every change
/// shows at once and is saved behind it; each "System" says what the
/// desktop answers.
class AppearanceSection extends ConsumerStatefulWidget {
  const new({super.key});

  @override
  ConsumerState<AppearanceSection> createState() => _AppearanceSectionState();
}

class _AppearanceSectionState extends ConsumerState<AppearanceSection> {
  String? _saveError;
  var _retrying = false;

  Future<void> _change(AppearanceSettings settings) async {
    final result = await ref
        .read(appearanceControllerProvider.notifier)
        .change(settings);
    if (!mounted) return;
    setState(() {
      _saveError = switch (result) {
        Err(:final failure) =>
          "Couldn't save that change, so it lasts until you close the app. "
              '${failureMessage(failure)}',
        Ok() => null,
      };
    });
  }

  Future<void> _retry() async {
    setState(() => _retrying = true);
    await ref.read(appearanceControllerProvider.notifier).retry();
    if (mounted) setState(() => _retrying = false);
  }

  @override
  Widget build(BuildContext context) {
    final tokens = context.tokens;
    final state = ref.watch(appearanceControllerProvider);
    final settings = state.settings;
    final desktop = ref.watch(desktopAppearanceProvider);
    final look = ref.watch(appearanceProvider);
    final now = ref.watch(appClockProvider)();

    return SettingsPanel(
      title: 'Appearance',
      subtitle: 'Changes show at once.',
      body: ListView(
        children: [
          if (state.readFailure case final failure?) ...[
            AppBanner(
              message:
                  "Couldn't read your settings, so these are the usual "
                  'ones. ${failureMessage(failure)}',
              tone: BannerTone.warning,
              actionLabel: _retrying ? null : 'Try again',
              onAction: _retrying ? null : () => unawaited(_retry()),
            ),
            SizedBox(height: tokens.spacing.s16),
          ],
          if (_saveError case final error?) ...[
            AppBanner(message: error, tone: BannerTone.error),
            SizedBox(height: tokens.spacing.s16),
          ],
          SettingRow(
            title: 'Accent',
            description: 'The colour of what is chosen, focused or playing.',
            control: SegmentedControl<AppAccent>(
              options: [
                for (final accent in AppAccent.values)
                  SegmentOption(
                    value: accent,
                    label: accent.label,
                    swatch: accent.base,
                  ),
              ],
              value: settings.accent,
              onChanged: (accent) =>
                  unawaited(_change(settings.copyWith(accent: accent))),
            ),
          ),
          SettingRow(
            title: 'Text size',
            description: textSizeNote(settings.textSize, desktop),
            control: SegmentedControl<TextSizeChoice>(
              options: [
                for (final size in TextSizeChoice.values)
                  SegmentOption(value: size, label: size.label),
              ],
              value: settings.textSize,
              onChanged: (size) =>
                  unawaited(_change(settings.copyWith(textSize: size))),
            ),
          ),
          SettingRow(
            title: 'Density',
            description:
                'Compact fits more rows in the long lists: channels, '
                'categories and the Guide.',
            control: SegmentedControl<AppDensity>(
              options: [
                for (final density in AppDensity.values)
                  SegmentOption(value: density, label: density.label),
              ],
              value: settings.density,
              onChanged: (density) =>
                  unawaited(_change(settings.copyWith(density: density))),
            ),
          ),
          SettingRow(
            title: 'Reduce motion',
            description: reduceMotionNote(settings.reduceMotion, desktop),
            control: SegmentedControl<SystemSwitch>(
              options: [
                for (final choice in SystemSwitch.values)
                  SegmentOption(value: choice, label: choice.label),
              ],
              value: settings.reduceMotion,
              onChanged: (choice) =>
                  unawaited(_change(settings.copyWith(reduceMotion: choice))),
            ),
          ),
          SettingRow(
            title: 'Clock',
            description: clockNote(settings.clock, look.timeStyle, now),
            control: SegmentedControl<ClockChoice>(
              options: [
                for (final choice in ClockChoice.values)
                  SegmentOption(value: choice, label: choice.label),
              ],
              value: settings.clock,
              onChanged: (choice) =>
                  unawaited(_change(settings.copyWith(clock: choice))),
            ),
          ),
        ],
      ),
    );
  }
}

/// `115 %`: a text scale as the page writes it.
String _percent(double scale) => '${(scale * 100).round()} %';

/// Under Text size: what System means here, and the cap when the desktop
/// is past it.
String textSizeNote(TextSizeChoice choice, SystemAppearance desktop) {
  const follows = "System follows your desktop's text size, up to 130 %.";
  if (choice != TextSizeChoice.system) return follows;
  final asked = desktop.textScale;
  if (!asked.isFinite) return follows;
  if (asked > AppearanceSettings.maxTextScale) {
    return '$follows Your desktop is at ${_percent(asked)}, so this is 130 %.';
  }
  if (asked < AppearanceSettings.minTextScale) {
    return '$follows Your desktop is at ${_percent(asked)}, so this is 100 %.';
  }
  return '$follows Your desktop is at ${_percent(asked)}.';
}

/// Under Reduce motion: what it does, and what the desktop says.
String reduceMotionNote(SystemSwitch choice, SystemAppearance desktop) {
  const does = 'No zoom or shimmer, and nothing moves for longer than a blink.';
  if (choice != SystemSwitch.system) return does;
  return desktop.reduceMotion
      ? '$does Your desktop has animations off, so this is on.'
      : '$does Your desktop has animations on, so this is off.';
}

/// Under Clock: the time now, as it will be written.
String clockNote(ClockChoice choice, TimeStyle style, DateTime now) {
  final sample = 'It is ${formatClock(now, style)}';
  return choice == ClockChoice.system
      ? '$sample, as your desktop writes it.'
      : '$sample.';
}
