/// Display formatting for the few numbers and dates the UI shows. The app
/// is in English only (docs/00), so this stays small instead of pulling
/// in a locale library.
library;

/// `12,340`.
String formatCount(int value) {
  final digits = value.abs().toString();
  final out = StringBuffer(value < 0 ? '-' : '');
  for (var i = 0; i < digits.length; i++) {
    if (i > 0 && (digits.length - i) % 3 == 0) out.write(',');
    out.write(digits[i]);
  }
  return out.toString();
}

/// `Nov 3, 2026`, in local time.
String formatDate(DateTime date) {
  final local = date.toLocal();
  return '${_months[local.month - 1]} ${local.day}, ${local.year}';
}

/// `48.2 MB`.
String formatBytes(int bytes) {
  const units = ['bytes', 'KB', 'MB', 'GB', 'TB'];
  var size = bytes.toDouble();
  var unit = 0;
  while (size >= 1024 && unit < units.length - 1) {
    size /= 1024;
    unit++;
  }
  return unit == 0
      ? '$bytes bytes'
      : '${size.toStringAsFixed(1)} ${units[unit]}';
}

/// `6 s`, `1 min 12 s`.
String formatDuration(Duration duration) {
  final seconds = duration.inSeconds;
  if (seconds < 60) return '${seconds < 1 ? '<1' : seconds} s';
  final rest = seconds % 60;
  return rest == 0 ? '${seconds ~/ 60} min' : '${seconds ~/ 60} min $rest s';
}

/// `just now`, `12 min ago`, `3 h ago`, `yesterday`, `4 days ago`, then
/// the date. A time in the future (a skewed clock) reads as just now.
String formatAgo(DateTime at, DateTime now) {
  final elapsed = now.difference(at);
  if (elapsed.inMinutes < 1) return 'just now';
  if (elapsed.inMinutes < 60) return '${elapsed.inMinutes} min ago';
  if (elapsed.inHours < 24) return '${elapsed.inHours} h ago';
  final days = _calendarDays(at, now);
  if (days <= 1) return 'yesterday';
  if (days < 7) return '$days days ago';
  return 'on ${formatDate(at)}';
}

/// `Nov 3`: a date within the current year, in local time.
String formatShortDate(DateTime date) {
  final local = date.toLocal();
  return '${_months[local.month - 1]} ${local.day}';
}

/// Whole local calendar days from [from] to [to].
int _calendarDays(DateTime from, DateTime to) {
  final a = from.toLocal();
  final b = to.toLocal();
  return DateTime.utc(
    b.year,
    b.month,
    b.day,
  ).difference(DateTime.utc(a.year, a.month, a.day)).inDays;
}

const _months = [
  'Jan',
  'Feb',
  'Mar',
  'Apr',
  'May',
  'Jun',
  'Jul',
  'Aug',
  'Sep',
  'Oct',
  'Nov',
  'Dec',
];

/// `8:05 PM`, in local time (the 12/24 h setting arrives in Phase 9).
String formatClock(DateTime at) {
  final local = at.toLocal();
  final hour = local.hour % 12 == 0 ? 12 : local.hour % 12;
  final minute = local.minute.toString().padLeft(2, '0');
  return '$hour:$minute ${local.hour < 12 ? 'AM' : 'PM'}';
}

/// `8:00 – 10:00 PM`, or `11:30 AM – 1:00 PM` when the halves differ.
String formatTimeRange(DateTime start, DateTime end) {
  final a = formatClock(start);
  final b = formatClock(end);
  final sameHalf = a.substring(a.length - 2) == b.substring(b.length - 2);
  return sameHalf ? '${a.substring(0, a.length - 3)} – $b' : '$a – $b';
}

/// `38 min left`, `1 h 24 min left`.
String formatTimeLeft(Duration left) {
  final minutes = left.inMinutes < 1 ? 1 : left.inMinutes;
  if (minutes < 60) return '$minutes min left';
  final rest = minutes % 60;
  return rest == 0
      ? '${minutes ~/ 60} h left'
      : '${minutes ~/ 60} h $rest min left';
}

/// `8:05`: [formatClock] without AM/PM, for the Guide's ruler and its
/// narrow cells, where the half of the day is clear from the labels
/// around it.
String formatClockShort(DateTime at) {
  final clock = formatClock(at);
  return clock.substring(0, clock.length - 3);
}

/// `8:00 – 10:00`: [formatTimeRange] without AM/PM.
String formatTimeRangeShort(DateTime start, DateTime end) =>
    '${formatClockShort(start)} – ${formatClockShort(end)}';

/// True when [a] and [b] fall in the same half of the day (AM or PM), in
/// local time.
bool sameMeridiem(DateTime a, DateTime b) =>
    (a.toLocal().hour < 12) == (b.toLocal().hour < 12);

/// `Tuesday`, in local time.
String formatWeekday(DateTime at) => _weekdays[at.toLocal().weekday - 1];

/// `Wed 16`: a day pill in the Guide.
String formatDayPill(DateTime day) {
  final local = day.toLocal();
  return '${_weekdays[local.weekday - 1].substring(0, 3)} ${local.day}';
}

/// `Today`, `Tomorrow`, `Yesterday`, else `Tue Sep 15` — [day] as seen
/// from [now], both in local time.
String formatRelativeDay(DateTime day, DateTime now) {
  final days = _calendarDays(now, day);
  if (days == 0) return 'Today';
  if (days == 1) return 'Tomorrow';
  if (days == -1) return 'Yesterday';
  final local = day.toLocal();
  return '${_weekdays[local.weekday - 1].substring(0, 3)} '
      '${_months[local.month - 1]} ${local.day}';
}

const _weekdays = [
  'Monday',
  'Tuesday',
  'Wednesday',
  'Thursday',
  'Friday',
  'Saturday',
  'Sunday',
];
