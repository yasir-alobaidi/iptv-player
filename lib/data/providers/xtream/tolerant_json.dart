/// Readers for Xtream JSON values that accept every shape docs/02 says
/// panels send: numbers as strings, booleans as `"1"`/`"0"`, `""` for
/// missing, `[]` where an object belongs. None of them throw; a value that
/// can't be read is null, and the caller decides whether the row survives
/// without it.
library;

import 'package:iptv_player/data/providers/provider_text.dart';

/// An int from `12`, `12.0`, `"12"`, `" 12 "` or `"12.0"`.
int? readInt(Object? value) => switch (value) {
  final int v => v,
  final double v when v.isFinite => v.truncate(),
  final String v => int.tryParse(v.trim()) ?? _truncated(double.tryParse(v)),
  _ => null,
};

int? _truncated(double? value) =>
    value == null || !value.isFinite ? null : value.truncate();

/// A double from a number or its string form. `"7,4"` reads as 7.4:
/// some panels format ratings for a comma locale.
double? readDouble(Object? value) => switch (value) {
  final num v when v.isFinite => v.toDouble(),
  final String v => _finite(
    double.tryParse(v.trim()) ?? double.tryParse(v.trim().replaceAll(',', '.')),
  ),
  _ => null,
};

double? _finite(double? value) =>
    value == null || !value.isFinite ? null : value;

/// Xtream booleans: `1`/`0`, `"1"`/`"0"`, `true`/`false`, `"true"`.
bool? readBool(Object? value) => switch (value) {
  final bool v => v,
  final num v => v != 0,
  final String v => switch (v.trim().toLowerCase()) {
    '1' || 'true' || 'yes' => true,
    '0' || 'false' || 'no' || '' => false,
    _ => null,
  },
  _ => null,
};

/// Raw text: strings as they are (trimmed), numbers in their string form
/// (ids arrive either way), `""` as null.
String? readString(Object? value) => switch (value) {
  final String v when v.trim().isNotEmpty => v.trim(),
  final num v => v is int || v != v.truncate() ? '$v' : '${v.truncate()}',
  _ => null,
};

/// Display text: [readString], then [cleanText].
String? readText(Object? value) => cleanText(readString(value));

/// A unix-seconds timestamp as UTC, from a number or a numeric string.
/// Zero and negative values mean "none", as panels use them.
DateTime? readUnixTime(Object? value) {
  final seconds = readInt(value);
  if (seconds == null || seconds <= 0) return null;
  return DateTime.fromMillisecondsSinceEpoch(seconds * 1000, isUtc: true);
}

/// An object, or empty for `[]`, `""`, null or anything else: panels send
/// `info: []` when there is no info.
Map<String, Object?> readMap(Object? value) =>
    value is Map<String, Object?> ? value : const {};

/// The rows of a list response. A list is the list; an object is its
/// values (some panels key rows by id); anything else is no rows.
List<Object?> readRows(Object? value) => switch (value) {
  final List<Object?> v => v,
  final Map<String, Object?> v => v.values.toList(),
  _ => const [],
};

/// A year from `1995`, `"1995"`, `"1995-03-01"` or `"03/01/1995"`, within
/// a plausible range.
int? readYear(Object? value) {
  final direct = readInt(value);
  if (direct != null && direct > 1800 && direct < 2200) return direct;
  final text = readString(value);
  if (text == null) return null;
  final match = RegExp(r'\b(1[89]\d\d|2[01]\d\d)\b').firstMatch(text);
  return match == null ? null : int.parse(match[1]!);
}

/// The first usable image URL from a string or a list of strings
/// (`backdrop_path` comes both ways).
String? readImage(Object? value) => switch (value) {
  final String v => cleanImageUrl(v),
  final List<Object?> v =>
    v
        .map((e) => e is String ? cleanImageUrl(e) : null)
        .firstWhere((e) => e != null, orElse: () => null),
  _ => null,
};
