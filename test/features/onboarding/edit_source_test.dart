import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:iptv_player/app/destinations.dart';
import 'package:iptv_player/app/router.dart';
import 'package:iptv_player/core/result.dart';
import 'package:iptv_player/design/components.dart';
import 'package:iptv_player/features/sources/domain/source.dart';

import '../../app/app_harness.dart';
import 'onboarding_fakes.dart';

void main() {
  late OnboardingFakes fakes;
  setUp(() => fakes = OnboardingFakes());

  Future<AppUnderTest> pump(WidgetTester tester) async {
    // Opened from Settings, as the Sources page does, so Back has
    // somewhere to go.
    final app = await pumpApp(
      tester,
      initialLocation: AppDestination.settings.path,
      overrides: fakes.overrides,
    );
    unawaited(app.router.push<void>(editSourcePath('src-1')));
    await settleApp(tester);
    return app;
  }

  Finder field(String label) =>
      find.ancestor(of: find.text(label), matching: find.byType(AppTextField));

  String textOf(WidgetTester tester, String label) => tester
      .widget<EditableText>(
        find.descendant(of: field(label), matching: find.byType(EditableText)),
      )
      .controller
      .text;

  testWidgets('fills the form in; the password stays blank', (tester) async {
    fakes.sources.seed();
    await pump(tester);

    expect(find.text('Edit Northwind TV'), findsOneWidget);
    // No step indicator and no type cards: a source keeps its type.
    expect(find.byType(StepIndicator), findsNothing);
    expect(find.byType(ChoiceCard), findsNothing);
    expect(textOf(tester, 'Server address'), 'http://line.northwind.test');
    expect(textOf(tester, 'Username'), 'alice');
    expect(textOf(tester, 'Password'), isEmpty);
    expect(find.text('Saved; leave empty to keep it'), findsOneWidget);
    expect(find.text('Save'), findsOneWidget);
    expect(find.text('Test connection'), findsOneWidget);
  });

  testWidgets('a rename saves without a test and without a sync', (
    tester,
  ) async {
    fakes.sources.seed();
    final app = await pump(tester);

    await tester.enterText(
      find.descendant(of: field('Name'), matching: find.byType(EditableText)),
      'Northwind',
    );
    await tester.tap(find.text('Save'));
    await settleApp(tester);

    expect(fakes.checker.checked, isEmpty);
    final (id, draft) = fakes.sources.updated.single;
    expect(id, 'src-1');
    expect(draft.name, 'Northwind');
    // A blank password means "keep the saved one".
    expect(draft.password, isNull);
    expect(fakes.sync.syncCalls, isEmpty);
    expect(app.location, AppDestination.settings.path);
  });

  testWidgets('a new server is tested with the saved password first', (
    tester,
  ) async {
    fakes.sources.seed();
    await pump(tester);

    await tester.enterText(
      find.descendant(
        of: field('Server address'),
        matching: find.byType(EditableText),
      ),
      'http://backup.northwind.test',
    );
    await tester.pump();
    expect(find.text('Save tests the new details first.'), findsOneWidget);

    // Enter in a field: Save, which tests first.
    await tester.testTextInput.receiveAction(TextInputAction.done);
    await settleApp(tester);
    expect(fakes.sources.updated, isEmpty);
    final tested = fakes.checker.checked.single;
    expect(tested.url, 'http://backup.northwind.test');
    expect(tested.password, 's3cret');
    expect(find.text('Connected'), findsOneWidget);
    // Focus moves to Save once the test passes.
    expect(focusIsOn(tester, find.text('Save')), isTrue);

    await tester.sendKeyEvent(LogicalKeyboardKey.enter);
    await settleApp(tester);
    final (_, draft) = fakes.sources.updated.single;
    expect(draft.url, 'http://backup.northwind.test');
    expect(draft.password, isNull);
    // A new sign-in may mean other data: it syncs again.
    expect(fakes.sync.syncCalls, ['src-1']);
  });

  testWidgets('a failed test stops the save', (tester) async {
    fakes.sources.seed();
    fakes.checker.result = Err(AuthFailure('rejected'));
    await pump(tester);

    await tester.enterText(
      find.descendant(
        of: field('Password'),
        matching: find.byType(EditableText),
      ),
      'wrong',
    );
    await tester.tap(find.text('Save'));
    await settleApp(tester);

    expect(fakes.checker.checked.single.password, 'wrong');
    expect(find.text('Sign-in refused'), findsOneWidget);
    expect(fakes.sources.updated, isEmpty);
  });

  testWidgets('a playlist URL comes from the keyring to be edited', (
    tester,
  ) async {
    fakes.sources.seed(type: SourceType.m3uUrl);
    await pump(tester);

    expect(
      textOf(tester, 'Playlist URL'),
      'http://lists.northwind.test/get.php?username=alice&password=s3cret',
    );
  });

  testWidgets("a keyring that won't open is an error with Retry", (
    tester,
  ) async {
    fakes.sources.seed();
    fakes.sources.credentials = Err(SecureStorageFailure('locked'));
    await pump(tester);

    expect(find.text("Couldn't open this source"), findsOneWidget);
    expect(find.textContaining('keyring'), findsOneWidget);

    fakes.sources.credentials = null;
    await tester.tap(find.text('Retry'));
    await settleApp(tester);
    expect(find.text('Edit Northwind TV'), findsOneWidget);
  });

  testWidgets('a missing saved password asks for it', (tester) async {
    fakes.sources.seed();
    fakes.sources.credentials = Err(AuthFailure('no stored password'));
    await pump(tester);

    expect(find.text('Saved; leave empty to keep it'), findsNothing);
    await tester.tap(find.text('Save'));
    await settleApp(tester);

    expect(find.text('Enter your password.'), findsOneWidget);
    expect(fakes.sources.updated, isEmpty);
  });

  testWidgets('Back and Esc return to Settings without saving', (tester) async {
    fakes.sources.seed();
    final app = await pump(tester);

    await tester.sendKeyEvent(LogicalKeyboardKey.escape);
    await settleApp(tester);

    expect(app.location, AppDestination.settings.path);
    expect(fakes.sources.updated, isEmpty);
  });
}
