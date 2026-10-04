// fakeAsync drives these futures by elapsing time, not by awaiting them.
// ignore_for_file: discarded_futures

import 'package:fake_async/fake_async.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:iptv_player/core/library/library_item.dart';
import 'package:iptv_player/features/playback/domain/playable.dart';
import 'package:iptv_player/features/playback/domain/playback_state.dart';
import 'package:iptv_player/features/playback/domain/source_connections.dart';
import 'package:iptv_player/features/vod/domain/watch_progress.dart';

import 'support/playback_fakes.dart';

/// Phase 8 decision 8: library files and downloads on the one
/// coordinator — no connection, no reconnects, history by quick hash.
void main() {
  const length = Duration(minutes: 42);

  LibraryItem file({
    int id = 7,
    LibraryKind kind = LibraryKind.movie,
    List<ExternalSubtitle> subtitles = const [],
  }) => LibraryItem(
    id: id,
    folderId: 1,
    relPath: 'Paper Kites (2019).mkv',
    sizeBytes: 1,
    modifiedAt: DateTime.utc(2026),
    quickHash: 'hash-$id',
    kind: kind,
    title: 'Paper Kites',
    year: 2019,
    addedAt: DateTime.utc(2026),
    duration: length,
    path: '/media/films/Paper Kites (2019).mkv',
    subtitles: subtitles,
  );

  Rig playingFile(FakeAsync async, LibraryItem item, {Duration? from}) {
    final rig = Rig();
    rig.coordinator.playVod(PlayableLibraryItem(item), from: from);
    async.flushMicrotasks();
    rig.engine
      ..duration(length)
      ..firstFrame();
    return rig;
  }

  test('a file of your own plays from its path, with its subtitles, and '
      'holds no connection', () {
    fakeAsync((async) {
      final item = file(
        subtitles: const [
          ExternalSubtitle(
            fileName: 'Paper Kites (2019).en.srt',
            format: 'srt',
          ),
        ],
      );
      final rig = playingFile(async, item, from: const Duration(minutes: 3));
      final request = rig.engine.opened.single;
      expect(request.url, '/media/films/Paper Kites (2019).mkv');
      expect(request.live, isFalse);
      expect(request.start, const Duration(minutes: 3));
      expect(request.subtitleFiles, ['/library/Paper Kites (2019).en.srt']);
      expect(rig.state, isA<PlaybackPlaying>());
      expect(rig.coordinator.connections.held(''), 0);
      expect(rig.resolver.resolvedFiles, ['hash-7']);
      rig.coordinator.stop();
      async.flushMicrotasks();
      expect(rig.progress.saves.last.ref, const LocalRef('hash-7'));
    });
  });

  test('a downloaded movie plays from its file: its source loses its '
      "connection, and progress stays the title's", () {
    fakeAsync((async) {
      final rig = Rig();
      // A channel of the same source first, on its one connection.
      rig.coordinator.playLive(channel(1));
      async.flushMicrotasks();
      rig.engine.firstFrame();
      expect(rig.coordinator.connections.held('src'), 1);

      rig.resolver.downloads['m1'] = '/v/Movies/A (2020)/A (2020).mkv';
      rig.coordinator.playVod(PlayableMovie(movie(1)));
      async.flushMicrotasks();
      rig.engine
        ..duration(length)
        ..firstFrame();
      expect(rig.engine.opened.last.url, '/v/Movies/A (2020)/A (2020).mkv');
      expect(rig.coordinator.connections.held('src'), 0);
      expect(
        rig.coordinator.connections.held('src', except: StreamHolder.player),
        0,
      );
      rig.coordinator.stop();
      async.flushMicrotasks();
      expect(rig.progress.saves.last.ref, PlayableMovie(movie(1)).vodRef);
    });
  });

  test('trouble with a file on this computer fails at once: missing or '
      'damaged, no reconnecting', () {
    fakeAsync((async) {
      final rig = playingFile(async, file());
      rig.engine.fail('Failed to read');
      async.flushMicrotasks();
      final failed = rig.state as PlaybackFailed;
      expect(failed.problem.kind, PlaybackProblemKind.fileUnreadable);
      expect(rig.states.whereType<PlaybackReconnecting>(), isEmpty);
      expect(rig.prober.details, isEmpty, reason: 'no provider to ask');

      // A stall, too.
      final stalled = playingFile(async, file());
      async.elapse(const Duration(seconds: 30));
      expect(
        (stalled.state as PlaybackFailed).problem.kind,
        PlaybackProblemKind.fileUnreadable,
      );
    });
  });

  test("a file that isn't there fails before it opens", () {
    fakeAsync((async) {
      final rig = Rig();
      rig.resolver.missingFiles.add(9);
      rig.coordinator.playVod(PlayableLibraryItem(file(id: 9)));
      async.flushMicrotasks();
      final failed = rig.state as PlaybackFailed;
      expect(failed.problem.kind, PlaybackProblemKind.fileUnreadable);
      expect(rig.engine.opened, isEmpty);
    });
  });

  test('a file that ends early has ended: nothing to reconnect to', () {
    fakeAsync((async) {
      final rig = playingFile(async, file());
      rig.engine.progress(const Duration(minutes: 10));
      async.elapse(const Duration(seconds: 1));
      rig.engine.end();
      async.flushMicrotasks();
      expect(rig.state, isA<PlaybackEnded>());
    });
  });
}
