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

    testWidgets('says so when there is no guide data', (tester) async {
      await pumpDesign(
        tester,
        SizedBox(
          width: 420,
          child: ChannelRow(name: 'City News', onPressed: () {}),
        ),
      );

      expect(find.text('No guide data'), findsOneWidget);
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
  });
}
