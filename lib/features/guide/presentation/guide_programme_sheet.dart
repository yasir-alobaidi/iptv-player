import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:iptv_player/design/components.dart';
import 'package:iptv_player/design/tokens.dart';
import 'package:iptv_player/features/guide/domain/epg.dart';
import 'package:iptv_player/features/guide/presentation/guide_text.dart';
import 'package:iptv_player/features/live_tv/data/live_tv_providers.dart';
import 'package:iptv_player/features/live_tv/domain/channels.dart';

/// Opens the programme detail sheet (the approved sketch, ADR-011): the
/// programme, its channel and description, **Watch channel** and the
/// channel's favorite. Esc closes it.
Future<void> showGuideProgrammeSheet(
  BuildContext context, {
  required ChannelItem channel,
  required EpgProgramme programme,
  required DateTime now,
  required VoidCallback onWatch,
}) => showAppDialog<void>(
  context,
  builder: (_) => GuideProgrammeSheet(
    channel: channel,
    programme: programme,
    now: now,
    onWatch: onWatch,
  ),
);

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
    super.key,
  });

  final ChannelItem channel;
  final EpgProgramme programme;
  final DateTime now;
  final VoidCallback onWatch;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tokens = context.tokens;
    final colors = tokens.colors;
    // The favorite as it is now, so the button follows its own press.
    final fresh = ref.watch(freshChannelProvider(channel)).value ?? channel;
    final ended = !programme.end.isAfter(now);
    final subtitle = programme.subtitle?.trim() ?? '';
    final description = programme.description?.trim() ?? '';

    return AppDialog(
      title: programme.title,
      subtitle: programmeSheetMeta(programme, now),
      onClose: () => Navigator.of(context).pop(),
      child: Padding(
        padding: EdgeInsets.only(bottom: tokens.spacing.s20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Divider(height: 1, color: colors.border),
            SizedBox(height: tokens.spacing.s12),
            Text(
              guideChannelLine(fresh.name, fresh.number),
              style: tokens.text.label.copyWith(color: colors.textSecondary),
            ),
            if (subtitle.isNotEmpty) ...[
              SizedBox(height: tokens.spacing.s12),
              Text(
                subtitle,
                style: tokens.text.bodyStrong.copyWith(
                  color: colors.textPrimary,
                ),
              ),
            ],
            if (description.isNotEmpty) ...[
              SizedBox(height: tokens.spacing.s12),
              Flexible(
                child: SingleChildScrollView(
                  child: Text(
                    description,
                    style: tokens.text.body.copyWith(
                      color: colors.textEmphasis,
                    ),
                  ),
                ),
              ),
            ],
            SizedBox(height: tokens.spacing.s20),
            Row(
              children: [
                AppButton(
                  label: ended ? 'Already finished' : 'Watch channel',
                  icon: AppIcons.play,
                  autofocus: !ended,
                  onPressed: ended
                      ? null
                      : () {
                          Navigator.of(context).pop();
                          onWatch();
                        },
                ),
                SizedBox(width: tokens.spacing.s8),
                AppButton(
                  label: fresh.isFavorite
                      ? 'Remove from favorites'
                      : 'Add to favorites',
                  icon: fresh.isFavorite ? AppIcons.starFilled : AppIcons.star,
                  variant: AppButtonVariant.secondary,
                  autofocus: ended,
                  onPressed: () => unawaited(
                    ref
                        .read(channelRepositoryProvider)
                        .setFavorite(fresh, on: !fresh.isFavorite),
                  ),
                ),
                const Spacer(),
                const Kbd('Esc'),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
