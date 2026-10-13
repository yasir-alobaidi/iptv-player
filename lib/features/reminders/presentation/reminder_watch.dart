import 'dart:async';

import 'package:iptv_player/app/router.dart';
import 'package:iptv_player/core/core_providers.dart';
import 'package:iptv_player/core/notices/app_notices.dart';
import 'package:iptv_player/core/platform/window_controls.dart';
import 'package:iptv_player/features/casting/presentation/cast_actions.dart';
import 'package:iptv_player/features/live_tv/domain/channels.dart';
import 'package:iptv_player/features/live_tv/presentation/live_tv_screen.dart';
import 'package:iptv_player/features/playback/data/playback_providers.dart';
import 'package:iptv_player/features/playback/domain/playable.dart';
import 'package:iptv_player/features/reminders/data/reminder_providers.dart';
import 'package:iptv_player/features/reminders/presentation/reminder_actions.dart';
import 'package:iptv_player/features/reminders/presentation/reminder_alerts.dart';
import 'package:iptv_player/features/reminders/presentation/reminder_text.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'reminder_watch.g.dart';

/// Watch on a reminder, from the desktop's notification or the app's
/// toast, plays its channel (Phase 9 decision 10). Alive from launch:
/// `bootstrap()` reads it once.
///
/// It listens to the alerts' stream itself: a provider nobody watches is
/// paused, and a Watch must not wait for a screen.
@Riverpod(keepAlive: true)
void reminderWatches(Ref ref) {
  final container = ref.container;
  final listening = ref
      .watch(reminderAlertsProvider)
      .watches
      .listen(
        (watch) => unawaited(watchReminder(container, watch)),
        onError: (Object _) {},
      );
  ref.onDispose(() => unawaited(listening.cancel()));
}

/// The window forward, then the channel: full screen here, replacing
/// what plays as Enter on a channel does, or on the TV while casting. A
/// channel the source no longer lists says so.
Future<void> watchReminder(
  ProviderContainer container,
  ReminderWatch watch,
) async {
  final reminder = watch.reminder;
  // The window first, whatever comes of the channel: the user chose the
  // app. From a toast it is in front already.
  try {
    await container
        .read(windowControlsProvider)
        .bringToFront(activationToken: watch.activationToken);
  } on Object catch (error) {
    container
        .read(appLogProvider)
        .warning('reminders', 'The window was not brought forward: $error');
  }
  final channel = await reminderChannel(container, reminder);
  if (channel == null) {
    container
        .read(appNoticesProvider)
        .show(AppNotice(reminderChannelGoneText(reminder.channelName)));
    return;
  }
  final playback = container.read(playbackCoordinatorProvider);
  if (playback.casting) {
    await playOnTv(container, PlayableChannel(channel));
    return;
  }
  final router = container.read(routerProvider);
  if (isSearchOpen(router)) router.pop();
  // The player already up (a movie, another channel): it shows the new
  // channel, and whoever opened it sees to its end.
  final playerOpen = router.state.uri.path == playerRoutePath;
  unawaited(playback.playLive(channel));
  if (playerOpen) return;
  await router.push<void>(
    playerRoutePath,
    extra: ChannelQuery(sourceId: channel.sourceId),
  );
  // Back where the user was, and the stream stops there, as it does
  // after a channel opened from search.
  if (playback.current != null) unawaited(playback.stop());
}
