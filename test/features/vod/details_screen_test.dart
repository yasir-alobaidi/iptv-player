import 'dart:async';

import 'package:flutter/services.dart';
import 'package:flutter_riverpod/misc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:iptv_player/core/result.dart';
import 'package:iptv_player/data/db/user_tables.dart';
import 'package:iptv_player/data/providers/xtream/xtream_models.dart';
import 'package:iptv_player/design/components.dart';
import 'package:iptv_player/features/vod/domain/titles.dart';
import 'package:iptv_player/features/vod/domain/vod_launcher.dart';
import 'package:iptv_player/features/vod/presentation/details_state.dart';

import '../../app/app_harness.dart';
import 'catalogue_screen_test.dart' show focusedLabel;
import 'vod_fakes.dart';

/// What a Play asked for.
final class RecordingLauncher implements VodLauncher {
  final played = <String>[];

  @override
  Future<void> playMovie(MovieItem movie, {Duration? from}) async =>
      played.add('${movie.remoteKey} from ${from?.inMinutes ?? 0}');

  @override
  Future<void> playEpisode(
    SeriesItem series,
    EpisodeItem episode, {
    Duration? from,
  }) async => played.add('${episode.remoteKey} from ${from?.inMinutes ?? 0}');
}

const _info = XtreamMovieInfo(
  plot: 'A storm strands a ferry in a small fishing town.',
  cast: 'Tomas Lind, Mara Okafor',
  director: 'Ana Ribeiro',
  genre: 'Drama, Mystery',
  runtimeMinutes: 118,
  videoHeight: 1080,
  audioChannels: 6,
);

const _episodes = XtreamSeriesInfo(
  plot: 'A harbor inspector follows the tide logs.',
  genre: 'Thriller',
  episodes: [
    XtreamEpisode(
      id: '7101',
      season: 1,
      episode: 1,
      title: 'Low Water',
      durationSeconds: 3120,
    ),
    XtreamEpisode(
      id: '7102',
      season: 1,
      episode: 2,
      title: 'Ledger',
      durationSeconds: 2880,
      plot: 'The missing pages turn up aboard the Meridian.',
    ),
    XtreamEpisode(
      id: '7201',
      season: 2,
      episode: 1,
      title: 'Undertow',
      durationSeconds: 3000,
    ),
  ],
);

void main() {
  Future<(VodFakes, RecordingLauncher, AppUnderTest)> open(
    WidgetTester tester,
    String location, {
    FutureOr<void> Function(VodFakes vod)? before,
  }) async {
    final vod = VodFakes();
    final launcher = RecordingLauncher();
    addTearDown(() => tester.runAsync(vod.db.close));
    await tester.runAsync(vod.seed);
    vod.details
      ..movieAnswer = const Ok(_info)
      ..seriesAnswer = const Ok(_episodes);
    await tester.runAsync(() async => await before?.call(vod));
    final app = await pumpApp(
      tester,
      initialLocation: location,
      overrides: <Override>[
        ...vod.overrides,
        vodLauncherProvider.overrideWithValue(launcher),
      ],
    );
    await settle(tester);
    return (vod, launcher, app);
  }

  group('movie', () {
    testWidgets('what the row knows at once; the details while they load', (
      tester,
    ) async {
      await open(
        tester,
        '/movies/src-1/501',
        before: (vod) => vod.details.gate = Completer<void>(),
      );

      expect(find.text('The Quiet Harbor'), findsWidgets);
      expect(find.text('MOVIE'), findsOneWidget);
      expect(find.byType(Skeleton), findsWidgets);
      expect(find.text('Play'), findsOneWidget);
    });

    testWidgets('fetched: the plot, the credits, runtime, genres and '
        'badges; Play has the focus and starts at 0', (tester) async {
      final (_, launcher, _) = await open(tester, '/movies/src-1/501');

      expect(find.text('MOVIE  /  DRAMA'), findsOneWidget);
      expect(find.text(_info.plot!), findsOneWidget);
      expect(find.text('Ana Ribeiro'), findsOneWidget);
      expect(find.text('Tomas Lind, Mara Okafor'), findsOneWidget);
      expect(find.text('1 h 58 min'), findsOneWidget);
      expect(find.text('Drama, Mystery'), findsOneWidget);
      expect(find.text('FHD'), findsOneWidget);
      expect(find.text('5.1'), findsOneWidget);
      expect(find.text('Start over'), findsNothing);
      expect(focusedLabel(), 'Play');

      await tester.sendKeyEvent(LogicalKeyboardKey.enter);
      await settle(tester);
      expect(launcher.played, ['501 from 0']);
    });

    testWidgets('left part-way: Resume from where, Start over, and the time '
        'left', (tester) async {
      final (_, launcher, _) = await open(
        tester,
        '/movies/src-1/501',
        before: (vod) => vod.db.watchHistoryDao.touch(
          UserItemType.movie,
          'src-1',
          '501',
          vod.now,
          positionMs: 72 * 60000,
          durationMs: 118 * 60000,
          completed: false,
        ),
      );
      await settle(tester);

      expect(find.text('Resume from 1:12:00'), findsOneWidget);
      expect(find.text('46 min left'), findsOneWidget);
      await tester.tap(find.text('Resume from 1:12:00'));
      await tester.tap(find.text('Start over'));
      await settle(tester);
      expect(launcher.played, ['501 from 72', '501 from 0']);
    });

    testWidgets('a first fetch that fails says why, and Retry fetches '
        'again', (tester) async {
      final (vod, _, _) = await open(
        tester,
        '/movies/src-1/501',
        before: (vod) =>
            vod.details.movieAnswer = Err(NetworkFailure('offline')),
      );

      expect(find.textContaining("Couldn't load the details."), findsOneWidget);
      vod.details.movieAnswer = const Ok(_info);
      await tester.tap(find.text('Retry'));
      await settle(tester);
      expect(find.text(_info.plot!), findsOneWidget);
      expect(vod.details.movieCalls, 2);
    });

    testWidgets('a provider with no plot says so', (tester) async {
      await open(
        tester,
        '/movies/src-1/501',
        before: (vod) => vod.details.movieAnswer = const Ok(XtreamMovieInfo()),
      );

      expect(find.text('No description from your provider.'), findsOneWidget);
    });

    testWidgets('Esc goes back; a second open makes no request', (
      tester,
    ) async {
      final (vod, _, app) = await open(tester, '/movies/src-1/501');
      expect(vod.details.movieCalls, 1);

      await tester.sendKeyEvent(LogicalKeyboardKey.escape);
      await settle(tester);
      expect(app.location, '/movies');

      app.router.go('/movies/src-1/501');
      await settle(tester);
      expect(find.text(_info.plot!), findsOneWidget);
      expect(vod.details.movieCalls, 1);
    });

    testWidgets('F toggles the favorite', (tester) async {
      await open(tester, '/movies/src-1/501');

      await tester.sendKeyEvent(LogicalKeyboardKey.keyF);
      await settle(tester);
      expect(
        tester
            .widget<AppIconButton>(
              find.byWidgetPredicate(
                (w) => w is AppIconButton && w.icon == AppIcons.starFilled,
              ),
            )
            .selected,
        isTrue,
      );
    });

    testWidgets('a movie the provider dropped: not available', (tester) async {
      await open(tester, '/movies/src-1/999');

      expect(find.text('Not available'), findsOneWidget);
      expect(
        find.text('This movie is no longer available from your provider.'),
        findsOneWidget,
      );
    });
  });

  group('series', () {
    testWidgets('skeleton rows while the episodes load', (tester) async {
      await open(
        tester,
        '/series/src-1/77',
        before: (vod) => vod.details.gate = Completer<void>(),
      );

      expect(find.text('Glass Tide'), findsWidgets);
      expect(find.byType(Skeleton), findsWidgets);
    });

    testWidgets('nothing watched: the seasons, the first season shown, Play '
        'S1 · E1 with the focus', (tester) async {
      final (_, launcher, _) = await open(tester, '/series/src-1/77');

      expect(find.text('2 seasons'), findsOneWidget);
      expect(find.text('Thriller'), findsOneWidget);
      expect(find.text('Season 1'), findsOneWidget);
      expect(find.text('Season 2'), findsOneWidget);
      expect(find.text('2 episodes'), findsOneWidget);
      expect(find.text('Low Water'), findsOneWidget);
      expect(find.text('52 min'), findsOneWidget);
      expect(focusedLabel(), 'Play S1 · E1');

      await tester.sendKeyEvent(LogicalKeyboardKey.enter);
      await settle(tester);
      expect(launcher.played, ['7101 from 0']);
    });

    testWidgets('one watched, one part-way: Continue it, ✓ and the time '
        'left on the rows', (tester) async {
      final (_, launcher, _) = await open(
        tester,
        '/series/src-1/77',
        before: (vod) async {
          await vod.db.watchHistoryDao.touch(
            UserItemType.episode,
            'src-1',
            '7101',
            vod.now,
            positionMs: 52 * 60000,
            durationMs: 52 * 60000,
            completed: true,
            seriesKey: '77',
          );
          await vod.db.watchHistoryDao.touch(
            UserItemType.episode,
            'src-1',
            '7102',
            vod.now.add(const Duration(minutes: 1)),
            positionMs: 20 * 60000,
            durationMs: 48 * 60000,
            completed: false,
            seriesKey: '77',
          );
        },
      );
      await settle(tester);

      expect(find.text('Continue S1 · E2'), findsOneWidget);
      expect(find.text('52 min · Watched'), findsOneWidget);
      expect(find.text('28 min left'), findsOneWidget);

      await tester.tap(find.text('Continue S1 · E2'));
      await settle(tester);
      expect(launcher.played, ['7102 from 20']);
    });

    testWidgets('a mark that arrives while the page shows moves Continue '
        'on', (tester) async {
      final (vod, _, _) = await open(tester, '/series/src-1/77');
      expect(find.text('Play S1 · E1'), findsOneWidget);

      // In the test's own zone: a write from runAsync would wait on the
      // page's stream, which only moves when the test pumps.
      unawaited(
        vod.db.watchHistoryDao.touch(
          UserItemType.episode,
          'src-1',
          '7101',
          vod.now,
          positionMs: 52 * 60000,
          durationMs: 52 * 60000,
          completed: true,
          seriesKey: '77',
        ),
      );
      await settle(tester);

      expect(find.text('Continue S1 · E2'), findsOneWidget);
    });

    testWidgets('another season on its tab; its episode plays', (tester) async {
      final (_, launcher, _) = await open(tester, '/series/src-1/77');

      await tester.tap(find.text('Season 2'));
      await settle(tester);
      expect(find.text('Undertow'), findsOneWidget);
      expect(find.text('1 episode'), findsOneWidget);

      await tester.tap(find.text('Undertow'));
      await settle(tester);
      expect(launcher.played, ['7201 from 0']);
    });

    testWidgets('a series with no episodes says so', (tester) async {
      await open(
        tester,
        '/series/src-1/77',
        before: (vod) =>
            vod.details.seriesAnswer = const Ok(XtreamSeriesInfo()),
      );

      expect(
        find.text('Your provider lists no episodes for this series yet'),
        findsOneWidget,
      );
    });

    testWidgets('a first fetch that fails: the reason and Retry', (
      tester,
    ) async {
      await open(
        tester,
        '/series/src-1/77',
        before: (vod) =>
            vod.details.seriesAnswer = Err(NetworkFailure('offline')),
      );

      expect(find.text("Couldn't load the episodes"), findsOneWidget);
      expect(find.text('Retry'), findsWidgets);
    });
  });
}
