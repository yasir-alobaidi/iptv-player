import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:iptv_player/app/destinations.dart';
import 'package:iptv_player/core/cast/cast_device.dart';
import 'package:iptv_player/core/cast/cast_planner.dart';
import 'package:iptv_player/data/db/db_providers.dart';
import 'package:iptv_player/data/settings/settings_repository.dart';
import 'package:iptv_player/features/casting/data/casting_providers.dart';
import 'package:iptv_player/features/settings/presentation/settings_section.dart';

import '../../../app/app_harness.dart';
import '../support/cast_ui_harness.dart';

const _tv = KnownCastDevice(
  id: 'tv1',
  name: 'Living Room TV',
  host: '192.168.1.155',
  port: 8009,
  manual: false,
  model: 'Chromecast',
  hevc: HevcSupport.auto,
  learned: CastLearned(maxHeight: 1080, refusedCodecs: {'hevc'}),
);

const _bedroom = KnownCastDevice(
  id: 'bedroom',
  name: 'Bedroom',
  host: '192.168.1.60',
  port: 8009,
  manual: true,
  hevc: HevcSupport.auto,
  learned: CastLearned(),
);

/// Settings → Casting (sketch C).
void main() {
  late CastUi ui;

  Future<ProviderContainer> pump(WidgetTester tester) async {
    ui = CastUi();
    addTearDown(() => tester.runAsync(ui.live.db.close));
    addTearDown(ui.dispose);
    await tester.runAsync(ui.live.seed);
    ui.cast.devices.devices
      ..['tv1'] = _tv
      ..['bedroom'] = _bedroom;
    await pumpApp(
      tester,
      initialLocation: AppDestination.settings.path,
      overrides: ui.overrides,
    );
    final container = ProviderScope.containerOf(
      tester.element(find.byType(MaterialApp)),
    );
    container
        .read(settingsLocationProvider.notifier)
        .show(SettingsSection.casting);
    await settleCast(tester);
    return container;
  }

  testWidgets('the kept devices: where they are, what they taught', (
    tester,
  ) async {
    await pump(tester);
    expect(find.text('Casting'), findsWidgets);
    expect(find.text('DEVICES'), findsOneWidget);
    expect(find.text('Chromecast · 192.168.1.155'), findsOneWidget);
    expect(find.text('Added by address · 192.168.1.60'), findsOneWidget);
    expect(find.text('Learned: 1080p at most · no HEVC'), findsOneWidget);
    expect(find.text('Reset'), findsOneWidget, reason: 'only what taught');
    expect(find.text('Dolby passthrough'), findsOneWidget);
    expect(find.text('Low-latency mode'), findsOneWidget);
    expect(find.text('Smooth interlaced'), findsOneWidget);
    expect(
      find.text('Your TV reaches this computer on ports 38400–38499.'),
      findsOneWidget,
    );
  });

  testWidgets('HEVC set, what was learned reset, a device forgotten', (
    tester,
  ) async {
    await pump(tester);
    await tester.tap(find.text('No').first);
    await settleCast(tester);
    expect(ui.cast.devices.devices['bedroom']!.hevc, HevcSupport.no);

    await tester.tap(find.text('Reset'));
    await settleCast(tester);
    expect(ui.cast.devices.devices['tv1']!.learned, const CastLearned());
    expect(find.text('Reset'), findsNothing);

    await tester.tap(find.text('Forget').first);
    await settleCast(tester);
    expect(ui.cast.devices.devices.keys, ['tv1']);
    expect(find.text('Bedroom'), findsNothing);
  });

  testWidgets('the casting settings are saved and used by the next cast', (
    tester,
  ) async {
    final container = await pump(tester);
    // Dolby passthrough, Low-latency mode, Smooth interlaced: their Ons.
    final ons = find.text('On');
    await tester.tap(ons.at(0));
    await settleCast(tester);
    await tester.tap(ons.at(2));
    await settleCast(tester);
    expect(
      container.read(castSettingsControllerProvider),
      const CastSettings(dolbyPassthrough: true, smoothInterlaced: true),
    );
    final stored = await tester.runAsync(
      () => container
          .read(settingsRepositoryProvider)
          .readValue<Object?>(SettingsKeys.cast, null),
    );
    expect(
      CastSettings.fromJson(stored!.valueOrNull),
      const CastSettings(dolbyPassthrough: true, smoothInterlaced: true),
    );
  });

  testWidgets('Firewall help', (tester) async {
    await pump(tester);
    await tester.tap(find.text('Firewall help'));
    await settleCast(tester);
    expect(find.text('Casting troubleshooting'), findsOneWidget);
  });

  testWidgets('none kept yet: says how one is', (tester) async {
    await pump(tester);
    await tester.tap(find.text('Forget').first);
    await settleCast(tester);
    await tester.tap(find.text('Forget').first);
    await settleCast(tester);
    expect(find.textContaining('No devices kept yet.'), findsOneWidget);
  });
}
