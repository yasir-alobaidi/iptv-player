import 'dart:io';

import 'package:drift/drift.dart' show driftRuntimeOptions;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:iptv_player/core/logging/app_log.dart';
import 'package:iptv_player/core/logging/secret_registry.dart';
import 'package:iptv_player/core/result.dart';
import 'package:iptv_player/core/secure/credential_store.dart';
import 'package:iptv_player/data/db/app_database.dart';
import 'package:iptv_player/features/sources/data/db_source_repository.dart';
import 'package:iptv_player/features/sources/domain/source.dart';
import 'package:logger/logger.dart';

const _password = 'Pw-7f3a9c1e';
const _playlistToken = 'tok9c2e81d4';
const _playlistUrl =
    'http://lists.test/get.php?username=viewer&password=$_password'
    '&type=m3u_plus';
const _tokenPlaylistUrl = 'http://cdn.test/p/$_playlistToken/list.m3u';
const _epgUrl = 'http://epg.test/xmltv.php?username=viewer&password=$_password';

const _xtream = SourceDraft(
  type: SourceType.xtream,
  name: 'Northwind TV',
  url: 'http://northwind.test:8080',
  username: 'viewer',
  password: _password,
);

final class _Harness {
  new(this.database)
    : store = InMemoryCredentialStore(),
      secrets = SecretRegistry(),
      memory = MemoryOutput() {
    log = AppLog(output: memory, secrets: secrets);
    var next = 0;
    repository = DbSourceRepository(
      database: database,
      store: store,
      secrets: secrets,
      log: log,
      clock: () => DateTime.utc(2026, 9, 18, 10),
      newId: () => 'src${++next}',
    );
  }

  final AppDatabase database;
  final InMemoryCredentialStore store;
  final SecretRegistry secrets;
  final MemoryOutput memory;
  late final AppLog log;
  late final DbSourceRepository repository;

  List<String> get logLines => [for (final e in memory.buffer) ...e.lines];

  Future<Source> add(SourceDraft draft) async =>
      (await repository.add(draft)).valueOrNull!;
}

void main() {
  // The hard-rule test opens a file database next to setUp's in-memory one.
  driftRuntimeOptions.dontWarnAboutMultipleDatabases = true;
  late _Harness h;

  setUp(() => h = _Harness(AppDatabase.memory()));
  tearDown(() async {
    await h.log.close();
    await h.database.close();
  });

  group('add', () {
    test('an Xtream source: the password goes to the secure store '
        'only', () async {
      final source = await h.add(_xtream);

      final row = await h.database.sourcesDao.byId(source.id);
      expect(row!.credentialRef, 'source.${source.id}');
      expect(row.username, 'viewer');
      expect(row.toJson().values, isNot(contains(_password)));
      expect(h.store.values['source.${source.id}'], contains(_password));
    });

    test('the server URL is normalized, and never keeps credentials', () async {
      final source = await h.add(
        _xtream.copyWith(
          url: '  http://viewer:$_password@northwind.test:8080/?x=1#frag/ ',
        ),
      );

      expect(source.displayUrl, 'http://northwind.test:8080');
    });

    test('a bare host gets http://, and a base path keeps its place', () async {
      final bare = await h.add(_xtream.copyWith(url: 'northwind.test:8080'));
      final based = await h.add(
        _xtream.copyWith(url: 'https://panel.test/iptv///'),
      );

      expect(bare.displayUrl, 'http://northwind.test:8080');
      expect(based.displayUrl, 'https://panel.test/iptv');
    });

    test('a playlist URL is stored masked; the real one is a secret', () async {
      final source = await h.add(
        const SourceDraft(
          type: SourceType.m3uUrl,
          name: 'Backup',
          url: _playlistUrl,
        ),
      );

      expect(source.displayUrl, 'http://lists.test/…');
      final credentials = await h.repository.credentialsFor(source.id);
      expect(credentials.valueOrNull!.url, _playlistUrl);
    });

    test('a playlist URL no pattern recognizes is still kept out of the '
        'database', () async {
      final source = await h.add(
        const SourceDraft(
          type: SourceType.m3uUrl,
          name: 'Token list',
          url: _tokenPlaylistUrl,
        ),
      );

      // redact() has no pattern for a token in a path; the origin can't
      // leak it.
      final row = await h.database.sourcesDao.byId(source.id);
      expect(row!.url, 'http://cdn.test/…');
      expect(row.toJson().values, isNot(contains(contains(_playlistToken))));
      final credentials = await h.repository.credentialsFor(source.id);
      expect(credentials.valueOrNull!.url, _tokenPlaylistUrl);
    });

    test('a playlist file with no EPG override needs no secret', () async {
      final source = await h.add(
        const SourceDraft(
          type: SourceType.m3uFile,
          name: 'Local',
          url: '/home/me/list.m3u',
        ),
      );

      final row = await h.database.sourcesDao.byId(source.id);
      expect(row!.credentialRef, isNull);
      expect(h.store.values, isEmpty);
      expect(
        (await h.repository.credentialsFor(source.id)).valueOrNull!.url,
        '/home/me/list.m3u',
      );
    });

    test('an EPG override is masked in the database and real in the '
        'credentials', () async {
      final source = await h.add(_xtream.copyWith(epgUrl: _epgUrl));

      expect(source.epgUrlDisplay, 'http://epg.test/…');
      final credentials = await h.repository.credentialsFor(source.id);
      expect(credentials.valueOrNull!.epgUrl, _epgUrl);
    });

    test('each new source goes last', () async {
      final first = await h.add(_xtream);
      final second = await h.add(_xtream.copyWith(name: 'Second'));

      expect(first.sortOrder, 0);
      expect(second.sortOrder, 1);
    });

    test('blank optional text is stored as absent', () async {
      final source = await h.add(
        _xtream.copyWith(userAgent: '  ', epgUrl: ' ', name: '  Spaced  '),
      );

      expect(source.userAgent, isNull);
      expect(source.epgUrlDisplay, isNull);
      expect(source.name, 'Spaced');
    });

    for (final (field, draft) in [
      ('name', _xtream.copyWith(name: '   ')),
      ('server', _xtream.copyWith(url: 'ftp://northwind.test')),
      ('server', _xtream.copyWith(url: '')),
      ('username', _xtream.copyWith(username: ' ')),
      ('password', _xtream.copyWith(password: null)),
      ('refresh hours', _xtream.copyWith(refreshHours: 0)),
      ('connection limit', _xtream.copyWith(maxConnectionsOverride: 0)),
      (
        'playlist URL',
        const SourceDraft(type: SourceType.m3uUrl, name: 'x', url: 'not a url'),
      ),
      ('file', const SourceDraft(type: SourceType.m3uFile, name: 'x', url: '')),
    ]) {
      test('refuses a draft with a bad $field, and stores nothing', () async {
        final result = await h.repository.add(draft);

        expect(result.failureOrNull, isA<InvalidInputFailure>());
        expect(result.failureOrNull!.detail, field);
        expect(await h.database.sourcesDao.count(), 0);
        expect(h.store.values, isEmpty);
      });
    }

    test('a locked keyring stops the add before anything is '
        'stored', () async {
      h.store.locked = true;

      final result = await h.repository.add(_xtream);

      expect(result.failureOrNull, isA<SecureStorageFailure>());
      expect(await h.database.sourcesDao.count(), 0);
    });

    test('a database that fails takes the new secret back out', () async {
      await h.database.customStatement(
        'CREATE TRIGGER refuse BEFORE INSERT ON sources '
        "BEGIN SELECT RAISE(ABORT, 'disk full'); END",
      );

      final result = await h.repository.add(_xtream);

      expect(result.failureOrNull, isA<StorageFailure>());
      expect(h.store.values, isEmpty);
    });
  });

  group('update', () {
    test('a blank password keeps the stored one', () async {
      final source = await h.add(_xtream);

      final result = await h.repository.update(
        source.id,
        _xtream.copyWith(name: 'Renamed', password: null),
      );

      expect(result.valueOrNull!.name, 'Renamed');
      final credentials = await h.repository.credentialsFor(source.id);
      expect(credentials.valueOrNull!.password, _password);
    });

    test('a new password replaces the old', () async {
      final source = await h.add(_xtream);

      await h.repository.update(
        source.id,
        _xtream.copyWith(password: 'n3w-pw'),
      );

      final credentials = await h.repository.credentialsFor(source.id);
      expect(credentials.valueOrNull!.password, 'n3w-pw');
    });

    test('keeps the order and the creation time; moves updatedAt', () async {
      var now = DateTime.utc(2026, 9, 18, 10);
      final repository = DbSourceRepository(
        database: h.database,
        store: h.store,
        secrets: h.secrets,
        log: h.log,
        clock: () => now,
      );
      await repository.add(_xtream.copyWith(name: 'First'));
      final second = (await repository.add(_xtream)).valueOrNull!;

      now = DateTime.utc(2026, 9, 19);
      final updated = (await repository.update(
        second.id,
        _xtream,
      )).valueOrNull!;

      expect(updated.sortOrder, 1);
      expect(updated.createdAt, DateTime.utc(2026, 9, 18, 10));
      expect(updated.updatedAt, DateTime.utc(2026, 9, 19));
    });

    test('a source cannot change its type', () async {
      final source = await h.add(_xtream);

      final result = await h.repository.update(
        source.id,
        const SourceDraft(
          type: SourceType.m3uUrl,
          name: 'x',
          url: _playlistUrl,
        ),
      );

      expect(result.failureOrNull, isA<InvalidInputFailure>());
    });

    test('an unknown source is not found', () async {
      final result = await h.repository.update('nope', _xtream);

      expect(result.failureOrNull, isA<NotFoundFailure>());
    });

    test('dropping the only secret deletes it', () async {
      final source = await h.add(
        const SourceDraft(
          type: SourceType.m3uFile,
          name: 'Local',
          url: '/home/me/list.m3u',
          epgUrl: _epgUrl,
        ),
      );
      expect(h.store.values, hasLength(1));

      await h.repository.update(
        source.id,
        const SourceDraft(
          type: SourceType.m3uFile,
          name: 'Local',
          url: '/home/me/list.m3u',
        ),
      );

      expect(h.store.values, isEmpty);
      final row = await h.database.sourcesDao.byId(source.id);
      expect(row!.credentialRef, isNull);
    });

    test('a locked keyring leaves the source as it was', () async {
      final source = await h.add(_xtream);
      h.store.locked = true;

      final result = await h.repository.update(
        source.id,
        _xtream.copyWith(name: 'Renamed'),
      );

      expect(result.failureOrNull, isA<SecureStorageFailure>());
      expect(
        (await h.repository.byId(source.id)).valueOrNull!.name,
        'Northwind TV',
      );
    });
  });

  group('remove', () {
    test('deletes the row, its catalogue and its secret', () async {
      final source = await h.add(_xtream);
      await h.database.channelsDao.upsertAll([
        ChannelsCompanion.insert(
          sourceId: source.id,
          remoteKey: '1',
          name: 'BBC One',
        ),
      ]);

      expect(await h.repository.remove(source.id), isA<Ok<void>>());

      expect(await h.database.sourcesDao.count(), 0);
      expect(await h.database.channelsDao.countFor(source.id), 0);
      expect(h.store.values, isEmpty);
    });

    test('removing an unknown source succeeds', () async {
      expect(await h.repository.remove('nope'), isA<Ok<void>>());
    });

    test('a locked keyring still removes the source; the secret is pruned '
        'later', () async {
      final kept = await h.add(_xtream.copyWith(name: 'Kept'));
      final gone = await h.add(_xtream);
      h.store.locked = true;

      expect(await h.repository.remove(gone.id), isA<Ok<void>>());
      expect(h.logLines.join('\n'), contains('pruned after the next sync'));

      h.store.locked = false;
      expect(h.store.values.keys, contains('source.${gone.id}'));
      expect((await h.repository.pruneOrphanedSecrets()).valueOrNull, 1);
      expect(h.store.values.keys, ['source.${kept.id}']);
    });

    test('pruning leaves keys that are not source secrets alone', () async {
      await h.store.write('something.else', 'x');

      expect((await h.repository.pruneOrphanedSecrets()).valueOrNull, 0);
      expect(h.store.values.keys, ['something.else']);
    });
  });

  test('reorder stores the new order, and watchAll follows it', () async {
    final a = await h.add(_xtream.copyWith(name: 'A'));
    final b = await h.add(_xtream.copyWith(name: 'B'));
    final c = await h.add(_xtream.copyWith(name: 'C'));

    await h.repository.reorder([c.id, a.id, b.id]);

    final sources = await h.repository.watchAll().first;
    expect(sources.map((s) => s.name), ['C', 'A', 'B']);
  });

  group('credentialsFor', () {
    test('a missing password asks the user again, as an auth '
        'failure', () async {
      final source = await h.add(_xtream);
      await h.store.delete('source.${source.id}');

      final result = await h.repository.credentialsFor(source.id);

      expect(result.failureOrNull, isA<AuthFailure>());
    });

    test('a corrupt secret reads as missing, not as a crash', () async {
      final source = await h.add(_xtream);
      await h.store.write('source.${source.id}', 'not json {');

      final result = await h.repository.credentialsFor(source.id);

      expect(result.failureOrNull, isA<AuthFailure>());
    });

    test('loaded secrets are masked in any later log line', () async {
      final source = await h.add(_xtream);
      final credentials = (await h.repository.credentialsFor(source.id))
          .valueOrNull!;

      // A panel with its own URL shape, which no redact() pattern knows.
      h.log.info('sync', 'GET http://cdn.test/v/${credentials.password}/1');

      expect(h.logLines.last, isNot(contains(_password)));
    });

    test("printing credentials doesn't print the password", () async {
      final source = await h.add(_xtream);
      final credentials = (await h.repository.credentialsFor(source.id))
          .valueOrNull!;

      expect(credentials.toString(), isNot(contains(_password)));
    });
  });

  test('hard rule 3: a full round-trip leaves no secret in the database '
      'file or the log', () async {
    final directory = await Directory.systemTemp.createTemp('sources_test');
    addTearDown(() => directory.delete(recursive: true));
    final file = File('${directory.path}/iptv_player.sqlite');
    final disk = _Harness(AppDatabase(NativeDatabase(file)));

    final xtream = await disk.add(_xtream.copyWith(epgUrl: _epgUrl));
    final playlist = await disk.add(
      const SourceDraft(
        type: SourceType.m3uUrl,
        name: 'List',
        url: _playlistUrl,
      ),
    );
    final tokenList = await disk.add(
      const SourceDraft(
        type: SourceType.m3uUrl,
        name: 'Token',
        url: _tokenPlaylistUrl,
      ),
    );
    await disk.repository.update(
      xtream.id,
      _xtream.copyWith(name: 'Edited', password: '$_password-2'),
    );
    for (final id in [xtream.id, playlist.id, tokenList.id]) {
      final credentials = (await disk.repository.credentialsFor(id))
          .valueOrNull!;
      // What a sync will log when it starts.
      disk.log.info('sync', 'Fetching ${credentials.url}');
    }
    await disk.repository.reorder([tokenList.id, playlist.id, xtream.id]);
    await disk.repository.remove(playlist.id);
    await disk.log.close();
    await disk.database.close();

    final secrets = [_password, '$_password-2', _playlistToken];
    for (final entry in directory.listSync().whereType<File>()) {
      final text = String.fromCharCodes(entry.readAsBytesSync());
      for (final secret in secrets) {
        expect(text, isNot(contains(secret)), reason: entry.path);
      }
    }
    final log = disk.logLines.join('\n');
    expect(log, contains('Fetching'));
    for (final secret in secrets) {
      expect(log, isNot(contains(secret)));
    }
  });
}
