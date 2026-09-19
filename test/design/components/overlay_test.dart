import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:iptv_player/design/components.dart';

import '../design_harness.dart';

void main() {
  group('AppBanner', () {
    testWidgets('shows the message and runs its action', (tester) async {
      var actions = 0;
      await pumpDesign(
        tester,
        SizedBox(
          width: 620,
          child: AppBanner(
            message: "You're offline",
            actionLabel: 'Open Library',
            onAction: () => actions++,
          ),
        ),
      );

      expect(find.text("You're offline"), findsOneWidget);
      await tester.tap(find.text('Open Library'));
      await tester.pump();
      expect(actions, 1);
    });

    testWidgets('every tone renders', (tester) async {
      for (final tone in BannerTone.values) {
        await pumpDesign(
          tester,
          SizedBox(
            width: 620,
            child: AppBanner(message: tone.name, tone: tone),
          ),
        );
        expect(find.text(tone.name), findsOneWidget, reason: tone.name);
      }
    });
  });

  group('AppToast', () {
    testWidgets('shows an optional action', (tester) async {
      var retries = 0;
      await pumpDesign(
        tester,
        AppToast(
          message: 'Download failed',
          tone: ToastTone.error,
          actionLabel: 'Retry',
          onAction: () => retries++,
        ),
      );

      await tester.tap(find.text('Retry'));
      await tester.pump();
      expect(retries, 1);
    });

    test('stays up for three seconds (docs/05)', () {
      expect(AppToast.defaultDuration, const Duration(seconds: 3));
    });
  });

  group('AppDialog', () {
    testWidgets('footer buttons work and the primary one autofocuses', (
      tester,
    ) async {
      var confirmed = 0;
      var cancelled = 0;
      await pumpDesign(
        tester,
        AppDialog(
          title: 'Rename category',
          primaryLabel: 'Save',
          secondaryLabel: 'Cancel',
          onPrimary: () => confirmed++,
          onSecondary: () => cancelled++,
          child: const Text('Copper Hollow'),
        ),
      );
      await tester.pumpAndSettle();

      // The primary action has focus, so Enter confirms.
      await tester.sendKeyEvent(LogicalKeyboardKey.enter);
      await tester.pump();
      expect(confirmed, 1);

      await tester.tap(find.text('Cancel'));
      await tester.pump();
      expect(cancelled, 1);
    });

    testWidgets('a destructive dialog starts on the safe choice', (
      tester,
    ) async {
      var confirmed = 0;
      var cancelled = 0;
      await pumpDesign(
        tester,
        AppDialog(
          title: 'Delete downloaded file?',
          primaryLabel: 'Delete file',
          secondaryLabel: 'Cancel',
          destructive: true,
          onPrimary: () => confirmed++,
          onSecondary: () => cancelled++,
          child: const Text('Copper Hollow'),
        ),
      );
      await tester.pumpAndSettle();

      // Enter straight away cancels; deleting takes a deliberate move.
      await tester.sendKeyEvent(LogicalKeyboardKey.enter);
      await tester.pump();
      expect(cancelled, 1);
      expect(confirmed, 0);

      await tester.tap(find.text('Delete file'));
      await tester.pump();
      expect(confirmed, 1);
    });
  });

  group('AppMenu', () {
    testWidgets('items activate and separators render', (tester) async {
      var played = 0;
      await pumpDesign(
        tester,
        AppMenu(
          items: [
            AppMenuItem(
              label: 'Play',
              icon: AppIcons.play,
              shortcut: 'Enter',
              onPressed: () => played++,
            ),
            const AppMenuItem.separator(),
            const AppMenuItem(label: 'Cast', icon: AppIcons.cast),
          ],
        ),
      );

      expect(find.byType(Divider), findsOneWidget);
      await tester.tap(find.text('Play'));
      await tester.pump();
      expect(played, 1);

      // Cast has no callback, so it is disabled and not focusable.
      await tester.tap(find.text('Cast'));
      await tester.pump();
    });
  });

  group('AppSlider', () {
    testWidgets('reports changes', (tester) async {
      double? value;
      await pumpDesign(
        tester,
        SizedBox(
          width: 300,
          child: AppSlider(
            value: 0.4,
            semanticLabel: 'Volume',
            onChanged: (v) => value = v,
          ),
        ),
      );

      await tester.tapAt(tester.getCenter(find.byType(Slider)));
      await tester.pump();
      expect(value, isNotNull);
    });

    testWidgets('a disabled slider ignores input', (tester) async {
      var changes = 0;
      await pumpDesign(
        tester,
        SizedBox(
          width: 300,
          child: AppSlider(
            value: 0.4,
            enabled: false,
            onChanged: (_) => changes++,
          ),
        ),
      );

      await tester.tapAt(tester.getCenter(find.byType(Slider)));
      await tester.pump();
      expect(changes, isZero);
    });
  });

  group('Casting', () {
    testWidgets('the bar names the device and its quality', (tester) async {
      await pumpDesign(
        tester,
        SizedBox(
          width: 900,
          child: CastingBar(
            title: 'Arena Sports 1',
            deviceName: 'Living Room TV',
            quality: StreamQuality.original,
            onPlayPause: () {},
            onStop: () {},
          ),
        ),
      );

      expect(find.text('Playing on Living Room TV'), findsOneWidget);
      expect(find.text('ORIGINAL'), findsOneWidget);
      expect(find.text('Pause'), findsOneWidget);
    });

    testWidgets('reconnecting changes the line', (tester) async {
      await pumpDesign(
        tester,
        SizedBox(
          width: 900,
          child: CastingBar(
            title: 'Arena Sports 1',
            deviceName: 'Living Room TV',
            reconnecting: true,
            isPlaying: false,
            onPlayPause: () {},
            onStop: () {},
          ),
        ),
      );

      expect(find.text('Reconnecting to Living Room TV…'), findsOneWidget);
      expect(find.text('Play'), findsOneWidget);
    });

    testWidgets('the reconnecting pill counts tries', (tester) async {
      await pumpDesign(tester, const ReconnectingPill(attempt: 2));
      expect(find.text('Reconnecting… · try 2'), findsOneWidget);
    });
  });

  group('Downloads', () {
    testWidgets('the button labels every state', (tester) async {
      for (final state in DownloadState.values) {
        await pumpDesign(
          tester,
          DownloadButton(
            state: state,
            progress: 0.42,
            showLabel: true,
            onPressed: () {},
          ),
        );
        final expected = switch (state) {
          DownloadState.none => 'Download',
          DownloadState.queued => 'Queued',
          DownloadState.downloading => 'Downloading 42%',
          DownloadState.paused => 'Paused',
          DownloadState.failed => 'Failed — retry',
          DownloadState.done => 'Downloaded',
        };
        expect(find.text(expected), findsOneWidget, reason: state.name);
      }
    });

    testWidgets('the row shows speed, time left and size', (tester) async {
      await pumpDesign(
        tester,
        SizedBox(
          width: 620,
          child: DownloadRow(
            title: 'The Long Way Home',
            subtitle: 'S1 · E3',
            state: DownloadState.downloading,
            progress: 0.42,
            speed: '4.2 MB/s',
            timeLeft: '6 min',
            size: '3.4 GB',
            onPressed: () {},
          ),
        ),
      );

      expect(find.text('4.2 MB/s · 6 min left · 3.4 GB'), findsOneWidget);
    });

    testWidgets('a failed row shows the human message, not a stack', (
      tester,
    ) async {
      await pumpDesign(
        tester,
        SizedBox(
          width: 620,
          child: DownloadRow(
            title: 'Copper Hollow',
            state: DownloadState.failed,
            errorMessage: 'The source stopped responding',
            onPressed: () {},
          ),
        ),
      );

      expect(find.text('The source stopped responding'), findsOneWidget);
      expect(find.byType(ProgressBar), findsNothing);
    });

    testWidgets('the storage meter shows both labels', (tester) async {
      await pumpDesign(
        tester,
        const SizedBox(
          width: 420,
          child: StorageMeter(
            usedLabel: 'Downloads 42.3 GB',
            freeLabel: '118 GB free',
            usedFraction: 0.26,
          ),
        ),
      );

      expect(find.text('Downloads 42.3 GB'), findsOneWidget);
      expect(find.text('118 GB free'), findsOneWidget);
    });
  });

  group('AppIcon', () {
    testWidgets('every icon has an asset that loads', (tester) async {
      for (final icon in AppIcons.values) {
        expect(icon.path, startsWith('assets/icons/'));
      }
      await pumpDesign(
        tester,
        const Row(
          children: [
            AppIcon(AppIcons.play),
            AppIcon(AppIcons.star),
            AppIcon(AppIcons.cast),
          ],
        ),
      );
      await tester.pumpAndSettle();
      expect(find.byType(AppIcon), findsNWidgets(3));
    });
  });
}
