import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:iptv_player/app/destinations.dart';
import 'package:iptv_player/core/result.dart';
import 'package:iptv_player/design/components.dart';
import 'package:iptv_player/features/settings/presentation/settings_section.dart';
import 'package:iptv_player/features/sources/domain/source.dart';

import '../../../app/app_harness.dart';
import '../../onboarding/onboarding_fakes.dart';

void main() {
  late OnboardingFakes fakes;
  setUp(() {
    fakes = OnboardingFakes();
    fakes.categories.lists.addAll(sampleCategories());
  });

  Future<AppUnderTest> pump(WidgetTester tester) async {
    final app = await pumpApp(
      tester,
      initialLocation: AppDestination.settings.path,
      overrides: fakes.overrides,
    );
    await tester.tap(find.text('Categories').first);
    await settleApp(tester);
    return app;
  }

  Finder row(String name) => find.ancestor(
    of: find.text(name),
    matching: find.byType(FocusableSurface),
  );

  CheckState checkOf(WidgetTester tester, String name) => tester
      .widget<AppCheckbox>(
        find.descendant(of: row(name), matching: find.byType(AppCheckbox)),
      )
      .state;

  List<String> shownNames(WidgetTester tester) => [
    for (final surface in tester.widgetList<FocusableSurface>(
      find.byType(FocusableSurface),
    ))
      if (surface.semanticLabel case final label?
          when _rowLabel.hasMatch(label))
        label.split(',').first,
  ];

  testWidgets('no source: says so and offers to add one', (tester) async {
    await pump(tester);

    expect(find.text('No categories yet'), findsOneWidget);
    expect(find.text('Add a source'), findsOneWidget);
  });

  testWidgets('loading, then the list with counts and a summary', (
    tester,
  ) async {
    fakes.sources.seed(lastSyncedAt: fakes.now);
    final gate = fakes.categories.gate = Completer<void>();
    await pump(tester);
    expect(find.byType(Skeleton), findsWidgets);

    gate.complete();
    await settleApp(tester);

    expect(find.text('UK | Sports'), findsOneWidget);
    expect(find.text('214 channels'), findsOneWidget);
    expect(checkOf(tester, 'UK | Kids'), CheckState.off);
    expect(
      find.textContaining('7 of 10 shown · 12 channels without a category'),
      findsOneWidget,
    );
    expect(find.text('Live TV'), findsOneWidget);
    expect(find.text('Movies'), findsOneWidget);
  });

  testWidgets('an error offers Retry', (tester) async {
    fakes.sources.seed();
    fakes.categories.watchFailure = StorageFailure('disk');
    await pump(tester);

    expect(find.text("Couldn't load the categories"), findsOneWidget);
    expect(find.text('Retry'), findsOneWidget);
  });

  testWidgets('a source with no categories yet explains why', (tester) async {
    fakes.sources.seed();
    fakes.categories.lists.clear();
    await pump(tester);

    expect(find.text('No categories from Northwind TV'), findsOneWidget);
    expect(find.textContaining("hasn't synced yet"), findsOneWidget);
  });

  testWidgets('Space on a row flips it, at once and in the store', (
    tester,
  ) async {
    fakes.sources.seed();
    await pump(tester);

    Focus.of(tester.element(find.text('UK | Kids'))).requestFocus();
    await tester.pump();
    await tester.sendKeyEvent(LogicalKeyboardKey.space);
    await tester.pump();

    expect(checkOf(tester, 'UK | Kids'), CheckState.on);
    expect(fakes.categories.writes, ['setHidden 4 false']);
  });

  testWidgets('Show hidden off lists only what shows; filter narrows', (
    tester,
  ) async {
    fakes.sources.seed();
    await pump(tester);

    await tester.tap(find.text('Show hidden'));
    await settleApp(tester);
    expect(find.text('UK | Kids'), findsNothing);
    expect(find.text('AR | MBC'), findsNothing);
    expect(find.text('UK | News'), findsOneWidget);

    await tester.enterText(find.byType(EditableText), 'sport');
    await settleApp(tester);
    expect(shownNames(tester), ['UK | Sports', 'US | Sports']);
    expect(find.text('2 match "sport"'), findsOneWidget);

    // Select none acts on what the filter shows.
    await tester.tap(find.text('Select none'));
    await tester.pump();
    expect(fakes.categories.writes.last, 'setHiddenMany 2 true');
  });

  testWidgets('rename: dialog, save, and back to the provider name', (
    tester,
  ) async {
    fakes.sources.seed();
    await pump(tester);

    await tester.tap(findByLabel('Rename Music'));
    await settleApp(tester);
    expect(find.text('Rename category'), findsOneWidget);
    await tester.enterText(
      find.descendant(
        of: find.byType(AppDialog),
        matching: find.byType(EditableText),
      ),
      'Radio & music',
    );
    await tester.testTextInput.receiveAction(TextInputAction.done);
    await settleApp(tester);

    expect(fakes.categories.writes, ['rename 9 Radio & music']);
    expect(find.text('Radio & music'), findsOneWidget);
    expect(find.text('was Music'), findsOneWidget);

    await tester.tap(findByLabel('Rename Radio & music'));
    await settleApp(tester);
    expect(find.text('Your provider calls it "Music".'), findsOneWidget);
    await tester.tap(find.text("Use provider's name"));
    await settleApp(tester);

    expect(fakes.categories.writes.last, 'rename 9 <provider>');
    expect(find.text('Music'), findsOneWidget);
    expect(find.text('was Music'), findsNothing);
  });

  testWidgets('the rename dialog opens with its name selected in the field', (
    tester,
  ) async {
    fakes.sources.seed();
    await pump(tester);

    await tester.tap(findByLabel('Rename Music'));
    await settleApp(tester);

    final field = find.descendant(
      of: find.byType(AppDialog),
      matching: find.byType(EditableText),
    );
    expect(focusIsOn(tester, field), isTrue);
    final selection = tester.widget<EditableText>(field).controller.selection;
    expect(selection.start, 0);
    expect(selection.end, 'Music'.length);
  });

  testWidgets('Esc closes the rename dialog without a change', (tester) async {
    fakes.sources.seed();
    await pump(tester);

    await tester.tap(findByLabel('Rename Music'));
    await settleApp(tester);
    await tester.sendKeyEvent(LogicalKeyboardKey.escape);
    await settleApp(tester);

    expect(find.text('Rename category'), findsNothing);
    expect(fakes.categories.writes, isEmpty);
  });

  testWidgets("Alt+Down reorders; Provider's order undoes it", (tester) async {
    fakes.sources.seed();
    await pump(tester);
    expect(find.text("Provider's order"), findsNothing);

    Focus.of(tester.element(find.text('UK | Sports'))).requestFocus();
    await tester.pump();
    await tester.sendKeyDownEvent(LogicalKeyboardKey.altLeft);
    await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
    await tester.sendKeyUpEvent(LogicalKeyboardKey.altLeft);
    await settleApp(tester);

    expect(fakes.categories.writes, ['reorder 2,1,3,4,5,6,7,8,9,10']);
    expect(shownNames(tester).take(2), ['UK | News', 'UK | Sports']);
    // Focus stays on the moved row, so it can keep moving.
    expect(focusIsOn(tester, find.text('UK | Sports')), isTrue);

    await tester.tap(find.text("Provider's order"));
    await settleApp(tester);
    expect(fakes.categories.writes.last, 'resetOrder live');
    expect(shownNames(tester).take(2), ['UK | Sports', 'UK | News']);
  });

  testWidgets('reordering a filtered list moves past the shown neighbour', (
    tester,
  ) async {
    fakes.sources.seed();
    await pump(tester);

    await tester.enterText(find.byType(EditableText), 'news');
    await settleApp(tester);
    Focus.of(tester.element(find.text('UK | News'))).requestFocus();
    await tester.pump();
    await tester.sendKeyDownEvent(LogicalKeyboardKey.altLeft);
    await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
    await tester.sendKeyUpEvent(LogicalKeyboardKey.altLeft);
    await settleApp(tester);

    // UK | News (2) goes after US | News (5), across the hidden rows.
    expect(fakes.categories.writes, ['reorder 1,3,4,5,2,6,7,8,9,10']);
  });

  testWidgets('with two sources, a menu picks which one to manage', (
    tester,
  ) async {
    fakes.sources
      ..seed()
      ..seed(id: 'src-2', type: SourceType.m3uFile, name: 'Backup');
    await pump(tester);

    await tester.tap(find.widgetWithText(AppButton, 'Northwind TV'));
    await settleApp(tester);
    await tester.tap(find.text('Backup').last);
    await settleApp(tester);

    final container = ProviderScope.containerOf(
      tester.element(find.byType(Navigator).first),
    );
    expect(
      container.read(settingsLocationProvider).categoriesSourceId,
      'src-2',
    );
    expect(find.widgetWithText(AppButton, 'Backup'), findsOneWidget);
  });

  testWidgets('switching to Movies shows its list', (tester) async {
    fakes.sources.seed();
    await pump(tester);

    await tester.tap(find.text('Movies'));
    await settleApp(tester);

    expect(find.text('Action'), findsOneWidget);
    expect(find.text('800 movies'), findsOneWidget);
    expect(find.text('UK | Sports'), findsNothing);
  });

  testWidgets('a failed write says so and puts the switch back', (
    tester,
  ) async {
    fakes.sources.seed();
    fakes.categories.writeFailure = StorageFailure('disk full');
    await pump(tester);

    await tester.tap(row('UK | Kids'));
    await settleApp(tester);

    expect(find.textContaining("Couldn't save that change"), findsOneWidget);
    expect(checkOf(tester, 'UK | Kids'), CheckState.off);
  });
}

/// A category row's label: `UK | Sports, 214 channels`.
final _rowLabel = RegExp(r', [\d,]+ (channels?|movies?|series)$');
