import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// Hard rule 6: presentation code talks to domain interfaces and never
/// imports the libraries behind them. Checked on the source text, so a
/// new screen can't slip one in.
void main() {
  const forbidden = [
    'package:media_kit',
    'package:drift',
    'package:dio',
    'package:sqlite3',
    'package:iptv_player/data/',
    'dart:io',
    'dart:isolate',
  ];

  final presentation = [
    for (final entity in Directory('lib').listSync(recursive: true))
      if (entity is File &&
          entity.path.endsWith('.dart') &&
          !entity.path.endsWith('.g.dart') &&
          !entity.path.endsWith('.freezed.dart') &&
          (entity.path.contains(
                '${Platform.pathSeparator}presentation'
                '${Platform.pathSeparator}',
              ) ||
              entity.path.contains(
                '${Platform.pathSeparator}design'
                '${Platform.pathSeparator}',
              )))
        entity,
  ];

  test('finds the presentation code', () {
    expect(presentation, isNotEmpty);
  });

  for (final file in presentation) {
    test('${file.path} imports nothing from below the domain', () {
      final imports = [
        for (final line in file.readAsLinesSync())
          if (line.startsWith('import ')) line,
      ];
      for (final line in imports) {
        for (final library in forbidden) {
          expect(line, isNot(contains("'$library")), reason: line);
        }
      }
    });
  }
}
