import 'dart:async';
import 'dart:io';

import 'package:drift/drift.dart' show driftRuntimeOptions;
import 'package:drift/isolate.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:iptv_player/core/logging/app_log.dart';
import 'package:iptv_player/core/logging/secret_registry.dart';
import 'package:iptv_player/core/result.dart';
import 'package:iptv_player/core/secure/credential_store.dart';
import 'package:iptv_player/data/db/app_database.dart';
import 'package:iptv_player/data/providers/xmltv/xmltv_parser.dart';
import 'package:iptv_player/data/providers/xmltv/xmltv_reader.dart';
import 'package:iptv_player/data/sync/epg_import_work.dart';
import 'package:iptv_player/features/guide/domain/epg.dart';
import 'package:iptv_player/features/sources/data/db_source_repository.dart';
import 'package:iptv_player/features/sources/domain/source.dart';
import 'package:logger/logger.dart';

const _token = 'Tk9c2e81d4f00b';

/// The hour the guides below are built around.
final _now = DateTime.utc(2026, 9, 22, 12);

String _stamp(DateTime t) {
  String p(int v, [int w = 2]) => '$v'.padLeft(w, '0');
  final u = t.toUtc();
  return '${p(u.year, 4)}${p(u.month)}${p(u.day)}'
      '${p(u.hour)}${p(u.minute)}${p(u.second)} +0000';
}

/// [channels] channels with [perChannel] half-hour programmes each,
/// starting [from] before [_now].
String _guide({
  int channels = 2,
  int perChannel = 60,
  Duration from = const Duration(hours: 6),
  String extra = '',
  bool closed = true,
}) {
  final buffer = StringBuffer('<?xml version="1.0" encoding="UTF-8"?>\n<tv>\n');
  for (var c = 0; c < channels; c++) {
    buffer.writeln(
      '<channel id="ch$c.uk"><display-name>Channel $c</display-name> '
      '</channel>',
    );
  }
  final first = _now.subtract(from);
  for (var c = 0; c < channels; c++) {
    for (var i = 0; i < perChannel; i++) {
      final start = first.add(Duration(minutes: 30 * i));
      buffer.writeln(
        '<programme start="${_stamp(start)}" '
        'stop="${_stamp(start.add(const Duration(minutes: 30)))}" '
        'channel="ch$c.uk"><title>Show $c.$i</title> '
        '<desc>Episode $i of channel $c</desc></programme>',
      );
    }
  }
  buffer.write(extra);
  if (closed) buffer.writeln('</tv>');
  return '$buffer';
}

final class _Env {
  new _(this.directory, this.db);

  static Future<_Env> open() async {
    final directory = await Directory.systemTemp.createTemp('epg_work');
    final db = AppDatabase(await openAppDatabase(directory));
    final env = _Env._(directory, db);
    addTearDown(env.close);
    // An import belongs to a source (a foreign key), so there is one.
    final secrets = SecretRegistry();
    final log = AppLog(output: MemoryOutput(), secrets: secrets);
    addTearDown(log.close);
    final added =
        await DbSourceRepository(
          database: db,
          store: InMemoryCredentialStore(),
          secrets: secrets,
          log: log,
        ).add(
          SourceDraft(
            type: SourceType.m3uFile,
            name: 'Playlist',
            url: '${directory.path}/list.m3u',
          ),
        );
    env.sourceId = added.valueOrNull!.id;
    env.importRun = await db.epgDao.startImport(env.sourceId, _now);
    return env;
  }

  final Directory directory;
  final AppDatabase db;
  late final String sourceId;
  late final int importRun;
  final progress = <EpgImportProgress>[];

  String file(String name, List<int> bytes) {
    final file = File('${directory.path}/$name')..writeAsBytesSync(bytes);
    return file.path;
  }

  Future<EpgImportWork> work(
    XmltvInput input, {
    int batchSize = 25,
    int offsetMinutes = 0,
    int? importRun,
    Duration window = const Duration(days: 1),
  }) async => EpgImportWork(
    sourceId: sourceId,
    importRun: importRun ?? this.importRun,
    connection: await db.serializableConnection(),
    input: input,
    windowStartMs: _now.subtract(window).millisecondsSinceEpoch,
    windowEndMs: _now.add(window).millisecondsSinceEpoch,
    offsetMinutes: offsetMinutes,
    batchSize: batchSize,
    idleTimeout: const Duration(milliseconds: 500),
  );

  Future<Result<EpgImportWorkResult>> run(EpgImportWork work) =>
      runEpgImportWork(work, progress.add);

  Future<int> count(String table) async {
    final row = await db
        .customSelect('SELECT COUNT(*) AS n FROM $table')
        .getSingle();
    return row.read<int>('n');
  }

  Future<List<(String, int, int, String)>> staged() async {
    final rows = await db
        .customSelect(
          'SELECT epg_channel_id, start_utc, end_utc, title '
          'FROM epg_programs_staging ORDER BY epg_channel_id, start_utc',
        )
        .get();
    return [
      for (final row in rows)
        (
          row.read<String>('epg_channel_id'),
          row.read<int>('start_utc'),
          row.read<int>('end_utc'),
          row.read<String>('title'),
        ),
    ];
  }

  Future<void> close() async {
    await db.close();
    await directory.delete(recursive: true);
  }
}

/// A server that answers every request with [handle].
Future<String> _serve(
  Future<void> Function(HttpResponse r) handle, {
  String path = '/guide.xml',
}) async {
  final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
  addTearDown(() => server.close(force: true));
  server.listen((request) => unawaited(handle(request.response)));
  return 'http://127.0.0.1:${server.port}$path';
}

void main() {
  // The Flutter test binding fakes HttpClient with 400s; this needs sockets.
  setUpAll(() => HttpOverrides.global = null);
  // The isolate's body runs here, in the test's isolate, so its database
  // (connected through the DriftIsolate, as in the app) sits beside the
  // test's own.
  driftRuntimeOptions.dontWarnAboutMultipleDatabases = true;

  group('before a byte is parsed', () {
    test('a missing file is not found, and nothing is staged', () async {
      final env = await _Env.open();

      final result = await env.run(
        await env.work(XmltvFileInput('${env.directory.path}/nope.xml')),
      );

      expect(result.failureOrNull, isA<NotFoundFailure>());
      expect(await env.count('epg_programs_staging'), 0);
    });

    test('a 404 is not found, and the URL is in no failure', () async {
      final env = await _Env.open();
      final url = await _serve((r) {
        r.statusCode = 404;
        return r.close();
      }, path: '/epg/$_token/guide.xml');

      final result = await env.run(await env.work(XmltvUrlInput(url)));

      expect(result.failureOrNull, isA<NotFoundFailure>());
      expect(result.failureOrNull!.statusCode, 404);
      expect('${result.failureOrNull}', isNot(contains(_token)));
    });

    test('the work prints no secret', () async {
      final env = await _Env.open();
      final work = await env.work(
        const XmltvUrlInput('http://epg.test/epg/$_token/g.xml?password=x1y2'),
      );

      expect('$work', isNot(contains(_token)));
      expect('$work', isNot(contains('x1y2')));
    });
  });

  group('staging', () {
    test('writes whole batches, reports after each, and never touches the '
        'live guide', () async {
      final env = await _Env.open();
      final path = env.file('guide.xml', _guide().codeUnits);

      final result = await env.run(
        await env.work(XmltvFileInput(path), window: const Duration(days: 2)),
      );

      final work = result.valueOrNull;
      expect(work, isNotNull, reason: '${result.failureOrNull}');
      expect(work!.channels, 2);
      expect(work.programmes, 120);
      expect(work.outsideWindow, 0);
      expect(work.skipped, isEmpty);
      expect(work.truncated, isFalse);
      expect(await env.count('epg_programs_staging'), 120);
      expect(await env.count('epg_channels_staging'), 2);
      expect(await env.count('epg_programs'), 0);
      expect(await env.count('epg_channels'), 0);
      // Staged programmes move by whole batches, the last one excepted.
      final counts = [for (final p in env.progress) p.programmes];
      expect(counts.last, 120);
      for (final n in counts.where((n) => n != 120)) {
        expect(n % 25, 0, reason: '$counts');
      }
      expect(counts, containsAll([25, 50, 75, 100]));
      for (var i = 1; i < counts.length; i++) {
        expect(counts[i], greaterThanOrEqualTo(counts[i - 1]));
      }
      final last = env.progress.last;
      expect(last.totalBytes, _guide().length);
      expect(last.bytesRead, _guide().length);
      // The import is still the importer's to finish.
      final row = await env.db.epgDao.latestImport(env.sourceId);
      expect(row!.isLive, isFalse);
    });

    test('keeps only the window: the rest is counted, not staged', () async {
      final env = await _Env.open();
      // 24 hours from 6 hours back; the window is ±2 hours.
      final path = env.file('guide.xml', _guide(perChannel: 48).codeUnits);

      final result = await env.run(
        await env.work(XmltvFileInput(path), window: const Duration(hours: 2)),
      );

      final work = result.valueOrNull!;
      // Eight half-hours on each side of now, per channel.
      expect(work.programmes, 2 * 8);
      expect(work.outsideWindow, 2 * 48 - 2 * 8);
      for (final (_, start, end, _) in await env.staged()) {
        expect(end, greaterThan(_now.millisecondsSinceEpoch - 7200000));
        expect(start, lessThan(_now.millisecondsSinceEpoch + 7200000));
      }
    });

    test("the source's offset moves every time", () async {
      final env = await _Env.open();
      final path = env.file('guide.xml', _guide(channels: 1).codeUnits);

      final result = await env.run(
        await env.work(
          XmltvFileInput(path),
          offsetMinutes: -90,
          window: const Duration(days: 2),
        ),
      );

      expect(result.isOk, isTrue);
      final staged = await env.staged();
      final first = _now.subtract(const Duration(hours: 6, minutes: 90));
      expect(staged.first.$2, first.millisecondsSinceEpoch);
      expect(staged.first.$3 - staged.first.$2, 30 * 60000);
      expect(staged.first.$4, 'Show 0.0');
    });

    test('a gzipped file is found by its bytes and counted as it '
        'lies on disk', () async {
      final env = await _Env.open();
      final packed = gzip.encode(_guide().codeUnits);
      final path = env.file('guide.xml.gz', packed);

      final result = await env.run(
        await env.work(XmltvFileInput(path), window: const Duration(days: 2)),
      );

      expect(result.valueOrNull?.programmes, 120);
      expect(env.progress.last.totalBytes, packed.length);
      expect(env.progress.last.bytesRead, packed.length);
    });

    test('a guide cut off mid-file keeps what it read', () async {
      final env = await _Env.open();
      final path = env.file(
        'guide.xml',
        _guide(extra: '<programme start="2026', closed: false).codeUnits,
      );

      final result = await env.run(
        await env.work(XmltvFileInput(path), window: const Duration(days: 2)),
      );

      expect(result.valueOrNull?.truncated, isTrue);
      expect(result.valueOrNull?.programmes, 120);
    });

    test('a guide with no programmes fails, and stages none', () async {
      final env = await _Env.open();
      for (final (name, text) in [
        ('empty.xml', '<?xml version="1.0"?>\n<tv></tv>\n'),
        ('channels.xml', _guide(perChannel: 0)),
        // Everything a week ago: nothing in the window.
        ('stale.xml', _guide(from: const Duration(days: 7))),
      ]) {
        final result = await env.run(
          await env.work(XmltvFileInput(env.file(name, text.codeUnits))),
        );

        expect(result.failureOrNull, isA<ParseFailure>(), reason: name);
        expect(await env.count('epg_programs_staging'), 0, reason: name);
      }
    });

    test('a body that is not XMLTV is a parse failure', () async {
      final env = await _Env.open();
      final url = await _serve(
        (r) =>
            (r..write('<html><body>Service unavailable</body></html>')).close(),
      );

      final result = await env.run(await env.work(XmltvUrlInput(url)));

      expect(result.failureOrNull, isA<ParseFailure>());
    });

    test('a damaged gzip body is a parse failure', () async {
      final env = await _Env.open();
      final packed = gzip.encode(_guide().codeUnits);
      final path = env.file('guide.xml.gz', [
        ...packed.take(40),
        ...List.filled(400, 7),
      ]);

      final result = await env.run(await env.work(XmltvFileInput(path)));

      expect(result.failureOrNull, isA<ParseFailure>());
    });

    test('a server that stalls mid-guide times out', () async {
      final env = await _Env.open();
      final text = _guide();
      final url = await _serve((r) async {
        r.write(text.substring(0, text.length ~/ 2));
        await r.flush();
        // …and nothing more.
      });

      final result = await env.run(await env.work(XmltvUrlInput(url)));

      expect(result.failureOrNull, isA<TimeoutFailure>());
    });

    test('a write that fails is a storage failure', () async {
      final env = await _Env.open();
      final path = env.file('guide.xml', _guide().codeUnits);

      // An import that doesn't exist: the staged rows' foreign key fails.
      final result = await env.run(
        await env.work(
          XmltvFileInput(path),
          importRun: 999,
          window: const Duration(days: 2),
        ),
      );

      expect(result.failureOrNull, isA<StorageFailure>());
    });

    test("warnings hold no part of the guide's URL", () async {
      final env = await _Env.open();
      // A bad row whose channel id happens to be the URL's token.
      final text = _guide(
        extra:
            '<programme start="whenever" channel="$_token"> '
            '<title>X</title></programme>\n',
      );
      final url = await _serve(
        (r) => (r..write(text)).close(),
        path: '/epg/$_token/guide.xml',
      );

      final result = await env.run(
        await env.work(XmltvUrlInput(url), window: const Duration(days: 2)),
      );

      final work = result.valueOrNull!;
      expect(work.skipped[XmltvSkip.badDate], 1);
      expect(work.warnings, isNotEmpty);
      for (final warning in work.warnings) {
        expect(warning, isNot(contains(_token)));
      }
    });

    test('runs in its own isolate', () async {
      final env = await _Env.open();
      final path = env.file('guide.xml', _guide().codeUnits);
      final work = await env.work(
        XmltvFileInput(path),
        window: const Duration(days: 2),
      );

      final job = startEpgImportJob(work, timeout: const Duration(minutes: 1));
      final events = <EpgImportProgress>[];
      job.progress.listen(events.add);
      final result = await job.result;

      expect(result.valueOrNull?.valueOrNull?.programmes, 120);
      expect(events, isNotEmpty);
      expect(events.last.programmes, 120);
      expect(await env.count('epg_programs_staging'), 120);
    });
  });
}
