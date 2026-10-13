import 'package:iptv_player/core/text/format.dart';
import 'package:iptv_player/features/reminders/domain/reminder.dart';

// Every sentence a reminder says (sketch I).

/// The line under a notification's title: "Starting now on Blue Water",
/// or, for one whose start passed while the app was closed, "On now on
/// Blue Water, until 10:30 PM".
String reminderNoticeBody(DueReminder due, TimeStyle style) {
  final reminder = due.reminder;
  return switch (due.timing) {
    ReminderTiming.startingNow => 'Starting now on ${reminder.channelName}',
    ReminderTiming.onNow =>
      'On now on ${reminder.channelName}, until '
          '${formatClock(reminder.end, style)}',
  };
}

/// The same inside the app, on one line: "Starting now · The Harbor Pilot
/// on Blue Water".
String reminderToast(DueReminder due, TimeStyle style) {
  final reminder = due.reminder;
  final what = '${reminder.title} on ${reminder.channelName}';
  return switch (due.timing) {
    ReminderTiming.startingNow => 'Starting now · $what',
    ReminderTiming.onNow =>
      'On now · $what, until ${formatClock(reminder.end, style)}',
  };
}

/// After a guide refresh moved a programme: "The Harbor Pilot moved to
/// 9:45 PM. Your reminder moved with it." With the day when that
/// changed too.
String reminderMovedText(
  Reminder before,
  DateTime start,
  DateTime now,
  TimeStyle style,
) {
  final sameDay =
      formatRelativeDay(before.start, now) == formatRelativeDay(start, now);
  final when = sameDay
      ? formatClock(start, style)
      : '${formatRelativeDay(start, now)}, ${formatClock(start, style)}';
  return '${before.title} moved to $when. Your reminder moved with it.';
}

/// After a guide refresh dropped a programme.
String reminderGoneText(Reminder before) =>
    '${before.title} is no longer in the guide. Its reminder was removed.';

/// "Tomorrow, 9:30 PM": when a reminder will show, in lists and in the
/// toast that says one was set.
String reminderWhen(DateTime start, DateTime now, TimeStyle style) =>
    '${formatRelativeDay(start, now)}, ${formatClock(start, style)}';
