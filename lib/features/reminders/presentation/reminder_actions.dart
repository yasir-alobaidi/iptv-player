import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:iptv_player/app/destinations.dart';
import 'package:iptv_player/app/failure_message.dart';
import 'package:iptv_player/app/router.dart';
import 'package:iptv_player/core/core_providers.dart';
import 'package:iptv_player/core/notices/app_notices.dart';
import 'package:iptv_player/core/result.dart';
import 'package:iptv_player/features/guide/data/guide_providers.dart';
import 'package:iptv_player/features/guide/domain/epg.dart';
import 'package:iptv_player/features/guide/presentation/guide_programme_request.dart';
import 'package:iptv_player/features/live_tv/data/live_tv_providers.dart';
import 'package:iptv_player/features/live_tv/domain/channels.dart';
import 'package:iptv_player/features/live_tv/presentation/live_tv_state.dart';
import 'package:iptv_player/features/reminders/data/reminder_providers.dart';
import 'package:iptv_player/features/reminders/domain/reminder.dart';
import 'package:iptv_player/features/reminders/presentation/reminder_text.dart';
import 'package:iptv_player/features/settings/data/appearance_providers.dart';
import 'package:iptv_player/features/sources/presentation/current_source.dart';

// What Remind me, R, Ctrl+R and the list's rows do (Phase 9 decision 13).
// Made from the app's container, not a screen's `ref`: a toast's Undo and
// a jump to the Guide outlive the overlay or the dialog they started in.

/// The reminder set for [programme] on [channel] among [reminders]; null
/// when there is none.
Reminder? reminderFor(
  Iterable<Reminder> reminders,
  ChannelItem channel,
  EpgProgramme programme,
) {
  for (final reminder in reminders) {
    if (reminder.isFor(
      sourceId: channel.sourceId,
      channelKey: channel.remoteKey,
      start: programme.start,
    )) {
      return reminder;
    }
  }
  return null;
}

/// Sets a reminder for [programme] on [channel], or removes the one it
/// has; either way a toast says so, with Undo. One that is on already,
/// or over, says that instead: there is nothing left to be reminded of.
Future<void> toggleReminder(
  ProviderContainer container,
  ChannelItem channel,
  EpgProgramme programme,
) async {
  final repository = container.read(reminderRepositoryProvider);
  final notices = container.read(appNoticesProvider);
  final held = await repository.forSource(channel.sourceId);
  final set = reminderFor(held.valueOrNull ?? const [], channel, programme);
  if (set != null) {
    await removeReminder(container, set);
    return;
  }

  final now = container.read(appClockProvider)();
  if (!programme.start.isAfter(now)) {
    notices.show(AppNotice(reminderTooLateText(programme.title)));
    return;
  }
  final result = await repository.set(
    ReminderDraft(
      sourceId: channel.sourceId,
      channelKey: channel.remoteKey,
      xmltvId: programme.channelId,
      channelName: channel.name,
      title: programme.title,
      start: programme.start,
      end: programme.end,
    ),
  );
  switch (result) {
    case Ok(value: final reminder):
      notices.show(
        AppNotice.undoable(
          reminderSetText(
            reminder.start,
            now,
            container.read(timeStyleProvider),
          ),
          onUndo: () => unawaited(repository.remove(reminder.id)),
        ),
      );
    case Err(:final failure):
      notices.show(
        AppNotice(
          "Couldn't set the reminder. ${failureMessage(failure)}",
          tone: NoticeTone.error,
        ),
      );
  }
}

/// Removes [reminder] and says so, with Undo.
Future<void> removeReminder(
  ProviderContainer container,
  Reminder reminder,
) async {
  final repository = container.read(reminderRepositoryProvider);
  final notices = container.read(appNoticesProvider);
  switch (await repository.remove(reminder.id)) {
    case Ok():
      notices.show(
        AppNotice.undoable(
          reminderRemovedText(reminder.title),
          onUndo: () => unawaited(
            repository.set(
              ReminderDraft(
                sourceId: reminder.sourceId,
                channelKey: reminder.channelKey,
                xmltvId: reminder.xmltvId,
                channelName: reminder.channelName,
                title: reminder.title,
                start: reminder.start,
                end: reminder.end,
              ),
            ),
          ),
        ),
      );
    case Err(:final failure):
      notices.show(
        AppNotice(
          "Couldn't remove the reminder. ${failureMessage(failure)}",
          tone: NoticeTone.error,
        ),
      );
  }
}

/// The channel [reminder] is for, as the source lists it now; null when
/// it no longer does.
Future<ChannelItem?> reminderChannel(
  ProviderContainer container,
  Reminder reminder,
) async =>
    (await container
            .read(channelRepositoryProvider)
            .byRemoteKey(reminder.sourceId, reminder.channelKey))
        .valueOrNull;

/// Enter on a row of the list: the Guide on [reminder]'s programme, with
/// its sheet open, as search opens an upcoming one. With the Guide
/// switched off (ADR-031; reminders work without it), its channel in
/// Live TV instead, as search's "Show in Live TV". [beforeLeaving] runs
/// once it is known there is somewhere to go (the list closes itself
/// with it). A channel that is gone says so and goes nowhere: false.
Future<bool> showReminderInGuide(
  ProviderContainer container,
  Reminder reminder, {
  void Function()? beforeLeaving,
}) async {
  final channel = await reminderChannel(container, reminder);
  if (channel == null) {
    container
        .read(appNoticesProvider)
        .show(AppNotice(reminderChannelGoneText(reminder.channelName)));
    return false;
  }
  if (!container.read(guideEnabledProvider)) {
    _browse(container, channel.sourceId);
    beforeLeaving?.call();
    container.read(routerProvider).go(AppDestination.liveTv.path);
    // Live TV's view is made with the screen: set once it is up.
    WidgetsBinding.instance
      ..addPostFrameCallback((_) {
        container.read(liveTvControllerProvider.notifier)
          ..showSearch(channel.name)
          ..select(channel);
      })
      ..ensureVisualUpdate();
    return true;
  }
  // The guide's own programme, so the sheet has its description; the
  // reminder's copy when a refresh is between the two.
  final window = await container
      .read(epgRepositoryProvider)
      .windowForChannels([channel.id], reminder.start, reminder.end);
  final programme =
      window.valueOrNull?[channel.id]
          ?.where((found) => found.start.isAtSameMomentAs(reminder.start))
          .firstOrNull ??
      EpgProgramme(
        id: 0,
        channelId: reminder.xmltvId,
        start: reminder.start,
        end: reminder.end,
        title: reminder.title,
      );
  _browse(container, channel.sourceId);
  beforeLeaving?.call();
  container
      .read(guideProgrammeRequestProvider.notifier)
      .show(channel, programme);
  container.read(routerProvider).go(AppDestination.guide.path);
  return true;
}

/// Browses [sourceId] when the reminder is another source's: the screen
/// it opens shows the browsed one.
void _browse(ProviderContainer container, String sourceId) {
  if (container.read(currentSourceProvider)?.id != sourceId) {
    container.read(chosenSourceIdProvider.notifier).choose(sourceId);
  }
}
