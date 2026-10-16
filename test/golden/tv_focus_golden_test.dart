// Every test in this file is a golden; the tag is declared in
// dart_test.yaml so `flutter test --exclude-tags golden` can drop them
// on Windows.
@Tags(['golden'])
library;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:iptv_player/design/components.dart';
import 'package:iptv_player/design/tokens.dart';

import '../design/design_harness.dart';
import 'golden_harness.dart';

/// [child] drawn focused, as the keyboard or the remote would leave it.
Widget _focused(Widget child) => SurfaceStateOverride(
  states: const SurfaceStates(focused: true),
  child: child,
);

/// The controls a remote lands on, focused beside the same at rest, as a
/// TV draws them (ADR-029): the ring on a card's picture and not its
/// caption, a tab's ring round its label above the underline, an icon
/// button as tall as the button beside it, a row's ring inside its list.
class _Sheet extends StatelessWidget {
  const new();

  @override
  Widget build(BuildContext context) {
    final tokens = context.tokens;
    final spacing = tokens.spacing;
    final gap = SizedBox(width: spacing.s24);
    return ColoredBox(
      color: tokens.colors.bg,
      child: Padding(
        padding: EdgeInsets.all(spacing.s32),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _focused(
                  const PosterCard(
                    title: 'Northbound',
                    meta: '2024',
                    rating: 7.2,
                    width: 150,
                  ),
                ),
                gap,
                const PosterCard(
                  title: 'Paper Kites',
                  meta: '2019',
                  rating: 6.4,
                  width: 150,
                ),
                gap,
                _focused(
                  const LandscapeCard(
                    title: 'The Quiet Harbor',
                    subtitle: 'Movie · 46 min left',
                    progress: 0.6,
                    width: 270,
                  ),
                ),
                gap,
                _focused(
                  const ChannelTile(
                    name: 'Arena Sports 1',
                    programme: 'Continental Cup',
                    progress: 0.4,
                  ),
                ),
              ],
            ),
            SizedBox(height: spacing.s32),
            Row(
              children: [
                CountTab(
                  label: 'Channels',
                  count: 8,
                  selected: true,
                  onPressed: () {},
                ),
                SizedBox(width: spacing.s8),
                _focused(
                  CountTab(
                    label: 'Movies',
                    count: 3,
                    selected: false,
                    onPressed: () {},
                  ),
                ),
                SizedBox(width: spacing.s8),
                CountTab(
                  label: 'Series',
                  count: 0,
                  selected: false,
                  onPressed: () {},
                ),
                gap,
                _focused(AppChip(label: 'Drama', onPressed: () {})),
                SizedBox(width: spacing.s8),
                AppChip(label: 'All', selected: true, onPressed: () {}),
              ],
            ),
            SizedBox(height: spacing.s32),
            Row(
              children: [
                _focused(
                  AppButton(
                    label: 'Play',
                    icon: AppIcons.play,
                    size: AppButtonSize.xl,
                    onPressed: () {},
                  ),
                ),
                SizedBox(width: spacing.s12),
                AppIconButton(
                  icon: AppIcons.star,
                  tooltip: 'Add to favorites',
                  bordered: true,
                  size: tokens.details.movieActionHeight,
                  onPressed: () {},
                ),
                gap,
                AppButton(
                  label: 'Edit',
                  icon: AppIcons.edit,
                  variant: AppButtonVariant.secondary,
                  onPressed: () {},
                ),
                SizedBox(width: spacing.s8),
                _focused(
                  AppIconButton(
                    icon: AppIcons.more,
                    tooltip: 'More',
                    bordered: true,
                    size: 44,
                    onPressed: () {},
                  ),
                ),
              ],
            ),
            SizedBox(height: spacing.s32),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _list(),
                SizedBox(width: spacing.s48),
                // A film's seek bar with the remote on it, and at rest.
                SizedBox(
                  width: 520,
                  child: Column(
                    children: [
                      for (final focused in [true, false])
                        AppSlider(
                          value: 0.4,
                          bufferedValue: 0.5,
                          overVideo: true,
                          focused: focused,
                          bubbleLabel: (_) => '48:10',
                          onChanged: (_) {},
                        ),
                    ],
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _list() => SizedBox(
    width: 420,
    height: 140,
    child: ListView(
      children: [
        _focused(
          ChannelRow(
            name: 'Ironwood Arena',
            number: 1,
            nowTitle: 'Archive Late',
            progress: 0.3,
            onPressed: () {},
          ),
        ),
        ChannelRow(
          name: 'Zephyr Kids',
          number: 2,
          nowTitle: 'Fathom Tonight',
          progress: 0.5,
          onPressed: () {},
        ),
      ],
    ),
  );
}

void main() {
  group('Focus on a TV', skip: goldenSkipReason, () {
    setUp(hideDebugBanner);

    testWidgets('every kind of control', (tester) async {
      // The TV's canvas, its text 1.2× (ADR-026).
      tester.view.physicalSize = const Size(TvCanvas.width, 720);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      await pumpDesign(
        tester,
        const _Sheet(),
        tv: true,
        textScale: TvCanvas.textScale,
      );
      await tester.pumpAndSettle();
      await expectLater(
        find.byType(MaterialApp),
        matchesGoldenFile('images/tv_focus.png'),
      );
    });
  });
}
