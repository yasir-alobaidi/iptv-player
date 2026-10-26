import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:iptv_player/app/failure_message.dart';
import 'package:iptv_player/core/result.dart';
import 'package:iptv_player/design/components.dart';
import 'package:iptv_player/design/tokens.dart';
import 'package:iptv_player/features/diagnostics/data/report_share_providers.dart';
import 'package:iptv_player/features/diagnostics/domain/report_share.dart';

/// "Send the report to your phone" (ADR-059): [load] makes the report,
/// which this device then serves on the network as [fileName] for a phone
/// that scans the code, until the dialog closes.
Future<void> showSendReportDialog(
  BuildContext context, {
  required Future<Result<String>> Function() load,
  required String fileName,
}) => showAppDialog<void>(
  context,
  builder: (_) => SendReportDialog(load: load, fileName: fileName),
);

/// The dialog [showSendReportDialog] opens: the code and the steps once
/// the report is offered, with Done focused in every state.
class SendReportDialog extends ConsumerStatefulWidget {
  const new({required this.load, required this.fileName, super.key});

  final Future<Result<String>> Function() load;
  final String fileName;

  @override
  ConsumerState<SendReportDialog> createState() => _SendReportDialogState();
}

sealed class _Stage {
  const new();

  /// Each stage is a new dialog, so Done takes the focus again.
  String get name;
}

final class _Preparing extends _Stage {
  const new();

  @override
  String get name => 'preparing';
}

final class _Ready extends _Stage {
  const new(this.offer);

  final ReportOffer offer;

  @override
  String get name => 'ready';
}

final class _NoNetwork extends _Stage {
  const new();

  @override
  String get name => 'no network';
}

final class _Failed extends _Stage {
  const new(this.failure);

  final AppFailure failure;

  @override
  String get name => 'failed';
}

class _SendReportDialogState extends ConsumerState<SendReportDialog> {
  _Stage _stage = const _Preparing();
  var _fetched = false;
  ReportOffer? _offer;
  StreamSubscription<void>? _fetches;

  /// Bumped by every start and by dispose: an answer for an older one is
  /// dropped (an offer that comes too late is closed).
  var _attempt = 0;

  @override
  void initState() {
    super.initState();
    unawaited(_prepare());
  }

  @override
  void dispose() {
    _attempt++;
    unawaited(_fetches?.cancel());
    unawaited(_offer?.close());
    super.dispose();
  }

  Future<void> _prepare() async {
    final attempt = ++_attempt;
    final sharer = ref.read(reportSharerProvider);
    final loaded = await _guard(widget.load);
    if (!mounted || attempt != _attempt) return;
    final String text;
    switch (loaded) {
      case Err(:final failure):
        setState(() => _stage = _Failed(failure));
        return;
      case Ok(:final value):
        text = value;
    }
    final offered = await _guard(
      () => sharer.offer(text, fileName: widget.fileName),
    );
    if (!mounted || attempt != _attempt) {
      unawaited(offered.valueOrNull?.close());
      return;
    }
    if (offered case Ok(value: final offer)) {
      _offer = offer;
      _fetches = offer.fetched.listen((_) {
        if (mounted && !_fetched) setState(() => _fetched = true);
      });
    }
    setState(
      () => _stage = switch (offered) {
        Ok(value: final offer) => _Ready(offer),
        Err(failure: NetworkFailure()) => const _NoNetwork(),
        Err(:final failure) => _Failed(failure),
      },
    );
  }

  void _retry() {
    unawaited(_fetches?.cancel());
    unawaited(_offer?.close());
    setState(() {
      _fetches = null;
      _offer = null;
      _fetched = false;
      _stage = const _Preparing();
    });
    unawaited(_prepare());
  }

  /// The last line of defence: a throw reads as a failure.
  static Future<Result<T>> _guard<T>(Future<Result<T>> Function() body) async {
    try {
      return await body();
    } on Object catch (error) {
      return Err(AppFailure.fromError(error));
    }
  }

  @override
  Widget build(BuildContext context) {
    final stage = _stage;
    final retry = stage is _NoNetwork || stage is _Failed;
    return AppDialog(
      // A new dialog per stage, so Done takes the focus again: Try again,
      // where it was, is gone.
      key: ValueKey(stage.name),
      title: 'Send the report to your phone',
      width: 760,
      primaryLabel: 'Done',
      onPrimary: () => Navigator.of(context).pop(),
      secondaryLabel: retry ? 'Try again' : null,
      onSecondary: retry ? _retry : null,
      // Taller than the window at a large text size: it scrolls, never
      // overflows.
      child: SingleChildScrollView(
        child: switch (stage) {
          _Preparing() => const _PreparingView(),
          _Ready(:final offer) => _OfferView(
            address: offer.address.toString(),
            fetched: _fetched,
          ),
          _NoNetwork() => const _ProblemView(
            title: "This TV isn't on a network a phone can reach.",
            message: 'Connect it to Wi-Fi or a cable and try again.',
          ),
          _Failed(:final failure) => _ProblemView(
            title: "The report couldn't be made",
            message: failureMessage(failure),
          ),
        },
      ),
    );
  }
}

/// The code's side: big enough for a phone's camera across a room.
const _codeSize = 240.0;

class _PreparingView extends StatelessWidget {
  const new();

  @override
  Widget build(BuildContext context) {
    final tokens = context.tokens;
    return Row(
      children: [
        Skeleton(
          width: _codeSize,
          height: _codeSize,
          borderRadius: tokens.radii.smAll,
        ),
        SizedBox(width: tokens.spacing.s24),
        Expanded(
          child: Text(
            'Getting the report ready…',
            style: tokens.text.body.copyWith(
              color: tokens.colors.textSecondary,
            ),
          ),
        ),
      ],
    );
  }
}

class _OfferView extends StatelessWidget {
  const new({required this.address, required this.fetched});

  final String address;
  final bool fetched;

  static const _steps = [
    'Connect your phone to the same Wi-Fi as this TV.',
    "Point the phone's camera at the code and open the link.",
    'Tap Download the report, then send the file.',
  ];

  @override
  Widget build(BuildContext context) {
    final tokens = context.tokens;
    final colors = tokens.colors;
    final body = tokens.text.body.copyWith(color: colors.textPrimary);
    final caption = tokens.text.caption.copyWith(color: colors.textSecondary);
    final statusColor = fetched ? colors.success : colors.textSecondary;

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        QrCodeView(
          data: address,
          size: _codeSize,
          semanticLabel: "A code for the phone's camera: $address",
        ),
        SizedBox(width: tokens.spacing.s24),
        Expanded(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              for (final (index, step) in _steps.indexed) ...[
                if (index > 0) SizedBox(height: tokens.spacing.s12),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '${index + 1}.',
                      style: tokens.text.bodyStrong.copyWith(
                        color: colors.accentBase,
                      ),
                    ),
                    SizedBox(width: tokens.spacing.s8),
                    Expanded(child: Text(step, style: body)),
                  ],
                ),
              ],
              SizedBox(height: tokens.spacing.s20),
              Text(
                "Or type this address in the phone's browser:",
                style: caption,
              ),
              SizedBox(height: tokens.spacing.s4),
              Text(
                address,
                style: tokens.text.mono.copyWith(color: colors.textPrimary),
              ),
              SizedBox(height: tokens.spacing.s20),
              Semantics(
                liveRegion: true,
                child: Row(
                  children: [
                    AppIcon(
                      fetched ? AppIcons.check : AppIcons.clock,
                      size: 18,
                      color: statusColor,
                    ),
                    SizedBox(width: tokens.spacing.s8),
                    Expanded(
                      child: Text(
                        fetched
                            ? 'Your phone has the report.'
                            : 'Waiting for your phone…',
                        style: tokens.text.bodyStrong.copyWith(
                          color: statusColor,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              SizedBox(height: tokens.spacing.s12),
              Text(
                'No passwords or server addresses are in it. The address '
                'works while this window is open.',
                style: tokens.text.caption.copyWith(color: colors.textTertiary),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

/// No code to show: why, and what to do; Try again is the dialog's.
class _ProblemView extends StatelessWidget {
  const new({required this.title, required this.message});

  final String title;
  final String message;

  @override
  Widget build(BuildContext context) {
    final tokens = context.tokens;
    final colors = tokens.colors;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        AppIcon(AppIcons.alertCircle, size: 24, color: colors.danger),
        SizedBox(width: tokens.spacing.s12),
        Expanded(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: tokens.text.bodyStrong.copyWith(
                  color: colors.textPrimary,
                ),
              ),
              SizedBox(height: tokens.spacing.s4),
              Text(
                message,
                style: tokens.text.body.copyWith(color: colors.textSecondary),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
