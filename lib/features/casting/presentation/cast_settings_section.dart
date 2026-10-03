import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:iptv_player/app/failure_message.dart';
import 'package:iptv_player/core/cast/cast_device.dart';
import 'package:iptv_player/core/cast/cast_planner.dart';
import 'package:iptv_player/core/result.dart';
import 'package:iptv_player/design/components.dart';
import 'package:iptv_player/design/tokens.dart';
import 'package:iptv_player/features/casting/data/casting_providers.dart';
import 'package:iptv_player/features/casting/presentation/add_cast_device_dialog.dart';
import 'package:iptv_player/features/casting/presentation/cast_help.dart';
import 'package:iptv_player/features/casting/presentation/cast_text.dart';
import 'package:iptv_player/features/casting/presentation/casting_view_state.dart';
import 'package:iptv_player/features/settings/presentation/settings_screen.dart';

/// Settings → Casting (sketch C): the devices the app keeps, each with
/// its HEVC choice, what it taught (Reset) and Forget; Dolby passthrough,
/// Low-latency mode and Smooth interlaced; the ports a firewall must let
/// in. Every change is saved at once and applies to the next cast.
class CastSettingsSection extends ConsumerStatefulWidget {
  const new({super.key});

  @override
  ConsumerState<CastSettingsSection> createState() =>
      _CastSettingsSectionState();
}

class _CastSettingsSectionState extends ConsumerState<CastSettingsSection> {
  String? _error;

  Future<void> _run(Future<Result<void>> change, String what) async {
    final result = await change;
    if (!mounted) return;
    setState(() {
      _error = switch (result) {
        Err(:final failure) => "Couldn't $what. ${failureMessage(failure)}",
        Ok() => null,
      };
    });
  }

  void _settings(CastSettings settings) => unawaited(
    _run(
      ref.read(castSettingsControllerProvider.notifier).update(settings),
      'save that change',
    ),
  );

  @override
  Widget build(BuildContext context) {
    final tokens = context.tokens;
    final colors = tokens.colors;
    final settings = ref.watch(castSettingsControllerProvider);
    final devices = ref.watch(knownCastDevicesProvider);
    final store = ref.read(castDeviceStoreProvider);

    return SettingsPanel(
      title: 'Casting',
      subtitle: 'Applies to the next thing you cast.',
      actions: [
        AppButton(
          label: 'Add device by address',
          icon: AppIcons.plus,
          variant: AppButtonVariant.secondary,
          size: AppButtonSize.s,
          onPressed: () => unawaited(showAddCastDeviceDialog(context)),
        ),
      ],
      body: ListView(
        children: [
          if (_error case final error?) ...[
            AppBanner(message: error, tone: BannerTone.error),
            SizedBox(height: tokens.spacing.s16),
          ],
          Text(
            'DEVICES',
            style: tokens.text.overline.copyWith(color: colors.textTertiary),
          ),
          SizedBox(height: tokens.spacing.s8),
          ...switch (devices) {
            AsyncData(:final value) when value.isEmpty => [
              Padding(
                padding: EdgeInsets.symmetric(vertical: tokens.spacing.s12),
                child: Text(
                  'No devices kept yet. A device is kept once you cast to '
                  'it or add it by address.',
                  style: tokens.text.caption.copyWith(
                    color: colors.textTertiary,
                  ),
                ),
              ),
            ],
            AsyncData(:final value) => [
              for (final device in value)
                _DeviceSettings(
                  device: device,
                  onHevc: (hevc) => unawaited(
                    _run(
                      store.setHevcSupport(device.id, hevc),
                      'change ${device.name}',
                    ),
                  ),
                  onReset: () => unawaited(
                    _run(
                      store.setLearned(device.id, const CastLearned()),
                      'reset ${device.name}',
                    ),
                  ),
                  onForget: () => unawaited(
                    _run(store.forget(device.id), 'forget ${device.name}'),
                  ),
                ),
            ],
            AsyncError() => [
              const AppBanner(
                message: "Couldn't read the devices.",
                tone: BannerTone.error,
              ),
            ],
            _ => [const SkeletonRow()],
          },
          SizedBox(height: tokens.spacing.s16),
          _Row(
            title: 'Dolby passthrough',
            description:
                'Send Dolby audio untouched, for a TV on an AV receiver. '
                'Off converts it to AAC, which every TV plays.',
            control: _OnOff(
              value: settings.dolbyPassthrough,
              onChanged: (on) =>
                  _settings(settings.copyWith(dolbyPassthrough: on)),
            ),
          ),
          _Row(
            title: 'Low-latency mode',
            description:
                'One continuous stream for every channel: less delay, but '
                'a restart shows on the TV.',
            control: _OnOff(
              value: settings.lowLatency,
              onChanged: (on) => _settings(settings.copyWith(lowLatency: on)),
            ),
          ),
          _Row(
            title: 'Smooth interlaced',
            description:
                'Re-encode interlaced channels with deinterlacing. Smoother '
                'motion, at the cost of this computer working harder.',
            control: _OnOff(
              value: settings.smoothInterlaced,
              onChanged: (on) =>
                  _settings(settings.copyWith(smoothInterlaced: on)),
            ),
          ),
          _Row(
            title: 'Firewall',
            description:
                'Your TV reaches this computer on ports $castPortRange.',
            control: AppButton(
              label: 'Firewall help',
              variant: AppButtonVariant.secondary,
              size: AppButtonSize.s,
              onPressed: () => unawaited(showCastHelp(context)),
            ),
          ),
        ],
      ),
    );
  }
}

class _DeviceSettings extends StatelessWidget {
  const new({
    required this.device,
    required this.onHevc,
    required this.onReset,
    required this.onForget,
  });

  final KnownCastDevice device;
  final ValueChanged<HevcSupport> onHevc;
  final VoidCallback onReset;
  final VoidCallback onForget;

  @override
  Widget build(BuildContext context) {
    final tokens = context.tokens;
    final colors = tokens.colors;
    final learned = castLearnedLine(device.learned);
    final where = [
      if (device.manual) 'Added by address' else ?device.model,
      device.host,
    ].join(' · ');
    return Container(
      padding: EdgeInsets.symmetric(vertical: tokens.spacing.s12),
      decoration: BoxDecoration(
        border: Border(bottom: BorderSide(color: colors.surface3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              AppIcon(AppIcons.deviceTv, size: 18, color: colors.textSecondary),
              SizedBox(width: tokens.spacing.s12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      device.name,
                      style: tokens.text.label
                          .withWeight(700)
                          .copyWith(color: colors.textPrimary),
                    ),
                    Text(
                      where,
                      style: tokens.text.caption.copyWith(
                        color: colors.textTertiary,
                      ),
                    ),
                  ],
                ),
              ),
              AppButton(
                label: 'Forget',
                variant: AppButtonVariant.ghost,
                size: AppButtonSize.s,
                onPressed: onForget,
              ),
            ],
          ),
          SizedBox(height: tokens.spacing.s12),
          Wrap(
            spacing: tokens.spacing.s16,
            runSpacing: tokens.spacing.s8,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              Text(
                'HEVC',
                style: tokens.text.caption.copyWith(
                  color: colors.textSecondary,
                ),
              ),
              SegmentedControl<HevcSupport>(
                options: const [
                  SegmentOption(value: HevcSupport.auto, label: 'Automatic'),
                  SegmentOption(value: HevcSupport.yes, label: 'Yes'),
                  SegmentOption(value: HevcSupport.no, label: 'No'),
                ],
                value: device.hevc,
                onChanged: onHevc,
              ),
              if (learned != null) ...[
                Text(
                  learned,
                  style: tokens.text.caption.copyWith(
                    color: colors.textSecondary,
                  ),
                ),
                AppButton(
                  label: 'Reset',
                  variant: AppButtonVariant.secondary,
                  size: AppButtonSize.s,
                  onPressed: onReset,
                ),
              ],
            ],
          ),
        ],
      ),
    );
  }
}

/// A setting: its name and what it does on the left, the control on the
/// right (as Settings → Playback lays them out).
class _Row extends StatelessWidget {
  const new({
    required this.title,
    required this.description,
    required this.control,
  });

  final String title;
  final String description;
  final Widget control;

  @override
  Widget build(BuildContext context) {
    final tokens = context.tokens;
    final colors = tokens.colors;
    return Container(
      padding: EdgeInsets.symmetric(vertical: tokens.spacing.s16),
      decoration: BoxDecoration(
        border: Border(bottom: BorderSide(color: colors.surface3)),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: tokens.text.label.copyWith(color: colors.textPrimary),
                ),
                SizedBox(height: tokens.spacing.s4),
                Text(
                  description,
                  style: tokens.text.caption.copyWith(
                    color: colors.textTertiary,
                  ),
                ),
              ],
            ),
          ),
          SizedBox(width: tokens.spacing.s24),
          control,
        ],
      ),
    );
  }
}

class _OnOff extends StatelessWidget {
  const new({required this.value, required this.onChanged});

  final bool value;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) => SegmentedControl<bool>(
    options: const [
      SegmentOption(value: false, label: 'Off'),
      SegmentOption(value: true, label: 'On'),
    ],
    value: value,
    onChanged: onChanged,
  );
}
