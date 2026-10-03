import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:iptv_player/core/text/format.dart';
import 'package:iptv_player/design/components.dart';
import 'package:iptv_player/design/tokens.dart';
import 'package:iptv_player/features/casting/data/casting_providers.dart';
import 'package:iptv_player/features/casting/presentation/casting_view_state.dart';
import 'package:iptv_player/features/live_tv/data/live_tv_providers.dart';
import 'package:iptv_player/features/live_tv/domain/channels.dart';

/// Sketch B: Live TV's preview while casting, in place of a picture. It
/// says what plays on the TV; moving through the list changes nothing
/// until Enter (Phase 7 decision 2).
class CastPreviewCard extends ConsumerWidget {
  const new({required this.deviceName, this.channel, super.key});

  final String deviceName;

  /// What plays on the TV; null when nothing does yet.
  final ChannelItem? channel;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tokens = context.tokens;
    final colors = tokens.colors;
    final channel = this.channel;
    final now = channel == null
        ? null
        : ref.watch(nowNextProvider(channel)).value?.now;
    final secondary = tokens.text.caption.copyWith(color: colors.textSecondary);
    return Container(
      color: colors.surface2,
      padding: EdgeInsets.all(tokens.spacing.s20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Row(
            children: [
              AppIcon(
                AppIcons.castConnected,
                size: 18,
                color: colors.accentBase,
              ),
              SizedBox(width: tokens.spacing.s8),
              Expanded(
                child: Text(
                  channel == null
                      ? 'Connected to $deviceName'
                      : 'Playing on $deviceName',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: tokens.text.label
                      .withWeight(700)
                      .copyWith(color: colors.accentBase),
                ),
              ),
            ],
          ),
          if (channel != null) ...[
            SizedBox(height: tokens.spacing.s12),
            Text(
              channel.number == null
                  ? channel.name
                  : '${channel.number} · ${channel.name}',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: tokens.text.bodyStrong.copyWith(color: colors.textPrimary),
            ),
            if (now != null) ...[
              SizedBox(height: tokens.spacing.s4),
              Text(
                '${now.title} · ${formatTimeRangeShort(now.start, now.end)}',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: secondary,
              ),
            ],
          ],
          SizedBox(height: tokens.spacing.s8),
          Text(
            'Enter on a channel plays it on the TV.',
            style: tokens.text.caption.copyWith(color: colors.textTertiary),
          ),
          SizedBox(height: tokens.spacing.s16),
          Wrap(
            spacing: tokens.spacing.s8,
            runSpacing: tokens.spacing.s8,
            children: [
              if (channel != null)
                AppButton(
                  label: 'Open casting view',
                  variant: AppButtonVariant.secondary,
                  size: AppButtonSize.s,
                  onPressed: () =>
                      ref.read(castingViewOpenProvider.notifier).open(),
                ),
              AppButton(
                label: 'Stop casting',
                icon: AppIcons.stop,
                variant: AppButtonVariant.dangerOutline,
                size: AppButtonSize.s,
                onPressed: () =>
                    unawaited(ref.read(castCoordinatorProvider).disconnect()),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
