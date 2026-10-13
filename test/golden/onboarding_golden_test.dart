// Every test in this file is a golden; the tag is declared in
// dart_test.yaml so `flutter test --exclude-tags golden` can drop them
// on Windows.
@Tags(['golden'])
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:iptv_player/app/router.dart';

import '../app/app_harness.dart';
import '../features/onboarding/onboarding_fakes.dart';
import 'golden_harness.dart';

void main() {
  group('onboarding', () {
    sceneTest('Welcome', (tester) async {
      hideDebugBanner();
      await pumpApp(
        tester,
        initialLocation: welcomeRoutePath,
        overrides: OnboardingFakes().overrides,
      );

      await golden(tester, 'images/onboarding_welcome.png');
    });

    sceneTest('Pick categories', (tester) async {
      hideDebugBanner();
      final fakes = OnboardingFakes();
      fakes.categories.lists.addAll(sampleCategories());
      await pumpApp(
        tester,
        initialLocation: pickCategoriesPath('src-1'),
        overrides: fakes.overrides,
      );

      await golden(tester, 'images/onboarding_pick_categories.png');
    });
  }, skip: goldenSkipReason);
}
