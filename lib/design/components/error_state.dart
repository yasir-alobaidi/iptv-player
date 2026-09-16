import 'package:flutter/material.dart';
import 'package:iptv_player/design/app_icon.dart';
import 'package:iptv_player/design/components/app_button.dart';
import 'package:iptv_player/design/tokens.dart';

/// Error placeholder: a human first line, Retry, and the technical detail
/// hidden behind a disclosure (docs/05, hard rule 4). [details] is already
/// redacted by the time it reaches here.
class ErrorState extends StatefulWidget {
  const new({
    required this.title,
    this.message,
    this.details,
    this.onRetry,
    this.retryLabel = 'Retry',
    this.compact = false,
    super.key,
  });

  final String title;
  final String? message;

  /// Redacted technical text (an AppFailure detail), shown on request.
  final String? details;
  final VoidCallback? onRetry;
  final String retryLabel;
  final bool compact;

  @override
  State<ErrorState> createState() => _ErrorStateState();
}

class _ErrorStateState extends State<ErrorState> {
  bool _showDetails = false;

  @override
  Widget build(BuildContext context) {
    final tokens = context.tokens;
    final colors = tokens.colors;

    // Scrolls rather than overflowing when the pane is short — with
    // the details open this can be taller than its container.
    return Center(
      child: SingleChildScrollView(
        padding: EdgeInsets.all(tokens.spacing.s24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: widget.compact ? 44 : 56,
              height: widget.compact ? 44 : 56,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: colors.danger.withValues(alpha: 0.12),
                borderRadius: tokens.radii.mdAll,
              ),
              child: AppIcon(
                AppIcons.alertCircle,
                size: widget.compact ? 20 : 24,
                color: colors.danger,
              ),
            ),
            SizedBox(height: tokens.spacing.s16),
            Text(
              widget.title,
              textAlign: TextAlign.center,
              style: (widget.compact ? tokens.text.titleSmall : tokens.text.h3)
                  .copyWith(color: colors.textPrimary),
            ),
            if (widget.message != null) ...[
              SizedBox(height: tokens.spacing.s8),
              ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 420),
                child: Text(
                  widget.message!,
                  textAlign: TextAlign.center,
                  style: tokens.text.body.copyWith(color: colors.textSecondary),
                ),
              ),
            ],
            SizedBox(height: tokens.spacing.s20),
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (widget.onRetry != null)
                  AppButton(
                    label: widget.retryLabel,
                    icon: AppIcons.retry,
                    onPressed: widget.onRetry,
                  ),
                if (widget.onRetry != null && widget.details != null)
                  SizedBox(width: tokens.spacing.s8),
                if (widget.details != null)
                  AppButton(
                    label: _showDetails ? 'Hide details' : 'Details',
                    variant: AppButtonVariant.ghost,
                    onPressed: () =>
                        setState(() => _showDetails = !_showDetails),
                  ),
              ],
            ),
            if (_showDetails && widget.details != null) ...[
              SizedBox(height: tokens.spacing.s16),
              ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 520),
                child: Container(
                  width: double.infinity,
                  padding: EdgeInsets.all(tokens.spacing.s12),
                  decoration: BoxDecoration(
                    color: colors.surface1,
                    borderRadius: tokens.radii.smAll,
                    border: Border.all(color: colors.border),
                  ),
                  child: SelectableText(
                    widget.details!,
                    style: tokens.text.mono.copyWith(
                      color: colors.textSecondary,
                    ),
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
