import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:iptv_player/design/components.dart';
import 'package:iptv_player/design/tokens.dart';

import '../design_harness.dart';

void main() {
  group('ChannelLogo', () {
    test('monograms come from the first two words', () {
      expect(ChannelLogo.monogramOf('Arena Sports 1'), 'AS');
      expect(ChannelLogo.monogramOf('Vista'), 'VI');
      expect(ChannelLogo.monogramOf('X'), 'X');
      expect(ChannelLogo.monogramOf('  '), '?');
      expect(ChannelLogo.monogramOf('4K | Sky Sports'), '4S');
    });

    test('the same name always gets the same color', () {
      expect(
        ChannelLogo.colorOf('Arena Sports 1'),
        ChannelLogo.colorOf('Arena Sports 1'),
      );
      expect(
        ChannelLogo.monogramPalette,
        contains(ChannelLogo.colorOf('City News')),
      );
    });

    testWidgets('renders the monogram when there is no image', (tester) async {
      await pumpDesign(tester, const ChannelLogo(name: 'Arena Sports 1'));
      expect(find.text('AS'), findsOneWidget);
    });
  });

  group('ChannelRow', () {
    testWidgets('shows number, name, now title and progress', (tester) async {
      await pumpDesign(
        tester,
        SizedBox(
          width: 420,
          child: ChannelRow(
            name: 'Arena Sports 1',
            number: 201,
            nowTitle: 'Arsenal v Chelsea',
            progress: 0.42,
            onPressed: () {},
          ),
        ),
      );

      expect(find.text('201'), findsOneWidget);
      expect(find.text('Arena Sports 1'), findsOneWidget);
      expect(find.text('Arsenal v Chelsea'), findsOneWidget);
      expect(find.byType(ProgressBar), findsOneWidget);
    });

    testWidgets('draws the quality badge after the name, raised on the '
        'selected row', (tester) async {
      await pumpDesign(
        tester,
        Column(
          children: [
            SizedBox(
              width: 420,
              child: ChannelRow(
                name: 'Arena Sports 1',
                quality: 'FHD',
                onPressed: () {},
              ),
            ),
            SizedBox(
              width: 420,
              child: ChannelRow(
                name: 'Arena Sports 2',
                quality: 'HD',
                selected: true,
                onPressed: () {},
              ),
            ),
            SizedBox(
              width: 420,
              child: ChannelRow(name: 'Zebra TV', onPressed: () {}),
            ),
          ],
        ),
      );

      final fhd = tester.widget<ChannelBadge>(
        find.widgetWithText(ChannelBadge, 'FHD'),
      );
      final hd = tester.widget<ChannelBadge>(
        find.widgetWithText(ChannelBadge, 'HD'),
      );
      expect(fhd.raised, isFalse);
      expect(hd.raised, isTrue);
      expect(find.byType(ChannelBadge), findsNWidgets(2));
      expect(
        tester.getTopLeft(find.text('FHD')).dx,
        greaterThan(tester.getTopRight(find.text('Arena Sports 1')).dx),
      );
    });

    testWidgets('says so when there is no guide information', (tester) async {
      await pumpDesign(
        tester,
        SizedBox(
          width: 420,
          child: ChannelRow(name: 'City News', onPressed: () {}),
        ),
      );

      expect(find.text('No guide information'), findsOneWidget);
    });

    testWidgets('says nothing while the guide was not looked up', (
      tester,
    ) async {
      await pumpDesign(
        tester,
        SizedBox(
          width: 420,
          child: ChannelRow(
            name: 'City News',
            guideKnown: false,
            onPressed: () {},
          ),
        ),
      );

      expect(find.text('No guide information'), findsNothing);
    });

    testWidgets('in a gap in the guide, says what comes next', (tester) async {
      await pumpDesign(
        tester,
        SizedBox(
          width: 420,
          child: ChannelRow(
            name: 'City News',
            upNext: '21:00 · The Late News',
            onPressed: () {},
          ),
        ),
      );

      expect(find.text('Next 21:00 · The Late News'), findsOneWidget);
      expect(find.text('No guide information'), findsNothing);
      expect(find.byType(ProgressBar), findsNothing);
    });

    testWidgets('Enter opens it and Shift+F10 opens the menu', (tester) async {
      var opened = 0;
      var menus = 0;
      await pumpDesign(
        tester,
        SizedBox(
          width: 420,
          child: ChannelRow(
            name: 'Arena Sports 1',
            autofocus: true,
            onPressed: () => opened++,
            onMenu: () => menus++,
          ),
        ),
      );
      await tester.pumpAndSettle();

      await tester.sendKeyEvent(LogicalKeyboardKey.enter);
      await tester.pump();
      expect(opened, 1);

      await tester.sendKeyDownEvent(LogicalKeyboardKey.shiftLeft);
      await tester.sendKeyEvent(LogicalKeyboardKey.f10);
      await tester.sendKeyUpEvent(LogicalKeyboardKey.shiftLeft);
      await tester.pump();
      expect(menus, 1);
    });

    testWidgets('follows the density token', (tester) async {
      await pumpDesign(
        tester,
        SizedBox(
          width: 420,
          child: ChannelRow(name: 'City News', onPressed: () {}),
        ),
        density: AppDensity.compact,
      );

      expect(
        tester.getSize(find.byType(ChannelRow)).height,
        AppDensity.compact.rowHeight,
      );
    });
  });

  group('Cards', () {
    testWidgets('PosterCard shows title, meta and rating', (tester) async {
      await pumpDesign(
        tester,
        PosterCard(
          title: 'Copper Hollow',
          meta: '2025',
          rating: 7.1,
          onPressed: () {},
        ),
      );

      expect(find.text('Copper Hollow'), findsWidgets);
      expect(find.text('2025 ·'), findsOneWidget);
      expect(find.text('7.1'), findsOneWidget);
    });

    testWidgets('PosterCard grows on focus', (tester) async {
      await pumpDesign(
        tester,
        PosterCard(title: 'Copper Hollow', autofocus: true, onPressed: () {}),
      );
      await tester.pumpAndSettle();

      expect(
        tester.widget<AnimatedScale>(find.byType(AnimatedScale)).scale,
        AppTokens.defaults().focus.tileScale,
      );
    });

    testWidgets('LandscapeCard is 16:9', (tester) async {
      await pumpDesign(
        tester,
        LandscapeCard(
          title: 'The Long Way Home',
          subtitle: 'S1 · E3',
          width: 320,
          onPressed: () {},
        ),
      );

      final artwork = tester.getSize(find.byType(ClipRRect).first);
      expect(artwork.width / artwork.height, closeTo(16 / 9, 0.01));
    });

    testWidgets("a card's progress is on its picture's bottom edge; on a TV "
        'inside it, clear of the ring drawn inside the edge', (tester) async {
      Future<(Rect, Rect)> bar({required bool tv}) async {
        await pumpDesign(
          tester,
          Center(
            child: LandscapeCard(
              key: ValueKey(tv),
              title: 'The Long Way Home',
              subtitle: 'Movie · 46 min left',
              progress: 0.6,
              width: 320,
              autofocus: true,
              onPressed: () {},
            ),
          ),
          tv: tv,
        );
        await tester.pumpAndSettle();
        return (
          tester.getRect(find.byType(ClipRRect).first),
          tester.getRect(find.byType(ProgressBar)),
        );
      }

      final (picture, edge) = await bar(tv: false);
      expect(edge.bottom, closeTo(picture.bottom, 0.01));
      expect(edge.width, closeTo(picture.width, 0.01));

      const focus = AppFocusTokens.tv;
      final (tvPicture, inside) = await bar(tv: true);
      // The focused card grows; the bar and the gap grow with it.
      final scale = tvPicture.width / 320;
      expect(inside.height, closeTo(focus.cardBarHeight * scale, 0.01));
      expect(
        tvPicture.bottom - inside.bottom,
        closeTo(focus.cardBarInset * scale, 0.5),
      );
      expect(
        tvPicture.bottom - inside.bottom,
        greaterThan(focus.ringWidth * scale),
      );
    });
  });

  group('SectionHeader', () {
    testWidgets('See all is activated with Enter', (tester) async {
      var seen = 0;
      await pumpDesign(
        tester,
        SizedBox(
          width: 420,
          child: SectionHeader(
            title: 'Continue watching',
            subtitle: '6 items',
            onSeeAll: () => seen++,
          ),
        ),
      );
      await tester.pumpAndSettle();

      await tester.sendKeyEvent(LogicalKeyboardKey.tab);
      await tester.pumpAndSettle();
      await tester.sendKeyEvent(LogicalKeyboardKey.enter);
      await tester.pump();

      expect(seen, 1);
    });

    testWidgets('without onSeeAll there is no button', (tester) async {
      await pumpDesign(
        tester,
        const SizedBox(width: 420, child: SectionHeader(title: 'Favorites')),
      );

      expect(find.text('See all'), findsNothing);
    });
  });

  group('HorizontalRail', () {
    testWidgets('builds items lazily', (tester) async {
      final built = <int>[];
      await pumpDesign(
        tester,
        SizedBox(
          width: 400,
          child: HorizontalRail(
            height: 120,
            itemCount: 500,
            itemBuilder: (context, index) {
              built.add(index);
              return const SizedBox(width: 120, height: 120);
            },
          ),
        ),
      );

      expect(built.length, lessThan(20));
      expect(built, contains(0));
    });

    testWidgets('edge arrows stay out of the tab order', (tester) async {
      await pumpDesign(
        tester,
        SizedBox(
          width: 400,
          child: HorizontalRail(
            height: 120,
            itemCount: 20,
            itemBuilder: (context, index) =>
                const SizedBox(width: 120, height: 120),
          ),
        ),
      );

      expect(find.byType(ExcludeFocus), findsNWidgets(2));
    });

    testWidgets('a card keyed by what it shows keeps its state (its focus) '
        'when the row re-sorts, not its place (ADR-039)', (tester) async {
      Widget rail(List<String> names) => SizedBox(
        width: 400,
        child: HorizontalRail(
          height: 120,
          itemCount: names.length,
          findItemIndexCallback: (key) => switch (key) {
            ValueKey<String>(:final value) when names.contains(value) =>
              names.indexOf(value),
            _ => null,
          },
          itemBuilder: (context, index) => _Card(key: ValueKey(names[index])),
        ),
      );
      await pumpDesign(tester, rail(['a', 'b', 'c']));
      final c = tester.state<_CardState>(find.byKey(const ValueKey('c')));
      c.focus.requestFocus();
      await tester.pump();

      await pumpDesign(tester, rail(['c', 'a', 'b']));
      expect(
        tester.state(find.byKey(const ValueKey('c'))),
        same(c),
        reason: 'the same card, first now',
      );
      expect(c.focus.hasPrimaryFocus, isTrue);
      expect(
        tester.getTopLeft(find.byKey(const ValueKey('c'))).dx,
        tester.getTopLeft(find.byType(HorizontalRail)).dx,
      );
    });
  });
}

class _Card extends StatefulWidget {
  const new({super.key});

  @override
  State<_Card> createState() => _CardState();
}

class _CardState extends State<_Card> {
  final focus = FocusNode();

  @override
  void dispose() {
    focus.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) =>
      Focus(focusNode: focus, child: const SizedBox(width: 120, height: 120));
}
