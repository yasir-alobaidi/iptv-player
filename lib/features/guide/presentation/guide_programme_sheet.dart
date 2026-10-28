import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:iptv_player/design/components.dart';
import 'package:iptv_player/design/tokens.dart';
import 'package:iptv_player/features/guide/data/guide_providers.dart';
import 'package:iptv_player/features/guide/domain/epg.dart';
import 'package:iptv_player/features/guide/presentation/guide_text.dart';
import 'package:iptv_player/features/live_tv/data/live_tv_providers.dart';
import 'package:iptv_player/features/live_tv/domain/channels.dart';
import 'package:iptv_player/features/live_tv/presentation/touch_sheet.dart';
import 'package:iptv_player/features/reminders/data/reminder_providers.dart';
import 'package:iptv_player/features/reminders/presentation/reminder_actions.dart';
import 'package:iptv_player/features/reminders/presentation/reminder_text.dart';

/// Opens the programme detail sheet (the approved sketch, ADR-011): the
/// programme, its channel and description, **Watch channel**, **Remind
/// me** on one that hasn't started (Phase 9 decision 13) and the
/// channel's favorite. Esc closes it.
///
/// On a phone held upright (ADR-068) it comes up from the bottom edge, a
/// [TouchSheet], its buttons one under the other at a thumb's reach.
Future<void> showGuideProgrammeSheet(
  BuildContext context, {
  required ChannelItem channel,
  required EpgProgramme programme,
  required DateTime now,
  required VoidCallback onWatch,
}) {
  final touch = touchSheetFits(context);
  Widget sheet(BuildContext _) => GuideProgrammeSheet(
    channel: channel,
    programme: programme,
    now: now,
    onWatch: onWatch,
    touch: touch,
  );
  return touch
      ? showTouchSheet<void>(context, builder: sheet)
      : showAppDialog<void>(context, builder: sheet);
}

/// A centred sheet over a scrim, focus first on Watch channel. Watch plays
/// the channel now: it never pretends to play a programme that has ended,
/// which reads "Already finished" instead (catch-up comes with the archive
/// phase).
class GuideProgrammeSheet extends ConsumerWidget {
  const new({
    required this.channel,
    required this.programme,
    required this.now,
    required this.onWatch,
    this.touch = false,
    super.key,
  });

  final ChannelItem channel;
  final EpgProgramme programme;
  final DateTime now;
  final VoidCallback onWatch;

  /// A phone's sheet (ADR-068): from the bottom edge, the buttons full
  /// width one under the other.
  final bool touch;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tokens = context.tokens;
    final colors = tokens.colors;
    // The favorite as it is now, so the button follows its own press.
    final fresh = ref.watch(freshChannelProvider(channel)).value ?? channel;
    // The grid's copy has no description; the whole one follows.
    final whole =
        ref.watch(guideProgrammeProvider(programme.id)).value ?? programme;
    final ended = !programme.end.isAfter(now);
    final upcoming = programme.start.isAfter(now);
    final reminded =
        upcoming &&
        reminderFor(
              ref.watch(remindersProvider).value ?? const [],
              channel,
              programme,
            ) !=
            null;
    final subtitle = whole.subtitle?.trim() ?? '';
    final description = whole.description?.trim() ?? '';
    final watch = AppButton(
      label: ended ? 'Already finished' : 'Watch channel',
      icon: AppIcons.play,
      autofocus: !ended,
      size: touch ? AppButtonSize.l : AppButtonSize.m,
      expand: touch,
      onPressed: ended
          ? null
          : () {
              Navigator.of(context).pop();
              onWatch();
            },
    );
    final remind = upcoming
        ? AppButton(
            label: reminded ? '$reminderSetLabel · Remove' : remindMeLabel,
            icon: reminded ? AppIcons.bellFilled : AppIcons.bell,
            variant: AppButtonVariant.secondary,
            size: touch ? AppButtonSize.l : AppButtonSize.m,
            expand: touch,
            onPressed: () => unawaited(
              toggleReminder(
                ProviderScope.containerOf(context, listen: false),
                channel,
                programme,
              ),
            ),
          )
        : null;
    final favorite = AppButton(
      label: fresh.isFavorite ? 'Remove from favorites' : 'Add to favorites',
      icon: fresh.isFavorite ? AppIcons.starFilled : AppIcons.star,
      variant: AppButtonVariant.secondary,
      size: touch ? AppButtonSize.l : AppButtonSize.m,
      expand: touch,
      autofocus: ended,
      onPressed: () => unawaited(
        ref
            .read(channelRepositoryProvider)
            .setFavorite(fresh, on: !fresh.isFavorite),
      ),
    );
    final about = <Widget>[
      Text(
        guideChannelLine(fresh.name, fresh.number),
        style: tokens.text.label.copyWith(color: colors.textSecondary),
      ),
      if (subtitle.isNotEmpty) ...[
        SizedBox(height: tokens.spacing.s12),
        Text(
          subtitle,
          style: tokens.text.bodyStrong.copyWith(color: colors.textPrimary),
        ),
      ],
      if (description.isNotEmpty) ...[
        SizedBox(height: tokens.spacing.s12),
        Flexible(
          child: SingleChildScrollView(
            child: Text(
              description,
              style: tokens.text.body.copyWith(color: colors.textEmphasis),
            ),
          ),
        ),
      ],
    ];

    if (touch) {
      return TouchSheet(
        title: programme.title,
        subtitle: programmeSheetMeta(programme, now, tokens.timeStyle),
        child: Padding(
          padding: EdgeInsets.fromLTRB(
            tokens.spacing.s20,
            0,
            tokens.spacing.s20,
            tokens.spacing.s16,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Divider(height: 1, color: colors.border),
              SizedBox(height: tokens.spacing.s12),
              ...about,
              SizedBox(height: tokens.spacing.s20),
              watch,
              if (remind != null) ...[
                SizedBox(height: tokens.spacing.s8),
                remind,
              ],
              SizedBox(height: tokens.spacing.s8),
              favorite,
            ],
          ),
        ),
      );
    }

    return AppDialog(
      title: programme.title,
      subtitle: programmeSheetMeta(programme, now, tokens.timeStyle),
      // Wide enough for Watch channel, Remind me and the favorite on one
      // line.
      width: 640,
      onClose: () => Navigator.of(context).pop(),
      child: Padding(
        padding: EdgeInsets.only(bottom: tokens.spacing.s20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Divider(height: 1, color: colors.border),
            SizedBox(height: tokens.spacing.s12),
            ...about,
            SizedBox(height: tokens.spacing.s20),
            Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                // The longest three labels are wider than the sheet: they
                // wrap, and never clip.
                Expanded(
                  child: Wrap(
                    spacing: tokens.spacing.s8,
                    runSpacing: tokens.spacing.s8,
                    children: [watch, ?remind, favorite],
                  ),
                ),
                if (KeyHints.shownIn(context)) ...[
                  SizedBox(width: tokens.spacing.s8),
                  // Beside the last line of buttons, at its middle.
                  SizedBox(
                    height: context.scaled(AppButtonSize.m.height),
                    child: const Center(child: Kbd('Esc')),
                  ),
                ],
              ],
            ),
          ],
        ),
      ),
    );
  }
}
