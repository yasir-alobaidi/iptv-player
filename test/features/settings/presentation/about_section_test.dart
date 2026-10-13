import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:iptv_player/app/destinations.dart';
import 'package:iptv_player/core/core_providers.dart';
import 'package:iptv_player/core/platform/app_version.dart';
import 'package:iptv_player/core/platform/licenses.dart';
import 'package:iptv_player/design/components.dart';
import 'package:iptv_player/features/settings/presentation/about_section.dart';
import 'package:iptv_player/features/settings/presentation/licenses_dialog.dart';
import 'package:iptv_player/features/sources/presentation/source_shell_slots.dart';

import '../../../app/app_harness.dart';
import '../../casting/support/cast_ui_harness.dart' show focusedLabelOf;
import '../../onboarding/onboarding_fakes.dart';

void main() {
  const packages = [
    PackageLicenses('FFmpeg', [
      LicenseEntryWithLineBreaks([
        'FFmpeg',
      ], 'FFmpeg terms\n\nSecond paragraph'),
    ]),
    PackageLicenses('flutter', [
      LicenseEntryWithLineBreaks(['flutter'], 'Flutter terms'),
    ]),
    PackageLicenses('Manrope', [
      LicenseEntryWithLineBreaks(['Manrope'], 'Open Font License'),
    ]),
  ];

  /// Settings → About & diagnostics. [licenses] null never answers.
  Future<void> open(
    WidgetTester tester, {
    AppVersion version = const AppVersion(version: '0.1.0', build: '1'),
    FutureOr<List<PackageLicenses>> Function()? licenses,
  }) async {
    final fakes = OnboardingFakes()..sources.seed();
    await pumpApp(
      tester,
      initialLocation: AppDestination.settings.path,
      overrides: [
        ...fakes.overrides,
        ...sourceShellOverrides,
        appVersionProvider.overrideWith((ref) async => version),
        licensesProvider.overrideWith(
          (ref) async => licenses == null ? packages : await licenses(),
        ),
      ],
    );
    await tester.tap(find.text('About & diagnostics').first);
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

  testWidgets('says the name, the version, the build and the system', (
    tester,
  ) async {
    debugDefaultTargetPlatformOverride = TargetPlatform.linux;
    await open(tester);

    expect(find.text('IPTV Player 0.1.0 (build 1) · Linux'), findsOneWidget);
    debugDefaultTargetPlatformOverride = null;
  });

  testWidgets('a build that says no version says so, and nothing else breaks', (
    tester,
  ) async {
    debugDefaultTargetPlatformOverride = TargetPlatform.windows;
    await open(tester, version: AppVersion.unknown);

    expect(find.text('IPTV Player version unknown · Windows'), findsOneWidget);
    debugDefaultTargetPlatformOverride = null;
  });

  test('the line while the version is still being read', () {
    expect(aboutLine(null, TargetPlatform.linux), 'IPTV Player · Linux');
  });

  testWidgets('Licences, by keyboard: the list has the focus on the first '
      'package, ↓ and Enter show another, Tab reaches its text, Esc closes', (
    tester,
  ) async {
    await open(tester);
    await tabTo(tester, 'Licences');
    await tester.sendKeyEvent(LogicalKeyboardKey.enter);
    await settleApp(tester);

    expect(find.byType(LicensesDialog), findsOneWidget);
    expect(
      find.text(
        'What IPTV Player is built with: 3 packages, fonts and programs.',
      ),
      findsOneWidget,
    );
    expect(focusedLabelOf(tester), 'FFmpeg');
    expect(find.textContaining('FFmpeg terms'), findsOneWidget);
    expect(find.textContaining('Second paragraph'), findsOneWidget);

    await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
    await tester.pump();
    expect(focusedLabelOf(tester), 'flutter');
    // The text follows a choice, not the focus passing by.
    expect(find.textContaining('FFmpeg terms'), findsOneWidget);

    await tester.sendKeyEvent(LogicalKeyboardKey.enter);
    await settleApp(tester);
    expect(find.text('Flutter terms'), findsOneWidget);
    expect(find.textContaining('FFmpeg terms'), findsNothing);

    // The list is one Tab stop: the next is the text.
    await tester.sendKeyEvent(LogicalKeyboardKey.tab);
    await tester.pump();
    expect(
      FocusManager.instance.primaryFocus!.context!
          .findAncestorWidgetOfExactType<ScrollPane>(),
      isNotNull,
    );

    await tester.sendKeyEvent(LogicalKeyboardKey.escape);
    await settleApp(tester);
    expect(find.byType(LicensesDialog), findsNothing);
    // Back where it was opened from.
    expect(focusedLabelOf(tester), 'Licences');
  });

  testWidgets('while the licences are read the dialog says so', (tester) async {
    final never = Completer<List<PackageLicenses>>();
    await open(tester, licenses: () => never.future);
    await tabTo(tester, 'Licences');
    await tester.sendKeyEvent(LogicalKeyboardKey.enter);
    await settleApp(tester);

    expect(find.bySemanticsLabel('Reading the licences'), findsOneWidget);
    expect(find.byType(Skeleton), findsWidgets);
    never.complete(packages);
    await settleApp(tester);
    expect(find.textContaining('FFmpeg terms'), findsOneWidget);
  });

  testWidgets("licences that can't be read: a plain line, the detail behind "
      'Details, and Try again reads them', (tester) async {
    var fail = true;
    await open(
      tester,
      licenses: () => fail ? throw StateError('NOTICES is gone') : packages,
    );
    await tabTo(tester, 'Licences');
    await tester.sendKeyEvent(LogicalKeyboardKey.enter);
    await settleApp(tester);

    expect(find.text("The licences couldn't be read"), findsOneWidget);
    expect(find.textContaining('NOTICES is gone'), findsNothing);

    fail = false;
    await tabTo(tester, 'Try again');
    await tester.sendKeyEvent(LogicalKeyboardKey.enter);
    await settleApp(tester);

    expect(find.text("The licences couldn't be read"), findsNothing);
    expect(find.textContaining('FFmpeg terms'), findsOneWidget);
  });

  testWidgets('a build with no licences at all says so', (tester) async {
    await open(tester, licenses: () => const []);
    await tabTo(tester, 'Licences');
    await tester.sendKeyEvent(LogicalKeyboardKey.enter);
    await settleApp(tester);

    expect(find.text('No licences to show'), findsOneWidget);
  });
}
