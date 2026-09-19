import 'package:flutter/material.dart';
import 'package:iptv_player/design/components.dart';
import 'package:iptv_player/design/tokens.dart';
import 'package:iptv_player/features/onboarding/presentation/onboarding_state.dart';

/// Below this width the onboarding pages drop to one column and narrower
/// margins.
const onboardingNarrowWidth = 1100.0;

/// The onboarding pages' frame (canvas): the backdrop, the app mark and
/// the step indicator on top, then the page's [title], [subtitle] and
/// body, and a [footer] of actions pinned to the bottom.
class OnboardingFrame extends StatelessWidget {
  const new({
    required this.title,
    required this.subtitle,
    required this.body,
    required this.footer,
    this.step,
    this.trailing,
    this.maxWidth,
    super.key,
  });

  /// Zero-based index into [onboardingSteps]; null hides the indicator
  /// (editing a source is not a step of adding one).
  final int? step;
  final String title;
  final String subtitle;
  final Widget body;
  final Widget footer;

  /// Sits to the right of the title (Pick categories' summary).
  final Widget? trailing;

  /// Centres the page in a column this wide (Sync: 640).
  final double? maxWidth;

  @override
  Widget build(BuildContext context) {
    final tokens = context.tokens;
    final colors = tokens.colors;
    final spacing = tokens.spacing;
    final narrow = MediaQuery.sizeOf(context).width < onboardingNarrowWidth;

    Widget page = Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Semantics(
                    header: true,
                    child: Text(
                      title,
                      style: tokens.text.hero.copyWith(
                        color: colors.textPrimary,
                      ),
                    ),
                  ),
                  SizedBox(height: spacing.s8),
                  Text(
                    subtitle,
                    style: tokens.text.body.copyWith(
                      color: colors.textSecondary,
                    ),
                  ),
                ],
              ),
            ),
            if (trailing != null) ...[SizedBox(width: spacing.s24), trailing!],
          ],
        ),
        SizedBox(height: spacing.s20 + 2),
        Expanded(child: body),
        SizedBox(height: spacing.s20),
        footer,
      ],
    );
    if (maxWidth != null) {
      page = Center(
        child: ConstrainedBox(
          constraints: BoxConstraints(maxWidth: maxWidth!),
          child: Padding(
            padding: EdgeInsets.only(top: spacing.s20),
            child: page,
          ),
        ),
      );
    }

    return Material(
      type: MaterialType.transparency,
      child: AppBackdrop(
        child: SafeArea(
          child: Padding(
            padding: EdgeInsets.symmetric(
              horizontal: narrow ? spacing.s32 : spacing.s64,
              vertical: spacing.s32,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  children: [
                    const AppMark.small(),
                    SizedBox(width: spacing.s24),
                    Expanded(
                      child: Align(
                        alignment: Alignment.centerRight,
                        child: step == null
                            ? const SizedBox.shrink()
                            : StepIndicator(
                                steps: onboardingSteps,
                                current: step!,
                              ),
                      ),
                    ),
                  ],
                ),
                SizedBox(height: spacing.s24 + 4),
                Expanded(child: page),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// A row of actions under an onboarding page: [leading] on the left, the
/// rest on the right, with an optional [note] before them.
class OnboardingFooter extends StatelessWidget {
  const new({required this.actions, this.leading, this.note, super.key});

  final Widget? leading;
  final String? note;
  final List<Widget> actions;

  @override
  Widget build(BuildContext context) {
    final tokens = context.tokens;
    return Row(
      children: [
        ?leading,
        SizedBox(width: tokens.spacing.s12),
        // Takes the free space whether or not there is a note, so the
        // actions always sit at the right edge.
        Expanded(
          child: note == null
              ? const SizedBox.shrink()
              : Text(
                  note!,
                  textAlign: TextAlign.right,
                  style: tokens.text.caption.copyWith(
                    color: tokens.colors.textTertiary,
                  ),
                ),
        ),
        SizedBox(width: tokens.spacing.s12),
        for (final (index, action) in actions.indexed) ...[
          if (index > 0) SizedBox(width: tokens.spacing.s12),
          action,
        ],
      ],
    );
  }
}
