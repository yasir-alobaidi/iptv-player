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

// Setting, removing and listing them (sketches F–H).

/// What a control that sets one says, and what it says once it is set.
const remindMeLabel = 'Remind me';
const reminderSetLabel = 'Reminder set';

/// A menu's and a key hint's way to take one back.
const removeReminderLabel = 'Remove reminder';

/// The toast after setting one: "Reminder set · Tomorrow, 9:30 PM".
String reminderSetText(DateTime start, DateTime now, TimeStyle style) =>
    '$reminderSetLabel · ${reminderWhen(start, now, style)}';

/// The toast after removing one: "Reminder removed · The Harbor Pilot".
String reminderRemovedText(String title) => 'Reminder removed · $title';

/// Remind me on a programme that is on already, or over.
String reminderTooLateText(String title) => '$title has already started.';

/// A reminder whose channel the source no longer lists: Watch, and Enter
/// in the list, say so.
String reminderChannelGoneText(String channelName) =>
    '$channelName is no longer in your channels.';

/// The list's title and Settings → Guide's row: "Reminders · 3".
String remindersTitle(int count) =>
    count == 0 ? 'Reminders' : 'Reminders · ${formatCount(count)}';

/// Under the list (sketch H): the one limit, said plainly.
const remindersLimit =
    'A reminder shows when its programme starts, while the app is open.';

/// The empty list: where one is set.
const noRemindersTitle = 'No reminders';
const noRemindersMessage =
    'Press R on an upcoming programme in the Guide, or choose Remind me '
    'in Search.';

/// The same with the Guide switched off (ADR-031): nowhere sets one then.
const noRemindersMessageGuideOff =
    'Reminders are set on programmes in the Guide, which is switched '
    'off. Switch it on in Settings → Guide to set one.';

/// A row of the list, for assistive technology: "The Harbor Pilot, Blue
/// Water, Tomorrow, 9:30 PM".
String reminderRowLabel(Reminder reminder, DateTime now, TimeStyle style) => [
  reminder.title,
  reminder.channelName,
  reminderWhen(reminder.start, now, style),
].join(', ');

/// The bell in the Guide's toolbar, for assistive technology.
String remindersButtonLabel(int count) => switch (count) {
  0 => 'Reminders, none set',
  1 => 'Reminders, 1 set',
  _ => 'Reminders, ${formatCount(count)} set',
};
