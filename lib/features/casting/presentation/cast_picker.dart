import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:iptv_player/core/cast/cast_device.dart';
import 'package:iptv_player/core/cast/cast_readiness.dart';
import 'package:iptv_player/design/components.dart';
import 'package:iptv_player/design/tokens.dart';
import 'package:iptv_player/features/casting/data/casting_providers.dart';
import 'package:iptv_player/features/casting/presentation/add_cast_device_dialog.dart';
import 'package:iptv_player/features/casting/presentation/cast_actions.dart';
import 'package:iptv_player/features/casting/presentation/cast_help.dart';
import 'package:iptv_player/features/casting/presentation/cast_text.dart';
import 'package:iptv_player/features/casting/presentation/casting_view_state.dart';
import 'package:iptv_player/features/live_tv/data/live_tv_providers.dart';
import 'package:iptv_player/features/playback/data/playback_providers.dart';
import 'package:iptv_player/features/playback/domain/playable.dart';

/// Opens the device picker (canvas `Cast device picker`). [item] is what
/// will be cast; without one, whatever plays here moves to the TV.
Future<void> showCastPicker(
  BuildContext context, {
  Playable? item,
  Duration? from,
}) async {
  // C again while it shows: it is already there.
  if (CastPicker._shown > 0) return;
  await showAppDialog<void>(
    context,
    builder: (_) => CastPicker(item: item, from: from),
  );
}

/// The device picker: the devices on the network and the ones added by
/// address, with their model line and status; Add device by IP address;
/// "Device not showing?" help. One Tab stop for the list, arrows inside,
/// Enter casts, Esc closes. While a cast is on it offers Stop casting.
class CastPicker extends ConsumerStatefulWidget {
  const new({this.item, this.from, super.key});

  final Playable? item;
  final Duration? from;

  /// How long the picker looks before the help comes forward.
  static const searchTime = Duration(seconds: 10);

  /// Pickers on screen now.
  static int _shown = 0;

  @override
  ConsumerState<CastPicker> createState() => _CastPickerState();
}

class _CastPickerState extends ConsumerState<CastPicker> {
  Timer? _searching;
  bool _waited = false;

  @override
  void initState() {
    super.initState();
    CastPicker._shown++;
    _searching = Timer(CastPicker.searchTime, () {
      if (mounted) setState(() => _waited = true);
    });
  }

  @override
  void dispose() {
    CastPicker._shown--;
    _searching?.cancel();
    super.dispose();
  }

  void _close() => Navigator.of(context).pop();

  void _castTo(CastDevice device) {
    final container = ProviderScope.containerOf(context, listen: false);
    _close();
    unawaited(castTo(container, device, item: widget.item, from: widget.from));
  }

  Future<void> _stop() async {
    _close();
    await ref.read(castCoordinatorProvider).disconnect();
  }

  Future<void> _addDevice() async {
    await showAddCastDeviceDialog(context);
  }

  @override
  Widget build(BuildContext context) {
    final tokens = context.tokens;
    final colors = tokens.colors;
    final cast = tokens.cast;
    final devices = ref.watch(castDevicesProvider);
    final known = <String, KnownCastDevice>{
      for (final device
          in ref.watch(knownCastDevicesProvider).value ??
              const <KnownCastDevice>[])
        device.id: device,
    };
    final ready = ref.watch(castReadinessProvider) == CastReadiness.ready;
    final online = ref.watch(castNetworkAvailableProvider).value ?? true;
    final state = ref.watch(castingStateProvider).value;
    final castingTo = state?.active == true ? state?.device : null;
    final list = devices.value ?? const <CastDevice>[];
    final what = widget.item ?? state?.item ?? _playingHere();
    final programme = switch (what) {
      PlayableChannel(:final channel) =>
        ref.watch(nowNextProvider(channel)).value?.now?.title,
      _ => null,
    };

    return FocusPane(
      debugLabel: 'cast-picker',
      child: Center(
        child: Container(
          width: cast.pickerWidth,
          padding: EdgeInsets.all(cast.pickerPadding),
          decoration: BoxDecoration(
            color: colors.surface2,
            borderRadius: tokens.radii.lgAll,
            border: Border.all(color: colors.border),
            boxShadow: tokens.elevation.overlay,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _Header(
                subtitle: castWhatLine(what, programme: programme),
                onClose: _close,
              ),
              if (castingTo != null) ...[
                SizedBox(height: cast.pickerGap),
                _Casting(device: castingTo, onStop: () => unawaited(_stop())),
              ],
              SizedBox(height: cast.pickerGap),
              if (!ready)
                const AppBanner(
                  message: "This build can't cast: FFmpeg is missing.",
                  tone: BannerTone.error,
                )
              else if (!online)
                const AppBanner(
                  message:
                      "This computer isn't on a network. Connect it to the "
                      'same Wi-Fi as your TV.',
                  tone: BannerTone.warning,
                )
              else
                _Searching(found: list.isNotEmpty, waited: _waited),
              if (list.isNotEmpty) ...[
                SizedBox(height: cast.pickerGap),
                FocusPane(
                  tabStop: true,
                  debugLabel: 'cast-devices',
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      for (final (index, device) in list.indexed)
                        Padding(
                          padding: EdgeInsets.only(
                            top: index == 0 ? 0 : tokens.spacing.s4 + 2,
                          ),
                          child: _DeviceRow(
                            device: device,
                            known: known[device.id],
                            casting: castingTo?.id == device.id,
                            autofocus: index == 0,
                            onCast: ready ? () => _castTo(device) : null,
                          ),
                        ),
                    ],
                  ),
                ),
              ],
              SizedBox(height: cast.pickerGap),
              Container(height: 1, color: colors.border),
              SizedBox(height: cast.pickerGap),
              _AddByAddress(onPressed: () => unawaited(_addDevice())),
              SizedBox(height: cast.pickerGap),
              _Help(expanded: _waited && list.isEmpty),
            ],
          ),
        ),
      ),
    );
  }

  Playable? _playingHere() => ref.read(playbackCoordinatorProvider).state.item;
}

class _Header extends StatelessWidget {
  const new({required this.subtitle, required this.onClose});

  final String subtitle;
  final VoidCallback onClose;

  @override
  Widget build(BuildContext context) {
    final tokens = context.tokens;
    final colors = tokens.colors;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Semantics(
                header: true,
                child: Text(
                  'Cast to a device',
                  style: tokens.text.titleLarge.copyWith(
                    color: colors.textPrimary,
                  ),
                ),
              ),
              SizedBox(height: tokens.spacing.s4),
              Text(
                subtitle,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: tokens.text.caption.copyWith(
                  color: colors.textSecondary,
                ),
              ),
            ],
          ),
        ),
        SizedBox(width: tokens.spacing.s12),
        AppIconButton(
          icon: AppIcons.close,
          tooltip: 'Close',
          shortcut: 'Esc',
          size: 36,
          iconSize: 18,
          onPressed: onClose,
        ),
      ],
    );
  }
}

/// Casting already: to which device, and Stop casting.
class _Casting extends StatelessWidget {
  const new({required this.device, required this.onStop});

  final CastDevice device;
  final VoidCallback onStop;

  @override
  Widget build(BuildContext context) {
    final tokens = context.tokens;
    final colors = tokens.colors;
    return Container(
      padding: EdgeInsets.fromLTRB(
        tokens.spacing.s16,
        tokens.spacing.s12,
        tokens.spacing.s12,
        tokens.spacing.s12,
      ),
      decoration: BoxDecoration(
        color: colors.accentSoft,
        borderRadius: tokens.radii.mdAll,
        border: Border.all(color: colors.accentSoftBorder),
      ),
      child: Row(
        children: [
          AppIcon(AppIcons.castConnected, size: 18, color: colors.accentBase),
          SizedBox(width: tokens.spacing.s12),
          Expanded(
            child: Text(
              'Casting to ${device.name}',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: tokens.text.label
                  .withWeight(700)
                  .copyWith(color: colors.textPrimary),
            ),
          ),
          AppButton(
            label: 'Stop casting',
            icon: AppIcons.stop,
            variant: AppButtonVariant.dangerOutline,
            size: AppButtonSize.s,
            onPressed: onStop,
          ),
        ],
      ),
    );
  }
}

/// "Looking for devices on your network…", or after a while with none,
/// that none was found.
class _Searching extends StatelessWidget {
  const new({required this.found, required this.waited});

  final bool found;
  final bool waited;

  @override
  Widget build(BuildContext context) {
    final tokens = context.tokens;
    final colors = tokens.colors;
    final nothing = waited && !found;
    return Row(
      children: [
        if (nothing)
          AppIcon(AppIcons.alertCircle, size: 16, color: colors.warning)
        else
          const AppSpinner(),
        SizedBox(width: tokens.spacing.s8 + 2),
        Expanded(
          child: Text(
            nothing
                ? 'No devices found yet. Still looking…'
                : 'Looking for devices on your network…',
            style: tokens.text.caption.copyWith(color: colors.textTertiary),
          ),
        ),
      ],
    );
  }
}

class _DeviceRow extends StatelessWidget {
  const new({
    required this.device,
    required this.known,
    required this.casting,
    required this.autofocus,
    required this.onCast,
  });

  final CastDevice device;
  final KnownCastDevice? known;
  final bool casting;
  final bool autofocus;
  final VoidCallback? onCast;

  @override
  Widget build(BuildContext context) {
    final tokens = context.tokens;
    final colors = tokens.colors;
    final cast = tokens.cast;
    final status = castDeviceStatus(device, casting: casting);
    final statusColor = switch (status) {
      CastDeviceStatus.available => colors.success,
      CastDeviceStatus.busy => colors.warning,
      CastDeviceStatus.casting => colors.accentBase,
      CastDeviceStatus.notAnswering => colors.textTertiary,
    };
    final dim =
        status == CastDeviceStatus.busy ||
        status == CastDeviceStatus.notAnswering;
    final label = castDeviceStatusLabel(device, status);
    final model = castModelLine(device, known);
    return FocusableSurface(
      onPressed: onCast,
      enabled: onCast != null,
      autofocus: autofocus,
      borderRadius: tokens.radii.mdAll,
      hoverBackground: colors.surface3,
      semanticLabel: '${device.name}, $model, $label',
      builder: (context, states) => Opacity(
        opacity: dim ? 0.6 : 1,
        child: Container(
          padding: EdgeInsets.all(tokens.spacing.s12),
          decoration: BoxDecoration(
            color: states.highlighted ? colors.surface3 : null,
            borderRadius: tokens.radii.mdAll,
          ),
          child: Row(
            children: [
              Container(
                width: cast.deviceIconSize,
                height: cast.deviceIconSize,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: states.highlighted ? colors.border : colors.surface3,
                  borderRadius: BorderRadius.circular(cast.deviceIconRadius),
                ),
                child: AppIcon(
                  AppIcons.deviceTv,
                  size: 22,
                  color: states.highlighted
                      ? colors.textPrimary
                      : colors.textSecondary,
                ),
              ),
              SizedBox(width: tokens.spacing.s12 + 2),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      device.name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: tokens.text.bodyStrong.copyWith(
                        color: colors.textPrimary,
                      ),
                    ),
                    SizedBox(height: tokens.spacing.s4 - 1),
                    Text(
                      model,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: tokens.text.caption.copyWith(
                        color: colors.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
              SizedBox(width: tokens.spacing.s12),
              if (status != CastDeviceStatus.busy) ...[
                Container(
                  width: cast.statusDot,
                  height: cast.statusDot,
                  decoration: BoxDecoration(
                    color: statusColor,
                    borderRadius: tokens.radii.pillAll,
                  ),
                ),
                SizedBox(width: tokens.spacing.s4 + 2),
              ],
              Text(
                label,
                style: tokens.text.labelSmall
                    .withWeight(700)
                    .copyWith(color: statusColor),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _AddByAddress extends StatelessWidget {
  const new({required this.onPressed});

  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final tokens = context.tokens;
    final colors = tokens.colors;
    return FocusableSurface(
      onPressed: onPressed,
      borderRadius: tokens.radii.controlAll,
      hoverBackground: colors.surface3,
      semanticLabel: 'Add device by IP address',
      builder: (context, states) => Padding(
        padding: EdgeInsets.symmetric(
          horizontal: tokens.spacing.s12,
          vertical: tokens.spacing.s4 + 2,
        ),
        child: Row(
          children: [
            AppIcon(AppIcons.plus, size: 18, color: colors.textPrimary),
            SizedBox(width: tokens.spacing.s12),
            Text(
              'Add device by IP address',
              style: tokens.text.label
                  .withWeight(700)
                  .copyWith(color: colors.textPrimary),
            ),
          ],
        ),
      ),
    );
  }
}

/// "Device not showing?" with Troubleshoot; the whole help once nothing
/// was found for a while.
class _Help extends StatelessWidget {
  const new({required this.expanded});

  final bool expanded;

  @override
  Widget build(BuildContext context) {
    final tokens = context.tokens;
    final colors = tokens.colors;
    final style = tokens.text.caption
        .withWeight(400)
        .copyWith(color: colors.textSecondary, height: 19 / 13);
    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: tokens.spacing.s12 + 2,
        vertical: tokens.spacing.s12,
      ),
      decoration: BoxDecoration(
        color: colors.surface1,
        borderRadius: tokens.radii.controlAll,
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          AppIcon(AppIcons.info, size: 18, color: colors.textTertiary),
          SizedBox(width: tokens.spacing.s8 + 2),
          Expanded(
            child: expanded
                ? CastTroubleshooting(style: style)
                : Wrap(
                    crossAxisAlignment: WrapCrossAlignment.center,
                    children: [
                      Text(
                        'Device not showing? It needs to be on the same '
                        'Wi-Fi as this computer, and not on a guest '
                        'network. ',
                        style: style,
                      ),
                      FocusableSurface(
                        onPressed: () => unawaited(showCastHelp(context)),
                        borderRadius: tokens.radii.xsAll,
                        semanticLabel: 'Troubleshoot',
                        builder: (context, states) => Text(
                          'Troubleshoot',
                          style: style
                              .withWeight(700)
                              .copyWith(
                                color: states.highlighted
                                    ? colors.accentHover
                                    : colors.accentBase,
                              ),
                        ),
                      ),
                    ],
                  ),
          ),
        ],
      ),
    );
  }
}
