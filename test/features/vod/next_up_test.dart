import 'package:flutter_test/flutter_test.dart';
import 'package:iptv_player/features/vod/domain/next_up.dart';
import 'package:iptv_player/features/vod/domain/titles.dart';
import 'package:iptv_player/features/vod/domain/watch_progress.dart';

void main() {
  final t0 = DateTime.utc(2026, 9, 28, 20);
  EpisodeItem episode(int season, int number) => EpisodeItem(
    id: season * 100 + number,
    sourceId: 'src',
    seriesKey: '77',
    remoteKey: 'e$season-$number',
    season: season,
    episode: number,
    title: 'Episode $number',
  );
  final details = SeriesDetails(
    seasons: [
      Season(number: 1, episodes: [episode(1, 1), episode(1, 2)]),
      Season(number: 2, episodes: [episode(2, 1)]),
    ],
  );
  WatchMark mark(Duration position, {int minute = 0, bool done = false}) =>
      WatchMark(
        position: position,
        duration: const Duration(minutes: 50),
        completed: done,
        updatedAt: t0.add(Duration(minutes: minute)),
      );
  String describe(NextUp? up) =>
      up == null ? 'none' : '${up.kind.name} ${up.episode.remoteKey}';

  test('nothing watched: the first episode', () {
    expect(describe(nextUpFor(details, {})), 'start e1-1');
  });

  test('one in progress: resume it where it was', () {
    final up = nextUpFor(details, {'e1-2': mark(const Duration(minutes: 20))});
    expect(describe(up), 'resume e1-2');
    expect(up!.from, const Duration(minutes: 20));
  });

  test('the last watched was finished: the next, across seasons', () {
    expect(
      describe(
        nextUpFor(details, {
          'e1-1': mark(const Duration(minutes: 50), done: true),
          'e1-2': mark(const Duration(minutes: 49), minute: 1, done: true),
        }),
      ),
      'next e2-1',
    );
  });

  test('the newest that counts wins; a few seconds of another do not', () {
    expect(
      describe(
        nextUpFor(details, {
          'e1-1': mark(const Duration(minutes: 30), minute: 5),
          'e2-1': mark(const Duration(seconds: 20), minute: 9),
        }),
      ),
      'resume e1-1',
    );
  });

  test('all watched: the first again; no episodes: nothing', () {
    expect(
      describe(
        nextUpFor(details, {
          'e2-1': mark(const Duration(minutes: 50), done: true),
        }),
      ),
      'again e1-1',
    );
    expect(nextUpFor(const SeriesDetails(), {}), isNull);
  });
}
