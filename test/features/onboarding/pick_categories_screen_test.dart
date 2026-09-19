import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:iptv_player/app/router.dart';
import 'package:iptv_player/core/result.dart';
import 'package:iptv_player/design/components.dart';
import 'package:iptv_player/features/onboarding/presentation/onboarding_state.dart';
import 'package:iptv_player/features/sources/domain/categories.dart';
import 'package:iptv_player/features/sources/domain/source.dart';

import '../../app/app_harness.dart';
import 'onboarding_fakes.dart';

void main() {
  late OnboardingFakes fakes;
  setUp(() {
    fakes = OnboardingFakes();
    fakes.categories.lists.addAll(sampleCategories());
  });

  const id = 'src-1';

  Future<AppUnderTest> pump(WidgetTester tester) => pumpApp(
    tester,
    initialLocation: pickCategoriesPath(id),
    overrides: fakes.overrides,
  );

  Finder tile(String name) => find.ancestor(
    of: find.text(name),
    matching: find.byType(FocusableSurface),
  );

  CheckState checkOf(WidgetTester tester, Finder surface) => tester
      .widget<AppCheckbox>(
        find.descendant(of: surface, matching: find.byType(AppCheckbox)),
      )
      .state;

  testWidgets('clusters by country, first group open, with the summary', (
    tester,
  ) async {
    await pump(tester);

    expect(find.text('Pick what you watch'), findsOneWidget);
    for (final label in [
      'United Kingdom',
      'United States',
      'Arabic',
      'No country tag',
    ]) {
      expect(find.text(label), findsOneWidget);
    }
    // The first group is open: its categories show without their tag.
    expect(find.text('Sports'), findsOneWidget);
    expect(find.text('Kids'), findsOneWidget);
    expect(find.text('3 of 4 on · 830 of 902 channels'), findsOneWidget);
    expect(find.text('Rotana'), findsNothing);
    // 7 of 10 on; 1,628 of 1,794 channels with the 12 uncategorized.
    expect(find.text('1,628 of 1,794 channels'), findsOneWidget);
    expect(
      find.text('12 channels without a category are always shown.'),
      findsOneWidget,
    );
    expect(checkOf(tester, tile('Kids')), CheckState.off);
    // Tabs for the kinds that have anything: no Series.
    expect(find.text('Live TV'), findsOneWidget);
    expect(find.text('Movies'), findsOneWidget);
    expect(find.text('Series'), findsNothing);
  });

  testWidgets('a tile flips its category, at once and in the store', (
    tester,
  ) async {
    await pump(tester);

    await tester.tap(tile('Kids'));
    await tester.pump();
    expect(checkOf(tester, tile('Kids')), CheckState.on);
    await settleApp(tester);

    expect(fakes.categories.writes, ['setHidden 4 false']);
    expect(find.text('4 of 4 on · 902 channels'), findsOneWidget);
    expect(find.text('1,700 of 1,794 channels'), findsOneWidget);
  });

  testWidgets('Space on a focused tile flips it too', (tester) async {
    await pump(tester);

    Focus.of(tester.element(find.text('Sports'))).requestFocus();
    await tester.pump();
    await tester.sendKeyEvent(LogicalKeyboardKey.space);
    await settleApp(tester);

    expect(fakes.categories.writes, ['setHidden 1 true']);
  });

  testWidgets("a group's checkbox turns the whole group on or off", (
    tester,
  ) async {
    await pump(tester);

    await tester.tap(find.bySemanticsLabel('Show every Arabic category'));
    await settleApp(tester);
    expect(fakes.categories.writes, ['setHiddenMany 2 false']);
    expect(find.text('2 of 2 on · 94 channels'), findsOneWidget);

    await tester.tap(find.bySemanticsLabel('Hide every Arabic category'));
    await settleApp(tester);
    expect(fakes.categories.writes.last, 'setHiddenMany 2 true');
  });

  testWidgets('a group opens and closes', (tester) async {
    await pump(tester);

    await tester.tap(find.text('Arabic'));
    await settleApp(tester);
    expect(find.text('Rotana'), findsOneWidget);

    await tester.tap(find.text('United Kingdom'));
    await settleApp(tester);
    expect(find.text('Kids'), findsNothing);
  });

  testWidgets('Select none and Select all act on the whole kind', (
    tester,
  ) async {
    await pump(tester);

    await tester.tap(find.text('Select none'));
    await settleApp(tester);
    expect(fakes.categories.writes.last, 'setHiddenMany 10 true');
    expect(find.text('12 of 1,794 channels'), findsOneWidget);

    await tester.tap(find.text('Select all'));
    await settleApp(tester);
    expect(fakes.categories.writes.last, 'setHiddenMany 10 false');
  });

  testWidgets('the filter narrows the list, and Select acts on what shows', (
    tester,
  ) async {
    await pump(tester);

    await tester.enterText(find.byType(EditableText), 'news');
    await settleApp(tester);

    // Matching groups open, keeping their clusters; the rest go.
    expect(find.text('United Kingdom'), findsOneWidget);
    expect(find.text('United States'), findsOneWidget);
    expect(find.text('News'), findsNWidgets(2));
    expect(find.text('Arabic'), findsNothing);
    await tester.tap(find.text('Select none'));
    await settleApp(tester);
    expect(fakes.categories.writes.last, 'setHiddenMany 2 true');

    await tester.enterText(find.byType(EditableText), 'zzz');
    await settleApp(tester);
    expect(find.text('No categories match "zzz"'), findsOneWidget);
  });

  testWidgets('the Movies tab shows movie categories', (tester) async {
    await pump(tester);

    await tester.tap(find.text('Movies'));
    await settleApp(tester);

    expect(find.text('Action'), findsOneWidget);
    expect(find.text('2 of 2 movie categories on'), findsOneWidget);
    // One cluster: no group header.
    expect(find.text('No country tag'), findsNothing);
  });

  testWidgets('a failed write is undone and said', (tester) async {
    fakes.categories.writeFailure = StorageFailure('disk full');
    await pump(tester);

    await tester.tap(tile('Kids'));
    await settleApp(tester);

    expect(checkOf(tester, tile('Kids')), CheckState.off);
    expect(find.textContaining("Couldn't save that change."), findsOneWidget);
  });

  testWidgets('loading shows placeholders', (tester) async {
    fakes.categories.gate = Completer();
    await pump(tester);

    expect(find.bySemanticsLabel('Loading categories'), findsOneWidget);
    expect(find.byType(Skeleton), findsWidgets);

    fakes.categories.gate!.complete();
    await settleApp(tester);
    expect(find.text('United Kingdom'), findsOneWidget);
  });

  testWidgets('an error offers Retry', (tester) async {
    fakes.categories.watchFailure = StorageFailure('gone');
    await pump(tester);

    expect(find.text("Couldn't load your categories"), findsOneWidget);

    fakes.categories.watchFailure = null;
    await tester.tap(find.text('Retry'));
    await settleApp(tester);
    expect(find.text('United Kingdom'), findsOneWidget);
  });

  testWidgets('a source with no categories says there is nothing to pick', (
    tester,
  ) async {
    fakes.categories.lists.clear();
    await pump(tester);

    expect(find.text('Nothing to pick'), findsOneWidget);
    expect(find.text('Finish'), findsOneWidget);
  });

  testWidgets('Finish goes Home and forgets the typed details', (tester) async {
    final app = await pump(tester);
    final container = ProviderScope.containerOf(
      tester.element(find.byType(MaterialApp)),
    );
    container.read(pendingSourceDraftProvider.notifier).draft =
        const SourceDraft(type: SourceType.m3uFile, name: 'x', url: '/x.m3u');

    await tester.tap(find.text('Finish'));
    await settleApp(tester);

    expect(app.location, '/');
    expect(container.read(pendingSourceDraftProvider), isNull);
  });

  testWidgets('Finish returns to Settings when adding started there', (
    tester,
  ) async {
    final app = await pump(tester);
    final container = ProviderScope.containerOf(
      tester.element(find.byType(MaterialApp)),
    );
    container.read(onboardingReturnPathProvider.notifier).path = '/settings';

    await tester.tap(find.text('Finish'));
    await settleApp(tester);

    expect(app.location, '/settings');
    // Used once: the next source added from Welcome ends at Home.
    expect(container.read(onboardingReturnPathProvider), isNull);
  });

  test('sample data has the kinds the tests expect', () {
    expect(sampleCategories().keys, CatalogueKind.values);
  });
}
