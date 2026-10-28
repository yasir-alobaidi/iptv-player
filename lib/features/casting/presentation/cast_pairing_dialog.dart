import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:iptv_player/core/cast/cast_device.dart';
import 'package:iptv_player/core/cast/cast_pairing.dart';
import 'package:iptv_player/design/components.dart';
import 'package:iptv_player/design/tokens.dart';
import 'package:iptv_player/features/casting/data/casting_providers.dart';

/// Pairs this computer with [device], an AirPlay TV that shows a code
/// (ADR-067): the TV shows it as the dialog opens, the user types it once,
/// and the pairing is kept for every cast after. True when paired.
Future<bool> showCastPairingDialog(BuildContext context, CastDevice device) =>
    showAppDialog<bool>(
      context,
      builder: (_) => CastPairingDialog(device: device),
    ).then((paired) => paired ?? false);

class CastPairingDialog extends ConsumerStatefulWidget {
  const new({required this.device, super.key});

  final CastDevice device;

  @override
  ConsumerState<CastPairingDialog> createState() => _CastPairingDialogState();
}

class _CastPairingDialogState extends ConsumerState<CastPairingDialog> {
  final _code = TextEditingController();
  CastPairingAttempt? _attempt;
  bool _starting = true;
  bool _sending = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    unawaited(_start());
  }

  @override
  void dispose() {
    // Closed without pairing: the TV takes its code away.
    if (_attempt case final attempt?) unawaited(attempt.cancel());
    _code.dispose();
    super.dispose();
  }

  String get _name => widget.device.name;

  Future<void> _start() async {
    setState(() {
      _starting = true;
      _error = null;
    });
    final started = await ref.read(castPairingProvider).start(widget.device);
    if (!mounted) {
      if (started case CastPairingShown(:final attempt)) {
        unawaited(attempt.cancel());
      }
      return;
    }
    setState(() {
      _starting = false;
      switch (started) {
        case CastPairingShown(:final attempt):
          _attempt = attempt;
        case CastPairingUnavailable(:final reason):
          _error = switch (reason) {
            CastPairingProblem.unreachable =>
              "Couldn't reach $_name. Check that it is on.",
            CastPairingProblem.busy => '$_name is busy. Try again in a minute.',
            CastPairingProblem.refused =>
              "$_name didn't start pairing. Check that AirPlay is on in its "
                  'settings.',
          };
      }
    });
  }

  Future<void> _pair() async {
    final attempt = _attempt;
    final code = _code.text.trim();
    if (attempt == null || _sending) return;
    if (!RegExp(r'^\d{4}$').hasMatch(code)) {
      setState(() => _error = 'Type the 4 digits shown on $_name.');
      return;
    }
    setState(() {
      _sending = true;
      _error = null;
    });
    final result = await attempt.finish(code);
    if (!mounted) return;
    // One code per attempt: a wrong one ends it, and a new code is shown.
    _attempt = null;
    switch (result) {
      case CastPairingResult.paired:
        Navigator.of(context).pop(true);
      case CastPairingResult.wrongCode:
        _code.clear();
        setState(() => _sending = false);
        await _start();
        if (mounted) {
          setState(
            () => _error =
                "That code didn't match. $_name shows a new one: type it.",
          );
        }
      case CastPairingResult.tooManyTries:
        setState(() {
          _sending = false;
          _error =
              '$_name wants a pause after several tries. Try again in '
              'a few minutes.';
        });
      case CastPairingResult.failed:
        setState(() {
          _sending = false;
          _error = "Pairing with $_name didn't finish. Try again.";
        });
    }
  }

  @override
  Widget build(BuildContext context) {
    final tokens = context.tokens;
    final colors = tokens.colors;
    final ready = _attempt != null && !_sending;
    return AppDialog(
      title: 'Pair with $_name',
      subtitle:
          'Type the code shown on its screen. Bijou keeps the pairing, '
          'so this is asked once.',
      width: tokens.cast.pickerWidth,
      focusButtons: false,
      primaryLabel: _sending ? 'Pairing…' : 'Pair',
      onPrimary: ready ? () => unawaited(_pair()) : null,
      secondaryLabel: _attempt == null && !_starting && !_sending
          ? 'Try again'
          : 'Cancel',
      onSecondary: _attempt == null && !_starting && !_sending
          ? () => unawaited(_start())
          : () => Navigator.of(context).pop(false),
      onClose: () => Navigator.of(context).pop(false),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          AppTextField(
            controller: _code,
            autofocus: true,
            hint: '1234',
            errorText: _error,
            enabled: ready,
            keyboardType: TextInputType.number,
            onSubmitted: (_) => unawaited(_pair()),
          ),
          if (_starting) ...[
            SizedBox(height: tokens.spacing.s12),
            Row(
              children: [
                const AppSpinner(),
                SizedBox(width: tokens.spacing.s8),
                Expanded(
                  child: Text(
                    'Asking $_name for its code…',
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
