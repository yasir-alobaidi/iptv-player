import 'dart:async';

import 'package:iptv_player/core/logging/app_log.dart';
import 'package:iptv_player/core/result.dart';
import 'package:iptv_player/features/reminders/domain/reminder.dart';

const _tag = 'reminders';

/// Shows reminders when their programmes start (Phase 9 decision 10).
/// Plain rules over a clock:
///
/// - one timer to the next reminder that is due, and a look again every
///   minute, so a computer that slept through a start, or a clock that
///   was set, is caught;
/// - a reminder whose start has come is taken out of the store first and
///   shown only by whoever took it out, so it never shows twice;
/// - one whose start passed a while ago is shown only while its
///   programme is still on, and dropped without a word once it is over.
///
/// It runs only while the app does: there is no helper that starts with
/// the computer.
final class ReminderScheduler {
  new({
    required this._reminders,
    required this._onDue,
    required this._log,
    DateTime Function()? clock,
    this.lookEvery = const Duration(minutes: 1),
    this.onTimeWithin = const Duration(seconds: 90),
  }) : _clock = clock ?? DateTime.now;

  final ReminderRepository _reminders;
  final FutureOr<void> Function(DueReminder due) _onDue;
  final AppLog _log;
  final DateTime Function() _clock;

  /// How often the list is looked at whatever the timer says.
  final Duration lookEvery;

  /// A reminder shown this soon after its start still says "Starting
  /// now": the look every minute may be that late.
  final Duration onTimeWithin;

  StreamSubscription<List<Reminder>>? _watching;
  Timer? _next;
  Timer? _tick;
  Future<void> _checking = Future.value();
  bool _disposed = false;

  /// Shows what is due now (what fell due while the app was closed, if
  /// still on), then keeps watch.
  Future<void> start() async {
    if (_disposed || _watching != null) return;
    _tick = Timer.periodic(lookEvery, (_) => unawaited(check()));
    // Every change of the list (one set, moved, removed) is looked at:
    // the next one due may be another now.
    _watching = _reminders.watchAll().listen(
      (_) => unawaited(check()),
      onError: (Object error) =>
          _log.warning(_tag, "Couldn't watch the reminders: $error"),
    );
    await check();
  }

  /// Looks at the list now. One look at a time: a second asked for while
  /// one runs waits for it, so a reminder is taken by one of them only.
  Future<void> check() {
    final previous = _checking;
    return _checking = previous.then((_) => _check());
  }

  Future<void> _check() async {
    if (_disposed) return;
    final listed = await _reminders.all();
    if (_disposed) return;
    final reminders = listed.valueOrNull;
    if (reminders == null) {
      _log.warning(
        _tag,
        "Couldn't read the reminders: ${listed.failureOrNull}",
      );
      return;
    }
    final now = _clock();
    DateTime? soonest;
    for (final reminder in reminders) {
      if (reminder.start.isAfter(now)) {
        if (soonest == null || reminder.start.isBefore(soonest)) {
          soonest = reminder.start;
        }
        continue;
      }
      // Out of the store first: whatever happens next, it won't be due
      // again.
      final removed = await _reminders.remove(reminder.id);
      if (_disposed) return;
      if (removed.valueOrNull != true) continue;
      if (!reminder.end.isAfter(now)) {
        _log.info(_tag, 'A reminder fell due and was over: not shown');
        continue;
      }
      final late = now.difference(reminder.start) > onTimeWithin;
      try {
        await _onDue(
          DueReminder(
            reminder,
            late ? ReminderTiming.onNow : ReminderTiming.startingNow,
          ),
        );
      } on Object catch (error) {
        _log.warning(_tag, "A reminder couldn't be shown: $error");
      }
    }
    _arm(soonest, now);
  }

  void _arm(DateTime? soonest, DateTime now) {
    _next?.cancel();
    _next = null;
    if (soonest == null || _disposed) return;
    final wait = soonest.difference(now);
    // A timer's longest wait is far past any guide; a clock that jumps
    // is what the look every minute is for.
    _next = Timer(wait.isNegative ? Duration.zero : wait, () {
      unawaited(check());
    });
  }

  void dispose() {
    _disposed = true;
    _next?.cancel();
    _tick?.cancel();
    unawaited(_watching?.cancel());
  }
}

/// Runs decision 12 over a source's reminders after its guide went live:
/// each follows its programme. Returns what changed, to be said.
final class ReminderFollower {
  new({required this._reminders, required this._guide, required this._log});

  final ReminderRepository _reminders;
  final ReminderGuide _guide;
  final AppLog _log;

  Future<List<FollowedReminder>> follow(String sourceId) async {
    final listed = await _reminders.forSource(sourceId);
    final changed = <FollowedReminder>[];
    for (final reminder in listed.valueOrNull ?? const <Reminder>[]) {
      final answer = await _guide.lookUp(
        sourceId: sourceId,
        xmltvId: reminder.xmltvId,
        title: reminder.title,
        around: reminder.start,
        within: followWithin,
      );
      final guide = answer.valueOrNull;
      if (guide == null) {
        // A guide that can't be read says nothing about the programme.
        _log.warning(
          _tag,
          "Couldn't look a reminder up in the guide: ${answer.failureOrNull}",
        );
        continue;
      }
      switch (followReminder(reminder, guide)) {
        case ReminderKept():
          break;
        case ReminderGone():
          if ((await _reminders.remove(reminder.id)).valueOrNull ?? false) {
            changed.add(FollowedReminder(reminder, const ReminderGone()));
          }
        case final ReminderMoved moved:
          final result = await _reminders.move(
            reminder.id,
            moved.start,
            moved.end,
          );
          if (result is Ok) {
            changed.add(FollowedReminder(reminder, moved));
          } else {
            // Another reminder is already at the new time: this one is
            // the same programme twice.
            await _reminders.remove(reminder.id);
          }
      }
    }
    return changed;
  }
}

/// A reminder a guide refresh moved or removed, as it was before.
final class FollowedReminder {
  const new(this.before, this.outcome);

  final Reminder before;
  final ReminderFollow outcome;
}
