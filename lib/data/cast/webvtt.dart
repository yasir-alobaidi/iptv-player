/// WebVTT as FFmpeg writes it, moved in time (docs/04 "Subtitles").
library;

final _timing = RegExp(
  r'^((?:\d+:)?\d{2}:\d{2}\.\d{3})[ \t]+-->[ \t]+'
  r'((?:\d+:)?\d{2}:\d{2}\.\d{3})(.*)$',
);

/// [text] with every cue moved back by [by]: a cue that ends at or before
/// [by] is left out, one that is showing then starts at 0. Anything that
/// isn't a cue (the header, notes, styles) is kept as it is. Text that
/// isn't WebVTT comes back with no cues.
String shiftWebVtt(String text, Duration by) {
  final body = text.startsWith('﻿') ? text.substring(1) : text;
  final blocks = body
      .replaceAll('\r\n', '\n')
      .replaceAll('\r', '\n')
      .trimRight()
      .split(RegExp(r'\n{2,}'));
  final out = <String>[];
  for (final (index, block) in blocks.indexed) {
    if (block.trim().isEmpty) continue;
    if (index == 0) {
      out.add(block.startsWith('WEBVTT') ? block : 'WEBVTT');
      if (block.startsWith('WEBVTT')) continue;
    }
    final lines = block.split('\n');
    // A cue's timing is its first line, or its second after an identifier.
    final at = lines.indexWhere(_timing.hasMatch);
    if (at < 0 || at > 1) {
      if (!lines.first.contains('-->')) out.add(block);
      continue;
    }
    final match = _timing.firstMatch(lines[at])!;
    final start = _read(match[1]!) - by;
    final end = _read(match[2]!) - by;
    if (end <= Duration.zero) continue;
    lines[at] =
        '${_write(start < Duration.zero ? Duration.zero : start)} --> '
        '${_write(end)}${match[3]}';
    out.add(lines.join('\n'));
  }
  if (out.isEmpty) out.add('WEBVTT');
  return '${out.join('\n\n')}\n';
}

/// How many cues [text] holds.
int webVttCues(String text) {
  var cues = 0;
  for (final line in text.split('\n')) {
    if (_timing.hasMatch(line.trimRight())) cues++;
  }
  return cues;
}

/// `01:02.345` or `1:01:02.345`.
Duration _read(String time) {
  final parts = time.split(':');
  final seconds = parts.removeLast().split('.');
  final minutes = int.parse(parts.removeLast());
  final hours = parts.isEmpty ? 0 : int.parse(parts.last);
  return Duration(
    hours: hours,
    minutes: minutes,
    seconds: int.parse(seconds[0]),
    milliseconds: int.parse(seconds[1]),
  );
}

String _write(Duration time) {
  String two(int n) => n.toString().padLeft(2, '0');
  final ms = time.inMilliseconds;
  return '${two(ms ~/ 3600000)}:${two(ms ~/ 60000 % 60)}:'
      '${two(ms ~/ 1000 % 60)}.${(ms % 1000).toString().padLeft(3, '0')}';
}
