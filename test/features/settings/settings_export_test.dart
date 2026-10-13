import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:iptv_player/features/settings/domain/settings_export.dart';

String _fixture(String name) =>
    File('test_fixtures/settings/$name').readAsStringSync();

Matcher _refused(SettingsFileProblem problem, {int? format}) => throwsA(
  isA<SettingsFileRefused>()
      .having((e) => e.problem, 'problem', problem)
      .having((e) => e.format, 'format', format),
);

void main() {
  group('reading a file', () {
    test('a good file gives its settings pages and each source whole', () {
      final file = parseSettingsExport(_fixture('good.json'));

      expect(file.exportedAt, DateTime.utc(2026, 10, 12, 18, 30));
      expect(file.appVersion, '0.1.0+1');
      expect(file.settings.keys, exportedSettingsPages);
      expect((file.settings['appearance']! as Map)['accent'], 'teal');

      final northwind = file.sources.first;
      expect(northwind.name, 'Northwind TV');
      expect(northwind.type, 'xtream');
      expect(northwind.fingerprint, '5f7a');
      expect(
        [
          for (final g in northwind.favoriteGroups)
            (g.name, g.order, g.collapsed),
        ],
        [('Sport', 0, false), ('News', 1, true)],
      );
      expect(
        [
          for (final f in northwind.favorites)
            (f.type, f.key, f.group, f.order),
        ],
        [
          ('live', '201', 'Sport', 0),
          ('live', '305', 'News', 0),
          ('movie', '9001', null, 2),
        ],
      );
      expect(northwind.favorites.first.addedAt, DateTime.utc(2026, 9, 20, 10));
      expect(northwind.hiddenCategories, 2);
      expect(northwind.renamedCategories, 1);
      expect(northwind.hiddenChannels, 1);
      expect(northwind.renamedChannels, 1);
      expect(northwind.guideMatches.single.xmltvId, 'arena1.uk');
      expect(northwind.reminders.single['title'], 'Late Scores');

      expect(file.sources.last.name, 'Harbor IPTV');
      expect(file.sources.last.favorites, hasLength(1));
    });

    test('a file cut short is damaged', () {
      expect(
        () => parseSettingsExport(_fixture('truncated.json')),
        _refused(SettingsFileProblem.damaged),
      );
    });

    test("a file that isn't JSON is damaged", () {
      expect(
        () => parseSettingsExport(_fixture('not_json.txt')),
        _refused(SettingsFileProblem.damaged),
      );
      expect(
        () => parseSettingsExport(''),
        _refused(SettingsFileProblem.damaged),
      );
    });

    test("JSON that isn't one of our files is not ours", () {
      expect(
        () => parseSettingsExport(_fixture('not_ours.json')),
        _refused(SettingsFileProblem.notOurs),
      );
      for (final text in [
        '[1, 2, 3]',
        '"iptv-player"',
        '{"app": "iptv-player"}',
        '{"app": "iptv-player", "format": "1"}',
        '{"app": "iptv-player", "format": 0}',
      ]) {
        expect(
          () => parseSettingsExport(text),
          _refused(SettingsFileProblem.notOurs),
          reason: text,
        );
      }
    });

    test('a file from a newer version is refused, with its format', () {
      expect(
        () => parseSettingsExport(_fixture('newer.json')),
        _refused(SettingsFileProblem.newer, format: 3),
      );
    });

    test('whatever is unknown or malformed inside a file is skipped, never '
        'fatal', () {
      final file = parseSettingsExport(_fixture('unknown_keys.json'));

      // A date that isn't one, a page that isn't a map, a page from a
      // later build.
      expect(file.exportedAt, DateTime.utc(1970));
      expect(file.settings.keys, ['appearance']);
      // The page's own values go through untouched: its own reader is
      // the tolerant one.
      expect((file.settings['appearance']! as Map)['accent'], 'ultraviolet');

      // Not a map, and no fingerprint: left out. The third is kept.
      final source = file.sources.single;
      expect(source.name, 'A source', reason: 'a blank name gets a plain one');
      expect([for (final f in source.favorites) f.key], ['1', '3']);
      expect(source.favorites.last.order, isNull);
      expect(source.favorites.last.addedAt, isNull);
      expect(
        [for (final g in source.favoriteGroups) (g.name, g.order, g.collapsed)],
        [('Kept', 0, false)],
      );
      expect(
        [for (final c in source.categories) (c.key, c.hidden, c.name)],
        [('7', false, null)],
      );
      expect(
        [for (final c in source.channels) (c.key, c.hidden, c.name)],
        [('8', false, null)],
      );
      expect(source.guideMatches.single.xmltvId, 'x.y');
      expect(source.reminders, [
        {'title': 'T'},
      ]);
    });
  });

  group('writing a file', () {
    final written = SettingsExport(
      exportedAt: DateTime.utc(2026, 10, 13, 9),
      appVersion: '0.1.0+1',
      settings: const {
        'appearance': {'accent': 'rose'},
      },
      sources: [
        ExportedSource(
          name: 'Northwind TV',
          type: 'xtream',
          fingerprint: 'ff00',
          favoriteGroups: const [ExportedFavoriteGroup(name: 'Sport')],
          favorites: [
            ExportedFavorite(
              type: 'live',
              key: '201',
              group: 'Sport',
              order: 4,
              addedAt: DateTime.utc(2026, 9, 20),
            ),
            const ExportedFavorite(type: 'movie', key: '9'),
          ],
          categories: const [
            ExportedCategory(kind: 'live', key: '1', hidden: true, order: 2),
            ExportedCategory(kind: 'series', key: '4', name: 'Dramas'),
          ],
          channels: const [ExportedChannel(key: '201', name: 'Arena One')],
          guideMatches: const [
            ExportedGuideMatch(channel: '201', xmltvId: 'arena1.uk'),
          ],
          reminders: const [
            {'title': 'Late Scores'},
          ],
        ),
      ],
    );

    test('what is written reads back the same', () {
      final read = parseSettingsExport(written.encode());

      expect(read.exportedAt, written.exportedAt);
      expect(read.appVersion, '0.1.0+1');
      expect(read.settings, written.settings);
      expect(
        jsonEncode(read.sources.single.toJson()),
        jsonEncode(written.sources.single.toJson()),
      );
    });

    test('it says it is ours, in this format, and a person can read it', () {
      final text = written.encode();
      final json = jsonDecode(text) as Map<String, Object?>;

      expect(json['app'], 'iptv-player');
      expect(json['format'], settingsExportFormat);
      expect(json['exported_at'], '2026-10-13T09:00:00.000Z');
      expect(text, contains('\n  "settings": {'));
    });

    test('nothing empty is written for what a favorite or a category has '
        'none of', () {
      final source = (jsonDecode(written.encode()) as Map)['sources'] as List;
      final favorites = (source.single as Map)['favorites'] as List;

      expect(favorites.last, {'type': 'movie', 'key': '9'});
    });
  });

  group('a source is recognized by a fingerprint', () {
    test('of its type, server and username: the same wherever it is made', () {
      final here = sourceFingerprint(
        type: 'xtream',
        server: 'http://tv.northwind.test:8080',
        username: 'viewer42',
      );
      final there = sourceFingerprint(
        type: 'xtream',
        server: 'HTTP://TV.Northwind.test:8080/  ',
        username: ' viewer42 ',
      );

      expect(here, there);
      expect(here, hasLength(64));
      // Pinned, and worked out apart from this code (Python's hashlib):
      // a change here would stop every file made before it from finding
      // its sources.
      expect(
        here,
        '9ba4b6786b6938cddc7c0fce88cacfe7643aedd52dec196688b35e4517236391',
      );
    });

    test('differs with any of the three', () {
      String of({
        String type = 'xtream',
        String server = 'http://a.test',
        String? username = 'u',
      }) => sourceFingerprint(type: type, server: server, username: username);

      final all = {
        of(),
        of(type: 'm3uUrl'),
        of(server: 'http://b.test'),
        of(username: 'v'),
        of(username: null),
      };
      expect(all, hasLength(5));
    });

    test('holds neither the server nor the username', () {
      final fingerprint = sourceFingerprint(
        type: 'xtream',
        server: 'http://tv.northwind.test:8080',
        username: 'viewer42',
      );

      expect(fingerprint, isNot(contains('northwind')));
      expect(fingerprint, isNot(contains('viewer42')));
      expect(fingerprint, matches(RegExp(r'^[0-9a-f]{64}$')));
    });
  });

  test('the suggested file name carries the local date', () {
    expect(
      settingsExportFileName(DateTime(2026, 10, 3, 23, 59)),
      'iptv-player-settings-2026-10-03.json',
    );
  });
}
