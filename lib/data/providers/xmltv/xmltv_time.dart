/// XMLTV times (docs/02 "XMLTV"): `20260914180000 +0200` to epoch
/// milliseconds UTC. Internal to the XMLTV parser; public for its tests.
library;

import 'package:iptv_player/data/providers/xmltv/xmltv_parser.dart';

/// [text] as epoch ms UTC, or the [XmltvSkip] code saying why it is not a
/// time: [XmltvSkip.badDate] or [XmltvSkip.badTimezone].
///
/// `YYYYMMDDhhmmss`, with 14, 12, 10 or 8 digits (the missing parts are
/// zero), then an optional zone, with or without a space: `+HHMM`,
/// `-HHMM`, `+HH:MM`, `+HH`, or `Z` / `UTC` / `GMT`. No zone is UTC, as
/// the XMLTV DTD says. A calendar-invalid date (30 February, hour 24) is
/// [XmltvSkip.badDate]; a zone past ±14 hours, minutes past 59, or a name
/// (`EST`) is [XmltvSkip.badTimezone] — a name is ambiguous, so it is not
/// guessed.
({int ms, String? skip}) parseXmltvTime(String text) {
  const badDate = (ms: 0, skip: XmltvSkip.badDate);
  const badZone = (ms: 0, skip: XmltvSkip.badTimezone);

  final value = text.trim();
  final length = value.length;
  var i = 0;
  while (i < length && _isDigit(value.codeUnitAt(i))) {
    i++;
  }
  if (i != 14 && i != 12 && i != 10 && i != 8) return badDate;
  final digits = i;

  final year = _number(value, 0, 4);
  final month = _number(value, 4, 2);
  final day = _number(value, 6, 2);
  final hour = digits >= 10 ? _number(value, 8, 2) : 0;
  final minute = digits >= 12 ? _number(value, 10, 2) : 0;
  final second = digits >= 14 ? _number(value, 12, 2) : 0;
  if (month < 1 ||
      month > 12 ||
      day < 1 ||
      day > _daysInMonth(year, month) ||
      hour > 23 ||
      minute > 59 ||
      second > 59) {
    return badDate;
  }

  while (i < length && _isBlank(value.codeUnitAt(i))) {
    i++;
  }
  var offsetMinutes = 0;
  if (i < length) {
    final sign = value.codeUnitAt(i);
    if (sign == 0x2b || sign == 0x2d) {
      // +HHMM, +HH:MM or +HH, and nothing after it.
      final rest = length - i - 1;
      final int hours;
      final int minutes;
      if (rest == 4 && _allDigits(value, i + 1, 4)) {
        hours = _number(value, i + 1, 2);
        minutes = _number(value, i + 3, 2);
      } else if (rest == 5 &&
          _allDigits(value, i + 1, 2) &&
          value.codeUnitAt(i + 3) == 0x3a &&
          _allDigits(value, i + 4, 2)) {
        hours = _number(value, i + 1, 2);
        minutes = _number(value, i + 4, 2);
      } else if (rest == 2 && _allDigits(value, i + 1, 2)) {
        hours = _number(value, i + 1, 2);
        minutes = 0;
      } else {
        return badZone;
      }
      if (hours > 14 || minutes > 59) return badZone;
      offsetMinutes = (hours * 60 + minutes) * (sign == 0x2d ? -1 : 1);
    } else {
      final zone = value.substring(i).toUpperCase();
      if (zone != 'Z' && zone != 'UTC' && zone != 'GMT') return badZone;
    }
  }

  final seconds =
      _daysFromCivil(year, month, day) * 86400 +
      hour * 3600 +
      minute * 60 +
      second;
  return (ms: (seconds - offsetMinutes * 60) * 1000, skip: null);
}

bool _isDigit(int unit) => unit >= 0x30 && unit <= 0x39;

bool _isBlank(int unit) => unit == 0x20 || unit == 0x09;

bool _allDigits(String text, int start, int count) {
  for (var i = start; i < start + count; i++) {
    if (!_isDigit(text.codeUnitAt(i))) return false;
  }
  return true;
}

/// The decimal number in [count] digits from [start]; the caller has
/// checked they are digits.
int _number(String text, int start, int count) {
  var value = 0;
  for (var i = start; i < start + count; i++) {
    value = value * 10 + text.codeUnitAt(i) - 0x30;
  }
  return value;
}

int _daysInMonth(int year, int month) {
  if (month == 2) {
    final leap = year % 4 == 0 && (year % 100 != 0 || year % 400 == 0);
    return leap ? 29 : 28;
  }
  return const [31, 0, 31, 30, 31, 30, 31, 31, 30, 31, 30, 31][month - 1];
}

/// Days since 1970-01-01 in the proleptic Gregorian calendar (Howard
/// Hinnant's `days_from_civil`): arithmetic, not a `DateTime` per time,
/// because a guide has two times per programme and a million programmes.
int _daysFromCivil(int year, int month, int day) {
  final y = month <= 2 ? year - 1 : year;
  final era = (y >= 0 ? y : y - 399) ~/ 400;
  final yearOfEra = y - era * 400;
  final dayOfYear =
      (153 * (month > 2 ? month - 3 : month + 9) + 2) ~/ 5 + day - 1;
  final dayOfEra =
      yearOfEra * 365 + yearOfEra ~/ 4 - yearOfEra ~/ 100 + dayOfYear;
  return era * 146097 + dayOfEra - 719468;
}
