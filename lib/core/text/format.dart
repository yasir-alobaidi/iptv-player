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
