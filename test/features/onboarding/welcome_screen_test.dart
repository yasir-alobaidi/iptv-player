import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:iptv_player/app/router.dart';
import 'package:iptv_player/design/components.dart';
import 'package:iptv_player/features/onboarding/presentation/connect_screen.dart';

import '../../app/app_harness.dart';
import 'onboarding_fakes.dart';

void main() {
  late OnboardingFakes fakes;
  setUp(() => fakes = OnboardingFakes());

  Future<AppUnderTest> pump(WidgetTester tester) => pumpApp(
    tester,
    initialLocation: welcomeRoutePath,
    overrides: fakes.overrides,
  );

  testWidgets('says what the app is and focuses the way on', (tester) async {
    await pump(tester);

    expect(
      find.text('Your channels, movies and series in one calm place.'),
      findsOneWidget,
    );
    final add = find.widgetWithText(AppButton, 'Add your first source');
    expect(add, findsOneWidget);
    expect(focusIsOn(tester, find.text('Add your first source')), isTrue);
  });

  testWidgets('Enter opens Connect, and Esc comes back', (tester) async {
    final app = await pump(tester);

    await tester.sendKeyEvent(LogicalKeyboardKey.enter);
    await settleApp(tester);
    expect(app.location, addSourceRoutePath);
    expect(find.byType(ConnectScreen), findsOneWidget);

    // Esc from a text field reaches the router too: Connect is a page.
    await tester.sendKeyEvent(LogicalKeyboardKey.escape);
    await settleApp(tester);
    expect(app.location, welcomeRoutePath);
  });

  testWidgets('"Open a file instead" goes to Connect with the file', (
    tester,
  ) async {
    fakes.pickedFile = '/home/me/tv/list.m3u';
    final app = await pump(tester);

    await tester.tap(find.text('Open a file instead'));
    await settleApp(tester);

    expect(fakes.pickerCalls, 1);
    expect(app.location, addSourceRoutePath);
    expect(find.text('/home/me/tv/list.m3u'), findsOneWidget);
    final file = tester.widget<ChoiceCard>(
      find.widgetWithText(ChoiceCard, 'M3U file'),
    );
    expect(file.selected, isTrue);
  });

  testWidgets('closing the file dialog stays on Welcome', (tester) async {
    final app = await pump(tester);

    await tester.tap(find.text('Open a file instead'));
    await settleApp(tester);

    expect(fakes.pickerCalls, 1);
    expect(app.location, welcomeRoutePath);
  });
}
