import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:iptv_player/core/result.dart';
import 'package:iptv_player/core/text/format.dart';
import 'package:iptv_player/design/appearance.dart';
import 'package:iptv_player/design/tokens.dart';
import 'package:iptv_player/features/settings/data/appearance_providers.dart';
import 'package:iptv_player/features/settings/domain/appearance_store.dart';

import 'appearance_fakes.dart';

void main() {
  ProviderContainer container(
    AppearanceStore store, {
    SystemAppearance desktop = const SystemAppearance(),
  }) {
    final container = ProviderContainer(
      overrides: appearanceOverrides(store: store, desktop: desktop),
    );
    addTearDown(container.dispose);
    return container;
  }

  test('the first read already has what was stored', () {
    final store = InMemoryAppearanceStore(
      const AppearanceSettings(accent: AppAccent.violet),
    );

    final look = container(store).read(appearanceProvider);

    expect(look.accent, AppAccent.violet);
  });

  test('a change shows at once and is saved behind it', () async {
    final store = ScriptedAppearanceStore();
    final providers = container(store);
    expect(providers.read(appearanceProvider).accent, AppAccent.blue);

    final saving = providers
        .read(appearanceControllerProvider.notifier)
        .change(const AppearanceSettings(accent: AppAccent.teal));

    // Before the write has finished.
    expect(providers.read(appearanceProvider).accent, AppAccent.teal);
    expect(await saving, isA<Ok<void>>());
    expect(store.saved.single.accent, AppAccent.teal);
  });

  test("a change that can't be saved still holds for this run", () async {
    final store = ScriptedAppearanceStore()
      ..saveFailure = StorageFailure('disk full');
    final providers = container(store);

    final result = await providers
        .read(appearanceControllerProvider.notifier)
        .change(const AppearanceSettings(density: AppDensity.compact));

    expect(result, isA<Err<void>>());
    expect(providers.read(appearanceProvider).density, AppDensity.compact);
  });

  test('a read that failed shows the defaults and says so; Try again reads '
      'what is kept', () async {
    final store = ScriptedAppearanceStore()
      ..readFailure = StorageFailure('locked');
    final providers = container(store);

    expect(
      providers.read(appearanceControllerProvider).readFailure,
      isA<StorageFailure>(),
    );
    expect(providers.read(appearanceProvider).accent, AppAccent.blue);

    // Still failing.
    await providers.read(appearanceControllerProvider.notifier).retry();
    expect(
      providers.read(appearanceControllerProvider).readFailure,
      isA<StorageFailure>(),
    );

    store
      ..readFailure = null
      ..stored = const AppearanceSettings(accent: AppAccent.rose);
    await providers.read(appearanceControllerProvider.notifier).retry();

    expect(providers.read(appearanceControllerProvider).readFailure, isNull);
    expect(providers.read(appearanceProvider).accent, AppAccent.rose);
  });

  test('a change saved after a failed read leaves nothing unread', () async {
    final store = ScriptedAppearanceStore()
      ..readFailure = StorageFailure('locked');
    final providers = container(store);

    await providers
        .read(appearanceControllerProvider.notifier)
        .change(const AppearanceSettings(clock: ClockChoice.h24));

    expect(providers.read(appearanceControllerProvider).readFailure, isNull);
  });

  test('System is answered by the desktop, and the clock is one provider '
      'for text made away from a screen', () {
    final providers = container(
      InMemoryAppearanceStore(),
      desktop: const SystemAppearance(
        textScale: 1.6,
        reduceMotion: true,
        use24Hour: true,
      ),
    );

    final look = providers.read(appearanceProvider);

    expect(look.textScale, 1.3);
    expect(look.reduceMotion, isTrue);
    expect(look.timeStyle, TimeStyle.h24);
    expect(providers.read(timeStyleProvider), TimeStyle.h24);
  });

  testWidgets("the desktop's own values are read from the platform", (
    tester,
  ) async {
    tester.platformDispatcher
      ..textScaleFactorTestValue = 1.15
      ..alwaysUse24HourFormatTestValue = true;
    addTearDown(tester.platformDispatcher.clearAllTestValues);
    final providers = ProviderContainer();
    addTearDown(providers.dispose);

    expect(
      providers.read(desktopAppearanceProvider),
      const SystemAppearance(textScale: 1.15, use24Hour: true),
    );

    // The desktop's text size changes while the app runs.
    tester.platformDispatcher.textScaleFactorTestValue = 1.3;
    await tester.pump();

    expect(providers.read(desktopAppearanceProvider).textScale, 1.3);
    expect(providers.read(appearanceProvider).textScale, 1.3);
  });
}
