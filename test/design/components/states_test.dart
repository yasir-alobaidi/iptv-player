import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:iptv_player/design/components.dart';
import 'package:iptv_player/design/tokens.dart';

import '../design_harness.dart';

void main() {
  group('EmptyState', () {
    testWidgets('offers the next action (no dead ends)', (tester) async {
      var actions = 0;
      await pumpDesign(
        tester,
        EmptyState(
          icon: Icons.download_rounded,
          title: 'Nothing downloading',
          message: 'Press D on a movie or episode to download it.',
          actionLabel: 'Open Movies',
          onAction: () => actions++,
        ),
      );

      expect(find.text('Nothing downloading'), findsOneWidget);
      expect(find.byIcon(Icons.download_rounded), findsOneWidget);

      await tester.tap(find.text('Open Movies'));
      await tester.pump();
      expect(actions, 1);
    });

    testWidgets('works without an icon or an action', (tester) async {
      await pumpDesign(tester, const EmptyState(title: 'No channels'));

      expect(find.text('No channels'), findsOneWidget);
      expect(find.byType(AppButton), findsNothing);
    });
  });

  group('ErrorState', () {
    testWidgets('shows a human message and retries', (tester) async {
      var retries = 0;
      await pumpDesign(
        tester,
        ErrorState(
          title: "Couldn't reach the provider",
          message: 'Check your connection and try again.',
          onRetry: () => retries++,
        ),
      );

      expect(find.text("Couldn't reach the provider"), findsOneWidget);
      await tester.tap(find.text('Retry'));
      await tester.pump();
      expect(retries, 1);
    });

    testWidgets('details stay hidden until asked for', (tester) async {
      const details = 'SocketException: Connection refused';
      await pumpDesign(
        tester,
        const ErrorState(
          title: "Couldn't reach the provider",
          details: details,
        ),
      );

      expect(find.text(details), findsNothing);

      await tester.tap(find.text('Details'));
      await tester.pumpAndSettle();
      expect(find.text(details), findsOneWidget);

      await tester.tap(find.text('Hide details'));
      await tester.pumpAndSettle();
      expect(find.text(details), findsNothing);
    });

    testWidgets('without details there is no disclosure', (tester) async {
      await pumpDesign(
        tester,
        ErrorState(title: 'Sync failed', onRetry: () {}),
      );

      expect(find.text('Details'), findsNothing);
    });
  });

  group('ProgressBar', () {
    testWidgets('determinate reports its value', (tester) async {
      await pumpDesign(
        tester,
        const SizedBox(width: 200, child: ProgressBar(value: 0.35)),
      );

      expect(
        tester
            .widget<LinearProgressIndicator>(
              find.byType(LinearProgressIndicator),
            )
            .value,
        0.35,
      );
    });

    testWidgets('indeterminate stands still under reduce motion', (
      tester,
    ) async {
      await pumpDesign(
        tester,
        const SizedBox(width: 200, child: ProgressBar()),
        reduceMotion: true,
      );

      expect(find.byType(LinearProgressIndicator), findsNothing);
      expect(find.byType(FractionallySizedBox), findsOneWidget);
    });
  });

  group('Skeleton', () {
    testWidgets('shimmers with full motion', (tester) async {
      await pumpDesign(tester, const Skeleton(width: 120));
      await tester.pump(const Duration(milliseconds: 100));

      final box = tester.widget<DecoratedBox>(
        find.descendant(
          of: find.byType(Skeleton),
          matching: find.byType(DecoratedBox),
        ),
      );
      expect((box.decoration as BoxDecoration).gradient, isNotNull);
    });

    testWidgets('is a flat block under reduce motion', (tester) async {
      await pumpDesign(tester, const Skeleton(width: 120), reduceMotion: true);

      final box = tester.widget<DecoratedBox>(
        find.descendant(
          of: find.byType(Skeleton),
          matching: find.byType(DecoratedBox),
        ),
      );
      final decoration = box.decoration as BoxDecoration;
      expect(decoration.gradient, isNull);
      expect(decoration.color, AppTokens.defaults().colors.surface3);
    });

    testWidgets('the row skeleton follows the density token', (tester) async {
      await pumpDesign(
        tester,
        const SizedBox(width: 280, child: SkeletonRow()),
        density: AppDensity.compact,
      );

      expect(
        tester.getSize(find.byType(SkeletonRow)).height,
        AppDensity.compact.rowHeight,
      );
    });
  });
}
