import 'dart:async';
import 'dart:io';

import 'package:fake_provider/profile.dart';
import 'package:fake_provider/server.dart';
import 'package:fake_provider/server_state.dart';
import 'package:fake_provider/xmltv.dart' show orphanXmltvId;
import 'package:flutter_test/flutter_test.dart';
import 'package:iptv_player/core/logging/app_log.dart';
import 'package:iptv_player/core/logging/secret_registry.dart';
import 'package:iptv_player/core/result.dart';
import 'package:iptv_player/core/secure/credential_store.dart';
import 'package:iptv_player/data/db/app_database.dart';
import 'package:iptv_player/data/providers/xmltv/xmltv_parser.dart';
import 'package:iptv_player/data/providers/xmltv/xmltv_reader.dart';
import 'package:iptv_player/data/sync/epg_importer.dart';
import 'package:iptv_player/data/sync/epg_match_service.dart';
import 'package:iptv_player/features/guide/data/db_epg_repository.dart';
import 'package:iptv_player/features/guide/domain/epg.dart';
import 'package:iptv_player/features/guide/domain/epg_match_summary.dart';
import 'package:iptv_player/features/sources/data/db_source_repository.dart';
import 'package:iptv_player/features/sources/domain/source.dart';
import 'package:logger/logger.dart';

const _username = 'viewer';
const _password = 'Pw-7f3a9c1e';
const _token = 'Tk9c2e81d4f00b';

/// The importer end to end: a real file database opened the way the app
/// opens it, the import isolate, and a real server — the fake provider
/// in-process, or a guide on disk.
final class _Env {
  new _(this.directory, this.db, {int batchSize = 50})
    : store = InMemoryCredentialStore(),
      memory = MemoryOutput() {
    final secrets = SecretRegistry();
    log = AppLog(output: memory, secrets: secrets);
    sources = DbSourceRepository(
      database: db,
      store: store,
      secrets: secrets,
      log: log,
    );
    guide = DbEpgRepository(db, clock: () => DateTime.now().toUtc());
    importer = EpgImporter(
      database: db,
      guide: guide,
      sources: sources,
      log: log,
      // Small batches, so a few thousand rows still take many.
      batchSize: batchSize,
    );
  }

  static Future<_Env> open({int batchSize = 50}) async {
    final directory = await Directory.systemTemp.createTemp('epg_importer');
    final db = AppDatabase(await openAppDatabase(directory));
    final env = _Env._(directory, db, batchSize: batchSize);
    addTearDown(env.close);
    return env;
  }

  final Directory directory;
  final AppDatabase db;
  final InMemoryCredentialStore store;
  final MemoryOutput memory;
  late final AppLog log;
  late final DbSourceRepository sources;
  late final DbEpgRepository guide;
  late final EpgImporter importer;

  List<String> get logLines => [for (final e in memory.buffer) ...e.lines];

  Future<String> add(SourceDraft draft) async {
    final added = await sources.add(draft);
    expect(added.isOk, isTrue, reason: '${added.failureOrNull}');
    return added.valueOrNull!.id;
  }

  /// A file in this environment's directory.
  String file(String name, String text) {
    final file = File('${directory.path}/$name')..writeAsStringSync(text);
    return file.path;
  }

  Future<GuideCoverage> coverage(String sourceId) async =>
      (await guide.coverage(sourceId)).valueOrNull!;

  Future<int> count(String table, [String where = '1']) async {
    final row = await db
        .customSelect('SELECT COUNT(*) AS n FROM $table WHERE $where')
        .getSingle();
    return row.read<int>('n');
  }

  Future<int> staged(int importRun) async =>
      await count('epg_programs_staging', 'import_run = $importRun') +
      await count('epg_channels_staging', 'import_run = $importRun');

  /// (channel, start) → (end, title, description) for a source's live
  /// programmes.
  Future<Map<(String, int), (int, String, String?)>> programmes(
    String sourceId,
  ) async {
    final rows = await db
        .customSelect(
          'SELECT epg_channel_id, start_utc, end_utc, title, description '
          "FROM epg_programs WHERE source_id = '$sourceId'",
        )
        .get();
    return {
      for (final row in rows)
        (row.read<String>('epg_channel_id'), row.read<int>('start_utc')): (
          row.read<int>('end_utc'),
          row.read<String>('title'),
          row.read<String?>('description'),
        ),
    };
  }

  Future<void> close() async {
    await importer.dispose();
    await log.close();
    await db.close();
    await directory.delete(recursive: true);
  }
}

/// The fake provider in-process, with a catalogue small enough that a
/// guide is quick: 36 channels, 32 of them with a guide id.
Future<FakeProviderServer> _fakeProvider({
  String profile = 'default',
  int liveCount = 36,
  int epgDays = 1,
}) async {
  final runDir = await Directory.systemTemp.createTemp('fake_provider');
  addTearDown(() => runDir.delete(recursive: true));
  final server = await FakeProviderServer.start(
    state: FakeServerState(
      profile: fakeProfiles[profile]!.copyWith(
        liveCount: liveCount,
        username: _username,
        password: _password,
      ),
      samplesDir: runDir.path,
      ffmpegPath: 'ffmpeg',
      runDir: runDir.path,
      epgDays: epgDays,
    ),
    port: 0,
  );
  addTearDown(server.close);
  return server;
}

/// A server that reads each request and hangs up without an answer: the
/// client's error then quotes the whole URL.
Future<String> _hangUp() async {
  final server = await ServerSocket.bind(InternetAddress.loopbackIPv4, 0);
  addTearDown(server.close);
  server.listen((socket) => socket.listen((_) => socket.destroy()));
  return 'http://127.0.0.1:${server.port}';
}

SourceDraft _xtream(
  Object server, {
  String password = _password,
  String? epgUrl,
  int offset = 0,
}) => SourceDraft(
  type: SourceType.xtream,
  name: 'Fake panel',
  url: '$server',
  username: _username,
  password: password,
  epgUrl: epgUrl,
  epgOffsetMinutes: offset,
);

SourceDraft _playlistFile(String path, {String? epgUrl}) => SourceDraft(
  type: SourceType.m3uFile,
  name: 'Playlist',
  url: path,
  epgUrl: epgUrl,
);

/// The fake provider's guide with [flags] in its query.
String _guideUrl(FakeProviderServer server, String flags) =>
    '${server.url}/xmltv.php?username=$_username&password=$_password&$flags';

/// A two-channel guide around [now], in XMLTV's own time format.
String _smallGuide(DateTime now) {
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
    for (var i = -2; i < 4; i++) {
      final start = hour.add(Duration(hours: i));
      buffer.writeln(
        '<programme start="${stamp(start)}" '
        'stop="${stamp(start.add(const Duration(hours: 1)))}" '
        'channel="$channel"><title>$channel at $i</title></programme>',
      );
    }
  }
  buffer.writeln('</tv>');
  return '$buffer';
}

void main() {
  // The Flutter test binding fakes HttpClient with 400s; this needs sockets.
  setUpAll(() => HttpOverrides.global = null);

  group('where the guide comes from', () {
    const xtream = SourceCredentials(
      url: 'http://panel.test:8080',
      username: _username,
      password: _password,
    );

    test("the user's EPG URL wins, for every type", () {
      for (final type in SourceType.values) {
        final location = resolveGuideLocation(
          type,
          const SourceCredentials(
            url: 'http://panel.test:8080',
            username: _username,
            password: _password,
            epgUrl: '  http://epg.test/$_token/guide.xml ',
            advertisedEpgUrls: ['http://other.test/guide.xml'],
          ),
        ).valueOrNull!;

        expect(location.value, 'http://epg.test/$_token/guide.xml');
        expect(location.kind, GuideLocationKind.override);
      }
    });

    test("an Xtream panel's own xmltv.php, with its credentials", () {
      final location = resolveGuideLocation(
        SourceType.xtream,
        xtream,
      ).valueOrNull!;

      expect(
        location.value,
        'http://panel.test:8080/xmltv.php?username=$_username'
        '&password=$_password',
      );
      expect(location.kind, GuideLocationKind.panel);
      expect(location.isFile, isFalse);
    });

    test('a panel under a path keeps it', () {
      for (final server in [
        'https://panel.test/iptv',
        'https://panel.test/iptv/',
        'https://panel.test/iptv//',
      ]) {
        expect(
          xtreamGuideUrl(server: server, username: 'u', password: 'p'),
          'https://panel.test/iptv/xmltv.php?username=u&password=p',
          reason: server,
        );
      }
    });

    test('odd characters in the credentials are query-encoded', () {
      const password = 'p&ss=w rd+/?#%é';
      const username = 'me@home & co';

      final url = xtreamGuideUrl(
        server: 'http://panel.test',
        username: username,
        password: password,
      )!;

      final uri = Uri.parse(url);
      expect(uri.path, '/xmltv.php');
      expect(uri.queryParameters, {'username': username, 'password': password});
      expect(uri.fragment, isEmpty);
      expect(url, isNot(contains('&ss=')));
      expect(url, isNot(contains('#')));
    });

    test('a panel with no usable server is invalid input', () {
      for (final server in ['', 'not a url', 'ftp://panel.test']) {
        final result = resolveGuideLocation(
          SourceType.xtream,
          SourceCredentials(url: server, username: 'u', password: 'p'),
        );

        expect(result.failureOrNull, isA<InvalidInputFailure>());
      }
    });

    test("a playlist's first EPG URL, blanks passed over", () {
      for (final type in [SourceType.m3uUrl, SourceType.m3uFile]) {
        final location = resolveGuideLocation(
          type,
          const SourceCredentials(
            url: 'http://lists.test/list.m3u',
            advertisedEpgUrls: [
              '  ',
              'http://epg.test/first.xml',
              'http://epg.test/second.xml',
            ],
          ),
        ).valueOrNull!;

        expect(location.value, 'http://epg.test/first.xml');
        expect(location.kind, GuideLocationKind.playlist);
      }
    });

    test('a playlist with none has no guide: not found', () {
      for (final type in [SourceType.m3uUrl, SourceType.m3uFile]) {
        final result = resolveGuideLocation(
          type,
          const SourceCredentials(url: '/home/me/list.m3u', epgUrl: ' '),
        );

        expect(result.failureOrNull, isA<NotFoundFailure>());
      }
    });

    test('anything without http(s) in front is a file', () {
      for (final (value, input) in [
        ('/home/me/guide.xml', const XmltvFileInput('/home/me/guide.xml')),
        (r'C:\guides\guide.xml', const XmltvFileInput(r'C:\guides\guide.xml')),
        (
          'file:///home/me/guide.xml',
          const XmltvFileInput('/home/me/guide.xml'),
        ),
        ('guide.xml.gz', const XmltvFileInput('guide.xml.gz')),
      ]) {
        final location = GuideLocation(value, GuideLocationKind.playlist);

        expect(location.isFile, isTrue, reason: value);
        expect(
          (location.input() as XmltvFileInput).path,
          input.path,
          reason: value,
        );
      }
      const web = GuideLocation(
        'HTTPS://epg.test/guide.xml',
        GuideLocationKind.override,
      );
      expect(web.isFile, isFalse);
      expect(
        web.input(userAgent: 'Special/1.0'),
        isA<XmltvUrlInput>().having((i) => i.userAgent, 'agent', 'Special/1.0'),
      );
    });

    test('a location prints no part of its value', () {
      final location = resolveGuideLocation(
        SourceType.xtream,
        xtream,
      ).valueOrNull!;

      expect('$location', isNot(contains(_password)));
      expect('$location', isNot(contains('panel.test')));
    });
  });

  group('an import', () {
    test('from an Xtream panel puts the guide live, and leaves nothing '
        'staged', () async {
      final server = await _fakeProvider();
      final env = await _Env.open();
      final id = await env.add(_xtream(server.url));

      final result = await env.importer.importGuide(id);

      final counts = result.valueOrNull;
      expect(counts, isNotNull, reason: '${result.failureOrNull}');
      expect(counts!.channels, 32);
      expect(counts.programmes, greaterThan(32 * 48));
      final coverage = await env.coverage(id);
      expect(coverage.hasGuide, isTrue);
      expect(coverage.guideChannels, 32);
      expect(coverage.programmes, counts.programmes);
      expect(coverage.lastImport!.outcome, GuideImportOutcome.succeeded);
      expect(coverage.lastImport!.isLive, isTrue);
      expect(coverage.coversAt(DateTime.now().toUtc()), isTrue);
      expect(await env.count('epg_programs'), counts.programmes);
      expect(await env.count('epg_programs_staging'), 0);
      expect(await env.count('epg_channels_staging'), 0);
      expect(
        env.logLines.where((l) => l.contains('Guide import $id succeeded')),
        hasLength(1),
      );
      for (final line in env.logLines) {
        expect(line, isNot(contains(_password)));
        expect(line, isNot(contains('xmltv.php')));
      }
    });

    test('keeps only the window, and nothing is outside it', () async {
      final server = await _fakeProvider(epgDays: 3);
      final env = await _Env.open(batchSize: 1000);
      final id = await env.add(_xtream(server.url));
      final before = DateTime.now().toUtc();

      await env.importer.importGuide(id);

      final coverage = await env.coverage(id);
      // The fake serves a day back and three ahead; the window is a day
      // back and seven ahead, so everything overlaps it.
      expect(
        coverage.firstStart!.isAfter(
          before.subtract(const Duration(days: 1, hours: 1)),
        ),
        isTrue,
      );
      expect(
        coverage.lastEnd!.isBefore(before.add(const Duration(days: 8))),
        isTrue,
      );
    });

    test("the quirky panel's guide: every bad row a skipped reason, the "
        'rest live', () async {
      final server = await _fakeProvider(profile: 'quirky');
      final env = await _Env.open();
      final id = await env.add(_xtream(server.url));

      final result = await env.importer.importGuide(id);

      expect(result.isOk, isTrue, reason: '${result.failureOrNull}');
      final counts = (await env.coverage(id)).lastImport!.counts;
      expect(counts.skipped[XmltvSkip.badDate], greaterThan(0));
      expect(counts.skipped[XmltvSkip.badTimezone], greaterThan(0));
      expect(counts.skipped[XmltvSkip.duplicateChannel], 1);
      expect(counts.truncated, isFalse);
      expect(counts.programmes, greaterThan(0));
      // The channel no stream has is in the guide all the same.
      final guideChannels = (await env.guide.guideChannels(
        id,
        query: orphanXmltvId,
      )).valueOrNull!;
      expect(guideChannels.single.xmltvId, orphanXmltvId);
      expect(env.logLines.where((l) => l.contains('X-MADE-UP-8')), isNotEmpty);
      expect(
        env.logLines.firstWhere((l) => l.contains('succeeded')),
        contains(XmltvSkip.badDate),
      );
    });

    test('a guide cut off mid-file imports what it read, marked '
        'truncated', () async {
      final server = await _fakeProvider();
      final env = await _Env.open();
      final id = await env.add(
        _playlistFile(
          env.file('list.m3u', '#EXTM3U\n'),
          epgUrl: _guideUrl(server, 'unclosed=1'),
        ),
      );

      final result = await env.importer.importGuide(id);

      expect(result.valueOrNull?.truncated, isTrue);
      final coverage = await env.coverage(id);
      expect(coverage.lastImport!.outcome, GuideImportOutcome.succeeded);
      expect(coverage.lastImport!.counts.truncated, isTrue);
      expect(coverage.programmes, greaterThan(0));
      expect(env.logLines.where((l) => l.contains('mid-file')), isNotEmpty);
    });

    test("a playlist file's guide, from the file its header names", () async {
      final env = await _Env.open();
      final id = await env.add(
        _playlistFile(env.file('list.m3u', '#EXTM3U\n')),
      );
      final guide = env.file('guide.xml', _smallGuide(DateTime.now()));
      await env.sources.setAdvertisedEpgUrls(id, [guide]);

      final result = await env.importer.importGuide(id);

      final counts = result.valueOrNull!;
      expect(counts.channels, 2);
      expect(counts.programmes, 12);
      expect(counts.skipped, isEmpty);
      expect(counts.truncated, isFalse);
    });

    test('a playlist with no guide is not found, and records no '
        'import', () async {
      final env = await _Env.open();
      final id = await env.add(
        _playlistFile(env.file('list.m3u', '#EXTM3U\n')),
      );

      final result = await env.importer.importGuide(id);

      expect(result.failureOrNull, isA<NotFoundFailure>());
      expect(await env.count('epg_imports'), 0);
    });

    test('an unknown source is not found', () async {
      final env = await _Env.open();

      final result = await env.importer.importGuide('nope');

      expect(result.failureOrNull, isA<NotFoundFailure>());
      expect(await env.count('epg_imports'), 0);
    });

    test('a wrong password fails as auth and keeps the guide '
        'there was', () async {
      final server = await _fakeProvider();
      final env = await _Env.open();
      final id = await env.add(_xtream(server.url));
      final first = (await env.importer.importGuide(id)).valueOrNull!;
      await env.sources.update(id, _xtream(server.url, password: 'wrong-pw'));

      final result = await env.importer.importGuide(id);

      expect(result.failureOrNull, isA<AuthFailure>());
      expect(result.failureOrNull!.statusCode, 401);
      final coverage = await env.coverage(id);
      expect(coverage.lastImport!.outcome, GuideImportOutcome.failed);
      expect(coverage.lastImport!.failureCode, 'auth');
      expect(coverage.lastImport!.failureStatus, 401);
      expect(coverage.programmes, first.programmes);
      expect(await env.count('epg_programs'), first.programmes);
      expect(await env.count('epg_programs_staging'), 0);
    });

    test('an empty guide fails and keeps the guide there was', () async {
      final server = await _fakeProvider();
      final env = await _Env.open();
      final id = await env.add(_xtream(server.url));
      final first = (await env.importer.importGuide(id)).valueOrNull!;
      await env.sources.update(
        id,
        _xtream(server.url, epgUrl: _guideUrl(server, 'channels=0')),
      );

      final result = await env.importer.importGuide(id);

      expect(result.failureOrNull, isA<ParseFailure>());
      final coverage = await env.coverage(id);
      expect(coverage.lastImport!.outcome, GuideImportOutcome.failed);
      expect(coverage.lastImport!.failureCode, 'parse');
      expect(coverage.guideChannels, 32);
      expect(await env.count('epg_programs'), first.programmes);
    });

    test("the source's offset moves every programme", () async {
      final server = await _fakeProvider();
      final env = await _Env.open(batchSize: 1000);
      final plain = await env.add(_xtream(server.url));
      final shifted = await env.add(_xtream(server.url, offset: 60));

      await env.importer.importGuide(plain);
      await env.importer.importGuide(shifted);

      final unshifted = await env.programmes(plain);
      final moved = await env.programmes(shifted);
      const hour = 3600 * 1000;
      var matched = 0;
      for (final MapEntry(key: (channel, start), value: (end, title, desc))
          in moved.entries) {
        final original = unshifted[(channel, start - hour)];
        // The window's edges keep a slightly different set.
        if (original == null) continue;
        matched++;
        expect(original.$1, end - hour);
        expect(original.$2, title);
        expect(original.$3, desc);
      }
      expect(matched, greaterThan(moved.length * 0.9));
    });

    test('asking again while one runs joins it', () async {
      final server = await _fakeProvider();
      final env = await _Env.open();
      final id = await env.add(_xtream(server.url));

      final first = env.importer.importGuide(id);
      final second = env.importer.importGuide(id);

      expect(identical(first, second), isTrue);
      expect((await first).isOk, isTrue);
      expect(await env.count('epg_imports'), 1);
    });

    test('progress arrives as it goes, counts only growing', () async {
      final server = await _fakeProvider();
      final env = await _Env.open();
      final id = await env.add(_xtream(server.url));
      final events = <EpgImportProgress>[];
      final listening = env.importer.progress
          .where((event) => event.$1 == id)
          .listen((event) => events.add(event.$2));

      final counts = (await env.importer.importGuide(id)).valueOrNull!;
      await listening.cancel();

      expect(events.length, greaterThan(3));
      for (var i = 1; i < events.length; i++) {
        expect(
          events[i].programmes,
          greaterThanOrEqualTo(events[i - 1].programmes),
        );
        expect(
          events[i].channels,
          greaterThanOrEqualTo(events[i - 1].channels),
        );
        expect(
          events[i].bytesRead,
          greaterThanOrEqualTo(events[i - 1].bytesRead),
        );
      }
      expect(events.last.programmes, counts.programmes);
      expect(events.last.channels, counts.channels);
      expect(events.last.bytesRead, greaterThan(0));
    });

    test('cancel stops the import, drops what it staged, and keeps the '
        'guide there was', () async {
      final server = await _fakeProvider();
      final env = await _Env.open();
      final id = await env.add(_xtream(server.url));
      final first = (await env.importer.importGuide(id)).valueOrNull!;
      // A week of guide: hundreds of batches.
      await env.sources.update(
        id,
        _xtream(server.url, epgUrl: _guideUrl(server, 'days=7')),
      );
      final started = Completer<void>();
      final listening = env.importer.progress.listen((event) {
        if (!started.isCompleted) started.complete();
      });

      final result = env.importer.importGuide(id);
      await started.future;
      await env.importer.cancel(id);
      await listening.cancel();

      expect((await result).failureOrNull, isA<CancelledFailure>());
      expect(env.importer.isImporting(id), isFalse);
      final coverage = await env.coverage(id);
      final cancelled = coverage.lastImport!;
      expect(cancelled.outcome, GuideImportOutcome.cancelled);
      expect(cancelled.failureCode, isNull);
      expect(await env.staged(cancelled.id), 0);
      expect(coverage.programmes, first.programmes);
      expect(await env.count('epg_programs'), first.programmes);
      expect(
        env.logLines.where((l) => l.contains('Guide import $id cancelled')),
        hasLength(1),
      );

      // And the next import runs cleanly.
      expect((await env.importer.importGuide(id)).isOk, isTrue);
    });

    test('dispose cancels every import', () async {
      final server = await _fakeProvider();
      final env = await _Env.open();
      final id = await env.add(
        _xtream(server.url, epgUrl: _guideUrl(server, 'days=7')),
      );
      final started = Completer<void>();
      final listening = env.importer.progress.listen((event) {
        if (!started.isCompleted) started.complete();
      });

      final result = env.importer.importGuide(id);
      await started.future;
      await listening.cancel();
      await env.importer.dispose();

      expect((await result).failureOrNull, isA<CancelledFailure>());
      expect(
        (await env.importer.importGuide(id)).failureOrNull,
        isA<CancelledFailure>(),
      );
    });
  });

  group('no secret leaves an import', () {
    test('a panel that hangs up: the failure has neither the password nor '
        'the URL', () async {
      final origin = await _hangUp();
      final env = await _Env.open();
      final id = await env.add(_xtream(origin));

      final result = await env.importer.importGuide(id);

      final failure = result.failureOrNull!;
      expect(failure, isA<NetworkFailure>());
      expect('$failure', isNot(contains(_password)));
      expect('$failure', isNot(contains('xmltv.php')));
      final coverage = await env.coverage(id);
      expect(coverage.lastImport!.failureCode, 'network');
      for (final line in env.logLines) {
        expect(line, isNot(contains(_password)));
      }
    });

    test('a token in the path of a playlist guide URL', () async {
      final origin = await _hangUp();
      final env = await _Env.open();
      final id = await env.add(
        _playlistFile(env.file('list.m3u', '#EXTM3U\n')),
      );
      await env.sources.setAdvertisedEpgUrls(id, [
        '$origin/epg/$_token/guide.xml',
      ]);

      final result = await env.importer.importGuide(id);

      final failure = result.failureOrNull!;
      expect(failure, isA<NetworkFailure>());
      expect('$failure', isNot(contains(_token)));
      expect('$failure', contains('127.0.0.1'));
      for (final line in env.logLines) {
        expect(line, isNot(contains(_token)));
      }
    });

    test('connection refused on a closed port', () async {
      final closed = await ServerSocket.bind(InternetAddress.loopbackIPv4, 0);
      final port = closed.port;
      await closed.close();
      final env = await _Env.open();
      final id = await env.add(_xtream('http://127.0.0.1:$port'));

      final failure = (await env.importer.importGuide(id)).failureOrNull!;

      expect(failure, isA<NetworkFailure>());
      expect('$failure', isNot(contains(_password)));
    });

    test('an HTTP 500 from a URL with a password', () async {
      final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
      addTearDown(() => server.close(force: true));
      server.listen((request) {
        request.response.statusCode = 500;
        unawaited(request.response.close());
      });
      final env = await _Env.open();
      final id = await env.add(
        _xtream('http://127.0.0.1:${server.port}/p/$_token'),
      );

      final failure = (await env.importer.importGuide(id)).failureOrNull!;

      expect(failure, isA<NetworkFailure>());
      expect(failure.statusCode, 500);
      expect('$failure', isNot(contains(_password)));
      expect('$failure', isNot(contains(_token)));
      expect((await env.coverage(id)).lastImport!.failureStatus, 500);
    });
  });

  group('matching after the swap', () {
    EpgMatchService service(_Env env, EpgMatchRunner runner) {
      final service = EpgMatchService(
        database: env.db,
        log: env.log,
        runner: runner,
      );
      addTearDown(service.dispose);
      return service;
    }

    EpgImporter importer(_Env env, EpgMatchService matches) {
      final importer = EpgImporter(
        database: env.db,
        guide: env.guide,
        sources: env.sources,
        log: env.log,
        matches: matches,
        batchSize: 500,
      );
      addTearDown(importer.dispose);
      return importer;
    }

    test('the source is rematched once its guide is live, and the import '
        'answers after that', () async {
      final server = await _fakeProvider();
      final env = await _Env.open();
      final id = await env.add(_xtream(server.url));
      final asked = Completer<(String, bool)>();
      final matched = Completer<Result<EpgMatchSummary>>();
      final withMatching = importer(
        env,
        service(env, (sourceId, _) async {
          asked.complete((sourceId, (await env.coverage(sourceId)).hasGuide));
          return await matched.future;
        }),
      );
      var answered = false;

      final imported = withMatching
          .importGuide(id)
          .whenComplete(() => answered = true);

      expect(await asked.future, (id, true));
      await pumpEventQueue();
      expect(answered, isFalse);
      expect(withMatching.isImporting(id), isTrue);
      matched.complete(const Ok(EpgMatchSummary(channels: 36)));
      expect((await imported).valueOrNull?.channels, 32);
    });

    test('a rematch that fails leaves the import succeeded, and the log '
        'says so', () async {
      final server = await _fakeProvider();
      final env = await _Env.open();
      final id = await env.add(_xtream(server.url));
      final withMatching = importer(
        env,
        service(
          env,
          (_, _) async => Err(StorageFailure('guide match: database is full')),
        ),
      );

      final result = await withMatching.importGuide(id);

      expect(result.isOk, isTrue, reason: '${result.failureOrNull}');
      final coverage = await env.coverage(id);
      expect(coverage.lastImport!.outcome, GuideImportOutcome.succeeded);
      expect(coverage.lastImport!.isLive, isTrue);
      expect(
        env.logLines.where(
          (l) => l.contains(
            'Guide import $id: the guide is in, but its '
            'channels were not matched to it (storage)',
          ),
        ),
        hasLength(1),
      );
    });

    test('a failed import matches nothing', () async {
      final server = await _fakeProvider();
      final env = await _Env.open();
      final id = await env.add(_xtream(server.url, password: 'wrong'));
      final asked = <String>[];
      final withMatching = importer(
        env,
        service(env, (sourceId, _) async {
          asked.add(sourceId);
          return const Ok(EpgMatchSummary(channels: 0));
        }),
      );

      final result = await withMatching.importGuide(id);

      expect(result.isOk, isFalse);
      expect(asked, isEmpty);
    });
  });
}
