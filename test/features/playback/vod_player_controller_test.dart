// fakeAsync drives these futures by elapsing time, not by awaiting them.
// ignore_for_file: discarded_futures

import 'package:fake_async/fake_async.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:iptv_player/core/library/library_item.dart';
import 'package:iptv_player/core/library/library_repository.dart';
import 'package:iptv_player/core/result.dart';
import 'package:iptv_player/features/playback/domain/playable.dart';
import 'package:iptv_player/features/playback/domain/playback_state.dart';
import 'package:iptv_player/features/playback/presentation/vod_player_controller.dart';
import 'package:iptv_player/features/vod/domain/catalogue.dart';
import 'package:iptv_player/features/vod/domain/titles.dart';
import 'package:iptv_player/features/vod/domain/watch_progress.dart';

import 'support/playback_fakes.dart';

/// A series of [episodes], in order: only what the player asks for.
final class _Episodes implements SeriesRepository {
  new(this.episodes);

  final List<EpisodeItem> episodes;

  @override
  Future<Result<EpisodeItem?>> episodeAfter(EpisodeItem episode) async {
    final i = episodes.indexWhere((e) => e.remoteKey == episode.remoteKey);
    return Ok(i < 0 || i + 1 >= episodes.length ? null : episodes[i + 1]);
  }

  @override
  Stream<int> watchCount(TitleQuery query) => throw UnimplementedError();

  @override
  Future<Result<List<SeriesItem>>> range(
    TitleQuery query,
    int offset,
    int limit,
  ) => throw UnimplementedError();

  @override
  Future<Result<SeriesItem?>> byRemoteKey(String sourceId, String key) =>
      throw UnimplementedError();

  @override
  Future<Result<void>> setFavorite(SeriesItem series, {required bool on}) =>
      throw UnimplementedError();

  @override
  Stream<Details<SeriesDetails>> details(SeriesItem series) =>
      throw UnimplementedError();
}

/// A show's files in the library, in order: only what the player asks
/// for.
final class _ShowFiles implements LibraryRepository {
  new(this.files);

  final List<LibraryItem> files;

  @override
  Future<LibraryItem?> episodeAfter(LibraryItem episode) async {
    final i = files.indexWhere((f) => f.id == episode.id);
    return i < 0 || i + 1 >= files.length ? null : files[i + 1];
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => throw UnimplementedError();
}

void main() {
  const length = Duration(minutes: 45);
  final e1 = episode(1, 1, duration: length);
  final e2 = episode(1, 2, duration: length);

  late Rig rig;
  late VodPlayerController vod;
  late List<Playable> finished;

  void start(
    FakeAsync async,
    Playable item, {
    Duration? from,
    Map<VodRef, WatchMark> marks = const {},
    LibraryRepository? library,
  }) {
    rig = Rig();
    rig.progress.marks.addAll(marks);
    finished = [];
    vod = VodPlayerController(
      coordinator: rig.coordinator,
      series: _Episodes([e1, e2]),
      progress: rig.progress,
      onFinished: finished.add,
      library: library,
    );
    rig.coordinator.playVod(item, from: from);
    async.flushMicrotasks();
    rig.engine
      ..duration(length)
      ..firstFrame();
    async.flushMicrotasks();
  }

  /// Plays from [from] seconds for [seconds], the position with the clock.
  void play(FakeAsync async, {required int from, required int seconds}) {
    for (var s = 1; s <= seconds; s++) {
      rig.engine.progress(Duration(seconds: from + s));
      async.elapse(const Duration(seconds: 1));
    }
  }

  List<String> seeks() => [
    for (final c in rig.engine.calls)
      if (c.startsWith('seek:')) c,
  ];

  group('seeking with the keys', () {
    test('the bar moves at once; one seek once the keys rest 300 ms', () {
      fakeAsync((async) {
        start(async, PlayableMovie(movie(1)));
        play(async, from: 0, seconds: 30);

        vod
          ..nudge(const Duration(seconds: 10))
          ..nudge(const Duration(seconds: 10));
        async.elapse(const Duration(milliseconds: 200));
        vod.nudge(const Duration(seconds: 60));
        expect(vod.pendingSeek, const Duration(seconds: 110));
        expect(vod.timeline.position, const Duration(seconds: 110));
        async.elapse(const Duration(milliseconds: 250));
        expect(seeks(), isEmpty);

        async.elapse(const Duration(milliseconds: 100));
        expect(seeks(), ['seek:110000']);
        expect(vod.pendingSeek, isNull);
        expect(vod.timeline.position, const Duration(seconds: 110));
      });
    });

    test('never before the start or past the end', () {
      fakeAsync((async) {
        start(async, PlayableMovie(movie(1)));
        play(async, from: 0, seconds: 5);
        vod.nudge(const Duration(seconds: -60));
        expect(vod.pendingSeek, Duration.zero);
        vod.nudge(const Duration(hours: 2));
        expect(vod.pendingSeek, length);
      });
    });

    test('a drag follows the mouse and seeks when let go', () {
      fakeAsync((async) {
        start(async, PlayableMovie(movie(1)));
        vod.dragTo(const Duration(minutes: 20));
        async.elapse(const Duration(seconds: 1));
        expect(seeks(), isEmpty);
        expect(vod.timeline.position, const Duration(minutes: 20));
        vod.dragTo(const Duration(minutes: 21), commit: true);
        async.flushMicrotasks();
        expect(seeks(), ['seek:1260000']);
      });
    });

    test('Space pauses and plays', () {
      fakeAsync((async) {
        start(async, PlayableMovie(movie(1)));
        vod.togglePause();
        async.flushMicrotasks();
        expect(vod.timeline.paused, isTrue);
        vod.togglePause();
        async.flushMicrotasks();
        expect(vod.timeline.paused, isFalse);
        expect(
          rig.engine.calls,
          containsAllInOrder(['paused:true', 'paused:false']),
        );
      });
    });
  });

  group('resumed', () {
    test('"Resumed from" shows for 5 s', () {
      fakeAsync((async) {
        start(
          async,
          PlayableMovie(movie(1)),
          from: const Duration(minutes: 24),
        );
        expect(vod.resumedFrom, const Duration(minutes: 24));
        async.elapse(const Duration(seconds: 5));
        expect(vod.resumedFrom, isNull);
      });
    });

    test('Home starts over and the line goes', () {
      fakeAsync((async) {
        start(
          async,
          PlayableMovie(movie(1)),
          from: const Duration(minutes: 24),
        );
        vod.startOver();
        async.flushMicrotasks();
        expect(vod.resumedFrom, isNull);
        expect(seeks(), ['seek:0']);
      });
    });

    test('nothing to say when it started from the beginning', () {
      fakeAsync((async) {
        start(async, PlayableMovie(movie(1)));
        expect(vod.resumedFrom, isNull);
      });
    });
  });

  group('the next episode', () {
    test('at 20 s left the card counts down from 10, then the next plays '
        'from its own resume point', () {
      fakeAsync((async) {
        start(
          async,
          PlayableEpisode(series, e1),
          marks: {
            e2.ref: WatchMark(
              position: const Duration(minutes: 3),
              updatedAt: DateTime.utc(2026),
              duration: length,
            ),
          },
        );
        async.flushMicrotasks();
        expect(vod.next?.item, PlayableEpisode(series, e2));

        final end = length.inSeconds;
        rig.coordinator.seek(length - const Duration(seconds: 30));
        async.flushMicrotasks();
        play(async, from: end - 30, seconds: 9);
        expect(vod.countdown, isNull);
        rig.engine.progress(Duration(seconds: end - 20));
        expect(vod.countdown, 10);
        async.elapse(const Duration(seconds: 1));
        expect(vod.countdown, 9);
        play(async, from: end - 20, seconds: 3);
        expect(vod.countdown, 6);
        play(async, from: end - 17, seconds: 6);

        expect(rig.state.item, PlayableEpisode(series, e2));
        expect(rig.engine.opened.last.start, const Duration(minutes: 3));
        expect(vod.countdown, isNull);
        expect(vod.item, PlayableEpisode(series, e2));
      });
    });

    test('Play now plays it at once', () {
      fakeAsync((async) {
        start(async, PlayableEpisode(series, e1));
        async.flushMicrotasks();
        vod.playNext();
        async.flushMicrotasks();
        expect(rig.state.item, PlayableEpisode(series, e2));
        expect(rig.engine.opened.last.start, isNull);
      });
    });

    test('the count leaves the episode saved as watched, at its end', () {
      fakeAsync((async) {
        start(async, PlayableEpisode(series, e1));
        async.flushMicrotasks();
        final end = length.inSeconds;
        rig.coordinator.seek(length - const Duration(seconds: 20));
        async.flushMicrotasks();
        play(async, from: end - 20, seconds: 10);

        expect(rig.state.item, PlayableEpisode(series, e2));
        final left = rig.progress.saves.lastWhere((s) => s.ref == e1.ref);
        expect(left.position, length);
        expect(isComplete(left.position, left.duration), isTrue);
      });
    });

    test('Play now in the credits saves the episode as watched too', () {
      fakeAsync((async) {
        start(async, PlayableEpisode(series, e1));
        async.flushMicrotasks();
        rig.coordinator.seek(length - const Duration(seconds: 20));
        async.flushMicrotasks();
        rig.progress.saves.clear();

        vod.playNext();
        async.flushMicrotasks();
        expect(rig.progress.saves.single, (
          ref: e1.ref,
          position: length,
          duration: length,
        ));
      });
    });

    test(
      'a pause holds the count; seeking back out of the credits stops it',
      () {
        fakeAsync((async) {
          start(async, PlayableEpisode(series, e1));
          async.flushMicrotasks();
          final end = length.inSeconds;
          rig.coordinator.seek(length - const Duration(seconds: 20));
          async.flushMicrotasks();
          expect(vod.countdown, 10);
          play(async, from: end - 20, seconds: 1);
          expect(vod.countdown, 9);

          vod.togglePause();
          async
            ..flushMicrotasks()
            ..elapse(const Duration(seconds: 30));
          expect(vod.countdown, 9);
          vod.togglePause();
          async.flushMicrotasks();

          rig.coordinator.seek(const Duration(minutes: 10));
          async.flushMicrotasks();
          expect(vod.countdown, isNull);
          expect(rig.state.item, PlayableEpisode(series, e1));
        });
      },
    );

    test('Esc cancels: the episode plays to its end, then the card again '
        'without the count', () {
      fakeAsync((async) {
        start(async, PlayableEpisode(series, e1));
        async.flushMicrotasks();
        final end = length.inSeconds;
        rig.coordinator.seek(length - const Duration(seconds: 15));
        async.flushMicrotasks();
        expect(vod.countdown, 10);

        vod.cancelNext();
        play(async, from: end - 14, seconds: 14);
        expect(vod.countdown, isNull);
        expect(rig.state.item, PlayableEpisode(series, e1));
        rig.engine.end();
        async.flushMicrotasks();

        expect(rig.state, isA<PlaybackEnded>());
        expect(vod.ended, isTrue);
        expect(finished, isEmpty);
        vod.playNext();
        async.flushMicrotasks();
        expect(rig.state.item, PlayableEpisode(series, e2));
        expect(vod.ended, isFalse);
      });
    });

    test('the last episode has no card and goes back to its series', () {
      fakeAsync((async) {
        start(async, PlayableEpisode(series, e2));
        async.flushMicrotasks();
        expect(vod.next, isNull);
        final end = length.inSeconds;
        rig.coordinator.seek(length - const Duration(seconds: 15));
        async.flushMicrotasks();
        play(async, from: end - 15, seconds: 15);
        expect(vod.countdown, isNull);
        rig.engine.end();
        async.flushMicrotasks();

        expect(finished, [PlayableEpisode(series, e2)]);
      });
    });

    test('an episode that ends before its card was answered goes on to the '
        'next', () {
      fakeAsync((async) {
        start(async, PlayableEpisode(series, e1));
        async.flushMicrotasks();
        rig.coordinator.seek(length);
        async.flushMicrotasks();
        rig.engine.end();
        async.flushMicrotasks();
        expect(rig.state.item, PlayableEpisode(series, e2));
      });
    });
  });

  test('a movie that ends goes back to its page', () {
    fakeAsync((async) {
      start(async, PlayableMovie(movie(1)));
      rig.coordinator.seek(length);
      async.flushMicrotasks();
      rig.engine.end();
      async.flushMicrotasks();
      expect(finished, [PlayableMovie(movie(1))]);
      expect(vod.next, isNull);
    });
  });

  group("the next file of the user's own show", () {
    LibraryItem file(int id, int episode, {LibraryKind? kind}) => LibraryItem(
      id: id,
      folderId: 1,
      relPath: 'Kettle Bay/Season 2/Kettle Bay - S02E0$episode.mkv',
      sizeBytes: 1,
      modifiedAt: DateTime.utc(2026),
      quickHash: 'hash-$id',
      kind: kind ?? LibraryKind.episode,
      title: 'Episode $episode',
      showTitle: 'Kettle Bay',
      season: 2,
      episode: episode,
      duration: length,
      addedAt: DateTime.utc(2026),
    );

    final f3 = file(3, 3);
    final f4 = file(4, 4);
    final show = _ShowFiles([f3, f4]);

    test('the card offers it, counts down, and plays it from its own '
        'place; the file left is saved as watched', () {
      fakeAsync((async) {
        start(
          async,
          PlayableLibraryItem(f3),
          library: show,
          marks: {
            const LocalRef('hash-4'): WatchMark(
              position: const Duration(minutes: 2),
              updatedAt: DateTime.utc(2026),
              duration: length,
            ),
          },
        );
        async.flushMicrotasks();
        final next = vod.next!;
        expect(next.item, PlayableLibraryItem(f4));
        expect(next.title, 'Episode 4');
        expect((next.season, next.episode), (2, 4));
        expect(next.from, const Duration(minutes: 2));
        expect(next.stillUrl, isNull);

        final end = length.inSeconds;
        rig.coordinator.seek(length - const Duration(seconds: 20));
        async.flushMicrotasks();
        expect(vod.countdown, 10);
        play(async, from: end - 20, seconds: 10);

        expect(rig.state.item, PlayableLibraryItem(f4));
        expect(rig.engine.opened.last.start, const Duration(minutes: 2));
        expect(rig.resolver.resolvedFiles, ['hash-3', 'hash-4']);
        final left = rig.progress.saves.lastWhere(
          (s) => s.ref == const LocalRef('hash-3'),
        );
        expect(isComplete(left.position, left.duration), isTrue);
      });
    });

    test('Play now plays it at once', () {
      fakeAsync((async) {
        start(async, PlayableLibraryItem(f3), library: show);
        async.flushMicrotasks();
        vod.playNext();
        async.flushMicrotasks();
        expect(rig.state.item, PlayableLibraryItem(f4));
        expect(rig.engine.opened.last.start, isNull);
      });
    });

    test('the last file, and a movie, have no card; the end goes back '
        'to the Library', () {
      fakeAsync((async) {
        start(async, PlayableLibraryItem(f4), library: show);
        async.flushMicrotasks();
        expect(vod.next, isNull);
        rig.coordinator.seek(length);
        async.flushMicrotasks();
        rig.engine.end();
        async.flushMicrotasks();
        expect(finished, [PlayableLibraryItem(f4)]);
      });
      fakeAsync((async) {
        final film = file(5, 5, kind: LibraryKind.movie);
        start(
          async,
          PlayableLibraryItem(film),
          library: _ShowFiles([film, f4]),
        );
        async.flushMicrotasks();
        expect(vod.next, isNull);
      });
    });
  });
}
