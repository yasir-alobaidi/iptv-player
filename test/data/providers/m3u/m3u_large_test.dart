import 'dart:async';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:iptv_player/data/providers/m3u/m3u_reader.dart';

/// The docs/02 "files can exceed 50 MB" case: a generated playlist of just
/// over 50 MB, too big to commit, written once for the group. CI checks
/// that it is read whole and correctly in a background isolate; the
/// `benchmark` test (skipped unless asked for) measures time, UI-isolate
/// gaps and memory.
void main() {
  late Directory directory;
  late File playlist;
  late int written;

  setUpAll(() async {
    directory = await Directory.systemTemp.createTemp('m3u_large');
    playlist = File('${directory.path}/large.m3u');
    written = await _writePlaylist(playlist, minBytes: 50 * 1024 * 1024);
  });
  tearDownAll(() => directory.delete(recursive: true));

  test('a 50 MB playlist is read whole in a background isolate', () async {
    final read = readM3uInBackground(M3uFileInput(playlist.path));
    var received = 0;
    final identities = <String>{};
    await for (final batch in read.batches) {
      received += batch.length;
      identities.addAll(batch.map((e) => e.identity));
    }
    final summary = (await read.result).valueOrNull!;

    expect(summary.entries, written);
    expect(summary.skipped, 0);
    expect(received, written);
    expect(identities, hasLength(written));
    // Entries 0, 10, 20 … are movies.
    expect(summary.movies, (written + 9) ~/ 10);
  }, timeout: const Timeout(Duration(minutes: 3)));

  test(
    'benchmark: time, UI-isolate gaps and memory',
    () async {
      var last = DateTime.now();
      var worst = Duration.zero;
      final ticker = Timer.periodic(const Duration(milliseconds: 16), (_) {
        final now = DateTime.now();
        if (now.difference(last) > worst) worst = now.difference(last);
        last = now;
      });
      final clock = Stopwatch()..start();
      final read = readM3uInBackground(M3uFileInput(playlist.path));
      await read.batches.drain<void>();
      final summary = (await read.result).valueOrNull!;
      ticker.cancel();

      final megabytes = await playlist.length() ~/ (1024 * 1024);
      // The benchmark's output is its result, read by whoever runs it.
      // ignore: avoid_print
      print(
        'M3U $megabytes MB, ${summary.entries} entries: '
        '${clock.elapsedMilliseconds} ms in the background; worst UI-isolate '
        'gap ${worst.inMilliseconds} ms; max RSS '
        '${ProcessInfo.maxRss ~/ (1024 * 1024)} MB',
      );
    },
    tags: ['benchmark'],
    timeout: const Timeout(Duration(minutes: 3)),
  );
}

/// Xtream-export-shaped lines (every 10th a movie, every 10th an episode)
/// until the file passes [minBytes]. Returns how many entries it wrote.
Future<int> _writePlaylist(File file, {required int minBytes}) async {
  final sink = file.openWrite()
    ..write('#EXTM3U url-tvg="http://epg.test/guide.xml"\n');
  var bytes = 0;
  var count = 0;
  while (bytes < minBytes) {
    final kind = switch (count % 10) {
      0 => 'movie',
      1 => 'series',
      _ => 'live',
    };
    final name = kind == 'series'
        ? 'Show ${count ~/ 10} S0${count % 9 + 1} E${count % 20 + 1}'
        : 'UK: Channel number $count HD &amp; more';
    final entry =
        '#EXTINF:-1 tvg-id="ch$count.uk" tvg-name="$name" '
        'tvg-logo="http://logos.test/$count.png" '
        'group-title="Group ${count % 180}",$name\n'
        'http://panel.test:8080/$kind/viewer/Pw-7f3a9c1e/$count'
        '.${kind == 'live' ? 'ts' : 'mkv'}\n';
    sink.write(entry);
    bytes += entry.length;
    count++;
  }
  await sink.close();
  return count;
}
