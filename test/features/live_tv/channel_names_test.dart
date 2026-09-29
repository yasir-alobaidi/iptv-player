import 'dart:io';
import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:iptv_player/features/guide/domain/epg_matcher.dart';
import 'package:iptv_player/features/live_tv/domain/channel_names.dart';

void main() {
  group('corpus (test_fixtures/channel_names/names.tsv)', () {
    for (final line in _corpus()) {
      test('"${line.raw}" → "${line.name}" ${line.badge ?? '-'}', () {
        final cleaned = cleanChannelName(line.raw);
        expect(cleaned.name, line.name);
        expect(cleaned.quality?.label, line.badge);
      });
    }

    test('cleaning a cleaned name changes nothing', () {
      for (final line in _corpus()) {
        final once = cleanChannelName(line.raw);
        final twice = cleanChannelName(once.name);
        expect(twice.name, once.name, reason: line.raw);
        // The badge went with the first pass; unless nothing was left to
        // show, nothing is taken twice.
        if (once.quality != null) expect(twice.quality, isNull);
      }
    });

    test('a cleaned name matches the guide as the provider name does', () {
      // Search and the Match… picker read the shown name; the guide's
      // matcher the provider's. Both must mean the same channel.
      for (final line in _corpus()) {
        final shown = cleanChannelName(line.raw).name;
        final key = normalizeChannelName(line.raw);
        if (key.isEmpty) continue;
        expect(normalizeChannelName(shown), key, reason: line.raw);
      }
    });
  });

  group('odd names never throw', () {
    test('empty and blank', () {
      expect(cleanChannelName(''), (name: '', quality: null));
      for (final blank in [' ', ' \t\n ', '\u00a0\u3000', '\ufffd']) {
        final cleaned = cleanChannelName(blank);
        expect(cleaned.name, blank, reason: 'nothing to show: kept');
        expect(cleaned.quality, isNull);
      }
    });

    test('odd whitespace, control characters and U+FFFD read as spaces', () {
      expect(
        cleanChannelName('UK:\u00a0BBC\u2003One\u0007\ufffdHD').name,
        'BBC One',
      );
      expect(cleanChannelName('\ufeffSky News\u200b').name, 'Sky News');
      expect(cleanChannelName('Sky\tNews\r\nHD'), (
        name: 'Sky News',
        quality: ChannelQuality.hd,
      ));
    });

    test('entities escaped twice, and ones that are not entities', () {
      expect(cleanChannelName('UK: Q&amp;amp;A HD').name, 'Q&A');
      expect(cleanChannelName('Tom &amp Jerry').name, 'Tom &amp Jerry');
      expect(
        cleanChannelName('R&D&#0;&#xD800;&#99999999;').name,
        'R&D&#0;&#xD800;&#99999999;',
      );
    });

    test('lone surrogates and emoji', () {
      const lone = 'UK: BBC \ud800One HD';
      expect(cleanChannelName(lone).name, 'BBC \ud800One');
      expect(cleanChannelName('UK: 📺 News HD').name, '📺 News');
      expect(cleanChannelName('📺').name, '📺');
    });

    test('500 characters', () {
      final long = 'UK: ${'Sky Sports ' * 45}HD';
      final cleaned = cleanChannelName(long);
      expect(cleaned.name, ('Sky Sports ' * 45).trim());
      expect(cleaned.quality, ChannelQuality.hd);
    });

    test('brackets that never close, or close twice', () {
      for (final odd in [
        'BBC One (HD',
        'BBC One HD)',
        'BBC One [(HD)]',
        '(',
        ')',
        '[]',
        '( )',
        'BBC One ()',
        'BBC One (HD))',
      ]) {
        expect(() => cleanChannelName(odd), returnsNormally, reason: odd);
        expect(cleanChannelName(odd).name, isNotEmpty, reason: odd);
      }
    });

    test('random text from the characters that matter', () {
      const alphabet = [
        'UK',
        'HD',
        'FHD',
        '4K',
        'Full',
        'H',
        '265',
        '50',
        'fps',
        'Backup',
        ':',
        '|',
        '-',
        '–',
        ' ',
        '  ',
        '(',
        ')',
        '[',
        ']',
        '{',
        '}',
        '+1',
        'ᴴᴰ',
        'ᶠ',
        '&amp;',
        '&',
        '#',
        ';',
        '\u00a0',
        '\ufffd',
        '\ud800',
        'الجزيرة',
        'канал',
        'é',
        '.',
        'EX-YU',
        '🇬🇧',
      ];
      final random = Random(7);
      for (var i = 0; i < 5000; i++) {
        final text = [
          for (var j = random.nextInt(9); j >= 0; j--)
            alphabet[random.nextInt(alphabet.length)],
        ].join();
        final cleaned = cleanChannelName(text);
        expect(cleaned.name, isNotEmpty, reason: text);
        final again = cleanChannelName(cleaned.name);
        expect(again.name, cleaned.name, reason: 'idempotent: $text');
      }
    });
  });

  group('ChannelQuality', () {
    test('labels are the canvas badges', () {
      expect(
        [for (final q in ChannelQuality.values) q.label],
        ['SD', 'HD', 'FHD', '4K'],
      );
    });

    test('fromStored reads what is stored and nothing else', () {
      for (final q in ChannelQuality.values) {
        expect(ChannelQuality.fromStored(q.name), q);
      }
      expect(ChannelQuality.fromStored(null), isNull);
      expect(ChannelQuality.fromStored('8k'), isNull);
      expect(ChannelQuality.fromStored('HD'), isNull);
    });
  });
}

List<({String raw, String name, String? badge})> _corpus() => [
  for (final line in File(
    'test_fixtures/channel_names/names.tsv',
  ).readAsLinesSync())
    if (line.trim().isNotEmpty && !line.startsWith('#'))
      switch (line.split('\t')) {
        [final raw, final name, final badge] => (
          raw: raw,
          name: name,
          badge: badge == '-' ? null : badge,
        ),
        _ => throw FormatException('three tab-separated fields: $line'),
      },
];
