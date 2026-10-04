import 'dart:async';
import 'dart:io';
import 'dart:typed_data';

import 'package:fake_provider/generator.dart';
import 'package:fake_provider/profile.dart';
import 'package:fake_provider/server.dart';
import 'package:fake_provider/server_state.dart';
import 'package:fake_provider/vod.dart' show fakePaddingByte;
import 'package:flutter_test/flutter_test.dart';
import 'package:iptv_player/core/downloads/download_runner.dart';
import 'package:iptv_player/data/downloads/http_download.dart';

/// Stand-in bytes for the panel's samples: the downloader parses nothing.
const int sampleSize = 600 * 1024;
final Uint8List sample = Uint8List.fromList(
  List<int>.generate(sampleSize, (i) => (i * 13 + 5) % 251),
);

const movie = '/movie/test/test/100000.mp4';

void main() {
  late Directory folder;
  late FakeProviderServer panel;

  setUpAll(() => HttpOverrides.global = null);

  setUp(() async {
    folder = Directory.systemTemp.createTempSync('http_download_');
    final samples = Directory('${folder.path}/samples')..createSync();
    for (final name in vodSamples) {
      File('${samples.path}/$name').writeAsBytesSync(sample);
    }
    panel = await FakeProviderServer.start(
      state: FakeServerState(
        profile: fakeProfiles['default']!.copyWith(maxConnections: 1),
        samplesDir: samples.path,
        ffmpegPath: 'ffmpeg',
        runDir: folder.path,
      ),
      port: 0,
    );
  });

  tearDown(() async {
    await panel.close();
    folder.deleteSync(recursive: true);
  });

  String part() => '${folder.path}/Movies/A (2020)/A (2020).mp4.part';

  /// One attempt, with what it said.
  Future<({List<DownloadNews> news, HttpDownloadOutcome outcome})> attempt(
    String path, {
    String? etag,
    String? lastModified,
    int? total,
    int? limit,
    DownloadTimings timings = const DownloadTimings(report: Duration.zero),
    void Function(HttpDownload download, DownloadNews news)? watch,
    String? url,
  }) async {
    final news = <DownloadNews>[];
    late HttpDownload download;
    download = HttpDownload(
      DownloadOrder(
        id: 7,
        sourceId: 'src',
        partPath: part(),
        etag: etag,
        lastModified: lastModified,
        total: total,
        bytesPerSecond: limit,
      ),
      () async => DownloadUpstream(
        url: url ?? panel.url.resolve(path).toString(),
        userAgent: 'IPTV Player test',
      ),
      (item) {
        news.add(item);
        watch?.call(download, item);
      },
      timings: timings,
    );
    final outcome = await download.run();
    return (news: news, outcome: outcome);
  }

  List<int> onDisk() => File(part()).readAsBytesSync();

  test('a whole file, straight into the .part, with its validators', () async {
    final run = await attempt(movie);
    expect(run.outcome, HttpDownloadOutcome.ended);
    final opened = run.news.whereType<DownloadOpened>().single;
    expect(opened.bytes, 0);
    expect(opened.total, sampleSize);
    expect(opened.etag, isNotNull);
    expect(opened.lastModified, isNotNull);
    expect(opened.restarted, isFalse);
    final done = run.news.last as DownloadDone;
    expect((done.bytes, done.total), (sampleSize, sampleSize));
    expect(onDisk(), sample);
    expect(run.news.whereType<DownloadMoved>(), isNotEmpty);
  });

  test('a body cut short is a network failure; the next attempt resumes with '
      'Range and If-Range and appends', () async {
    const cut = 200 * 1024;
    final first = await attempt('$movie?drop_after_bytes=$cut');
    final failed = first.news.last as DownloadFailedNews;
    expect(failed.end, DownloadEnd.network);
    expect(failed.bytes, cut);
    final opened = first.news.whereType<DownloadOpened>().single;

    final second = await attempt(movie, etag: opened.etag, total: opened.total);
    final resumed = second.news.whereType<DownloadOpened>().single;
    expect(resumed.bytes, cut);
    expect(resumed.restarted, isFalse);
    expect(resumed.total, sampleSize);
    expect(second.news.last, isA<DownloadDone>());
    expect(onDisk(), sample);

    // Last-Modified works as the validator too.
    File(part()).writeAsBytesSync(sample.sublist(0, cut));
    final third = await attempt(
      movie,
      lastModified: opened.lastModified,
      total: sampleSize,
    );
    expect(third.news.whereType<DownloadOpened>().single.restarted, isFalse);
    expect(onDisk(), sample);
  });

  test('a file that changed (If-Range fails) or a panel ignoring Range: '
      'the .part is emptied and it starts over', () async {
    for (final fault in ['change_etag=1', 'ignore_range=1']) {
      File(part())
        ..createSync(recursive: true)
        ..writeAsBytesSync(List.filled(1000, 9));
      final run = await attempt('$movie?$fault', etag: '"old"');
      final opened = run.news.whereType<DownloadOpened>().single;
      expect(opened.restarted, isTrue, reason: fault);
      expect(opened.bytes, 0, reason: fault);
      expect(run.news.last, isA<DownloadDone>(), reason: fault);
      expect(onDisk(), sample, reason: fault);
    }
  });

  test(
    'a .part already whole: the 416 ends it, with the size it names',
    () async {
      File(part())
        ..createSync(recursive: true)
        ..writeAsBytesSync(sample);
      final run = await attempt(movie, total: sampleSize);
      final done = run.news.single as DownloadDone;
      expect((done.bytes, done.total), (sampleSize, sampleSize));
      expect(onDisk(), sample);
    },
  );

  test('a Content-Length that lies: the short body fails, and the next '
      'attempt finds the file whole by the 416', () async {
    final first = await attempt('$movie?wrong_content_length=1');
    final failed = first.news.last as DownloadFailedNews;
    expect(failed.end, DownloadEnd.network);
    expect(failed.bytes, sampleSize);
    final opened = first.news.whereType<DownloadOpened>().single;
    expect(opened.total, sampleSize + 4096);

    final second = await attempt(
      '$movie?wrong_content_length=1',
      etag: opened.etag,
      total: opened.total,
    );
    final done = second.news.single as DownloadDone;
    expect(done.total, sampleSize, reason: "the 416's size is the truth");
    expect(onDisk(), sample);
  });

  test("the provider's refusals end it, each in its class", () async {
    for (final (fault, end) in [
      ('http_status=401', DownloadEnd.auth),
      // The fake panel's 403 names the connection limit.
      ('http_status=403', DownloadEnd.connectionLimit),
      ('http_status=404', DownloadEnd.notFound),
      ('http_status=429', DownloadEnd.connectionLimit),
      ('http_status=500', DownloadEnd.server),
      ('max_connections=0', DownloadEnd.connectionLimit),
    ]) {
      final run = await attempt('$movie?$fault');
      final failed = run.news.single as DownloadFailedNews;
      expect(failed.end, end, reason: fault);
      expect(failed.status, isNotNull, reason: fault);
    }
  });

  test('stopped mid-way: flushed, closed, and it says where', () async {
    final run = await attempt(
      '$movie?throttle_kbps=800',
      watch: (download, news) {
        if (news is DownloadMoved && news.bytes > 20 * 1024) {
          unawaited(download.stop());
        }
      },
    );
    final halted = run.news.last as DownloadHalted;
    expect(halted.bytes, greaterThan(20 * 1024));
    expect(halted.bytes, lessThan(sampleSize));
    expect(onDisk(), sample.sublist(0, halted.bytes));
    await Future<void>.delayed(const Duration(milliseconds: 100));
    expect(panel.state.activeStreams, 0, reason: 'the connection is let go');
  });

  test('the speed limit holds the pace', () async {
    final clock = Stopwatch()..start();
    // 400 KB/s for 600 KB: about 1.5 s.
    final run = await attempt(movie, limit: 400 * 1024);
    expect(run.news.last, isA<DownloadDone>());
    expect(clock.elapsed, greaterThan(const Duration(milliseconds: 1300)));
    expect(onDisk(), sample);
  });

  test(
    'a padded file (size_mb): progress all the way, every byte right',
    () async {
      final run = await attempt('$movie?size_mb=3');
      final done = run.news.last as DownloadDone;
      expect(done.bytes, 3 << 20);
      final bytes = onDisk();
      expect(bytes.sublist(0, sampleSize), sample);
      for (final at in [sampleSize, 2 << 20, (3 << 20) - 1]) {
        expect(bytes[at], fakePaddingByte(at), reason: '$at');
      }
    },
  );

  test(
    'forced to the disk every flushEvery bytes: what is durable says so',
    () async {
      final run = await attempt(
        '$movie?size_mb=20',
        timings: const DownloadTimings(
          report: Duration.zero,
          flushEvery: 8 << 20,
        ),
      );
      final durable = {
        for (final moved in run.news.whereType<DownloadMoved>()) moved.durable,
      };
      expect(durable, containsAll([0, greaterThanOrEqualTo(8 << 20)]));
      expect(run.news.last, isA<DownloadDone>());
    },
  );

  test('no URL: unresolved; no answer: network', () async {
    final news = <DownloadNews>[];
    final unresolved = HttpDownload(
      DownloadOrder(id: 1, sourceId: 's', partPath: part()),
      () async => null,
      news.add,
    );
    expect(await unresolved.run(), HttpDownloadOutcome.ended);
    expect((news.single as DownloadFailedNews).end, DownloadEnd.unresolved);

    final closed = await ServerSocket.bind(InternetAddress.loopbackIPv4, 0);
    final port = closed.port;
    await closed.close();
    final run = await attempt('/', url: 'http://127.0.0.1:$port/x.mp4');
    expect((run.news.single as DownloadFailedNews).end, DownloadEnd.network);
  });

  group('a scripted server', () {
    late HttpServer server;
    late Future<void> Function(HttpRequest request) answer;

    setUp(() async {
      server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0)
        ..listen((request) => answer(request));
    });
    tearDown(() => server.close(force: true));

    String url() => 'http://127.0.0.1:${server.port}/file.mkv';

    test('a 206 from the wrong place starts over without Range', () async {
      File(part())
        ..createSync(recursive: true)
        ..writeAsBytesSync(List.filled(100, 1));
      final ranges = <String?>[];
      answer = (request) async {
        final range = request.headers.value('range');
        ranges.add(range);
        final response = request.response;
        if (range != null) {
          response
            ..statusCode = 206
            ..headers.set('content-range', 'bytes 50-99/100')
            ..add(List.filled(50, 2));
        } else {
          response.add(List.filled(100, 3));
        }
        await response.close();
      };
      final run = await attempt('', url: url());
      expect(ranges, ['bytes=100-', null]);
      expect(run.news.last, isA<DownloadDone>());
      expect(onDisk(), List.filled(100, 3));
    });

    test('a playlist sent as octet-stream is still a playlist', () async {
      answer = (request) async {
        request.response
          ..headers.contentType = ContentType.binary
          ..write('#EXTM3U\n#EXT-X-VERSION:3\nseg0.ts\n');
        await request.response.close();
      };
      final run = await attempt('', url: url());
      expect(run.outcome, HttpDownloadOutcome.playlist);
      expect(run.news, isEmpty);
    });

    test('a server that goes quiet is a network failure after the idle '
        'wait', () async {
      answer = (request) async {
        request.response
          ..contentLength = 1 << 20
          ..add(List.filled(64 * 1024, 1));
        await request.response.flush();
        // Then nothing.
      };
      final run = await attempt(
        '',
        url: url(),
        timings: const DownloadTimings(idle: Duration(milliseconds: 300)),
      );
      final failed = run.news.last as DownloadFailedNews;
      expect(failed.end, DownloadEnd.network);
      expect(failed.bytes, greaterThan(0));
      expect(onDisk(), hasLength(failed.bytes));
    });

    test('a 403 about connections is the connection limit; other words, '
        'the account', () async {
      for (final (body, end) in [
        ('MAX_CONNECTIONS_REACHED', DownloadEnd.connectionLimit),
        ('Too many connections', DownloadEnd.connectionLimit),
        ('Your subscription has expired', DownloadEnd.auth),
      ]) {
        answer = (request) async {
          request.response
            ..statusCode = 403
            ..write(body);
          await request.response.close();
        };
        final run = await attempt('', url: url());
        final failed = run.news.single as DownloadFailedNews;
        expect(failed.end, end, reason: body);
        expect(failed.detail, body);
      }
    });

    test(
      "the User-Agent is the source's, and no credentials are logged",
      () async {
        String? agent;
        answer = (request) async {
          agent = request.headers.value('user-agent');
          request.response.statusCode = 500;
          await request.response.close();
        };
        final run = await attempt(
          '',
          url: 'http://127.0.0.1:${server.port}/movie/user/secretpass/1.mkv',
        );
        expect(agent, 'IPTV Player test');
        final failed = run.news.single as DownloadFailedNews;
        expect(failed.end, DownloadEnd.server);
        expect('${failed.detail}', isNot(contains('secretpass')));
      },
    );
  });
}
