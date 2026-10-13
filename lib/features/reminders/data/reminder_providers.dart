import 'dart:async';

import 'package:iptv_player/core/core_providers.dart';
import 'package:iptv_player/core/platform/system_notifier.dart';
import 'package:iptv_player/core/platform/window_controls.dart';
import 'package:iptv_player/data/db/db_providers.dart';
import 'package:iptv_player/features/guide/data/guide_providers.dart';
import 'package:iptv_player/features/reminders/data/db_reminder_repository.dart';
import 'package:iptv_player/features/reminders/domain/reminder.dart';
import 'package:iptv_player/features/reminders/domain/reminder_scheduler.dart';
import 'package:iptv_player/features/reminders/presentation/reminder_alerts.dart';
import 'package:iptv_player/features/settings/data/appearance_providers.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'reminder_providers.g.dart';

@Riverpod(keepAlive: true)
ReminderRepository reminderRepository(Ref ref) => DbReminderRepository(
  ref.watch(appDatabaseProvider),
  clock: ref.watch(appClockProvider),
);

@Riverpod(keepAlive: true)
ReminderGuide reminderGuide(Ref ref) =>
    DbReminderGuide(ref.watch(appDatabaseProvider));

/// Every reminder, soonest first.
@Riverpod(keepAlive: true)
Stream<List<Reminder>> reminders(Ref ref) =>
    ref.watch(reminderRepositoryProvider).watchAll();

/// How a due reminder is said, and where its Watch is heard.
@Riverpod(keepAlive: true)
ReminderAlerts reminderAlerts(Ref ref) {
  final alerts = ReminderAlerts(
    notifier: ref.watch(systemNotificationsProvider),
    window: ref.watch(windowControlsProvider),
    notices: ref.watch(appNoticesProvider),
    // Read when a reminder is due, not watched: a change of the clock in
    // Settings must not rebuild what holds the notices on screen.
    timeStyle: () => ref.read(timeStyleProvider),
    log: ref.watch(appLogProvider),
    clock: ref.watch(appClockProvider),
  );
  ref.onDispose(alerts.dispose);
  return alerts;
}

/// The reminders at work: shown when due, and following their programmes
/// through every guide refresh. `bootstrap()` starts it after the first
/// frame; nothing else needs to.
@Riverpod(keepAlive: true)
ReminderService reminderService(Ref ref) {
  final repository = ref.watch(reminderRepositoryProvider);
  final alerts = ref.watch(reminderAlertsProvider);
  final log = ref.watch(appLogProvider);
  final service = ReminderService(
    scheduler: ReminderScheduler(
      reminders: repository,
      onDue: alerts.show,
      log: log,
      clock: ref.watch(appClockProvider),
    ),
    follower: ReminderFollower(
      reminders: repository,
      guide: ref.watch(reminderGuideProvider),
      log: log,
    ),
    alerts: alerts,
    // The importer itself, not the screens' view of it: only it says
    // when a guide went live.
    wentLive: ref.watch(epgImporterProvider).wentLive,
  );
  ref.onDispose(service.dispose);
  return service;
}

/// The scheduler and the follower, started and stopped together.
final class ReminderService {
  new({
    required this.scheduler,
    required this._follower,
    required this._alerts,
    required this._wentLive,
  });

  final ReminderScheduler scheduler;
  final ReminderFollower _follower;
  final ReminderAlerts _alerts;
  final Stream<String> _wentLive;
  StreamSubscription<String>? _following;

  Future<void> start() async {
    _following ??= _wentLive.listen(
      (sourceId) => unawaited(follow(sourceId)),
      onError: (Object _) {},
    );
    await scheduler.start();
  }

  /// After [sourceId]'s guide went live: its reminders follow their
  /// programmes, and what changed is said.
  Future<void> follow(String sourceId) async {
    final changed = await _follower.follow(sourceId);
    _alerts.sayFollowed(changed);
    // A reminder may have moved to now, or to earlier than the next one.
    await scheduler.check();
  }

  void dispose() {
    unawaited(_following?.cancel());
    scheduler.dispose();
  }
}
