import 'dart:convert';
import 'dart:io';

import 'package:drift/drift.dart' show Value;
import 'package:flutter_test/flutter_test.dart';
import 'package:iptv_player/core/catalogue_kind.dart';
import 'package:iptv_player/core/result.dart';
import 'package:iptv_player/data/db/app_database.dart';
import 'package:iptv_player/data/db/user_tables.dart';
import 'package:iptv_player/data/settings/settings_repository.dart';
import 'package:iptv_player/features/settings/data/db_settings_transfer.dart';
import 'package:iptv_player/features/settings/domain/settings_export.dart';
import 'package:iptv_player/features/settings/domain/settings_transfer.dart';
import 'package:iptv_player/features/sources/domain/source.dart';
import 'package:path/path.dart' as p;

/// Strings found nowhere else, so finding one in a file is a leak (hard
/// rule 3).
const _server = 'http://tv.zq7northwind.test:8080';
const _username = 'viewerQX19';
const _password = 'pw-J4vK9-secret';

final _t0 = DateTime.utc(2026, 10, 1, 12);

Future<void> _source(
  AppDatabase db,
  String id, {
  String name = 'Northwind TV',
  SourceType type = SourceType.xtream,
  String url = _server,
  String? username = _username,
  int order = 0,
}) => db
    .into(db.sources)
    .insert(
      SourcesCompanion.insert(
        id: id,
        type: type,
        name: name,
        url: url,
        username: Value(username),
        sortOrder: Value(order),
        // Where a provider's raw account answer is kept: it names the
        // user, and must never reach a file.
        accountJson: Value(
          jsonEncode({'username': _username, 'password': _password}),
        ),
        createdAt: _t0,
        updatedAt: _t0,
      ),
    );

/// A source's catalogue as a sync leaves it: three live categories, a
/// movie category, five channels.
Future<void> _catalogue(AppDatabase db, String sourceId) async {
  for (final (kind, key, name) in [
    (CatalogueKind.live, '1', 'Sport'),
    (CatalogueKind.live, '2', 'News'),
    (CatalogueKind.live, '3', 'Kids'),
    (CatalogueKind.movie, '1', 'Drama'),
  ]) {
    await db
        .into(db.categories)
        .insert(
          CategoriesCompanion.insert(
            sourceId: sourceId,
            remoteKey: key,
            kind: kind,
            name: name,
          ),
        );
  }
  for (final (key, name) in [
    ('201', 'Arena Sports 1'),
    ('202', 'Arena Sports 2'),
    ('305', 'Harbour News 24'),
    ('410', 'Kids World'),
    ('999', 'Shopping 24'),
  ]) {
    await db
        .into(db.channels)
        .insert(
          ChannelsCompanion.insert(
            sourceId: sourceId,
            remoteKey: key,
            name: name,
          ),
        );
  }
}

Future<int> _categoryId(
  AppDatabase db,
  String sourceId,
  CatalogueKind kind,
  String key,
) async => (await db.categoriesDao.idsByRemoteKey(sourceId, kind))[key]!;

/// The choices a user made on the first computer.
Future<void> _choices(AppDatabase db, String sourceId) async {
  final favorites = db.favoritesDao;
  final sport = await favorites.createGroup(sourceId, 'Sport');
  final news = await favorites.createGroup(sourceId, 'News');
  await favorites.setCollapsed(news, collapsed: true);
  for (final key in ['201', '202', '305']) {
    await favorites.add(UserItemType.live, sourceId, key, _t0);
  }
  await favorites.add(UserItemType.movie, sourceId, '9001', _t0);
  await (db.update(
    db.favorites,
  )..where((t) => t.remoteKey.equals('201'))).write(
    FavoritesCompanion(groupId: Value(sport), sortOrder: const Value(1)),
  );
  await (db.update(
    db.favorites,
  )..where((t) => t.remoteKey.equals('202'))).write(
    FavoritesCompanion(groupId: Value(sport), sortOrder: const Value(0)),
  );
  await (db.update(
    db.favorites,
  )..where((t) => t.remoteKey.equals('305'))).write(
    FavoritesCompanion(groupId: Value(news), sortOrder: const Value(0)),
  );

  final categories = db.categoriesDao;
  final liveSport = await _categoryId(db, sourceId, CatalogueKind.live, '1');
  final liveNews = await _categoryId(db, sourceId, CatalogueKind.live, '2');
  final liveKids = await _categoryId(db, sourceId, CatalogueKind.live, '3');
  await categories.rename(liveSport, 'Sport & more');
  await categories.setHidden(liveKids, hidden: true);
  await categories.reorder([liveNews, liveSport, liveKids]);
  await categories.setHidden(
    await _categoryId(db, sourceId, CatalogueKind.movie, '1'),
    hidden: true,
  );

  final channels = db.channelsDao;
  await channels.rename(
    (await channels.byRemoteKey(sourceId, '201'))!.id,
    'Arena One',
  );
  await channels.setHidden(
    (await channels.byRemoteKey(sourceId, '999'))!.id,
    hidden: true,
  );
  await db.epgDao.setMapping(sourceId, '201', 'arena1.uk', _t0);
  await db.epgDao.setMapping(sourceId, '305', 'harbour.news', _t0);
}

const Map<String, Map<String, Object?>> _settings = {
  SettingsKeys.appearance: {
    'accent': 'teal',
    'text_size': 's115',
    'density': 'compact',
    'reduce_motion': 'on',
    'clock': 'h24',
  },
  SettingsKeys.playback: {
    'preset': 'stable',
    'audio': ['ar', 'en'],
    'subtitles': ['en'],
    'deinterlace': 'off',
    'hwdec': 'off',
  },
  SettingsKeys.guide: {'keep_days': 5},
  SettingsKeys.cast: {
    'dolby_passthrough': true,
    'low_latency': false,
    'smooth_interlaced': true,
  },
  SettingsKeys.downloads: {
    'folder': '/home/first/Videos/IPTV Player',
    'at_a_time': 2,
    'speed_limit_mbps': 0,
    'resume_on_launch': false,
    'keep_awake': true,
  },
};

Future<Map<String, Object?>> _stored(AppDatabase db, String key) async {
  final text = await db.settingsDao.read(key);
  return text == null ? {} : jsonDecode(text) as Map<String, Object?>;
}

void main() {
  late AppDatabase first;
  late AppDatabase second;
  late Directory folder;
  late String path;

  setUp(() async {
    first = AppDatabase.memory();
    second = AppDatabase.memory();
    folder = Directory.systemTemp.createTempSync('settings_transfer_');
    path = p.join(folder.path, 'iptv-player-settings.json');

    await _source(first, 'src-1');
    await _catalogue(first, 'src-1');
    await _choices(first, 'src-1');
    for (final MapEntry(:key, :value) in _settings.entries) {
      await first.settingsDao.write(key, jsonEncode(value));
    }
    // What a file must never carry.
    await first.settingsDao.write(SettingsKeys.windowBounds, '{"w": 1440}');
  });

  tearDown(() async {
    await first.close();
    await second.close();
    folder.deleteSync(recursive: true);
  });

  DbSettingsTransfer transfer(
    AppDatabase db, {
    void Function()? beforeCommit,
  }) => DbSettingsTransfer(
    db,
    appVersion: '0.1.0+1',
    clock: () => DateTime.utc(2026, 10, 13, 9),
    beforeCommit: beforeCommit,
  );

  Future<ImportPlan> plan(AppDatabase db) async {
    final read = await transfer(db).read(path);
    return (read as SettingsFileReadable).plan;
  }

  /// The same account added on the second computer, under another id, as
  /// a fresh sync leaves it.
  Future<void> sameSourceOnSecond() async {
    await _source(second, 'other-id', name: 'My provider');
    await _catalogue(second, 'other-id');
  }

  group('export', () {
    test('writes the settings pages and each source’s choices, and says '
        'what it wrote', () async {
      final summary = (await transfer(first).exportTo(path)).valueOrNull!;

      expect(summary.path, path);
      expect(summary.sources, 1);
      expect(summary.favorites, 4);
      expect(summary.bytes, File(path).lengthSync());

      final file = parseSettingsExport(File(path).readAsStringSync());
      expect(file.appVersion, '0.1.0+1');
      expect(file.exportedAt, DateTime.utc(2026, 10, 13, 9));
      expect(file.settings.keys, exportedSettingsPages);
      final source = file.sources.single;
      expect(source.name, 'Northwind TV');
      expect(source.type, 'xtream');
      expect(source.favorites, hasLength(4));
      expect(source.favoriteGroups, hasLength(2));
      // Every category is there, so the ones picked by hand transfer.
      expect(source.categories, hasLength(4));
      expect(source.hiddenCategories, 2);
      // Only the channels the user touched.
      expect([for (final c in source.channels) c.key]..sort(), ['201', '999']);
      expect(source.guideMatches, hasLength(2));
    });

    test('hard rule 3: no password, username, server address or folder in '
        'the file, and nothing but the five settings pages', () async {
      await transfer(first).exportTo(path);
      final text = File(path).readAsStringSync();

      expect(text, isNot(contains(_username)));
      expect(text, isNot(contains(_password)));
      expect(text, isNot(contains('zq7northwind')));
      expect(text, isNot(contains(Uri.parse(_server).host)));
      expect(text, isNot(contains('/home/first')));
      expect(text, isNot(contains('1440')), reason: 'the window is this PC’s');
      expect(
        (jsonDecode(text) as Map)['settings'],
        isNot(contains('window.bounds')),
      );
      expect(
        ((jsonDecode(text) as Map)['settings'] as Map)['downloads'],
        isNot(contains('folder')),
      );
    });

    test(
      'replaces a file already there, and leaves no half-written one',
      () async {
        File(path).writeAsStringSync('old');

        expect(await transfer(first).exportTo(path), isA<Ok<ExportSummary>>());

        expect(File(path).readAsStringSync(), startsWith('{'));
        expect(File('$path.part').existsSync(), isFalse);
      },
    );

    test("a folder that can't be written is a failure, not a crash", () async {
      final result = await transfer(first)
          .exportTo(p.join(folder.path, 'no', 'such', 'folder', 'x.json'));

      expect(result.failureOrNull, isA<StorageFailure>());
    });

    test('a database with no source and no settings still exports', () async {
      final summary = (await transfer(second).exportTo(path)).valueOrNull!;

      expect(summary.sources, 0);
      final file = parseSettingsExport(File(path).readAsStringSync());
      expect(file.settings, isEmpty);
      expect(file.sources, isEmpty);
    });
  });

  group('import, end to end on a second database', () {
    setUp(() => transfer(first).exportTo(path));

    test('the preview says what will happen and changes nothing', () async {
      await sameSourceOnSecond();

      final preview = await plan(second);

      expect(preview.replacesSettings, isTrue);
      expect(preview.settingsPages, exportedSettingsPages);
      final source = preview.sources.single;
      expect(source.isHere, isTrue);
      expect(source.sourceId, 'other-id');
      expect(source.sourceName, 'My provider');
      expect(preview.missing, isEmpty);
      expect(await second.select(second.favorites).get(), isEmpty);
      expect(await second.settingsDao.readAll(), isEmpty);
    });

    test('settings, favorites with groups and order, hidden and renamed '
        'categories and channels, and guide matches all arrive', () async {
      await sameSourceOnSecond();
      await second.settingsDao.write(
        SettingsKeys.downloads,
        jsonEncode({'folder': '/home/second/Videos', 'at_a_time': 1}),
      );

      final summary = (await transfer(second).apply(await plan(second)))
          .valueOrNull!;

      expect(summary.settingsPages, exportedSettingsPages);
      expect(summary.sources, 1);
      expect(summary.skippedSources, 0);
      expect(summary.favorites, 4);
      expect(summary.categories, 4);
      expect(summary.channels, 2);
      expect(summary.guideMatches, 2);
      expect(summary.notHere, 0);

      // Settings: replaced; the download folder stays this computer's.
      expect(
        await _stored(second, SettingsKeys.appearance),
        _settings[SettingsKeys.appearance],
      );
      expect(
        await _stored(second, SettingsKeys.playback),
        _settings[SettingsKeys.playback],
      );
      expect(await _stored(second, SettingsKeys.guide), {'keep_days': 5});
      expect(
        await _stored(second, SettingsKeys.cast),
        _settings[SettingsKeys.cast],
      );
      final downloads = await _stored(second, SettingsKeys.downloads);
      expect(downloads['folder'], '/home/second/Videos');
      expect(downloads['at_a_time'], 2);
      expect(downloads['keep_awake'], isTrue);

      // Favorites, in their groups, in their order.
      final groups = await second.select(second.favoriteGroups).get();
      expect(
        {for (final g in groups) g.name: (g.sortOrder, g.collapsed)},
        {'Sport': (0, false), 'News': (1, true)},
      );
      final groupNames = {for (final g in groups) g.id: g.name};
      final favorites = await second.select(second.favorites).get();
      expect(favorites.every((f) => f.sourceId == 'other-id'), isTrue);
      expect(
        {
          for (final f in favorites)
            (f.itemType.name, f.remoteKey): (
              groupNames[f.groupId],
              f.sortOrder,
            ),
        },
        {
          ('live', '201'): ('Sport', 1),
          ('live', '202'): ('Sport', 0),
          ('live', '305'): ('News', 0),
          ('movie', '9001'): (null, 0),
        },
      );

      // Categories: hidden, renamed, in the user's order.
      final categories = await second.select(second.categories).get();
      expect(
        {
          for (final c in categories)
            (c.kind.name, c.remoteKey): (
              c.isHidden,
              c.displayName,
              c.sortOrder,
            ),
        },
        {
          ('live', '1'): (false, 'Sport & more', 1),
          ('live', '2'): (false, null, 0),
          ('live', '3'): (true, null, 2),
          ('movie', '1'): (true, null, null),
        },
      );

      // Channels: the renamed one and the hidden one.
      final channels = await second.select(second.channels).get();
      expect(
        {for (final c in channels) c.remoteKey: (c.isHidden, c.displayName)},
        {
          '201': (false, 'Arena One'),
          '202': (false, null),
          '305': (false, null),
          '410': (false, null),
          '999': (true, null),
        },
      );

      // Guide matches.
      final mappings = await second.epgDao.mappingsFor('other-id');
      expect(
        {for (final m in mappings) m.channelRemoteKey: m.xmltvId},
        {'201': 'arena1.uk', '305': 'harbour.news'},
      );
    });

    test("a source that isn't on this computer is named and skipped; the "
        'settings still arrive', () async {
      // The same server, another account.
      await _source(second, 'someone-else', username: 'another-user');
      await _catalogue(second, 'someone-else');

      final preview = await plan(second);
      expect(preview.here, isEmpty);
      expect(preview.missing.single.exported.name, 'Northwind TV');
      expect(preview.isEmpty, isFalse, reason: 'the settings pages count');

      final summary = (await transfer(second).apply(preview)).valueOrNull!;

      expect(summary.sources, 0);
      expect(summary.skippedSources, 1);
      expect(summary.favorites, 0);
      expect(await second.select(second.favorites).get(), isEmpty);
      expect(await second.select(second.sources).get(), hasLength(1));
      expect(await _stored(second, SettingsKeys.guide), {'keep_days': 5});
    });

    test('an import adds no source', () async {
      final preview = await plan(second);

      await transfer(second).apply(preview);

      expect(await second.select(second.sources).get(), isEmpty);
    });

    test("choices are merged into what is here: this computer's own "
        'favorite and hidden channel stay; one in both takes the file’s '
        'group and place', () async {
      await sameSourceOnSecond();
      final favorites = second.favoritesDao;
      await favorites.add(UserItemType.live, 'other-id', '410', _t0);
      await favorites.add(UserItemType.live, 'other-id', '201', _t0);
      await second.channelsDao.setHidden(
        (await second.channelsDao.byRemoteKey('other-id', '410'))!.id,
        hidden: true,
      );
      await second.epgDao.setMapping('other-id', '410', 'kids.world', _t0);

      await transfer(second).apply(await plan(second));

      final held = await second.select(second.favorites).get();
      expect([for (final f in held) f.remoteKey]..sort(), [
        '201',
        '202',
        '305',
        '410',
        '9001',
      ]);
      final groups = await second.select(second.favoriteGroups).get();
      final sport = groups.singleWhere((g) => g.name == 'Sport').id;
      final arena = held.singleWhere((f) => f.remoteKey == '201');
      expect(arena.groupId, sport);
      expect(arena.sortOrder, 1);
      expect(
        (await second.channelsDao.byRemoteKey('other-id', '410'))!.isHidden,
        isTrue,
      );
      expect(
        {
          for (final m in await second.epgDao.mappingsFor('other-id'))
            m.channelRemoteKey,
        },
        {'201', '305', '410'},
      );
    });

    test('importing the same file twice changes nothing more', () async {
      await sameSourceOnSecond();
      await transfer(second).apply(await plan(second));
      final favorites = await second.select(second.favorites).get();
      final groups = await second.select(second.favoriteGroups).get();

      await transfer(second).apply(await plan(second));

      expect(await second.select(second.favorites).get(), favorites);
      expect(await second.select(second.favoriteGroups).get(), groups);
    });

    test("what the provider's list no longer has here is left out and "
        'counted, never an error', () async {
      await _source(second, 'other-id');
      // A catalogue that lost a category and the two touched channels.
      await second
          .into(second.categories)
          .insert(
            CategoriesCompanion.insert(
              sourceId: 'other-id',
              remoteKey: '1',
              kind: CatalogueKind.live,
              name: 'Sport',
            ),
          );

      final summary = (await transfer(second).apply(await plan(second)))
          .valueOrNull!;

      expect(summary.categories, 1);
      expect(summary.channels, 0);
      expect(summary.notHere, 3 + 2);
      // Favorites and matches are kept by key: they attach when the
      // channel comes back.
      expect(summary.favorites, 4);
      expect(summary.guideMatches, 2);
    });

    test('an import that fails part-way changes nothing', () async {
      await sameSourceOnSecond();
      await second.settingsDao.write(
        SettingsKeys.guide,
        jsonEncode({'keep_days': 9}),
      );
      await second.favoritesDao.add(UserItemType.live, 'other-id', '410', _t0);
      final preview = await plan(second);

      final result = await transfer(
        second,
        // Everything has been written inside the transaction by now.
        beforeCommit: () => throw const FileSystemException('disk gone'),
      ).apply(preview);

      expect(result, isA<Err<ImportSummary>>());
      expect(await _stored(second, SettingsKeys.guide), {'keep_days': 9});
      expect(await second.settingsDao.read(SettingsKeys.appearance), isNull);
      expect(
        [
          for (final f in await second.select(second.favorites).get())
            f.remoteKey,
        ],
        ['410'],
      );
      expect(await second.select(second.favoriteGroups).get(), isEmpty);
      expect(await second.epgDao.mappingsFor('other-id'), isEmpty);
      final categories = await second.select(second.categories).get();
      expect(
        categories.every((c) => !c.isHidden && c.displayName == null),
        isTrue,
      );
      final channels = await second.select(second.channels).get();
      expect(
        channels.every((c) => !c.isHidden && c.displayName == null),
        isTrue,
      );
    });
  });

  group('which source a file’s source is', () {
    test('two sources here that are the same account: the first in the '
        'user’s order', () async {
      await transfer(first).exportTo(path);
      await _source(second, 'b', name: 'Second copy', order: 1);
      await _source(second, 'a', name: 'First copy');

      final preview = await plan(second);

      expect(preview.sources.single.sourceId, 'a');
    });

    test('a playlist file is the same playlist in another folder; a playlist '
        'from another server is not', () async {
      final db = AppDatabase.memory();
      addTearDown(db.close);
      await _source(
        db,
        'file',
        name: 'My list',
        type: SourceType.m3uFile,
        url: '/home/first/lists/channels.m3u',
        username: null,
      );
      await _source(
        db,
        'web',
        name: 'Web list',
        type: SourceType.m3uUrl,
        url: 'http://lists.first.test',
        username: null,
        order: 1,
      );
      await transfer(db).exportTo(path);
      await _source(
        second,
        'file-here',
        type: SourceType.m3uFile,
        url: r'C:\Users\me\Playlists\channels.m3u',
        username: null,
      );
      await _source(
        second,
        'web-here',
        type: SourceType.m3uUrl,
        url: 'http://lists.other.test',
        username: null,
        order: 1,
      );

      final preview = await plan(second);

      expect(preview.here.single.sourceId, 'file-here');
      expect(preview.missing.single.exported.name, 'Web list');
      // And the path itself never left the first computer.
      expect(File(path).readAsStringSync(), isNot(contains('/home/first')));
    });
  });

  group('a file that can’t be imported', () {
    Future<SettingsFileRead> read(String fixture) =>
        transfer(second).read(p.join('test_fixtures', 'settings', fixture));

    test(
      'damaged, not ours, and from a newer version: each says which',
      () async {
        expect(
          await read('truncated.json'),
          isA<SettingsFileUnusable>().having(
            (r) => r.problem,
            'problem',
            SettingsFileProblem.damaged,
          ),
        );
        expect(
          await read('not_json.txt'),
          isA<SettingsFileUnusable>().having(
            (r) => r.problem,
            'problem',
            SettingsFileProblem.damaged,
          ),
        );
        expect(
          await read('not_ours.json'),
          isA<SettingsFileUnusable>().having(
            (r) => r.problem,
            'problem',
            SettingsFileProblem.notOurs,
          ),
        );
        expect(
          await read('newer.json'),
          isA<SettingsFileUnusable>()
              .having((r) => r.problem, 'problem', SettingsFileProblem.newer)
              .having((r) => r.format, 'format', 3),
        );
      },
    );

    test("a file that isn't there, or isn't text, is unread or damaged: "
        'never a crash', () async {
      expect(
        await transfer(second).read(p.join(folder.path, 'missing.json')),
        isA<SettingsFileUnread>().having(
          (r) => r.failure,
          'failure',
          isA<StorageFailure>(),
        ),
      );
      final binary = File(p.join(folder.path, 'picture.json'))
        ..writeAsBytesSync([0xff, 0xd8, 0xff, 0xe0, 0x00, 0x10, 0x80, 0x81]);
      expect(
        await transfer(second).read(binary.path),
        isA<SettingsFileUnusable>().having(
          (r) => r.problem,
          'problem',
          SettingsFileProblem.damaged,
        ),
      );
    });

    test('the good fixture, with none of its sources here, imports its '
        'settings and skips both', () async {
      final read = await transfer(second)
          .read(p.join('test_fixtures', 'settings', 'good.json'));
      final preview = (read as SettingsFileReadable).plan;
      expect(
        [for (final s in preview.missing) s.exported.name],
        ['Northwind TV', 'Harbor IPTV'],
      );

      final summary = (await transfer(second).apply(preview)).valueOrNull!;

      expect(summary.skippedSources, 2);
      expect(summary.settingsPages, exportedSettingsPages);
    });

    test(
      'a file with unknown things inside imports what it understands',
      () async {
        final read = await transfer(second)
            .read(p.join('test_fixtures', 'settings', 'unknown_keys.json'));
        final preview = (read as SettingsFileReadable).plan;

        final summary = (await transfer(second).apply(preview)).valueOrNull!;

        expect(summary.settingsPages, ['appearance']);
        // The page's own reader takes what it knows: an accent it never
        // heard of is the default one.
        expect(
          (await _stored(second, SettingsKeys.appearance))['accent'],
          'ultraviolet',
        );
      },
    );
  });
}
