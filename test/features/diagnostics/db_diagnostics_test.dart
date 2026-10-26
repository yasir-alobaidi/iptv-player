import 'dart:convert';
import 'dart:io';

import 'package:drift/drift.dart' show Value;
import 'package:flutter_test/flutter_test.dart';
import 'package:iptv_player/core/catalogue_kind.dart';
import 'package:iptv_player/core/logging/app_log.dart';
import 'package:iptv_player/core/logging/rotating_file_output.dart';
import 'package:iptv_player/core/logging/secret_registry.dart';
import 'package:iptv_player/core/platform/app_version.dart';
import 'package:iptv_player/core/platform/last_exits.dart';
import 'package:iptv_player/core/platform/run_logs.dart';
import 'package:iptv_player/core/platform/system_facts.dart';
import 'package:iptv_player/core/player/fake_player_engine.dart';
import 'package:iptv_player/core/player/player_engine.dart';
import 'package:iptv_player/data/db/app_database.dart';
import 'package:iptv_player/data/db/catalogue_tables.dart' show SyncOutcome;
import 'package:iptv_player/data/settings/settings_repository.dart';
import 'package:iptv_player/features/diagnostics/data/db_decoder_notes.dart';
import 'package:iptv_player/features/diagnostics/data/db_diagnostics.dart';
import 'package:iptv_player/features/diagnostics/data/file_log_reader.dart';
import 'package:iptv_player/features/diagnostics/domain/log_lines.dart';
import 'package:iptv_player/features/settings/data/db_settings_transfer.dart';
import 'package:iptv_player/features/sources/domain/source.dart';
import 'package:path/path.dart' as p;

/// Strings found nowhere else, so finding one anywhere is a leak (hard
/// rule 3).
const _host = 'tv.zq7northwind.test';
const _server = 'http://$_host:8080';
const _username = 'viewerQX19';
const _password = 'pw-J4vK9-secret';
const _name = 'Zq7 Northwind Premium';

final _now = DateTime.utc(2026, 10, 13, 12);

final class _Facts implements SystemFactsReader {
  const new();

  @override
  Future<SystemFacts> read() async => const SystemFacts(
    os: 'Ubuntu 22.04.5 LTS',
    session: 'Wayland',
    desktop: 'GNOME',
    graphics: [GraphicsCard(name: 'Intel UHD Graphics 630', driver: 'i915')],
  );
}

void main() {
  late AppDatabase db;
  late Directory folder;
  late SecretRegistry secrets;

  setUp(() {
    db = AppDatabase.memory();
    folder = Directory.systemTemp.createTempSync('diagnostics_');
    secrets = SecretRegistry();
  });
  tearDown(() async {
    await db.close();
    folder.deleteSync(recursive: true);
  });

  DbDiagnostics diagnostics({
    LogReader? log,
    PlayerEngine? player,
    LastExitsSource exits = const NoLastExits(),
    RunLogsSource runLogs = const NoRunLogs(),
  }) => DbDiagnostics(
    db: db,
    version: () async => const AppVersion(version: '0.1.0', build: '1'),
    system: const _Facts(),
    decoders: DbDecoderNotes(SettingsRepository(db), clock: () => _now),
    log: log ?? const NoLogReader(),
    secrets: secrets,
    player: player,
    castFolder: Directory(p.join(folder.path, 'cast')),
    exits: exits,
    runLogs: runLogs,
    homeFolder: '/home/mariam',
    clock: () => _now,
  );

  Future<void> source(
    String id, {
    SourceType type = SourceType.xtream,
    String name = _name,
    int order = 0,
    int? maxOverride,
  }) => db
      .into(db.sources)
      .insert(
        SourcesCompanion.insert(
          id: id,
          type: type,
          name: name,
          url: _server,
          username: const Value(_username),
          sortOrder: Value(order),
          maxConnectionsOverride: Value(maxOverride),
          accountJson: Value(
            jsonEncode({'status': 'Active', 'max_connections': 1}),
          ),
          createdAt: _now,
          updatedAt: _now,
        ),
      );

  test('with no source at all, and nothing ever played or cast', () async {
    final report = (await diagnostics().report()).valueOrNull!;

    expect(report.split('\n'), [
      'Bijou 0.1.0+1 · Ubuntu 22.04.5 LTS · Wayland · GNOME',
      'Graphics: Intel UHD Graphics 630 (i915)',
      'Player: not available',
      'Decoding: nothing played yet',
      'Casting: FFmpeg not looked at yet · encoders not looked for yet',
      'Sources: none',
      contains('buffering balanced · hardware decoding auto'),
      'Library: 0 folders · 0 items',
      'Downloads: 0 waiting or running · 0 finished',
      'Recent warnings and errors: none',
    ]);
  });

  test("a TV's last ends and how it draws come from its record of them "
      '(ADR-058)', () async {
    final report = (await diagnostics(
      exits: _Exits(
        LastExits(
          exits: [
            AppExit(
              time: _now.subtract(const Duration(minutes: 5)),
              reason: ExitReason.crashNative,
              importance: 100,
              thread: '1.raster',
              drawing: true,
            ),
          ],
          drawing: const DrawingBackend(skia: true),
        ),
      ),
    ).report()).valueOrNull!;

    expect(report, contains('(i915) · drawn with Skia on OpenGL ES'));
    expect(report, contains('Unexpected ends (1):'));
    expect(report, contains('thread 1.raster'));
  });

  test("the report a phone takes has each run's own log, asked at its "
      'size; the one on the screen never reads them (ADR-059)', () async {
    final runLogs = _RunLogs(
      const RunLogs(
        previous: ['I Bijou   : Key DPAD_LEFT down', 'F libc    : Fatal'],
      ),
    );
    final service = diagnostics(runLogs: runLogs);

    final shown = (await service.report()).valueOrNull!;
    expect(runLogs.reads, isEmpty);
    expect(shown, isNot(contains('The run before')));

    final shared = (await service.shareReport()).valueOrNull!;
    expect(runLogs.reads, [DbDiagnostics.runLogBytes]);
    expect(
      shared,
      endsWith(
        'The run before, as Android logged it (2 lines):\n'
        '  I Bijou   : Key DPAD_LEFT down\n'
        '  F libc    : Fatal\n'
        'This run so far: nothing kept',
      ),
    );
  });

  test('a source whose last sync failed, with a guide import that skipped '
      'rows, and one that synced with skipped rows', () async {
    await source('a');
    await source('b', type: SourceType.m3uUrl, order: 1, maxOverride: 2);
    for (var i = 0; i < 3; i++) {
      await db
          .into(db.channels)
          .insert(
            ChannelsCompanion.insert(sourceId: 'a', remoteKey: '$i', name: 'C'),
          );
    }
    await db
        .into(db.categories)
        .insert(
          CategoriesCompanion.insert(
            sourceId: 'a',
            remoteKey: '1',
            kind: CatalogueKind.live,
            name: 'Sport',
          ),
        );
    final failed = await db.syncRunsDao.start(
      'a',
      _now.subtract(const Duration(minutes: 30)),
    );
    await db.syncRunsDao.finish(
      failed,
      outcome: SyncOutcome.failed,
      at: _now.subtract(const Duration(minutes: 29)),
      failure: 'network',
      failureStatus: 503,
    );
    final import = await db.epgDao.startImport(
      'a',
      _now.subtract(const Duration(hours: 5)),
    );
    await db.epgDao.finishImport(
      import,
      outcome: SyncOutcome.succeeded,
      at: _now
          .subtract(const Duration(hours: 5))
          .add(const Duration(seconds: 40)),
      countsJson: jsonEncode({
        'channels': 2,
        'programmes': 10,
        'skipped': {'no_title': 7, 'bad_time': 5},
      }),
    );
    final synced = await db.syncRunsDao.start(
      'b',
      _now.subtract(const Duration(hours: 2)),
    );
    await db.syncRunsDao.finish(
      synced,
      outcome: SyncOutcome.succeeded,
      at: _now.subtract(const Duration(hours: 2)),
      countsJson: jsonEncode({
        'channels': 0,
        'skipped': 41,
        'duration_ms': 8700,
      }),
    );

    final report = (await diagnostics().report()).valueOrNull!;

    expect(
      report,
      allOf(
        contains(
          'Source 1: Xtream · Active · 1 connection · 3 channels · 0 movies '
          '· 0 series\n'
          '  last sync: failed 30 min ago: network HTTP 503\n'
          '  guide: 0 programmes, last import 5 h ago, 40 s, 12 rows skipped',
        ),
        contains(
          'Source 2: M3U URL · Active · 2 connections · 0 channels · 0 '
          'movies · 0 series\n'
          '  last sync: 2 h ago, 8 s, 41 rows skipped\n'
          '  guide: never imported',
        ),
      ),
    );
  });

  test('what decoded what, the player, the remembered encoders, the '
      'settings, the library and the downloads', () async {
    await DbDecoderNotes(SettingsRepository(db), clock: () => _now).note(
      const StreamInfo(
        height: 1080,
        videoCodec: 'H.264 / AVC / MPEG-4 AVC / MPEG-4 part 10',
        hardwareDecoder: 'vaapi',
      ),
    );
    Directory(p.join(folder.path, 'cast')).createSync();
    File(p.join(folder.path, 'cast', 'encoders.json')).writeAsStringSync(
      jsonEncode({
        'format': 1,
        'ffmpeg': 'ffmpeg version n8.1.2-22-g0123abc',
        'encoders': [
          {'kind': 'nvenc'},
          {'kind': 'vaapi'},
          {'kind': 'something new'},
          {'kind': 'x264'},
        ],
      }),
    );
    await db.settingsDao.write(
      SettingsKeys.playback,
      jsonEncode({
        'preset': 'stable',
        'hwdec': 'off',
        'audio': ['ar'],
      }),
    );
    await db.settingsDao.write(
      SettingsKeys.downloads,
      jsonEncode({'folder': '/home/mariam/Videos/IPTV Player', 'at_a_time': 2}),
    );

    final report = (await diagnostics(
      player: FakePlayerEngine(),
    ).report()).valueOrNull!;

    expect(report, contains('Decoding: H.264 1080p → vaapi'));
    expect(
      report,
      contains(
        'Casting: ffmpeg version n8.1.2-22-g0123abc · encoders h264_nvenc '
        '· h264_vaapi · libx264',
      ),
    );
    expect(report, contains('buffering stable · hardware decoding off'));
    expect(report, contains('downloads at a time 2'));
    // The fake player says no version; nothing is invented for it.
    expect(report, contains('Player: not available'));
    // No path, and so no user name, from the settings.
    expect(report, isNot(contains('mariam')));
    expect(report, isNot(contains('Videos')));
  });

  test('the last 50 warnings and errors of the log, oldest first, and no '
      'more', () async {
    final logs = Directory(p.join(folder.path, 'logs'))..createSync();
    final lines = <String>[];
    for (var i = 0; i < 70; i++) {
      final at = _now.add(Duration(seconds: i)).toIso8601String();
      lines
        ..add('$at INFO [playback] Opening channel $i')
        ..add('$at WARN [watchdog] Stalled, attempt $i');
    }
    File(p.join(logs.path, 'app.log'))
        .writeAsStringSync('${lines.join('\n')}\n');

    final report = (await diagnostics(
      log: FileLogReader(directory: logs),
    ).report()).valueOrNull!;

    final problems = report
        .split('\n')
        .skipWhile((line) => !line.startsWith('Recent warnings and errors'))
        .toList();
    expect(problems.first, 'Recent warnings and errors (50):');
    expect(problems, hasLength(51));
    expect(problems[1], endsWith('Stalled, attempt 20'));
    expect(problems.last, endsWith('Stalled, attempt 69'));
    expect(report, isNot(contains('Opening channel')));
  });

  test('the report can be saved to a file, whole, and a folder that isn’t '
      'there is a failure', () async {
    final path = p.join(folder.path, 'report.txt');

    final saved = await diagnostics().save(path, 'line one\nline two');

    expect(saved.isOk, isTrue);
    expect(File(path).readAsStringSync(), 'line one\nline two\n');
    expect(File('$path.part').existsSync(), isFalse);
    expect(
      (await diagnostics().save(p.join(folder.path, 'no', 'x.txt'), 'x')).isOk,
      isFalse,
    );
  });

  // Phase 9's exit: "Copy diagnostics contains no credentials", and the
  // plan's "nothing secret leaves the app" for the log viewer, the
  // report and an export file.
  test('hard rule 3: a source whose server, username and password are '
      'strings found nowhere else — none of them in the log the viewer '
      'reads, in the report, or in an export file', () async {
    await source('a');
    secrets.add(_password);
    final logs = Directory(p.join(folder.path, 'logs'))..createSync();
    final output = RotatingFileOutput(directory: logs);
    // What the app's own code logs when things go wrong: URLs that
    // carry the sign-in, in every shape they come in.
    final log = AppLog(output: output, secrets: secrets)
      ..warning(
        'player',
        'Failed to open $_server/live/$_username/$_password/147.ts',
      )
      ..error(
        'sync',
        'The sync failed',
        error: Exception(
          'GET $_server/player_api.php?username=$_username'
          '&password=$_password answered 503',
        ),
      )
      ..warning(
        'm3u',
        'Unreadable playlist http://$_username:$_password@$_host/get.php',
      )
      ..warning('odd', 'A panel echoed the password: $_password')
      ..warning('guide', "$_name's guide at $_host:8080 gave nothing")
      ..warning('cast', 'Living Room TV at 192.168.1.155:8009 went quiet')
      ..warning('relay', 'http://127.0.0.1:38412/p/abc/stream.mp4 stalled');
    await log.close();

    final reader = FileLogReader(directory: logs);
    final viewer = [
      for (final row in (await reader.page(const LogQuery())).valueOrNull!.rows)
        row.raw,
    ].join('\n');
    final report = (await diagnostics(log: reader).report()).valueOrNull!;
    final exportPath = p.join(folder.path, 'export.json');
    await DbSettingsTransfer(db).exportTo(exportPath);
    final export = File(exportPath).readAsStringSync();

    for (final (what, text) in [
      ('the log viewer', viewer),
      ('the report', report),
      ('the export', export),
    ]) {
      expect(text, isNot(contains(_password)), reason: what);
      expect(text, isNot(contains(_username)), reason: what);
    }
    // The viewer shows the log as written, and the log names the server
    // its lines are about; the report and the export must not.
    for (final (what, text) in [
      ('the report', report),
      ('the export', export),
    ]) {
      expect(text, isNot(contains(_host)), reason: what);
      expect(text, isNot(contains('zq7northwind')), reason: what);
    }
    // The report doesn't say whose the source is, either.
    expect(report, isNot(contains(_name)));
    expect(report, contains('Source 1: Xtream'));
    // Nor where a device of the user's is.
    expect(report, isNot(contains('192.168.1.155')));
    // And the lines it was fed did arrive, readable, with what they must
    // not say replaced: this computer's own address stays.
    expect(viewer, contains('The sync failed'));
    expect(report, contains('Recent warnings and errors (8):'));
    expect(report, contains("Source 1's guide at <server>:8080 gave nothing"));
    expect(report, contains('Living Room TV at <address> went quiet'));
    expect(report, contains('http://127.0.0.1:38412/p/abc/stream.mp4 stalled'));
    expect(report, contains('GET http://<address>/player_api.php?username='));
  });
}

final class _RunLogs implements RunLogsSource {
  new(this._logs);

  final RunLogs _logs;
  final reads = <int>[];

  @override
  bool get available => true;

  @override
  Future<RunLogs?> read({int maxBytes = 0}) async {
    reads.add(maxBytes);
    return _logs;
  }
}

final class _Exits implements LastExitsSource {
  const new(this._last);

  final LastExits _last;

  @override
  bool get available => true;

  @override
  Future<LastExits?> read() async => _last;

  @override
  Future<void> seen(DateTime upTo) async {}
}
