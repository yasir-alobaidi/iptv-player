import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:iptv_player/data/providers/xmltv/xmltv_parser.dart';

/// The docs/02 "files can be 100–500 MB" case. The default test streams a
/// guide of over 100 MB, generated as it is read (nothing on disk, nothing
/// held), and checks that the parser's memory does not grow with it. The
/// `benchmark` test (skipped unless asked for) writes the docs/06 300 MB
/// guide to disk once and measures the parse.
void main() {
  test('a guide of over 100 MB is read in bounded memory', () async {
    final guide = _Guide(channels: 2000, programmesPerChannel: 160);
    final window = XmltvWindow(
      startMs: _base + 24 * _hourMs,
      endMs: _base + 48 * _hourMs,
    );
    var channels = 0;
    var programmes = 0;

    final before = ProcessInfo.currentRss;
    final summary = await parseXmltv(
      guide.bytes(),
      onChannel: (_) => channels++,
      onProgramme: (_) => programmes++,
      window: window,
    );
    final growth = ProcessInfo.maxRss - before;

    expect(guide.written, greaterThan(100 * _mb));
    expect(channels, 2000);
    expect(summary.channels, 2000);
    // Slots 48 to 95 of each channel overlap the second day.
    expect(programmes, 2000 * 48);
    expect(summary.programmes, programmes);
    expect(summary.outsideWindow, 2000 * (160 - 48));
    expect(summary.skipped, isEmpty);
    expect(summary.truncated, isFalse);
    // The parser holds a chunk, a carried token (at most 64 KiB), the
    // field caps and one pending programme per channel: well under a
    // megabyte of its own. What RSS shows beyond that is the VM's heap
    // breathing with the strings each row allocates. Reading the body
    // whole would add all of it (over 100 MB), and a DOM several times
    // that, so 64 MB tells the two apart with room to spare.
    expect(
      growth,
      lessThan(64 * _mb),
      reason: 'max RSS grew ${growth ~/ _mb} MB over the parse',
    );
    // The measurement, for docs/progress.md.
    // ignore: avoid_print
    print(
      'XMLTV ${guide.written ~/ _mb} MB streamed: max RSS '
      '+${growth ~/ _mb} MB',
    );
  }, timeout: const Timeout(Duration(minutes: 2)));

  test(
    'benchmark: the 300 MB guide, from disk',
    () async {
      final directory = await Directory.systemTemp.createTemp('xmltv_large');
      addTearDown(() => directory.delete(recursive: true));
      final file = File('${directory.path}/guide.xml');
      // docs/06's 300 MB guide: a week ahead and the day of history a
      // panel writes, in 30-minute slots. This generator's programmes are
      // a little smaller than the fake provider's (ADR-011 measured 2,150
      // channels for 300 MB there), so it takes more channels.
      final guide = _Guide(channels: 2400, programmesPerChannel: 8 * 48);
      await guide.bytes().pipe(file.openWrite());

      final now = _base + 24 * _hourMs;
      final window = XmltvWindow.around(
        DateTime.fromMillisecondsSinceEpoch(now, isUtc: true),
      );
      var last = DateTime.now();
      var worst = Duration.zero;
      final ticker = Timer.periodic(const Duration(milliseconds: 16), (_) {
        final now = DateTime.now();
        if (now.difference(last) > worst) worst = now.difference(last);
        last = now;
      });
      final before = ProcessInfo.currentRss;
      final clock = Stopwatch()..start();
      var programmes = 0;
      final summary = await parseXmltv(
        file.openRead(),
        onChannel: (_) {},
        onProgramme: (_) => programmes++,
        window: window,
      );
      final seconds = clock.elapsedMicroseconds / 1e6;
      ticker.cancel();

      expect(summary.programmes, programmes);
      expect(summary.skipped, isEmpty);
      final megabytes = guide.written / _mb;
      // The benchmark's output is its result, read by whoever runs it.
      // ignore: avoid_print
      print(
        'XMLTV ${megabytes.toStringAsFixed(0)} MB, '
        '${summary.channels} channels, $programmes programmes kept, '
        '${summary.outsideWindow} outside the window: '
        '${seconds.toStringAsFixed(2)} s = '
        '${(megabytes / seconds).toStringAsFixed(0)} MB/s on the test '
        'isolate (worst gap ${worst.inMilliseconds} ms, which is why the '
        'import runs in its own); max RSS ${ProcessInfo.maxRss ~/ _mb} MB, '
        '+${(ProcessInfo.maxRss - before) ~/ _mb} MB over the parse',
      );
    },
    tags: ['benchmark'],
    timeout: const Timeout(Duration(minutes: 5)),
  );
}

const int _mb = 1024 * 1024;
const int _hourMs = Duration.millisecondsPerHour;

/// Midnight UTC on the day the guide starts.
final int _base = DateTime.utc(2026, 9, 14).millisecondsSinceEpoch;

/// A guide in the shape the fake provider (and a panel) writes: every
/// channel, then every channel's programmes in 30-minute slots from
/// [_base]. Generated as it is read, 64 KB at a time.
final class _Guide {
  new({required this.channels, required this.programmesPerChannel});

  final int channels;
  final int programmesPerChannel;

  /// Bytes generated so far.
  int written = 0;

  static const _categories = [
    'Sports',
    'Movie',
    'News',
    'Documentary',
    'Series',
    'Music',
    'Children',
  ];

  Stream<List<int>> bytes() async* {
    // Every slot's time, written once rather than once per programme.
    String two(int value) => value.toString().padLeft(2, '0');
    final stamps = [
      for (var i = 0; i <= programmesPerChannel; i++)
        () {
          final t = DateTime.fromMillisecondsSinceEpoch(
            _base + i * _hourMs ~/ 2,
            isUtc: true,
          );
          return '${t.year}${two(t.month)}${two(t.day)}'
              '${two(t.hour)}${two(t.minute)}00 +0000';
        }(),
    ];
    final buffer = StringBuffer()
      ..writeln('<?xml version="1.0" encoding="UTF-8"?>')
      ..writeln('<tv generator-info-name="xmltv_large_test">');
    List<int> take() {
      final bytes = utf8.encode(buffer.toString());
      buffer.clear();
      written += bytes.length;
      return bytes;
    }

    for (var c = 0; c < channels; c++) {
      buffer
        ..writeln('  <channel id="ch$c.uk">')
        ..writeln(
          '    <display-name lang="en">UK: Channel $c HD</display-name>',
        )
        ..writeln('    <icon src="http://logos.test/$c.png" />')
        ..writeln('  </channel>');
      if (buffer.length > 64 * 1024) yield take();
    }
    var index = 0;
    for (var c = 0; c < channels; c++) {
      for (var i = 0; i < programmesPerChannel; i++, index++) {
        buffer
          ..writeln(
            '  <programme start="${stamps[i]}" stop="${stamps[i + 1]}" '
            'channel="ch$c.uk">',
          )
          ..writeln(
            '    <title lang="en">Programme $index on channel $c</title>',
          );
        if (index % 5 == 0) {
          buffer.writeln(
            '    <sub-title lang="en">Part ${1 + index % 9}</sub-title>',
          );
        }
        buffer
          ..writeln(
            '    <desc lang="en">Programme $index: who is in it, what '
            'happens, and why you might watch &amp; stay.</desc>',
          )
          ..writeln(
            '    <category lang="en">${_categories[index % 7]}</category>',
          );
        if (index % 4 == 1) {
          final episode = 'S${1 + index % 6}E${1 + index % 24}';
          buffer.writeln(
            '    <episode-num system="onscreen">$episode</episode-num>',
          );
        }
        buffer.writeln('  </programme>');
        if (buffer.length > 64 * 1024) yield take();
      }
    }
    buffer.writeln('</tv>');
    yield take();
  }
}
