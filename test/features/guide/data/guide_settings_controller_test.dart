import 'dart:async';
import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:iptv_player/core/core_providers.dart';
import 'package:iptv_player/core/logging/app_log.dart';
import 'package:iptv_player/core/logging/secret_registry.dart';
import 'package:iptv_player/core/result.dart';
import 'package:iptv_player/core/secure/credential_store.dart';
import 'package:iptv_player/data/db/app_database.dart';
import 'package:iptv_player/data/db/db_providers.dart';
import 'package:iptv_player/data/settings/settings_repository.dart';
import 'package:iptv_player/features/guide/data/guide_providers.dart';
import 'package:iptv_player/features/guide/domain/epg.dart';
import 'package:iptv_player/features/guide/domain/guide_matching.dart';
import 'package:iptv_player/features/guide/domain/guide_settings.dart';
import 'package:iptv_player/features/sources/data/source_providers.dart';
import 'package:iptv_player/features/sources/domain/source.dart';
import 'package:logger/logger.dart';

const _password = 'Pw-7f3a9c1e';

/// Records every re-import and holds each until the test finishes it, so
/// a test can see that they run one at a time.
final class _Imports implements GuideImportService {
  /// The sources re-imported, in the order they were asked for.
  final asked = <String>[];
  final importing = <String>{};
  final _running = <Completer<Result<EpgImportCounts>>>[];

  int get running => _running.length;

  /// Finishes the oldest re-import still running.
  Future<void> finishOne() async {
    _running.removeAt(0).complete(const Ok(EpgImportCounts()));
    await pumpEventQueue();
  }

  @override
  Future<Result<EpgImportCounts>> reimport(String sourceId) {
    asked.add(sourceId);
    final done = Completer<Result<EpgImportCounts>>();
    _running.add(done);
    return done.future;
  }

  @override
  bool isImporting(String sourceId) => importing.contains(sourceId);

  @override
  Stream<(String, EpgImportProgress)> get progress => const Stream.empty();

  @override
  Future<Result<EpgImportCounts>> importGuide(String sourceId) =>
      throw UnsupportedError('the controller only re-imports');

  @override
  Future<void> cancel(String sourceId) async {}

  @override
  Future<Result<GuideOrigin>> guideOrigin(String sourceId) async =>
      Err(NotFoundFailure('not asked'));
}

final class _FailingStore implements GuideSettingsStore {
  @override
  Future<Result<GuideSettings>> load() async => const Ok(GuideSettings());

  @override
  Future<Result<void>> save(GuideSettings settings) async =>
      Err(StorageFailure('the disk is full'));
}

/// A store whose read throws, which the real one never does.
final class _ThrowingStore implements GuideSettingsStore {
  @override
  Future<Result<GuideSettings>> load() async => throw StateError('broken');

  @override
  Future<Result<void>> save(GuideSettings settings) async => const Ok(null);
}

/// The controller over the real stores and repositories (an in-memory
/// database, an in-memory keyring) and a recording importer.
final class _Env {
  new _(this.db) {
    log = AppLog(output: MemoryOutput(), secrets: secrets);
  }

  static _Env open({
    AppDatabase? database,
    bool fakeImports = true,
    GuideSettingsStore? settingsStore,
  }) {
    final env = _Env._(database ?? AppDatabase.memory());
    addTearDown(env.close);
    env.container = ProviderContainer.test(
      overrides: [
        appDatabaseProvider.overrideWithValue(env.db),
        credentialStoreProvider.overrideWithValue(env.store),
        secretRegistryProvider.overrideWithValue(env.secrets),
        appLogProvider.overrideWithValue(env.log),
        if (fakeImports)
          guideImportServiceProvider.overrideWithValue(env.imports),
        if (settingsStore != null)
          guideSettingsStoreProvider.overrideWithValue(settingsStore),
      ],
    );
    return env;
  }

  final AppDatabase db;
  final store = InMemoryCredentialStore();
  final secrets = SecretRegistry();
  final imports = _Imports();
  late final AppLog log;
  late final ProviderContainer container;

  GuideSettingsController get controller =>
      container.read(guideSettingsControllerProvider.notifier);

  GuideSettings get settings => container.read(guideSettingsControllerProvider);

  SourceRepository get sources => container.read(sourceRepositoryProvider);

  SettingsRepository get settingsRepository =>
      container.read(settingsRepositoryProvider);

  Future<String> add(String name, {SourceDraft? draft}) async {
    final added = await sources.add(
      draft ??
          SourceDraft(
            type: SourceType.xtream,
            name: name,
            url: 'http://${name.toLowerCase()}.test:8080',
            username: 'viewer',
            password: _password,
          ),
    );
    expect(added.isOk, isTrue, reason: '${added.failureOrNull}');
    return added.valueOrNull!.id;
  }

  Future<Source> source(String id) async =>
      (await sources.byId(id)).valueOrNull!;

  /// Puts a one-programme guide in place for [sourceId].
  Future<void> giveGuide(String sourceId) async {
    final guide = container.read(epgRepositoryProvider);
    final run = (await guide.startImport(sourceId)).valueOrNull!;
    await guide.stageChannels(run, const [GuideChannel(xmltvId: 'one.uk')]);
    final start = DateTime.now().toUtc();
    await guide.stagePrograms(run, [
      EpgProgramme(
        id: 0,
        channelId: 'one.uk',
        start: start,
        end: start.add(const Duration(hours: 1)),
        title: 'News',
      ),
    ]);
    final committed = await guide.commitImport(
      sourceId: sourceId,
      importRun: run,
    );
    expect(committed.isOk, isTrue, reason: '${committed.failureOrNull}');
  }

  Future<void> close() async {
    await log.close();
    await db.close();
  }
}

void main() {
  group('the days kept', () {
    test('start as the default, then as stored', () async {
      final env = _Env.open();
      await env.settingsRepository.writeValue(SettingsKeys.guide, {
        'keep_days': 3,
      });

      expect(env.settings, const GuideSettings());
      await pumpEventQueue();

      expect(env.settings, const GuideSettings(keepDays: 3));
    });

    test('loaded completes once the stored value is in use, so an import '
        'at launch can wait for it', () async {
      final env = _Env.open();
      await env.settingsRepository.writeValue(SettingsKeys.guide, {
        'keep_days': 3,
      });

      env.settings;
      await env.controller.loaded;

      expect(env.settings, const GuideSettings(keepDays: 3));
    });

    test('loaded completes when the store throws too', () async {
      final env = _Env.open(settingsStore: _ThrowingStore());

      await env.controller.loaded.timeout(const Duration(seconds: 5));

      expect(env.settings, const GuideSettings());
    });

    test('a damaged stored value is the default', () async {
      final env = _Env.open();
      await env.settingsRepository.writeJsonText(
        SettingsKeys.guide,
        '{"keep_days": "a fortnight and a bit"}',
      );

      env.settings;
      await pumpEventQueue();

      expect(env.settings, const GuideSettings());
    });

    test('a choice made while the stored one loads wins', () async {
      final env = _Env.open();
      await env.settingsRepository.writeValue(SettingsKeys.guide, {
        'keep_days': 3,
      });

      env.settings;
      expect(await env.controller.setKeepDays(10), const Ok<void>(null));
      await pumpEventQueue();

      expect(env.settings.keepDays, 10);
      expect(
        (await env.container.read(guideSettingsStoreProvider).load())
            .valueOrNull,
        const GuideSettings(keepDays: 10),
      );
    });

    test('a change is saved, then re-imports the sources with a guide or '
        'an import running, one at a time, in source order', () async {
      final env = _Env.open();
      final a = await env.add('Alpha');
      await env.add('Bravo');
      final c = await env.add('Charlie');
      final d = await env.add('Delta');
      await env.giveGuide(a);
      await env.giveGuide(c);
      env.imports.importing.add(d);

      final saved = await env.controller.setKeepDays(3);

      expect(saved.isOk, isTrue);
      expect(env.settings.keepDays, 3);
      expect(
        (await env.container.read(guideSettingsStoreProvider).load())
            .valueOrNull,
        const GuideSettings(keepDays: 3),
      );
      await pumpEventQueue();
      expect(env.imports.asked, [a]);
      await env.imports.finishOne();
      expect(env.imports.asked, [a, c]);
      await env.imports.finishOne();
      expect(env.imports.asked, [a, c, d]);
      await env.imports.finishOne();
      expect(env.imports.asked, [a, c, d]);
      expect(env.imports.running, 0);
    });

    test('the same choice again saves and re-imports nothing', () async {
      final env = _Env.open();
      final a = await env.add('Alpha');
      await env.giveGuide(a);
      env.settings;
      await pumpEventQueue();

      final saved = await env.controller.setKeepDays(
        GuideSettings.defaultKeepDays,
      );
      await pumpEventQueue();

      expect(saved.isOk, isTrue);
      expect(
        (await env.settingsRepository.readJsonText(SettingsKeys.guide))
            .valueOrNull,
        isNull,
      );
      expect(env.imports.asked, isEmpty);
    });

    test('a second change stops the first round at its next '
        'source', () async {
      final env = _Env.open();
      final a = await env.add('Alpha');
      final b = await env.add('Bravo');
      await env.giveGuide(a);
      await env.giveGuide(b);

      await env.controller.setKeepDays(3);
      await pumpEventQueue();
      expect(env.imports.asked, [a]);

      await env.controller.setKeepDays(5);
      await pumpEventQueue();
      expect(env.imports.asked, [a, a]);

      // The first round's import of Alpha ends: that round goes no further.
      await env.imports.finishOne();
      expect(env.imports.asked, [a, a]);
      await env.imports.finishOne();
      expect(env.imports.asked, [a, a, b]);
      await env.imports.finishOne();
      expect(env.imports.asked, [a, a, b]);
      expect(env.settings.keepDays, 5);
    });

    test('a choice that can’t be saved is an error, and re-imports '
        'nothing', () async {
      final env = _Env.open(settingsStore: _FailingStore());
      final a = await env.add('Alpha');
      await env.giveGuide(a);

      final saved = await env.controller.setKeepDays(3);
      await pumpEventQueue();

      expect(saved.failureOrNull, isA<StorageFailure>());
      expect(env.imports.asked, isEmpty);
      expect(
        env.settings.keepDays,
        GuideSettings.defaultKeepDays,
        reason: 'imports must not use a choice that was not kept',
      );
    });

    test('days outside 1 to 14 are refused and nothing changes', () async {
      final env = _Env.open();
      final a = await env.add('Alpha');
      await env.giveGuide(a);

      for (final days in [0, -1, 15]) {
        final saved = await env.controller.setKeepDays(days);
        expect(
          saved.failureOrNull,
          isA<InvalidInputFailure>(),
          reason: '$days',
        );
      }
      await pumpEventQueue();
      expect(env.settings.keepDays, GuideSettings.defaultKeepDays);
      expect(env.imports.asked, isEmpty);
    });
  });

  group('a source’s time offset', () {
    test('is saved on the source, which keeps everything else and its '
        'password', () async {
      final env = _Env.open();
      final id = await env.add(
        'Panel',
        draft: const SourceDraft(
          type: SourceType.xtream,
          name: 'Panel',
          url: 'http://panel.test:8080/iptv',
          username: 'viewer',
          password: _password,
          epgUrl: 'http://epg.test/Tk9c2e81/guide.xml',
          userAgent: 'Special/1.0',
          liveFormat: LiveFormat.hls,
          epgOffsetMinutes: -30,
          refreshHours: 6,
          maxConnectionsOverride: 2,
        ),
      );
      final before = await env.source(id);
      final credentials = (await env.sources.credentialsFor(id)).valueOrNull;

      final saved = await env.controller.setOffset(before, 90);
      await pumpEventQueue();

      expect(saved.isOk, isTrue, reason: '${saved.failureOrNull}');
      final after = await env.source(id);
      expect(after.epgOffsetMinutes, 90);
      expect(
        after.copyWith(epgOffsetMinutes: -30, updatedAt: before.updatedAt),
        before,
      );
      expect((await env.sources.credentialsFor(id)).valueOrNull, credentials);
      // No guide yet: nothing to re-import.
      expect(env.imports.asked, isEmpty);
    });

    test('keeps a playlist’s address and the guides its header '
        'names', () async {
      final env = _Env.open();
      final id = await env.add(
        'List',
        draft: const SourceDraft(
          type: SourceType.m3uUrl,
          name: 'List',
          url: 'http://lists.test/get.php?username=viewer&password=$_password',
        ),
      );
      await env.sources.setAdvertisedEpgUrls(id, [
        'http://lists.test/xmltv.php?username=viewer&password=$_password',
      ]);
      final credentials = (await env.sources.credentialsFor(id)).valueOrNull;

      final saved = await env.controller.setOffset(await env.source(id), -60);

      expect(saved.isOk, isTrue, reason: '${saved.failureOrNull}');
      expect((await env.source(id)).epgOffsetMinutes, -60);
      expect((await env.sources.credentialsFor(id)).valueOrNull, credentials);
    });

    test('re-imports the source’s guide when it has one', () async {
      final env = _Env.open();
      final withGuide = await env.add('Alpha');
      final importing = await env.add('Bravo');
      final without = await env.add('Charlie');
      await env.giveGuide(withGuide);
      env.imports.importing.add(importing);

      for (final id in [withGuide, importing, without]) {
        expect(
          (await env.controller.setOffset(await env.source(id), 60)).isOk,
          isTrue,
        );
      }
      await pumpEventQueue();

      expect(env.imports.asked, [withGuide, importing]);
    });

    test('credentials that can’t be read are an error, and nothing '
        'changes', () async {
      final env = _Env.open();
      final id = await env.add('Alpha');
      await env.giveGuide(id);
      final before = await env.source(id);
      env.store.locked = true;

      final saved = await env.controller.setOffset(before, 120);
      await pumpEventQueue();

      expect(saved.failureOrNull, isA<SecureStorageFailure>());
      env.store.locked = false;
      expect(await env.source(id), before);
      expect(env.imports.asked, isEmpty);
    });
  });

  group('with the real importer', () {
    setUpAll(() => HttpOverrides.global = null);

    test('an import keeps the days the controller holds, and a change '
        're-imports with the new ones', () async {
      final directory = await Directory.systemTemp.createTemp('guide_settings');
      addTearDown(() => directory.delete(recursive: true));
      final env = _Env.open(
        database: AppDatabase(await openAppDatabase(directory)),
        fakeImports: false,
      );
      final list = File('${directory.path}/list.m3u')
        ..writeAsStringSync('#EXTM3U\n');
      final guide = File('${directory.path}/guide.xml')
        ..writeAsStringSync(_tenDayGuide(DateTime.now()));
      final id = await env.add(
        'List',
        draft: SourceDraft(
          type: SourceType.m3uFile,
          name: 'List',
          url: list.path,
        ),
      );
      await env.sources.setAdvertisedEpgUrls(id, [guide.path]);
      final importer = env.container.read(guideImportServiceProvider);

      // No guide yet: the change re-imports nothing. Its round reads the
      // database: waited for, or it can see the import below and cancel it.
      await env.controller.setKeepDays(3);
      await env.controller.reimporting;
      expect(importer.isImporting(id), isFalse);

      final before = DateTime.now().toUtc();
      final first = await importer.importGuide(id);
      expect(first.isOk, isTrue, reason: '${first.failureOrNull}');
      Future<int> hoursAhead() async {
        final coverage =
            (await env.container.read(epgRepositoryProvider).coverage(id))
                .valueOrNull!;
        return coverage.lastEnd!.difference(before).inHours;
      }

      expect(await hoursAhead(), inInclusiveRange(72, 74));

      await env.controller.setKeepDays(5);
      await _until(() async {
        final row = await env.db
            .customSelect(
              'SELECT COUNT(*) AS n FROM epg_imports '
              "WHERE outcome = 'succeeded'",
            )
            .getSingle();
        return row.read<int>('n') == 2 && !importer.isImporting(id);
      });

      expect(await hoursAhead(), inInclusiveRange(120, 122));
    });
  });
}

/// Waits for [done], checking every few milliseconds, for at most a
/// minute.
Future<void> _until(Future<bool> Function() done) async {
  final deadline = DateTime.now().add(const Duration(minutes: 1));
  while (!await done()) {
    if (DateTime.now().isAfter(deadline)) fail('timed out');
    await Future<void>.delayed(const Duration(milliseconds: 20));
  }
}

/// Two channels with a programme every two hours, from a day before
/// [now] to ten days after it.
String _tenDayGuide(DateTime now) {
  String stamp(DateTime t) {
    String p(int v, [int w = 2]) => '$v'.padLeft(w, '0');
    final u = t.toUtc();
    return '${p(u.year, 4)}${p(u.month)}${p(u.day)}'
        '${p(u.hour)}${p(u.minute)}${p(u.second)} +0000';
  }

  final hour = DateTime.utc(now.year, now.month, now.day, now.hour);
  final buffer = StringBuffer(
    '<?xml version="1.0" encoding="UTF-8"?>\n<tv>\n'
    '<channel id="one.uk"><display-name>One</display-name></channel>\n'
    '<channel id="two.uk"><display-name>Two</display-name></channel>\n',
  );
  for (final channel in ['one.uk', 'two.uk']) {
    for (var h = -24; h < 10 * 24; h += 2) {
      final start = hour.add(Duration(hours: h));
      buffer.writeln(
        '<programme start="${stamp(start)}" '
        'stop="${stamp(start.add(const Duration(hours: 2)))}" '
        'channel="$channel"><title>$channel at $h</title></programme>',
      );
    }
  }
  buffer.writeln('</tv>');
  return '$buffer';
}
