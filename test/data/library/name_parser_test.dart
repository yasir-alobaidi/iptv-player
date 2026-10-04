import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:iptv_player/core/library/library_item.dart';
import 'package:iptv_player/data/library/name_parser.dart';

/// docs/09's NameParser cases and the corpus around them
/// (`test_fixtures/library/names.json`): one expectation each.
void main() {
  final corpus =
      (jsonDecode(File('test_fixtures/library/names.json').readAsStringSync())
              as Map)['cases']
          as List;

  for (final entry in corpus.cast<Map<String, Object?>>()) {
    final path = entry['path']! as String;
    test(path, () {
      final expected = ParsedName(
        kind: LibraryKind.values.byName(entry['kind']! as String),
        title: entry['title']! as String,
        year: entry['year'] as int?,
        showTitle: entry['show'] as String?,
        season: entry['season'] as int?,
        episode: entry['episode'] as int?,
        episodeEnd: entry['episode_end'] as int?,
      );
      expect(parseVideoName(path), expected);
    });
  }

  test('never throws, whatever it is given', () {
    for (final odd in [
      '',
      '/',
      '.mkv',
      '...',
      '[]',
      '()',
      '(((.mkv',
      'S99E999999.mkv',
      'x' * 500,
      '\u0000\u0001.mp4',
      'a/b/c/d/e/f/g.mkv',
    ]) {
      expect(() => parseVideoName(odd), returnsNormally, reason: odd);
    }
  });
}
