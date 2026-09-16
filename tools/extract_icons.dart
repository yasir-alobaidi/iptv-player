// Extracts the design canvas's SVG icons into assets/icons/.
//
// Run from the repo root after the canvas changes:
//   dart run tools/extract_icons.dart
//
// Icons are identified by a hash of their markup, so renaming or moving
// them on the canvas is fine, but redrawing one changes its hash and the
// script fails loudly rather than silently dropping it.
import 'dart:convert';
import 'dart:io';

import 'package:crypto/crypto.dart';

/// Canvas icon hash -> asset name. Several canvas SVGs are the same icon
/// drawn twice; they map to one name and the first occurrence wins.
const _names = <String, String>{
  'a6768311b9': 'close',
  'b392231894': 'loading',
  '7615f64f4a': 'device-tv',
  '55e4a7605b': 'device-speaker',
  'ad82be7580': 'plus',
  'c1860ef0e2': 'info',
  '1066779ae4': 'cast-connected',
  '0713c75782': 'check',
  '74c1c70b2a': 'chevron-up',
  'f21f988782': 'chevron-down',
  'bbc8f8eaa3': 'chevron-left',
  '86cd5dd74d': 'chevron-right',
  '1fa7256b7c': 'volume-low',
  'a5f2811d54': 'volume-high',
  'd1650c2afc': 'volume-off',
  '582b8ead6c': 'stop',
  '732b99863f': 'pause',
  '437698dcf7': 'play',
  'e884ccdd54': 'home',
  '1c10e1c5c6': 'live-tv',
  'f980e9dbe3': 'guide',
  'bbdcb8571a': 'movies',
  'f3fd594fa0': 'series',
  '64cb43e703': 'star',
  'ea97956baf': 'library',
  '0ec9645b8e': 'settings',
  'f41b1a1dc3': 'search',
  '66c505307b': 'cast',
  '147681d9a1': 'drag-handle',
  'ec1a0e9a15': 'alert-circle',
  'a109091e6f': 'alert-triangle',
  '73b85511c4': 'retry',
  'c372c05cc4': 'rescan',
  'c12db54eb9': 'catch-up',
  '555c9a61bc': 'folder',
  '229ea0670f': 'storage',
  '2c539d9b00': 'download',
  'dc99cf1b1e': 'download-active',
  'dd45b41f0f': 'filter',
  'bd261eb27e': 'fullscreen',
  'b5d92b1d0f': 'exit-fullscreen',
  '0384a2f257': 'eye',
  'ce80d0965d': 'arrow-right',
  '75625c6c5e': 'clock',
  '380bd705b4': 'audio',
  '866ca49613': 'subtitles',
  'f667852557': 'aspect-ratio',
  '71203f634b': 'arrow-up',
  '19f422a4a2': 'arrow-down',
};

/// Canvas icons that duplicate one already in [_names]: same meaning,
/// drawn slightly differently. Dropped so there is one download icon.
const _duplicates = <String>{'34aa0b6b1a'};

/// The star is drawn outlined in the rail and filled when something is a
/// favorite, so it ships twice.
const _filledVariants = <String, String>{'64cb43e703': 'star-filled'};

final _svg = RegExp(r'<svg\b[^>]*>.*?</svg>', dotAll: true);
final _openTag = RegExp(r'^<svg\b[^>]*>');
final _closeTag = RegExp(r'</svg>$');
final _color = RegExp('(fill|stroke)="(#[0-9A-Fa-f]{3,8}|[a-zA-Z]+)"');
final _size = RegExp(' (width|height)="[^"]*"');

void main(List<String> args) {
  final design = Directory('design');
  if (!design.existsSync()) {
    stderr.writeln('Run this from the repo root (design/ not found).');
    exit(1);
  }

  final found = <String, _Icon>{};
  final files =
      design
          .listSync()
          .whereType<File>()
          .where((f) => f.path.endsWith('.dc.html'))
          .toList()
        ..sort((a, b) => a.path.compareTo(b.path));

  for (final file in files) {
    final source = file.readAsStringSync();
    for (final match in _svg.allMatches(source)) {
      final svg = match.group(0)!;
      final inner = svg
          .replaceFirst(_openTag, '')
          .replaceFirst(_closeTag, '')
          .replaceAll(RegExp(r'\s+'), ' ')
          .trim();
      final key = md5Short(inner);
      found.putIfAbsent(key, () => _Icon(key: key, svg: svg, inner: inner));
    }
  }

  final missing = _names.keys.where((k) => !found.containsKey(k)).toList();
  if (missing.isNotEmpty) {
    stderr.writeln(
      'These icons are no longer on the canvas: ${missing.join(", ")}.\n'
      'The canvas changed — update _names in this script.',
    );
    exit(1);
  }

  final unmapped = found.keys
      .where((k) => !_names.containsKey(k) && !_duplicates.contains(k))
      .toList();

  final out = Directory('assets/icons')..createSync(recursive: true);
  for (final file in out.listSync().whereType<File>()) {
    file.deleteSync();
  }

  var written = 0;
  for (final entry in _names.entries) {
    final icon = found[entry.key]!;
    File('${out.path}/${entry.value}.svg').writeAsStringSync(icon.normalized);
    written++;
    final filled = _filledVariants[entry.key];
    if (filled != null) {
      File('${out.path}/$filled.svg').writeAsStringSync(icon.filled);
      written++;
    }
  }

  stdout.writeln('Wrote $written icons to ${out.path}/');
  if (unmapped.isNotEmpty) {
    stdout.writeln('Not extracted (no name in _names): ${unmapped.join(", ")}');
  }
}

String md5Short(String value) =>
    md5.convert(utf8.encode(value)).toString().substring(0, 10);

class _Icon {
  new({required this.key, required this.svg, required this.inner});

  final String key;
  final String svg;
  final String inner;

  /// The canvas markup with its concrete colors swapped for currentColor
  /// and its pixel size dropped, so AppIcon can tint and size it.
  String get normalized {
    final open = _openTag.stringMatch(svg)!;
    final head = open
        .replaceAll(_size, '')
        .replaceAllMapped(
          _color,
          (m) => m.group(2) == 'none'
              ? '${m.group(1)}="none"'
              : '${m.group(1)}="currentColor"',
        );
    final body = inner.replaceAllMapped(
      _color,
      (m) => m.group(2) == 'none'
          ? '${m.group(1)}="none"'
          : '${m.group(1)}="currentColor"',
    );
    final withNs = head.contains('xmlns')
        ? head
        : head.replaceFirst('<svg', '<svg xmlns="http://www.w3.org/2000/svg"');
    return '$withNs$body</svg>\n';
  }

  /// Same icon, filled instead of outlined.
  String get filled => normalized
      .replaceFirst('fill="none"', 'fill="currentColor"')
      .replaceFirst('stroke="currentColor"', 'stroke="currentColor"');
}
