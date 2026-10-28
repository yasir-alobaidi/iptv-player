import 'package:flutter/material.dart';
import 'package:iptv_player/core/platform/window_bounds.dart';
import 'package:iptv_player/design/components.dart';
import 'package:iptv_player/design/tokens.dart';
import 'package:iptv_player/features/onboarding/presentation/onboarding_state.dart';
import 'package:iptv_player/features/settings/presentation/heading_then_body.dart';

/// Below this width the onboarding pages drop to one column and narrower
/// margins.
const onboardingNarrowWidth = 1100.0;

/// Shorter than this (a phone on its side) the onboarding pages are as
/// compact as a phone's, and their title scrolls with what is under it.
const onboardingShortHeight = 560.0;

/// Whether the onboarding pages are laid out for a phone held upright:
/// one column at full width, the fields one under another, the actions
/// across the bottom (ADR-068). By the screen's width, never the device.
bool onboardingOnPhone(BuildContext context) =>
    MediaQuery.sizeOf(context).width < WindowSizes.phoneWidth;

/// The onboarding pages' frame (canvas): the backdrop, the app mark and
/// the step indicator on top, then the page's [title], [subtitle] and
/// body, and a [footer] of actions pinned to the bottom.
///
/// On a phone, or a screen too short for the canvas's frame (ADR-068): 16
/// px margins, "Step 2 of 4 · Connect" in place of the indicator, a
/// smaller title, and the title and [body] scrolling as one when the
/// body would have less than [compactBodyMinHeight] (the keyboard up);
/// the footer stays above the keyboard.
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

  /// The least height a compact page's body is given: less, and the
  /// title scrolls away above it.
  static const compactBodyMinHeight = 280.0;

  /// Zero-based index into [onboardingSteps]; null hides the indicator
  /// (editing a source is not a step of adding one).
  final int? step;
  final String title;
  final String subtitle;
  final Widget body;
  final Widget footer;

  /// Sits to the right of the title (Pick categories' summary); under the
  /// subtitle on a phone.
  final Widget? trailing;

  /// Centres the page in a column this wide (Sync: 640).
  final double? maxWidth;

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.sizeOf(context);
    final compact =
        size.width < WindowSizes.phoneWidth ||
        size.height < onboardingShortHeight;
    // The system's keyboard (a phone's, a tablet's) takes the bottom of
    // the screen: the footer stays above it.
    final keyboard = MediaQuery.viewInsetsOf(context).bottom;
    return Material(
      type: MaterialType.transparency,
      child: AppBackdrop(
        child: Padding(
          padding: EdgeInsets.only(bottom: keyboard),
          child: MediaQuery.removeViewInsets(
            context: context,
            removeBottom: true,
            child: SafeArea(
              child: compact ? _compact(context) : _regular(context),
            ),
          ),
        ),
      ),
    );
  }

  Widget _regular(BuildContext context) {
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

    return Padding(
      padding: EdgeInsets.symmetric(
        horizontal: narrow ? spacing.s32 : spacing.s64,
        vertical: spacing.s32,
      ),
      // No wider than the canvas draws it, in the middle of a larger
      // window: a page that stands alone.
      child: PageMeasure(
        alignment: Alignment.topCenter,
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
                        : StepIndicator(steps: onboardingSteps, current: step!),
                  ),
                ),
              ],
            ),
            SizedBox(height: spacing.s24 + 4),
            Expanded(child: page),
          ],
        ),
      ),
    );
  }

  /// A phone's frame, or a short screen's (ADR-068).
  Widget _compact(BuildContext context) {
    final tokens = context.tokens;
    final colors = tokens.colors;
    final spacing = tokens.spacing;
    final step = this.step;

    final heading = Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Semantics(
          header: true,
          child: Text(
            title,
            style: tokens.text.h1.copyWith(color: colors.textPrimary),
          ),
        ),
        SizedBox(height: spacing.s4),
        Text(
          subtitle,
          style: tokens.text.body.copyWith(color: colors.textSecondary),
        ),
        if (trailing case final trailing?) ...[
          SizedBox(height: spacing.s12),
          Align(alignment: AlignmentDirectional.centerStart, child: trailing),
        ],
        SizedBox(height: spacing.s16),
      ],
    );

    Widget page = Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Expanded(
          child: HeadingThenBody(
            minBodyHeight: context.scaled(compactBodyMinHeight),
            heading: heading,
            body: body,
          ),
        ),
        SizedBox(height: spacing.s16),
        footer,
      ],
    );
    if (maxWidth != null) {
      page = Center(
        child: ConstrainedBox(
          constraints: BoxConstraints(maxWidth: maxWidth!),
          child: page,
        ),
      );
    }

    return Padding(
      padding: EdgeInsets.fromLTRB(
        spacing.s16,
        spacing.s12,
        spacing.s16,
        spacing.s16,
      ),
      child: PageMeasure(
        alignment: Alignment.topCenter,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                const AppMark.small(),
                SizedBox(width: spacing.s16),
                if (step != null)
                  Expanded(
                    child: Semantics(
                      label:
                          'Step ${step + 1} of ${onboardingSteps.length}: '
                          '${onboardingSteps[step]}',
                      excludeSemantics: true,
                      child: Text(
                        'Step ${step + 1} of ${onboardingSteps.length} · '
                        '${onboardingSteps[step]}',
                        textAlign: TextAlign.end,
                        style: tokens.text.caption
                            .withWeight(700)
                            .copyWith(color: colors.textSecondary),
                      ),
                    ),
                  ),
              ],
            ),
            SizedBox(height: spacing.s16),
            Expanded(child: page),
          ],
        ),
      ),
    );
  }
}

/// A row of actions under an onboarding page: [leading] on the left, the
/// rest on the right, with an optional [note] before them.
///
/// Narrower than [phoneWidth] (a phone, ADR-068): the note on a line of
/// its own, every action but the last across the width, and [leading]
/// beside the last action, which takes the rest of its line.
class OnboardingFooter extends StatelessWidget {
  const new({required this.actions, this.leading, this.note, super.key});

  final Widget? leading;
  final String? note;
  final List<Widget> actions;

  /// The least width at which the footer is one row.
  static const phoneWidth = 560.0;

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, constraints) =>
        constraints.maxWidth < phoneWidth ? _phone(context) : _row(context),
  );

  Widget _row(BuildContext context) {
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

  Widget _phone(BuildContext context) {
    final tokens = context.tokens;
    final spacing = tokens.spacing;
    final leading = this.leading;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (note case final note?) ...[
          Text(
            note,
            style: tokens.text.caption.copyWith(
              color: tokens.colors.textTertiary,
            ),
          ),
          SizedBox(height: spacing.s8),
        ],
        for (final action in actions.take(actions.length - 1)) ...[
          action,
          SizedBox(height: spacing.s8),
        ],
        Row(
          children: [
            ?leading,
            if (leading != null && actions.isNotEmpty)
              SizedBox(width: spacing.s12),
            if (actions.isNotEmpty) Expanded(child: actions.last),
          ],
        ),
      ],
    );
  }
}
