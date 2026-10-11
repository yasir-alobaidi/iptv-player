import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:iptv_player/core/library/library_item.dart';
import 'package:iptv_player/core/library/name_parser.dart';

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

  test("a provider's episode title: what it says beyond the number", () {
    for (final (title, said) in [
      ('Krusty Gets Busted', 'Krusty Gets Busted'),
      ('S01E01', ''),
      ('The.Show.S02E12', ''),
      ('the.show.s33e11.mp4', ''),
      ('The.Show.S35E15.1080p.WEB.H264-GRP-XTV', ''),
      ('The Show - S02E04 - Undertow', 'Undertow'),
      ('The.Show.S02E04.Under.The.Pier.720p.HDTV.x264', 'Under The Pier'),
      ('3x07', ''),
      ('Episode 4', ''),
      ('  ', ''),
      // Nothing of a code in it: kept, dots and all.
      ('Mr. Robinson Returns', 'Mr. Robinson Returns'),
      ('Face/Off', 'Face Off'),
      ('1984', '1984'),
    ]) {
      expect(providerEpisodeTitle(title), said, reason: title);
    }
  });

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
      expect(() => providerEpisodeTitle(odd), returnsNormally, reason: odd);
    }
  });
}
