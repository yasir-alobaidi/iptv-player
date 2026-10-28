import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:iptv_player/app/destinations.dart';
import 'package:iptv_player/core/catalogue_kind.dart';
import 'package:iptv_player/core/core_providers.dart';
import 'package:iptv_player/core/platform/form_factor.dart';
import 'package:iptv_player/core/result.dart';
import 'package:iptv_player/data/db/user_tables.dart';
import 'package:iptv_player/data/providers/xtream/xtream_models.dart';
import 'package:iptv_player/design/appearance.dart';
import 'package:iptv_player/design/components.dart';
import 'package:iptv_player/features/playback/presentation/vod_launch.dart';
import 'package:iptv_player/features/sources/presentation/source_shell_slots.dart';
import 'package:iptv_player/features/vod/domain/catalogue.dart';
import 'package:iptv_player/features/vod/presentation/catalogue_state.dart';
import 'package:iptv_player/features/vod/presentation/title_details_screen.dart';

import '../../app/app_harness.dart';
import '../settings/appearance_fakes.dart';
import 'details_screen_test.dart' show RecordingLauncher;
import 'vod_fakes.dart';

/// ADR-068: Movies, Series and a title's page on a phone held upright
/// (390 × 844, the shell's bottom bar): three posters a row, the sort as
/// a button beside the filter; a film's page with the backdrop across the
/// top and Play the page's width; a series' seasons as chips and its
/// episodes the page's width.
void main() {
  const phone = Size(390, 844);
  const info = XtreamMovieInfo(
    plot: 'A storm strands a ferry in a small fishing town.',
    cast: 'Tomas Lind, Mara Okafor',
    director: 'Ana Ribeiro',
    genre: 'Drama, Mystery',
    runtimeMinutes: 118,
    videoHeight: 1080,
    audioChannels: 6,
  );
  const episodes = XtreamSeriesInfo(
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

  Future<(VodFakes, RecordingLauncher)> open(
    WidgetTester tester,
    String location, {
    Future<void> Function(VodFakes vod)? before,
    TextSizeChoice text = TextSizeChoice.s100,
  }) async {
    final vod = VodFakes();
    final launcher = RecordingLauncher();
    addTearDown(() => tester.runAsync(vod.db.close));
    await tester.runAsync(() async {
      await vod.seed();
      await before?.call(vod);
    });
    vod.details
      ..movieAnswer = const Ok(info)
      ..seriesAnswer = const Ok(episodes);
    await pumpApp(
      tester,
      size: phone,
      initialLocation: location,
      withAppearance: true,
      overrides: <Override>[
        ...vod.overrides,
        ...sourceShellOverrides,
        ...appearanceOverrides(
          settings: const AppearanceSettings().copyWith(textSize: text),
        ),
        vodLauncherProvider.overrideWithValue(launcher),
        formFactorProvider.overrideWithValue(FormFactor.mobile),
      ],
    );
    await settle(tester);
    return (vod, launcher);
  }

  Rect rectOf(WidgetTester tester, Finder finder) => tester.getRect(finder);

  testWidgets('Movies: three posters a row, the width of the screen; the '
      'filter says how many, the sort is a button with its menu', (
    tester,
  ) async {
    await open(
      tester,
      AppDestination.movies.path,
      before: (vod) => vod.seedMany(24),
    );

    final cards = find.byType(PosterCard);
    final tops = <double, List<Rect>>{};
    for (final element in cards.evaluate()) {
      final rect = tester.getRect(find.byWidget(element.widget));
      tops.putIfAbsent(rect.top.roundToDouble(), () => []).add(rect);
    }
    final firstRow = tops[tops.keys.reduce((a, b) => a < b ? a : b)]!;
    expect(firstRow, hasLength(3));
    // Evenly, and nearly the screen's width between them.
    final widths = {for (final rect in firstRow) rect.width.round()};
    expect(widths, hasLength(1));
    final span = firstRow.last.right - firstRow.first.left;
    expect(span, greaterThan(phone.width - 48));
    // Posters 2:3.
    final picture = tester.getSize(
      find.descendant(of: cards.first, matching: find.byType(ClipRRect)).first,
    );
    expect(picture.height / picture.width, closeTo(1.5, 0.01));

    expect(find.text('Filter 27 movies'), findsOneWidget);
    expect(find.byType(SegmentedControl<TitleSort>), findsNothing);
    await tester.tap(find.byTooltip('Sort: Recently added'));
    await settle(tester);
    await tester.tap(find.text('Name').last);
    await settle(tester);
    final container = ProviderScope.containerOf(
      tester.element(find.byType(MaterialApp)),
    );
    expect(
      container.read(catalogueControllerProvider(CatalogueKind.movie))?.sort,
      TitleSort.name,
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets("a film's page: the backdrop across the top, ‹ Movies clear "
      'of the status bar, Play the width of the page, then the plot', (
    tester,
  ) async {
    final (_, launcher) = await open(tester, '/movies/src-1/501');

    expect(find.byType(DetailsStackedHero), findsOneWidget);
    final play = rectOf(tester, findByLabel('Play'));
    expect(play.width, greaterThan(phone.width * 0.7));
    expect(play.height, greaterThanOrEqualTo(44));
    final plot = rectOf(tester, find.text(info.plot!));
    expect(plot.top, greaterThan(play.bottom));
    final back = rectOf(tester, findByLabel('Back to Movies'));
    expect(back.left, lessThan(play.left + 8));
    expect(back.height, greaterThanOrEqualTo(44));

    await tester.tap(findByLabel('Play'));
    await settle(tester);
    expect(launcher.played, ['501 from 0']);
    expect(tester.takeException(), isNull);
  });

  testWidgets("a film's page at 130 %, part-watched: Resume, Start over and "
      'the time left fit without overflowing', (tester) async {
    await open(
      tester,
      '/movies/src-1/501',
      text: TextSizeChoice.s130,
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

    expect(find.text('Resume from 1:12:00'), findsOneWidget);
    expect(find.text('Start over'), findsOneWidget);
    expect(find.text('46 min left'), findsOneWidget);
    final resume = rectOf(tester, findByLabel('Resume from 1:12:00'));
    expect(resume.right, lessThanOrEqualTo(phone.width));
    expect(tester.takeException(), isNull);
  });

  testWidgets("a series' page: Play the width of the page, the seasons as "
      'chips, the episodes in a list with their descriptions; a chip shows '
      'its season, a tap plays an episode', (tester) async {
    final (_, launcher) = await open(tester, '/series/src-1/77');

    expect(findByLabel('Play S1 · E1'), findsOneWidget);
    expect(
      rectOf(tester, findByLabel('Play S1 · E1')).width,
      greaterThan(phone.width * 0.7),
    );
    expect(find.widgetWithText(AppChip, 'Season 1'), findsOneWidget);
    expect(find.widgetWithText(AppChip, 'Season 2'), findsOneWidget);
    expect(find.text('Low Water'), findsOneWidget);
    // On a phone the description shows without a focus.
    await tester.ensureVisible(find.text('Ledger'));
    expect(
      find.text('The missing pages turn up aboard the Meridian.'),
      findsOneWidget,
    );

    await tester.ensureVisible(find.widgetWithText(AppChip, 'Season 2'));
    await tester.tap(find.widgetWithText(AppChip, 'Season 2'));
    await settle(tester);
    expect(find.text('Undertow'), findsOneWidget);
    expect(find.text('Low Water'), findsNothing);

    await tester.tap(find.text('Undertow'));
    await settle(tester);
    expect(launcher.played, ['7201 from 0']);
    expect(tester.takeException(), isNull);
  });
}
