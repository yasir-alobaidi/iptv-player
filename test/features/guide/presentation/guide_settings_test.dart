import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:iptv_player/app/destinations.dart';
import 'package:iptv_player/app/router.dart';
import 'package:iptv_player/core/result.dart';
import 'package:iptv_player/design/components.dart';
import 'package:iptv_player/features/guide/domain/epg.dart';
import 'package:iptv_player/features/guide/domain/epg_matcher.dart';
import 'package:iptv_player/features/guide/domain/guide_settings.dart';
import 'package:iptv_player/features/guide/presentation/guide_match_picker.dart';
import 'package:iptv_player/features/guide/presentation/guide_match_request.dart';
import 'package:iptv_player/features/settings/presentation/settings_screen.dart';
import 'package:iptv_player/features/settings/presentation/settings_section.dart';
import 'package:iptv_player/features/sources/domain/source.dart';

import '../../../app/app_harness.dart';
import '../../onboarding/onboarding_fakes.dart';
import 'guide_settings_fakes.dart';

void main() {
  late OnboardingFakes base;
  late GuideFakes fakes;
  setUp(() {
    base = OnboardingFakes();
    fakes = GuideFakes(base);
  });

  /// The guide's state arrives a frame before the list that depends on
  /// it, and the list's pages a frame after that.
  Future<void> settle(WidgetTester tester) async {
    await settleApp(tester);
    await settleApp(tester);
  }

  ProviderContainer containerOf(WidgetTester tester) =>
      ProviderScope.containerOf(tester.element(find.byType(SettingsScreen)));

  Future<void> pump(WidgetTester tester) async {
    await pumpApp(
      tester,
      initialLocation: AppDestination.settings.path,
      overrides: fakes.overrides,
    );
    await tester.tap(
      find.descendant(
        of: find.byType(SettingsScreen),
        matching: find.text('Guide'),
      ),
    );
    await settle(tester);
  }

  /// A source with an imported guide, 2 hours old, and four channels:
  /// two unmatched, one matched by name, one by the user.
  void seedGuide() {
    base.sources.seed(lastSyncedAt: base.now);
    fakes.guide
      ..setCoverage(
        'src-1',
        GuideCoverage(
          lastImport: GuideImport(
            id: 4,
            outcome: GuideImportOutcome.succeeded,
            startedAt: base.now.subtract(const Duration(hours: 2)),
            finishedAt: base.now.subtract(const Duration(hours: 2)),
            isLive: true,
          ),
          updatedAt: base.now.subtract(const Duration(hours: 2)),
          guideChannels: 180,
          programmes: 142880,
          lastEnd: DateTime.utc(2026, 9, 21, 12),
          matchedChannels: 2,
          totalChannels: 4,
        ),
      )
      ..setChannels('src-1', [
        guideRow(1, 'Arena Sports 1'),
        guideRow(2, 'Velocity Motors HD'),
        guideRow(3, 'Marlow Drama', xmltvId: 'marlowdrama.uk'),
        guideRow(
          4,
          'Summit Outdoor',
          xmltvId: 'summit.outdoor.uk',
          rule: GuideMatchRule.manual,
          guideLabel: 'Summit Outdoor',
        ),
      ])
      ..candidates['src-1'] = [
        candidate('arenasports1.uk', 'Arena Sports 1', 1),
        candidate('arenasport1.fr', 'Arena Sport 1', 0.8),
        candidate('arenasports2.uk', 'Arena Sports 2', 0.7),
      ];
    fakes.matching.labels['arenasport1.fr'] = 'Arena Sport 1';
    fakes.matching.labels['arenasports1.uk'] = 'Arena Sports 1';
  }

  Finder row(String name) => find.ancestor(
    of: find.text(name),
    matching: find.byType(FocusableSurface),
  );

  group('states', () {
    testWidgets('no source: says so and offers to add one', (tester) async {
      await pump(tester);

      expect(find.text('No guide yet'), findsOneWidget);
      expect(find.text('Add a source'), findsOneWidget);
    });

    testWidgets('loading shows skeletons, then the guide', (tester) async {
      seedGuide();
      final gate = fakes.guide.coverageGate = Completer<void>();
      await pump(tester);
      expect(find.byType(Skeleton), findsWidgets);

      gate.complete();
      await settle(tester);

      expect(
        find.text("From your provider's XMLTV · updated 2 h ago"),
        findsOneWidget,
      );
    });

    testWidgets('a guide: where it came from, what matched, and the list', (
      tester,
    ) async {
      seedGuide();
      await pump(tester);

      expect(
        find.text("From your provider's XMLTV · updated 2 h ago"),
        findsOneWidget,
      );
      expect(
        find.text('2 of 4 channels matched · 142,880 programmes until Sep 21'),
        findsOneWidget,
      );
      expect(find.text('Refresh guide'), findsOneWidget);
      // Unmatched is the first list shown.
      expect(find.text('Arena Sports 1'), findsOneWidget);
      expect(find.text('Velocity Motors HD'), findsOneWidget);
      expect(find.text('Marlow Drama'), findsNothing);
      expect(find.text('No guide channel'), findsNWidgets(2));
      expect(find.text('Match…'), findsNWidgets(2));
      expect(
        find.textContaining("Channels you've hidden aren't listed"),
        findsOneWidget,
      );
    });

    testWidgets('the Matched by you and All lists', (tester) async {
      seedGuide();
      await pump(tester);

      await tester.tap(find.text('Matched by you'));
      await settle(tester);
      expect(find.text('Summit Outdoor'), findsOneWidget);
      expect(find.text('→ Summit Outdoor · yours'), findsOneWidget);
      expect(find.text('Change'), findsOneWidget);
      expect(find.text('Arena Sports 1'), findsNothing);

      await tester.tap(find.text('All'));
      await settle(tester);
      expect(find.text('Marlow Drama'), findsOneWidget);
      expect(find.text('→ marlowdrama.uk · by name'), findsOneWidget);
      expect(find.text('Arena Sports 1'), findsOneWidget);
    });

    testWidgets('the filter narrows the list, and says when nothing is left', (
      tester,
    ) async {
      seedGuide();
      await pump(tester);

      await tester.enterText(find.byType(EditableText).last, 'velo');
      await settle(tester);
      expect(find.text('Velocity Motors HD'), findsOneWidget);
      expect(find.text('Arena Sports 1'), findsNothing);

      await tester.enterText(find.byType(EditableText).last, 'zzz');
      await settle(tester);
      expect(find.text('No channels match "zzz"'), findsOneWidget);
    });

    testWidgets('all matched: says so in the row and the list', (tester) async {
      seedGuide();
      fakes.guide.setChannels('src-1', [
        guideRow(3, 'Marlow Drama', xmltvId: 'marlowdrama.uk'),
      ]);
      await pump(tester);

      expect(find.textContaining('Its one channel is matched'), findsOneWidget);
      expect(find.text('Every channel has a guide'), findsOneWidget);
    });

    testWidgets('no guide imported yet: Import guide, and the list waits', (
      tester,
    ) async {
      base.sources.seed(lastSyncedAt: base.now);
      await pump(tester);

      expect(
        find.text("No guide imported yet. From your provider's XMLTV."),
        findsOneWidget,
      );
      expect(find.text('Import guide'), findsOneWidget);
      expect(find.text('No guide to match against yet'), findsOneWidget);
    });

    testWidgets('importing: progress, Cancel, and the old guide stays', (
      tester,
    ) async {
      seedGuide();
      final gate = fakes.imports.gate = Completer<void>();
      await pump(tester);

      await tester.tap(find.text('Refresh guide'));
      await settle(tester);
      expect(find.text('Importing the guide…'), findsOneWidget);
      expect(
        find.text('The guide in use stays until the new one is in.'),
        findsOneWidget,
      );

      fakes.imports.report(
        'src-1',
        const EpgImportProgress(
          bytesRead: 1024 * 1024,
          totalBytes: 4 * 1024 * 1024,
          programmes: 1204,
        ),
      );
      await settle(tester);
      expect(
        find.text('Importing the guide · 1.0 MB of 4.0 MB · 1,204 programmes'),
        findsOneWidget,
      );

      await tester.tap(find.text('Cancel'));
      await settle(tester);
      expect(fakes.imports.calls, ['import src-1', 'cancel src-1']);

      gate.complete();
      await settle(tester);
      expect(find.text('Refresh guide'), findsOneWidget);
    });

    testWidgets('a first import that failed: the reason and Try again', (
      tester,
    ) async {
      base.sources.seed(lastSyncedAt: base.now);
      fakes.guide.setCoverage(
        'src-1',
        GuideCoverage(
          lastImport: GuideImport(
            id: 1,
            outcome: GuideImportOutcome.failed,
            startedAt: base.now,
            finishedAt: base.now,
            failureCode: 'network',
          ),
        ),
      );
      await pump(tester);

      expect(
        find.textContaining("The guide couldn't be imported. Can't reach"),
        findsOneWidget,
      );
      expect(find.text('Try again'), findsOneWidget);
    });

    testWidgets('a refresh that failed keeps the old guide and says so', (
      tester,
    ) async {
      seedGuide();
      fakes.guide.setCoverage(
        'src-1',
        GuideCoverage(
          lastImport: GuideImport(
            id: 5,
            outcome: GuideImportOutcome.failed,
            startedAt: base.now.subtract(const Duration(minutes: 20)),
            finishedAt: base.now.subtract(const Duration(minutes: 20)),
            failureCode: 'network',
            failureStatus: 503,
          ),
          updatedAt: base.now.subtract(const Duration(hours: 26)),
          guideChannels: 180,
          programmes: 900,
          matchedChannels: 2,
          totalChannels: 4,
        ),
      );
      await pump(tester);

      expect(find.textContaining('updated yesterday'), findsOneWidget);
      expect(
        find.textContaining('The last refresh failed 20 min ago'),
        findsOneWidget,
      );
      expect(find.textContaining('HTTP 503'), findsOneWidget);
      expect(
        find.textContaining('The guide above stays in use'),
        findsOneWidget,
      );
    });

    testWidgets('a playlist that names no guide: Edit source', (tester) async {
      base.sources.seed(type: SourceType.m3uUrl);
      fakes.imports.origins['src-1'] = Err(
        NotFoundFailure('the source has no guide URL'),
      );
      await pump(tester);

      expect(
        find.textContaining("This playlist doesn't name a guide"),
        findsOneWidget,
      );
      expect(find.text('Edit source'), findsOneWidget);
    });

    testWidgets('a locked keyring: says so, and Try again asks again', (
      tester,
    ) async {
      base.sources.seed();
      fakes.imports.origins['src-1'] = Err(SecureStorageFailure('locked'));
      await pump(tester);

      expect(find.textContaining('Unlock the keyring'), findsOneWidget);

      fakes.imports.origins.remove('src-1');
      await tester.tap(find.text('Try again'));
      await settle(tester);
      expect(find.textContaining('No guide imported yet'), findsOneWidget);
    });

    testWidgets('an import that could not start says why in a banner', (
      tester,
    ) async {
      base.sources.seed();
      fakes.imports.result = Err(SecureStorageFailure('locked'));
      await pump(tester);

      await tester.tap(find.text('Import guide'));
      await settle(tester);
      expect(
        find.textContaining("Couldn't import the guide. Couldn't use"),
        findsOneWidget,
      );
    });
  });

  group('the Match… picker', () {
    testWidgets('Enter on a row opens it, ranked, with the best match first', (
      tester,
    ) async {
      seedGuide();
      await pump(tester);

      await tester.tap(row('Arena Sports 1').first);
      await settle(tester);

      expect(find.byType(GuideMatchPicker), findsOneWidget);
      expect(find.text('Match Arena Sports 1'), findsOneWidget);
      expect(find.text('Now: No guide channel'), findsOneWidget);
      expect(
        find.byWidgetPredicate(
          (widget) => widget is AppBadge && widget.label == 'Best match',
        ),
        findsOneWidget,
      );
      expect(find.text('arenasport1.fr'), findsOneWidget);
    });

    testWidgets('↓ then Enter maps the highlighted channel and rematches', (
      tester,
    ) async {
      seedGuide();
      await pump(tester);
      await tester.tap(row('Arena Sports 1').first);
      await settle(tester);

      await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
      await tester.pump();
      await tester.testTextInput.receiveAction(TextInputAction.done);
      await settle(tester);

      expect(find.byType(GuideMatchPicker), findsNothing);
      expect(fakes.guide.mappingCalls, ['set ch-1 → arenasport1.fr']);
      expect(fakes.matching.calls, ['src-1']);
      // Matched now, so it left the Unmatched list.
      await settle(tester);
      expect(find.text('Arena Sports 1'), findsNothing);
      expect(find.text('Velocity Motors HD'), findsOneWidget);
    });

    testWidgets('typing filters the guide channels', (tester) async {
      seedGuide();
      await pump(tester);
      await tester.tap(row('Arena Sports 1').first);
      await settle(tester);

      await tester.enterText(
        find.descendant(
          of: find.byType(GuideMatchPicker),
          matching: find.byType(EditableText),
        ),
        'sports 2',
      );
      await tester.pump(const Duration(milliseconds: 200));
      await settle(tester);
      expect(find.text('arenasports2.uk'), findsOneWidget);
      expect(find.text('arenasport1.fr'), findsNothing);

      await tester.enterText(
        find.descendant(
          of: find.byType(GuideMatchPicker),
          matching: find.byType(EditableText),
        ),
        'nothing like it',
      );
      await tester.pump(const Duration(milliseconds: 200));
      await settle(tester);
      expect(
        find.text('No guide channel matches "nothing like it"'),
        findsOneWidget,
      );
    });

    testWidgets('Esc cancels and writes nothing', (tester) async {
      seedGuide();
      await pump(tester);
      await tester.tap(row('Arena Sports 1').first);
      await settle(tester);

      await tester.sendKeyEvent(LogicalKeyboardKey.escape);
      await settle(tester);

      expect(find.byType(GuideMatchPicker), findsNothing);
      expect(fakes.guide.mappingCalls, isEmpty);
      expect(fakes.matching.calls, isEmpty);
    });

    testWidgets('Undo my match removes the mapping and rematches', (
      tester,
    ) async {
      seedGuide();
      fakes.guide.userMappings[('src-1', 'ch-4')] = 'summit.outdoor.uk';
      await pump(tester);
      await tester.tap(find.text('Matched by you'));
      await settle(tester);
      await tester.tap(row('Summit Outdoor').first);
      await settle(tester);

      expect(find.text('Now: → Summit Outdoor · yours'), findsOneWidget);
      await tester.tap(find.text('Undo my match'));
      await settle(tester);

      expect(fakes.guide.mappingCalls, ['remove ch-4']);
      expect(fakes.matching.calls, ['src-1']);
      await settle(tester);
      expect(find.text("You haven't matched any channels"), findsOneWidget);
    });

    testWidgets('a mapping that could not be saved says so', (tester) async {
      seedGuide();
      fakes.guide.writeFailure = StorageFailure('disk full');
      await pump(tester);
      await tester.tap(row('Arena Sports 1').first);
      await settle(tester);

      await tester.tap(find.text('Match'));
      await settle(tester);

      expect(find.textContaining("Couldn't save that match."), findsOneWidget);
      expect(fakes.matching.calls, isEmpty);
      expect(find.text('No guide channel'), findsNWidgets(2));
    });

    testWidgets("a request from Live TV opens that channel's picker", (
      tester,
    ) async {
      seedGuide();
      await pump(tester);
      final container = containerOf(tester);

      await tester.tap(
        find.descendant(
          of: find.byType(SettingsScreen),
          matching: find.text('Sources'),
        ),
      );
      await settle(tester);
      openGuideMatch(
        container.read(routerProvider),
        container.read(settingsLocationProvider.notifier),
        container.read(guideMatchRequestProvider.notifier),
        sourceId: 'src-1',
        channelId: 2,
      );
      await settle(tester);
      await settle(tester);

      expect(find.text('Match Velocity Motors HD'), findsOneWidget);
      expect(container.read(guideMatchRequestProvider), isNull);
    });
  });

  group('the settings', () {
    testWidgets('Keep: a new number of days is saved and re-imports', (
      tester,
    ) async {
      seedGuide();
      await pump(tester);

      expect(find.text('7 days'), findsOneWidget);
      await tester.tap(find.text('7 days'));
      await settle(tester);
      await tester.tap(find.text('3 days'));
      await settle(tester);

      expect(fakes.settingsStore.saved, [const GuideSettings(keepDays: 3)]);
      expect(find.text('3 days'), findsOneWidget);
      expect(fakes.imports.calls, ['reimport src-1']);
    });

    testWidgets('the stored number of days is shown', (tester) async {
      seedGuide();
      fakes.settingsStore.stored = const GuideSettings(keepDays: 14);
      await pump(tester);

      expect(find.text('14 days'), findsOneWidget);
    });

    testWidgets('Time offset: arrows step half an hour, saved once settled', (
      tester,
    ) async {
      seedGuide();
      await pump(tester);
      expect(find.text('None'), findsOneWidget);

      Focus.of(tester.element(find.text('None'))).requestFocus();
      await tester.pump();
      for (var i = 0; i < 3; i++) {
        await tester.sendKeyEvent(LogicalKeyboardKey.arrowLeft);
        await tester.pump();
      }
      expect(find.text('−1 h 30 min'), findsOneWidget);
      expect(base.sources.updated, isEmpty);

      await tester.pump(const Duration(milliseconds: 1300));
      await settle(tester);
      expect(base.sources.updated, hasLength(1));
      final (id, draft) = base.sources.updated.single;
      expect(id, 'src-1');
      expect(draft.epgOffsetMinutes, -90);
      expect(draft.password, isNull, reason: 'the stored one is kept');
      expect(fakes.imports.calls, ['reimport src-1']);
      expect(find.text('−1 h 30 min'), findsOneWidget);
    });

    testWidgets('Time offset without a guide saves and imports nothing', (
      tester,
    ) async {
      base.sources.seed();
      await pump(tester);

      Focus.of(tester.element(find.text('None'))).requestFocus();
      await tester.pump();
      await tester.sendKeyEvent(LogicalKeyboardKey.arrowRight);
      await tester.pump(const Duration(milliseconds: 1300));
      await settle(tester);

      expect(base.sources.updated.single.$2.epgOffsetMinutes, 30);
      expect(fakes.imports.calls, isEmpty);
    });
  });
}
