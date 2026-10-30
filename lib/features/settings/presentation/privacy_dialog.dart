import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:iptv_player/core/app_identity.dart';
import 'package:iptv_player/core/platform/privacy_policy.dart';
import 'package:iptv_player/design/components.dart';
import 'package:iptv_player/design/tokens.dart';

/// About's Privacy: the privacy policy Google Play links to, in the app
/// as Play's User Data policy asks (ADR-068), on a TV too, which has no
/// browser to open a link in. One Tab stop, scrolled by the keyboard;
/// Esc closes.
Future<void> showPrivacyDialog(BuildContext context) =>
    showAppDialog<void>(context, builder: (context) => const PrivacyDialog());

class PrivacyDialog extends ConsumerWidget {
  const new({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tokens = context.tokens;
    final policy = ref.watch(privacyPolicyProvider);
    return AppDialog(
      title: 'Privacy policy',
      subtitle: 'What $appName does with your information.',
      width: 720,
      onClose: () => Navigator.of(context).pop(),
      child: Padding(
        padding: EdgeInsets.only(bottom: tokens.spacing.s20),
        child: SizedBox(
          height: 440,
          child: switch (policy) {
            AsyncData(:final value) when value.isEmpty => const EmptyState(
              icon: AppIcons.info,
              title: 'No privacy policy to show',
              message:
                  'This build came without it. It is also at '
                  '$privacyPolicyAddress.',
              compact: true,
            ),
            AsyncData(:final value) => _Policy(blocks: value),
            AsyncError(:final error) => ErrorState(
              title: "The privacy policy couldn't be read",
              message: 'It is part of the app itself. Try again.',
              details: '$error',
              onRetry: () => ref.invalidate(privacyPolicyProvider),
              retryLabel: 'Try again',
              compact: true,
            ),
            _ => Semantics(
              label: 'Reading the privacy policy',
              container: true,
              child: SkeletonColumn(
                children: [
                  for (var i = 0; i < 7; i++)
                    Padding(
                      padding: EdgeInsets.only(bottom: tokens.spacing.s8),
                      child: const Skeleton(height: 36),
                    ),
                ],
              ),
            ),
          },
        ),
      ),
    );
  }
}

class _Policy extends StatelessWidget {
  const new({required this.blocks});

  final List<PolicyBlock> blocks;

  @override
  Widget build(BuildContext context) {
    final tokens = context.tokens;
    final colors = tokens.colors;
    final spacing = tokens.spacing;
    final body = tokens.text.body.copyWith(color: colors.textSecondary);

    TextSpan spans(PolicyBlock block, TextStyle style) => TextSpan(
      style: style,
      children: [
        for (final run in block.runs)
          TextSpan(
            text: run.text,
            style: run.strong
                ? style.withWeight(700).copyWith(color: colors.textPrimary)
                : null,
          ),
      ],
    );

    Widget blockOf(PolicyBlock block) => switch (block) {
      PolicyHeading() => Padding(
        padding: EdgeInsets.only(top: spacing.s12),
        child: Text.rich(
          spans(block, tokens.text.h3.copyWith(color: colors.textPrimary)),
        ),
      ),
      PolicyNote() => Text.rich(
        spans(block, tokens.text.caption.copyWith(color: colors.textTertiary)),
      ),
      PolicyParagraph() => Text.rich(spans(block, body)),
      PolicyBullet() => Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: spacing.s20,
            child: Text('•', style: body),
          ),
          Expanded(child: Text.rich(spans(block, body))),
        ],
      ),
    };

    return DecoratedBox(
      decoration: BoxDecoration(
        color: colors.surface1,
        borderRadius: tokens.radii.controlAll,
        border: Border.all(color: colors.border),
      ),
      child: ScrollPane.child(
        semanticLabel: 'The privacy policy',
        padding: EdgeInsets.all(spacing.s16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            for (final (index, block) in blocks.indexed) ...[
              if (index > 0) SizedBox(height: spacing.s8),
              blockOf(block),
            ],
            SizedBox(height: spacing.s20),
            Text(
              'Also published at $privacyPolicyAddress',
              style: tokens.text.caption.copyWith(color: colors.textTertiary),
            ),
          ],
        ),
      ),
    );
  }
}
