import 'dart:async';

import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:iptv_player/app/destinations.dart';
import 'package:iptv_player/core/images/artwork_store.dart';
import 'package:iptv_player/core/result.dart';
import 'package:iptv_player/design/appearance.dart';
import 'package:iptv_player/design/components.dart';
import 'package:iptv_player/design/tokens.dart';
import 'package:iptv_player/features/guide/domain/epg.dart';
import 'package:iptv_player/features/settings/data/data_providers.dart';
import 'package:iptv_player/features/settings/domain/settings_export.dart';
import 'package:iptv_player/features/settings/domain/settings_transfer.dart';
import 'package:iptv_player/features/settings/presentation/data_section.dart';
import 'package:iptv_player/features/sources/presentation/source_shell_slots.dart';

import '../../../app/app_harness.dart';
import '../../casting/support/cast_ui_harness.dart' show focusedLabelOf;
import '../../guide/presentation/guide_settings_fakes.dart';
import '../../onboarding/onboarding_fakes.dart';
import '../appearance_fakes.dart';
import '../data_fakes.dart';

void main() {
  late GuideFakes fakes;
  late FakeArtworkStore pictures;
  late FakeTransfer transfer;
  late ScriptedAppearanceStore appearance;
  String? savePath;
  String? openPath;
  final saveNames = <String>[];

  final guide = GuideCoverage(
    lastImport: GuideImport(
      id: 4,
      outcome: GuideImportOutcome.succeeded,
      startedAt: DateTime.utc(2026, 9, 14, 10),
      finishedAt: DateTime.utc(2026, 9, 14, 10),
      isLive: true,
    ),
    updatedAt: DateTime.utc(2026, 9, 14, 10),
    guideChannels: 1290,
    programmes: 142880,
    lastEnd: DateTime(2026, 10, 19, 6),
  );

  setUp(() {
    fakes = GuideFakes(OnboardingFakes()..now = DateTime(2026, 10, 13, 9));
    fakes.base.sources.seed();
    fakes.guide.setCoverage('src-1', guide);
    pictures = FakeArtworkStore();
    transfer = FakeTransfer();
    appearance = ScriptedAppearanceStore();
    savePath = '/home/me/Documents/export.json';
    openPath = '/home/me/Documents/iptv-player-settings-2026-10-12.json';
    saveNames.clear();
  });

  /// Settings → Data.
  Future<void> open(
    WidgetTester tester, {
    Size size = const Size(1440, 900),
  }) async {
    await pumpApp(
      tester,
      initialLocation: AppDestination.settings.path,
      size: size,
      withAppearance: true,
      overrides: [
        ...fakes.overrides,
        ...sourceShellOverrides,
        ...appearanceOverrides(store: appearance),
        artworkStoreProvider.overrideWithValue(pictures),
        settingsTransferProvider.overrideWithValue(transfer),
        settingsSavePickerProvider.overrideWithValue((name) async {
          saveNames.add(name);
          return savePath;
        }),
        settingsOpenPickerProvider.overrideWithValue(() async => openPath),
      ],
    );
    await tester.tap(find.text('Data').first);
    await settleApp(tester);
    await settleApp(tester);
  }

  Future<void> tabTo(WidgetTester tester, String label) async {
    for (var i = 0; i < 40; i++) {
      if (focusedLabelOf(tester) == label) return;
      await tester.sendKeyEvent(LogicalKeyboardKey.tab);
      await tester.pump();
    }
    fail('Tab never reached "$label" (on ${focusedLabelOf(tester)})');
  }

  Future<void> press(WidgetTester tester, LogicalKeyboardKey key) async {
    await tester.sendKeyEvent(key);
    await settleApp(tester);
    await settleApp(tester);
  }

  bool enabled(WidgetTester tester, String label) =>
      tester
          .widget<AppButton>(find.widgetWithText(AppButton, label))
          .onPressed !=
      null;

  group('what the page says', () {
    testWidgets('the pictures kept, the guide and what a file holds', (
      tester,
    ) async {
      await open(tester);

      expect(find.byType(DataSection), findsOneWidget);
      expect(
        find.text(
          'Posters, logos and stills kept on this computer. 412 MB of 500 MB.',
        ),
        findsOneWidget,
      );
      expect(
        find.textContaining('142,880 programmes until Oct 19.'),
        findsOneWidget,
      );
      expect(
        find.textContaining('Never passwords, usernames or addresses.'),
        findsOneWidget,
      );
      for (final label in ['Clear', 'Clear guide', 'Export…', 'Import…']) {
        expect(enabled(tester, label), isTrue, reason: label);
      }
    });

    testWidgets('while the pictures are measured it says so, and Clear waits', (
      tester,
    ) async {
      pictures.gate = Completer<void>();
      await open(tester);

      expect(find.textContaining('Measuring them…'), findsOneWidget);
      expect(enabled(tester, 'Clear'), isFalse);

      pictures.gate!.complete();
      await settleApp(tester);
      expect(find.textContaining('412 MB of 500 MB.'), findsOneWidget);
      expect(enabled(tester, 'Clear'), isTrue);
    });

    testWidgets('nothing kept and no guide: each says so, and there is '
        'nothing to clear', (tester) async {
      pictures.bytes = 0;
      fakes.guide.setCoverage('src-1', const GuideCoverage());
      await open(tester);

      expect(find.textContaining('None are kept right now.'), findsOneWidget);
      expect(find.text('There is no guide on this computer.'), findsOneWidget);
      expect(enabled(tester, 'Clear'), isFalse);
      expect(enabled(tester, 'Clear guide'), isFalse);
      // A file can still be made and read.
      expect(enabled(tester, 'Export…'), isTrue);
      expect(enabled(tester, 'Import…'), isTrue);
    });

    testWidgets("pictures that can't be measured say so in plain words, and "
        'can still be cleared', (tester) async {
      pictures.usageFailure = StorageFailure('EACCES /home/me/.cache');
      await open(tester);

      expect(find.textContaining("Couldn't measure them."), findsOneWidget);
      expect(find.textContaining('EACCES'), findsNothing);
      expect(enabled(tester, 'Clear'), isTrue);
    });

    testWidgets('while a guide is being imported it can’t be cleared', (
      tester,
    ) async {
      fakes.guide.setCoverage(
        'src-1',
        GuideCoverage(
          lastImport: GuideImport(
            id: 5,
            outcome: GuideImportOutcome.running,
            startedAt: DateTime.utc(2026, 10, 13),
          ),
          programmes: 142880,
          guideChannels: 1290,
        ),
      );
      await open(tester);

      expect(
        find.text(
          'A guide is being imported. It can be cleared once that is done.',
        ),
        findsOneWidget,
      );
      expect(enabled(tester, 'Clear guide'), isFalse);
    });
  });

  group('Clear', () {
    testWidgets('asks first with Keep focused; Enter keeps everything', (
      tester,
    ) async {
      await open(tester);
      await tabTo(tester, 'Clear');
      await press(tester, LogicalKeyboardKey.enter);

      expect(find.text('Clear the kept pictures?'), findsOneWidget);
      expect(
        find.textContaining('412 MB of pictures will be deleted'),
        findsOneWidget,
      );
      expect(focusedLabelOf(tester), 'Keep');

      await press(tester, LogicalKeyboardKey.enter);

      expect(find.text('Clear the kept pictures?'), findsNothing);
      expect(pictures.clears, 0);
      expect(focusedLabelOf(tester), 'Clear', reason: 'back where it was');
    });

    testWidgets('Esc keeps everything too', (tester) async {
      await open(tester);
      await tabTo(tester, 'Clear');
      await press(tester, LogicalKeyboardKey.enter);

      await press(tester, LogicalKeyboardKey.escape);

      expect(find.text('Clear the kept pictures?'), findsNothing);
      expect(pictures.clears, 0);
    });

    testWidgets('chosen, it clears, says how much was freed, and the page '
        'says none are kept', (tester) async {
      await open(tester);
      await tabTo(tester, 'Clear');
      await press(tester, LogicalKeyboardKey.enter);
      await tabTo(tester, 'Clear');
      expect(
        find.ancestor(
          of: find.byWidget(
            FocusManager.instance.primaryFocus!.context!.widget,
          ),
          matching: find.byType(AppDialog),
        ),
        findsOneWidget,
        reason: "the dialog's own Clear",
      );
      await press(tester, LogicalKeyboardKey.enter);

      expect(pictures.clears, 1);
      expect(find.text('Pictures cleared · 412 MB freed'), findsOneWidget);
      expect(find.textContaining('None are kept right now.'), findsOneWidget);
      expect(enabled(tester, 'Clear'), isFalse);
      // Clear has nothing left to do, so the focus is on the next button
      // rather than nowhere.
      expect(focusedLabelOf(tester), 'Clear guide');
    });

    testWidgets('a clear that fails says so in plain words', (tester) async {
      pictures.clearFailure = StorageFailure('EBUSY');
      await open(tester);
      await tester.tap(find.widgetWithText(AppButton, 'Clear'));
      await settleApp(tester);
      await tester.tap(find.widgetWithText(AppButton, 'Clear').last);
      await settleApp(tester);
      await settleApp(tester);

      expect(
        find.textContaining("Couldn't clear the pictures."),
        findsOneWidget,
      );
      expect(find.textContaining('EBUSY'), findsNothing);
    });
  });

  group('Clear guide', () {
    testWidgets('asks first with Keep focused, then clears every source’s '
        'guide and says it comes back', (tester) async {
      fakes.base.sources.seed(id: 'src-2', name: 'Backup');
      fakes.guide.setCoverage('src-2', guide);
      await open(tester);
      expect(find.textContaining('285,760 programmes'), findsOneWidget);

      await tabTo(tester, 'Clear guide');
      await press(tester, LogicalKeyboardKey.enter);
      expect(find.text('Clear the guide?'), findsOneWidget);
      expect(find.textContaining('Your channel matches stay'), findsOneWidget);
      expect(focusedLabelOf(tester), 'Keep');

      await tabTo(tester, 'Clear guide');
      await press(tester, LogicalKeyboardKey.enter);

      expect(fakes.guide.cleared, ['src-1', 'src-2']);
      expect(
        find.text('Guide cleared. It comes back at its next refresh.'),
        findsOneWidget,
      );
      expect(find.text('There is no guide on this computer.'), findsOneWidget);
    });

    testWidgets('a clear that fails says so', (tester) async {
      fakes.guide.clearFailure = StorageFailure('locked');
      await open(tester);
      await tester.tap(find.widgetWithText(AppButton, 'Clear guide'));
      await settleApp(tester);
      await tester.tap(find.widgetWithText(AppButton, 'Clear guide').last);
      await settleApp(tester);
      await settleApp(tester);

      expect(
        find.textContaining("Couldn't clear the whole guide."),
        findsOneWidget,
      );
      expect(find.textContaining('142,880 programmes'), findsOneWidget);
    });
  });

  group('Export…', () {
    testWidgets('asks where, with a dated name, writes there and says what '
        'it wrote', (tester) async {
      await open(tester);
      await tabTo(tester, 'Export…');
      await press(tester, LogicalKeyboardKey.enter);

      expect(saveNames, ['iptv-player-settings-2026-10-13.json']);
      expect(transfer.exported, ['/home/me/Documents/export.json']);
      // The button was busy for a moment; the focus is back on it.
      expect(focusedLabelOf(tester), 'Export…');
      expect(
        find.text(
          'Exported your settings and choices · 2 sources · 212 favorites',
        ),
        findsOneWidget,
      );
    });

    testWidgets('a dialog closed without choosing writes nothing', (
      tester,
    ) async {
      savePath = null;
      await open(tester);
      await tabTo(tester, 'Export…');
      await press(tester, LogicalKeyboardKey.enter);

      expect(transfer.exported, isEmpty);
      expect(find.textContaining('Exported'), findsNothing);
      expect(enabled(tester, 'Export…'), isTrue);
    });

    testWidgets("a file that can't be written says so, and the line can be "
        'closed', (tester) async {
      transfer.exportFailure = StorageFailure('EROFS /media/usb');
      await open(tester);
      await tabTo(tester, 'Export…');
      await press(tester, LogicalKeyboardKey.enter);

      expect(find.textContaining("Couldn't write that file."), findsOneWidget);
      expect(find.textContaining('EROFS'), findsNothing);

      await tester.tap(find.bySemanticsLabel('Dismiss'));
      await settleApp(tester);
      expect(find.textContaining("Couldn't write that file."), findsNothing);
    });
  });

  group('Import…', () {
    testWidgets('shows what it will do first: the settings replaced, the '
        'source here with its counts, the source that isn’t here named — '
        'with Cancel focused', (tester) async {
      transfer.reading = SettingsFileReadable(sketchPlan());
      await open(tester);
      await tabTo(tester, 'Import…');
      await press(tester, LogicalKeyboardKey.enter);

      expect(
        find.text('Import "iptv-player-settings-2026-10-12.json"?'),
        findsOneWidget,
      );
      expect(find.text("replaced with the file's"), findsOneWidget);
      expect(
        find.text(
          '212 favorites · 3 groups · 41 hidden categories · 9 guide matches',
        ),
        findsOneWidget,
      );
      expect(find.text('Harbor IPTV'), findsOneWidget);
      expect(
        find.text(
          'not on this computer — add it under Sources, then import again',
        ),
        findsOneWidget,
      );
      expect(focusedLabelOf(tester), 'Cancel');

      // Enter straight away changes nothing.
      await press(tester, LogicalKeyboardKey.enter);
      expect(find.byType(ImportPreviewDialog), findsNothing);
      expect(transfer.applied, isEmpty);
      expect(focusedLabelOf(tester), 'Import…');
    });

    testWidgets('Import applies it, says what came over, matches the '
        "source's channels again, and the new look shows at once", (
      tester,
    ) async {
      transfer.reading = SettingsFileReadable(sketchPlan());
      await open(tester);
      BuildContext page() => tester.element(find.byType(DataSection));
      expect(page().tokens.colors.accent, AppAccent.blue);
      await tabTo(tester, 'Import…');
      await press(tester, LogicalKeyboardKey.enter);
      // What a real import leaves in the store.
      appearance.stored = const AppearanceSettings(accent: AppAccent.rose);

      await tabTo(tester, 'Import');
      await press(tester, LogicalKeyboardKey.enter);

      expect(transfer.applied, hasLength(1));
      expect(
        find.text(
          'Imported · settings replaced · 1 source merged in · 212 '
          'favorites · 9 guide matches · 1 source not on this computer',
        ),
        findsOneWidget,
      );
      expect(fakes.matching.calls, ['src-1']);
      expect(page().tokens.colors.accent, AppAccent.rose);
      expect(focusedLabelOf(tester), 'Import…');
    });

    testWidgets('an import that fails says nothing was changed', (
      tester,
    ) async {
      transfer
        ..reading = SettingsFileReadable(sketchPlan())
        ..applyFailure = StorageFailure('SQLITE_FULL');
      await open(tester);
      await tabTo(tester, 'Import…');
      await press(tester, LogicalKeyboardKey.enter);
      await tabTo(tester, 'Import');
      await press(tester, LogicalKeyboardKey.enter);

      expect(
        find.textContaining(
          "Couldn't import that file, so nothing was changed.",
        ),
        findsOneWidget,
      );
      expect(find.textContaining('SQLITE_FULL'), findsNothing);
      expect(find.textContaining('Imported'), findsNothing);
    });

    for (final (problem, format, words) in [
      (SettingsFileProblem.damaged, null, 'damaged or incomplete'),
      (
        SettingsFileProblem.notOurs,
        null,
        "isn't a settings file from IPTV Player",
      ),
      (SettingsFileProblem.newer, 3, 'newer version of IPTV Player (format 3)'),
    ]) {
      testWidgets('a file that is ${problem.name} is refused with what is '
          'wrong, and nothing is applied', (tester) async {
        transfer.reading = SettingsFileUnusable(problem, format: format);
        await open(tester);
        await tabTo(tester, 'Import…');
        await press(tester, LogicalKeyboardKey.enter);

        expect(find.text("This file can't be imported"), findsOneWidget);
        expect(find.textContaining(words), findsOneWidget);
        expect(focusedLabelOf(tester), 'Close');

        await press(tester, LogicalKeyboardKey.enter);
        expect(find.text("This file can't be imported"), findsNothing);
        expect(transfer.applied, isEmpty);
        expect(enabled(tester, 'Import…'), isTrue);
      });
    }

    testWidgets("a file that can't be opened says so on the page", (
      tester,
    ) async {
      transfer.reading = SettingsFileUnread(StorageFailure('ENOENT'));
      await open(tester);
      await tabTo(tester, 'Import…');
      await press(tester, LogicalKeyboardKey.enter);

      expect(find.textContaining("Couldn't read that file."), findsOneWidget);
      expect(find.textContaining('ENOENT'), findsNothing);
    });

    testWidgets('a file with nothing for this computer offers only Close', (
      tester,
    ) async {
      final plan = sketchPlan(settings: false);
      transfer.reading = SettingsFileReadable(
        ImportPlan(
          path: plan.path,
          file: plan.file,
          sources: [
            for (final source in plan.sources)
              ImportSourcePlan(exported: source.exported),
          ],
        ),
      );
      await open(tester);
      await tabTo(tester, 'Import…');
      await press(tester, LogicalKeyboardKey.enter);

      expect(
        find.text('Nothing in this file can be brought over to this computer.'),
        findsOneWidget,
      );
      expect(find.widgetWithText(AppButton, 'Import'), findsNothing);
      expect(focusedLabelOf(tester), 'Close');
    });

    testWidgets('a dialog closed without choosing reads nothing', (
      tester,
    ) async {
      openPath = null;
      await open(tester);
      await tabTo(tester, 'Import…');
      await press(tester, LogicalKeyboardKey.enter);

      expect(find.byType(ImportPreviewDialog), findsNothing);
      expect(enabled(tester, 'Import…'), isTrue);
    });
  });

  testWidgets('every control is reached by Tab, in the order the page reads', (
    tester,
  ) async {
    await open(tester);
    Focus.of(tester.element(find.text('Data').first)).requestFocus();
    await tester.pump();
    await tabTo(tester, 'Clear');

    final walked = <String?>['Clear'];
    for (var i = 0; i < 3; i++) {
      await tester.sendKeyEvent(LogicalKeyboardKey.tab);
      await tester.pump();
      walked.add(focusedLabelOf(tester));
    }

    expect(walked, ['Clear', 'Clear guide', 'Export…', 'Import…']);
  });

  testWidgets('at 130 % in the smallest window nothing overflows', (
    tester,
  ) async {
    appearance.stored = const AppearanceSettings(textSize: TextSizeChoice.s130);
    transfer.reading = SettingsFileReadable(sketchPlan());
    await open(tester, size: const Size(1024, 640));
    expect(tester.takeException(), isNull);

    await tabTo(tester, 'Import…');
    await press(tester, LogicalKeyboardKey.enter);

    expect(tester.takeException(), isNull);
    expect(find.byType(ImportPreviewDialog), findsOneWidget);
  });
}
