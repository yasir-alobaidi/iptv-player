import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:iptv_player/design/components.dart';
import 'package:iptv_player/design/tokens.dart';

import 'design_harness.dart';

/// Phase 9 decision 3: a height that holds text grows with the text;
/// pictures don't; at 100 % nothing moves.
void main() {
  group('the helper', () {
    Future<BuildContext> at(WidgetTester tester, double scale) async {
      await pumpDesign(
        tester,
        const SizedBox(key: Key('here')),
        textScale: scale,
      );
      return tester.element(find.byKey(const Key('here')));
    }

    testWidgets('at 100 % a height is itself, to the bit', (tester) async {
      final context = await at(tester, 1);

      expect(context.textScale, 1);
      for (final height in [34.0, 36.0, 44.0, 56.0, 72.0, 0.1 + 0.2]) {
        expect(context.scaled(height), height);
        expect(context.scaledAround(height, fixed: 12), height);
      }
    });

    testWidgets('at 130 % it is 1.3 times as tall', (tester) async {
      final context = await at(tester, 1.3);

      expect(context.textScale, 1.3);
      expect(context.scaled(40), closeTo(52, 1e-9));
      expect(context.scaled(56), closeTo(72.8, 1e-9));
    });

    testWidgets('around a picture only the rest grows', (tester) async {
      final context = await at(tester, 1.3);

      // A 100 px box with a 60 px picture: the 40 px of text become 52.
      expect(context.scaledAround(100, fixed: 60), closeTo(112, 1e-9));
    });
  });

  group('controls that hold text grow with it', () {
    for (final (scale, name) in [
      (1.0, '100 %'),
      (1.15, '115 %'),
      (1.3, '130 %'),
    ]) {
      testWidgets('at $name', (tester) async {
        await pumpDesign(
          tester,
          Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              for (final size in AppButtonSize.values)
                AppButton(
                  key: ValueKey(size),
                  label: 'Watch channel',
                  size: size,
                  onPressed: () {},
                ),
              AppChip(key: const Key('chip'), label: 'Sport', onPressed: () {}),
              const SizedBox(
                width: 320,
                child: AppTextField(key: Key('field'), label: 'Name'),
              ),
              SearchField(key: const Key('search'), onTap: () {}),
            ],
          ),
          textScale: scale,
        );

        expect(tester.takeException(), isNull);
        for (final size in AppButtonSize.values) {
          expect(
            tester.getSize(find.byKey(ValueKey(size))).height,
            closeTo(size.height * scale, 1e-6),
            reason: '$size',
          );
        }
        expect(
          tester.getSize(find.byKey(const Key('chip'))).height,
          closeTo(34 * scale, 1e-6),
        );
        expect(
          tester.getSize(find.byKey(const Key('search'))).height,
          closeTo(40 * scale, 1e-6),
        );
      });
    }
  });

  group('rows', () {
    Future<void> row(
      WidgetTester tester, {
      required double scale,
      AppDensity density = AppDensity.comfortable,
    }) => pumpDesign(
      tester,
      SizedBox(
        width: 520,
        child: ChannelRow(
          name: 'Northwind Sports 1',
          number: 1284,
          nowTitle: 'Continental Cup · Semi-final',
          progress: 0.4,
          timeLeft: '1 h 24 min left',
          onPressed: () {},
        ),
      ),
      density: density,
      textScale: scale,
    );

    testWidgets(
      'a channel row is 56 px, and 72.8 at 130 %; its logo stays 40',
      (tester) async {
        await row(tester, scale: 1);
        expect(tester.getSize(find.byType(ChannelRow)).height, 56);
        expect(tester.getSize(find.byType(ChannelLogo)), const Size(40, 40));

        await row(tester, scale: 1.3);
        expect(tester.takeException(), isNull);
        expect(
          tester.getSize(find.byType(ChannelRow)).height,
          closeTo(72.8, 1e-6),
        );
        expect(tester.getSize(find.byType(ChannelLogo)), const Size(40, 40));
      },
    );

    testWidgets('Compact is 44 px, and grows the same way', (tester) async {
      await row(tester, scale: 1, density: AppDensity.compact);
      expect(tester.getSize(find.byType(ChannelRow)).height, 44);

      await row(tester, scale: 1.3, density: AppDensity.compact);
      expect(tester.takeException(), isNull);
      expect(
        tester.getSize(find.byType(ChannelRow)).height,
        closeTo(57.2, 1e-6),
      );
    });

    for (final scale in [1.0, 1.15, 1.3]) {
      testWidgets('a channel number of any length is one line at $scale: '
          "your provider's list passes 10,000", (tester) async {
        for (final number in [7, 128, 1284, 12610, 104857]) {
          await pumpDesign(
            tester,
            SizedBox(
              width: 520,
              child: ChannelRow(
                name: 'Northwind Sports 1',
                number: number,
                onPressed: () {},
              ),
            ),
            textScale: scale,
          );

          final slot = tester.renderObject<RenderParagraph>(
            find.text('$number'),
          );
          expect(tester.takeException(), isNull);
          expect(
            slot.size.height,
            closeTo(18 * scale, 1),
            reason: '$number wrapped',
          );
          expect(slot.didExceedMaxLines, isFalse, reason: '$number is cut');
        }
      });
    }

    testWidgets("up to three digits the number keeps the canvas's 32 px", (
      tester,
    ) async {
      expect(ChannelRow.numberWidth(7), 32);
      expect(ChannelRow.numberWidth(999), 32);
      expect(ChannelRow.numberWidth(1000), greaterThan(32));
    });

    testWidgets('a channel tile asks for its height', (tester) async {
      late double usual;
      late double large;
      await pumpDesign(
        tester,
        Builder(
          builder: (context) {
            usual = ChannelTile.heightOf(context);
            return const SizedBox.shrink();
          },
        ),
      );
      await pumpDesign(
        tester,
        Builder(
          builder: (context) {
            large = ChannelTile.heightOf(context);
            return const SizedBox.shrink();
          },
        ),
        textScale: 1.3,
      );

      expect(usual, 84);
      expect(large, closeTo(109.2, 1e-6));
    });
  });

  group('pictures keep their size', () {
    testWidgets('a poster; an icon button grows as a button does', (
      tester,
    ) async {
      await pumpDesign(
        tester,
        Row(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            AppIconButton(
              icon: AppIcons.search,
              tooltip: 'Search',
              onPressed: () {},
            ),
            const PosterCard(title: 'Glass Tide', meta: '2025'),
          ],
        ),
        textScale: 1.3,
      );

      expect(tester.takeException(), isNull);
      // As tall as a text button beside it at this size (ADR-029: ☆ was
      // shorter than Play on a TV), its icon the same 20 px.
      expect(tester.getSize(find.byType(AppIconButton)), const Size(52, 52));
      expect(
        tester
            .getSize(
              find.descendant(
                of: find.byType(AppIconButton),
                matching: find.byType(AppIcon),
              ),
            )
            .width,
        20,
      );
      // The artwork is 160 × 240 whatever the text; the card under it
      // grows by its two lines.
      final card = tester.getSize(find.byType(PosterCard));
      expect(card.width, 160);
      expect(card.height, greaterThan(240 + (20 + 18) * 1.3));
    });
  });

  group('a segmented control', () {
    Widget control() => SegmentedControl<int>(
      options: const [
        SegmentOption(value: 0, label: 'System'),
        SegmentOption(value: 1, label: '12-hour'),
        SegmentOption(value: 2, label: '24-hour'),
      ],
      value: 0,
      onChanged: (_) {},
    );

    testWidgets('is one line where it fits', (tester) async {
      await pumpDesign(tester, control());

      final tops = {
        for (final label in ['System', '12-hour', '24-hour'])
          tester.getTopLeft(find.text(label)).dy,
      };
      expect(tops, hasLength(1));
    });

    testWidgets('wraps where it does not, and never overflows', (tester) async {
      await pumpDesign(
        tester,
        SizedBox(width: 150, child: control()),
        textScale: 1.3,
      );

      expect(tester.takeException(), isNull);
      final tops = {
        for (final label in ['System', '12-hour', '24-hour'])
          tester.getTopLeft(find.text(label)).dy,
      };
      expect(tops.length, greaterThan(1));
    });

    testWidgets('draws an accent as a dot of its color', (tester) async {
      await pumpDesign(
        tester,
        SegmentedControl<AppAccent>(
          options: [
            for (final accent in AppAccent.values)
              SegmentOption(
                value: accent,
                label: accent.label,
                swatch: accent.base,
              ),
          ],
          value: AppAccent.blue,
          onChanged: (_) {},
        ),
      );

      final dots = tester
          .widgetList<Container>(find.byType(Container))
          .map((container) => container.decoration)
          .whereType<BoxDecoration>()
          .where((decoration) => decoration.shape == BoxShape.circle)
          .map((decoration) => decoration.color)
          .toList();
      expect(dots, [for (final accent in AppAccent.values) accent.base]);
    });
  });
}
