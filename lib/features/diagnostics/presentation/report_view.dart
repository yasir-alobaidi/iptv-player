import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:iptv_player/app/failure_message.dart';
import 'package:iptv_player/core/app_identity.dart';
import 'package:iptv_player/core/core_providers.dart';
import 'package:iptv_player/core/notices/app_notices.dart';
import 'package:iptv_player/core/result.dart';
import 'package:iptv_player/design/components.dart';
import 'package:iptv_player/design/tokens.dart';
import 'package:iptv_player/features/diagnostics/data/diagnostics_providers.dart';
import 'package:iptv_player/features/diagnostics/presentation/send_report_dialog.dart';

/// `bijou-diagnostics-2026-10-13.txt`, the name Save suggests.
String diagnosticsFileName(DateTime now) {
  final day = now.toLocal();
  String two(int value) => '$value'.padLeft(2, '0');
  return '$appFileSlug-diagnostics-${day.year}-${two(day.month)}-'
      '${two(day.day)}.txt';
}

/// The diagnostics report (Phase 9 decision 9, sketch D): the text
/// itself, so the user sees what they are about to paste, with Copy
/// diagnostics and Save to file… above it; on a TV, which has neither a
/// clipboard nor a file to give, Send to phone (ADR-059). The text is one
/// Tab stop, scrolled by the keyboard.
class ReportView extends ConsumerStatefulWidget {
  const new({super.key});

  @override
  ConsumerState<ReportView> createState() => _ReportViewState();
}

class _ReportViewState extends ConsumerState<ReportView> {
  String? _error;
  var _saving = false;

  Future<void> _copy(String text) async {
    try {
      await Clipboard.setData(ClipboardData(text: text));
    } on Object {
      if (mounted) {
        setState(
          () => _error =
              "Couldn't reach the clipboard. Try Save to file… instead.",
        );
      }
      return;
    }
    if (!mounted) return;
    setState(() => _error = null);
    ref
        .read(appNoticesProvider)
        .show(AppNotice('Diagnostics copied', tone: NoticeTone.success));
  }

  Future<void> _save(String text) async {
    final name = diagnosticsFileName(ref.read(appClockProvider)());
    final path = await ref.read(reportSavePickerProvider)(name);
    if (path == null || !mounted) return;
    setState(() => _saving = true);
    final saved = await ref.read(diagnosticsProvider).save(path, text);
    if (!mounted) return;
    setState(() {
      _saving = false;
      _error = switch (saved) {
        Err(:final failure) =>
          "Couldn't write that file. ${failureMessage(failure)}",
        Ok() => null,
      };
    });
    if (saved is Ok) {
      ref
          .read(appNoticesProvider)
          .show(AppNotice('Diagnostics saved', tone: NoticeTone.success));
    }
  }

  Future<void> _send() => showSendReportDialog(
    context,
    load: ref.read(diagnosticsProvider).shareReport,
    fileName: diagnosticsFileName(ref.read(appClockProvider)()),
  );

  @override
  Widget build(BuildContext context) {
    final tokens = context.tokens;
    final colors = tokens.colors;
    final formFactor = ref.watch(formFactorProvider);
    final onTv = formFactor.isTv;
    final report = ref.watch(diagnosticsReportProvider);
    final text = report.value?.valueOrNull;
    // The service answers with a Result; an error here is the last line
    // of defence, and reads the same to the user.
    final failure =
        report.value?.failureOrNull ??
        (report.hasError ? UnexpectedFailure('${report.error}') : null);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Wrap(
          alignment: WrapAlignment.spaceBetween,
          crossAxisAlignment: WrapCrossAlignment.center,
          spacing: tokens.spacing.s16,
          runSpacing: tokens.spacing.s8,
          children: [
            ConstrainedBox(
              constraints: BoxConstraints(maxWidth: context.scaled(560)),
              child: Text(
                !formFactor.isDesktop
                    ? 'What the app and the player found on '
                          '${formFactor.thisDevice}. No passwords, usernames '
                          'or server addresses.'
                    : 'What the app, the player and the converter found on '
                          'this computer. No passwords, usernames or server '
                          'addresses.',
                style: tokens.text.caption.copyWith(color: colors.textTertiary),
              ),
            ),
            if (onTv)
              AppButton(
                label: 'Send to phone',
                size: AppButtonSize.s,
                onPressed: () => unawaited(_send()),
              )
            else
              Wrap(
                spacing: tokens.spacing.s8,
                runSpacing: tokens.spacing.s8,
                children: [
                  AppButton(
                    label: 'Copy diagnostics',
                    size: AppButtonSize.s,
                    onPressed: text == null
                        ? null
                        : () => unawaited(_copy(text)),
                  ),
                  // A phone has no save dialog to put a file where the
                  // user chooses (ADR-068): Copy is its way out.
                  if (formFactor.isDesktop)
                    AppButton(
                      label: 'Save to file…',
                      variant: AppButtonVariant.secondary,
                      size: AppButtonSize.s,
                      loading: _saving,
                      onPressed: text == null || _saving
                          ? null
                          : () => unawaited(_save(text)),
                    ),
                ],
              ),
          ],
        ),
        SizedBox(height: tokens.spacing.s12),
        if (_error case final error?) ...[
          AppBanner(
            message: error,
            tone: BannerTone.error,
            onDismiss: () => setState(() => _error = null),
          ),
          SizedBox(height: tokens.spacing.s12),
        ],
        Expanded(
          child: switch ((text, failure)) {
            (final text?, _) => DecoratedBox(
              decoration: BoxDecoration(
                color: colors.bg,
                borderRadius: tokens.radii.controlAll,
                border: Border.all(color: colors.border),
              ),
              child: ScrollPane.child(
                semanticLabel: 'The diagnostics report',
                padding: EdgeInsets.all(tokens.spacing.s16),
                child: SizedBox(
                  width: double.infinity,
                  child: Text(
                    text,
                    style: tokens.text.mono.copyWith(
                      color: colors.textSecondary,
                    ),
                  ),
                ),
              ),
            ),
            (_, final failure?) => ErrorState(
              title: "The report couldn't be made",
              message: failureMessage(failure),
              details: failure.detail,
              retryLabel: 'Try again',
              onRetry: () => ref.invalidate(diagnosticsReportProvider),
              compact: true,
            ),
            _ => Semantics(
              label: 'Making the report',
              container: true,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  for (final width in const [520.0, 440.0, 360.0, 480.0, 300.0])
                    Padding(
                      padding: EdgeInsets.only(bottom: tokens.spacing.s8),
                      child: Skeleton(width: width),
                    ),
                ],
              ),
            ),
          },
        ),
      ],
    );
  }
}
