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
    Duration duration = length,
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
      ..duration(duration)
      ..firstFrame();
    async.flushMicrotasks();
  }

  /// Seeks to [left] before the end of a file [duration] long.
  void at(FakeAsync async, Duration left, {Duration duration = length}) {
    rig.coordinator.seek(duration - left);
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

    test("a TV remote's held ←/→ steps 10 s, then 30 s, then a minute", () {
      expect(VodPlayerController.scrubStep(0), const Duration(seconds: 10));
      expect(VodPlayerController.scrubStep(19), const Duration(seconds: 10));
      expect(VodPlayerController.scrubStep(20), const Duration(seconds: 30));
      expect(VodPlayerController.scrubStep(59), const Duration(seconds: 30));
      expect(VodPlayerController.scrubStep(60), const Duration(minutes: 1));
      expect(VodPlayerController.scrubStep(600), const Duration(minutes: 1));
    });

    test('OK while the keys move the bar seeks now and plays on', () {
      fakeAsync((async) {
        start(async, PlayableMovie(movie(1)));
        play(async, from: 0, seconds: 30);
        expect(vod.seekNow(), isFalse, reason: 'no seek waiting');

        vod.togglePause();
        async.flushMicrotasks();
        vod.nudge(const Duration(seconds: 10));
        expect(vod.seekNow(), isTrue);
        async.flushMicrotasks();
        expect(seeks(), ['seek:40000']);
        expect(vod.pendingSeek, isNull);
        expect(vod.timeline.paused, isFalse);
        expect(rig.engine.calls.last, 'paused:false');

        // Playing, it plays on: no pause.
        vod.nudge(const Duration(seconds: 10));
        expect(vod.seekNow(), isTrue);
        async.elapse(const Duration(seconds: 1));
        expect(seeks(), ['seek:40000', 'seek:50000']);
        expect(rig.engine.calls.where((c) => c.startsWith('paused:')), [
          'paused:true',
          'paused:false',
        ]);
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
    test('from a minute left the card counts the seconds until the next '
        'plays by itself, read off the timeline: 50 at a minute left, its '
        'bar out of 50; at 10 s left the next plays from its own resume '
        'point', () {
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
        at(async, const Duration(seconds: 61));
        expect(vod.card, NextCardPhase.none);
        expect(vod.countdown, isNull);

        rig.engine.progress(Duration(seconds: end - 60));
        expect(vod.card, NextCardPhase.count);
        expect(vod.countdown, 50);
        expect(vod.countdownLength, 50);
        // Part of a second past it: still 50 (the seconds round up).
        rig.engine.progress(Duration(seconds: end - 60, milliseconds: 400));
        expect(vod.countdown, 50);
        play(async, from: end - 60, seconds: 29);
        expect(vod.countdown, 21, reason: '31 s left');
        play(async, from: end - 31, seconds: 20);
        expect(vod.countdown, 1, reason: '11 s left');
        expect(rig.state.item, PlayableEpisode(series, e1));

        rig.engine.progress(Duration(seconds: end - 10));
        async.elapse(const Duration(seconds: 1));
        expect(rig.state.item, PlayableEpisode(series, e2));
        expect(rig.engine.opened.last.start, const Duration(minutes: 3));
        expect(vod.countdown, isNull);
        expect(vod.item, PlayableEpisode(series, e2));
      });
    });

    test('the count is the timeline: a pause holds it and a seek moves it; '
        'the next plays once, whatever ticks follow', () {
      fakeAsync((async) {
        start(async, PlayableEpisode(series, e1));
        async.flushMicrotasks();
        final end = length.inSeconds;
        at(async, const Duration(seconds: 40));
        expect(vod.countdown, 30);

        vod.togglePause();
        async
          ..flushMicrotasks()
          ..elapse(const Duration(seconds: 30));
        expect(vod.countdown, 30);
        vod.togglePause();
        async.flushMicrotasks();

        at(async, const Duration(seconds: 25));
        expect(vod.countdown, 15);
        at(async, const Duration(seconds: 55));
        expect(vod.countdown, 45);

        // Into the last 10 s at once: it plays now, and only once.
        final opened = rig.engine.opened.length;
        at(async, const Duration(seconds: 5));
        for (var s = 4; s >= 0; s--) {
          rig.engine.progress(Duration(seconds: end - s));
        }
        rig.engine.end();
        async.elapse(const Duration(seconds: 1));
        expect(rig.engine.opened, hasLength(opened + 1));
        expect(rig.state.item, PlayableEpisode(series, e2));
      });
    });

    test('Next episode during the count plays it at once', () {
      fakeAsync((async) {
        start(async, PlayableEpisode(series, e1));
        async.flushMicrotasks();
        at(async, const Duration(seconds: 45));
        expect(vod.card, NextCardPhase.count);

        vod.playNext();
        async.flushMicrotasks();
        expect(rig.state.item, PlayableEpisode(series, e2));
        expect(vod.card, NextCardPhase.none);
      });
    });

    test('Hide skips it: no card for the rest of the episode, even back in '
        'the last minute; nothing plays by itself; the end offers the '
        'next', () {
      fakeAsync((async) {
        start(async, PlayableEpisode(series, e1));
        async.flushMicrotasks();
        final end = length.inSeconds;
        at(async, const Duration(seconds: 45));
        expect(vod.card, NextCardPhase.count);

        vod.hideNext();
        expect(vod.card, NextCardPhase.none);
        expect(vod.countdown, isNull);
        at(async, length - const Duration(minutes: 10));
        at(async, const Duration(seconds: 30));
        expect(vod.card, NextCardPhase.none);
        play(async, from: end - 30, seconds: 28);
        expect(vod.card, NextCardPhase.none);
        expect(vod.countdown, isNull);
        expect(rig.state.item, PlayableEpisode(series, e1));

        rig.engine.end();
        async.flushMicrotasks();
        expect(vod.ended, isTrue);
        expect(vod.card, NextCardPhase.end);
        expect(finished, isEmpty);
        expect(rig.state.item, PlayableEpisode(series, e1));
      });
    });

    test('seeking back out of the last minute takes the card away; the '
        'last minute brings it back', () {
      fakeAsync((async) {
        start(async, PlayableEpisode(series, e1));
        async.flushMicrotasks();
        at(async, const Duration(seconds: 50));
        expect(vod.card, NextCardPhase.count);
        at(async, const Duration(seconds: 90));
        expect(vod.card, NextCardPhase.none);
        expect(vod.countdown, isNull);
        at(async, const Duration(seconds: 40));
        expect(vod.card, NextCardPhase.count);
        expect(vod.countdown, 30);
      });
    });

    test('an episode of 4 minutes or less counts from 10 at 20 s left, a '
        'second at a time, its bar out of 10; a pause holds it', () {
      fakeAsync((async) {
        const short = Duration(minutes: 4);
        start(async, PlayableEpisode(series, e1), duration: short);
        async.flushMicrotasks();
        at(async, const Duration(seconds: 50), duration: short);
        expect(vod.card, NextCardPhase.none);
        at(async, const Duration(seconds: 20), duration: short);
        expect(vod.card, NextCardPhase.count);
        expect(vod.countdown, 10);
        expect(vod.countdownLength, 10);
        async.elapse(const Duration(seconds: 1));
        expect(vod.countdown, 9);

        vod.togglePause();
        async
          ..flushMicrotasks()
          ..elapse(const Duration(seconds: 5));
        expect(vod.countdown, 9);
        vod.togglePause();
        async
          ..flushMicrotasks()
          ..elapse(const Duration(seconds: 9));
        expect(rig.state.item, PlayableEpisode(series, e2));
      });
      fakeAsync((async) {
        const longer = Duration(minutes: 4, seconds: 1);
        start(async, PlayableEpisode(series, e1), duration: longer);
        async.flushMicrotasks();
        at(async, const Duration(seconds: 50), duration: longer);
        expect(vod.card, NextCardPhase.count);
        expect(vod.countdown, 40);
        expect(vod.countdownLength, 50);
      });
    });

    test("Next episode before the card plays it at once (the row's)", () {
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

    test('Next episode in the credits saves the episode as watched too', () {
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

    test('Hide during the count: the episode plays to its end, '
        'then the card again without the count', () {
      fakeAsync((async) {
        start(async, PlayableEpisode(series, e1));
        async.flushMicrotasks();
        final end = length.inSeconds;
        rig.coordinator.seek(length - const Duration(seconds: 15));
        async.flushMicrotasks();
        expect(vod.countdown, 5);

        vod.hideNext();
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

  test('a movie has neither the offer nor the count, a minute or 20 s '
      'from its end, and its end goes back to its page', () {
    fakeAsync((async) {
      start(async, PlayableMovie(movie(1)));
      async.flushMicrotasks();
      for (final left in [60, 45, 20, 10]) {
        at(async, Duration(seconds: left));
        expect(vod.next, isNull);
        expect(vod.card, NextCardPhase.none);
        expect(vod.countdown, isNull);
      }
      play(async, from: length.inSeconds - 10, seconds: 9);
      expect(vod.card, NextCardPhase.none);
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
