import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:iptv_player/core/cast/cast_device.dart';
import 'package:iptv_player/core/cast/cast_discovery.dart';
import 'package:iptv_player/design/components.dart';
import 'package:iptv_player/design/tokens.dart';
import 'package:iptv_player/features/casting/data/casting_providers.dart';

/// Sketch E: "Add a device by address". The address is asked who it is
/// (nothing shows on its screen); a device with a screen is kept and
/// listed from then on. Returns it, or null.
Future<CastDevice?> showAddCastDeviceDialog(BuildContext context) =>
    showAppDialog<CastDevice>(
      context,
      builder: (_) => const AddCastDeviceDialog(),
    );

class AddCastDeviceDialog extends ConsumerStatefulWidget {
  const new({super.key});

  @override
  ConsumerState<AddCastDeviceDialog> createState() =>
      _AddCastDeviceDialogState();
}

class _AddCastDeviceDialogState extends ConsumerState<AddCastDeviceDialog> {
  final _address = TextEditingController();
  bool _checking = false;
  String? _error;
  String? _found;

  @override
  void dispose() {
    _address.dispose();
    super.dispose();
  }

  Future<void> _add() async {
    if (_checking) return;
    final text = _address.text.trim();
    final address = CastAddress.tryParse(text);
    if (address == null) {
      setState(() {
        _error = 'Type an address like 192.168.1.60.';
        _found = null;
      });
      return;
    }
    setState(() {
      _checking = true;
      _error = null;
      _found = null;
    });
    final answer = await ref.read(castAddressCheckProvider).check(address);
    if (!mounted) return;
    switch (answer) {
      case CastDeviceAnswered(:final device):
        final model = device.model == null ? '' : ' (${device.model})';
        setState(() => _found = 'Found "${device.name}"$model.');
        final kept = await ref.read(castDeviceStoreProvider).addManual(device);
        if (!mounted) return;
        if (kept.failureOrNull != null) {
          setState(() {
            _checking = false;
            _error = "Couldn't keep it. Try again.";
          });
          return;
        }
        Navigator.of(context).pop(device);
      case CastAudioOnlyAnswered(:final name):
        setState(() {
          _checking = false;
          _error = '"$name" is a speaker: it has no screen to cast to.';
        });
      case CastNoAnswer():
        setState(() {
          _checking = false;
          _error = 'Nothing answered at $text.';
        });
    }
  }

  @override
  Widget build(BuildContext context) {
    final tokens = context.tokens;
    final colors = tokens.colors;
    return AppDialog(
      title: 'Add a device by address',
      subtitle:
          "Its IP address is in the TV's settings, under Network or About.",
      width: tokens.cast.pickerWidth,
      focusButtons: false,
      primaryLabel: _checking ? 'Looking…' : 'Add',
      onPrimary: _checking ? null : () => unawaited(_add()),
      secondaryLabel: 'Cancel',
      onSecondary: () => Navigator.of(context).pop(),
      onClose: () => Navigator.of(context).pop(),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          AppTextField(
            controller: _address,
            autofocus: true,
            hint: '192.168.1.60',
            errorText: _error,
            enabled: !_checking,
            onSubmitted: (_) => unawaited(_add()),
          ),
          if (_checking || _found != null) ...[
            SizedBox(height: tokens.spacing.s12),
            Row(
              children: [
                if (_found == null)
                  const AppSpinner()
                else
                  AppIcon(AppIcons.check, size: 16, color: colors.success),
                SizedBox(width: tokens.spacing.s8),
                Expanded(
                  child: Text(
                    _found ?? 'Looking at ${_address.text.trim()}…',
                    style: tokens.text.caption.copyWith(
                      color: colors.textSecondary,
                    ),
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}
