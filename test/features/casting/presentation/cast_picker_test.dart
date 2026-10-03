import 'dart:async';

import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:iptv_player/app/destinations.dart';
import 'package:iptv_player/core/cast/cast_device.dart';
import 'package:iptv_player/core/cast/cast_discovery.dart';
import 'package:iptv_player/core/cast/cast_readiness.dart';
import 'package:iptv_player/features/casting/domain/casting_state.dart';
import 'package:iptv_player/features/casting/presentation/add_cast_device_dialog.dart';
import 'package:iptv_player/features/casting/presentation/cast_picker.dart';
import 'package:iptv_player/features/playback/domain/playable.dart';

import '../../../app/app_harness.dart';
import '../support/cast_fakes.dart';
import '../support/cast_ui_harness.dart';

/// The dialog's address field (Live TV's filter field is there too).
final Finder _addressField = find.descendant(
  of: find.byType(AddCastDeviceDialog),
  matching: find.byType(EditableText),
);

const _bedroom = CastDevice(
  id: 'bedroom',
  name: 'Bedroom',
  host: '192.168.1.60',
  model: 'Chromecast',
  manual: true,
  answering: false,
);

const _kitchen = CastDevice(
  id: 'kitchen',
  name: 'Kitchen Display',
  host: '192.168.1.70',
  model: 'Chromecast built-in',
  status: 'Spotify',
);

/// The device picker (canvas `Cast device picker`): every state, the
/// keyboard, casting from it, Add by address and the help.
void main() {
  late CastUi ui;

  Future<void> pump(WidgetTester tester, {bool seed = true}) async {
    ui = CastUi();
    addTearDown(() => tester.runAsync(ui.live.db.close));
    addTearDown(ui.dispose);
    if (seed) await tester.runAsync(ui.live.seed);
    await pumpApp(
      tester,
      initialLocation: AppDestination.liveTv.path,
      overrides: ui.overrides,
    );
    await settleCast(tester);
  }

  Future<void> openPicker(WidgetTester tester) async {
    final cast = findByLabel('Cast');
    await tester.tap(cast.evaluate().isEmpty ? findByLabel('Casting') : cast);
    await settleCast(tester);
    expect(find.text('Cast to a device'), findsOneWidget);
  }

  /// Ends a session a test started, while the test still pumps.
  Future<void> stopCasting(WidgetTester tester) async {
    unawaited(ui.cast.coordinator.disconnect());
    await settleCast(tester);
  }

  testWidgets('the devices: name, what is known of them, their status', (
    tester,
  ) async {
    await pump(tester);
    ui.devices = [tvDevice, _bedroom, _kitchen];
    ui.cast.devices.devices['tv1'] = const KnownCastDevice(
      id: 'tv1',
      name: 'Living Room TV',
      host: '192.168.1.155',
      port: 8009,
      manual: false,
      model: 'Chromecast',
      hevc: HevcSupport.auto,
      learned: CastLearned(maxHeight: 1080, refusedCodecs: {'hevc'}),
    );
    await openPicker(tester);

    expect(find.text('Looking for devices on your network…'), findsOneWidget);
    expect(find.text('Living Room TV'), findsOneWidget);
    expect(find.text('Chromecast · 1080p · H.264 only'), findsOneWidget);
    expect(find.text('Available'), findsOneWidget);
    expect(find.text('Bedroom'), findsOneWidget);
    expect(find.text('Not answering'), findsOneWidget);
    expect(find.text('Busy · playing music'), findsOneWidget);
    expect(find.text('Add device by IP address'), findsOneWidget);
    expect(find.textContaining('Device not showing?'), findsOneWidget);
    expect(find.text('Choose a device, then play something.'), findsOneWidget);
  });

  testWidgets('nothing found after a while: the help comes forward', (
    tester,
  ) async {
    await pump(tester);
    await openPicker(tester);
    expect(find.text('Same network'), findsNothing);
    await tester.pump(CastPicker.searchTime);
    await settleCast(tester);
    expect(find.text('No devices found yet. Still looking…'), findsOneWidget);
    expect(find.text('Same network'), findsOneWidget);
    expect(find.text('Firewall'), findsOneWidget);
  });

  testWidgets('a build without FFmpeg says so, and casts nothing', (
    tester,
  ) async {
    await pump(tester);
    ui
      ..ready = CastReadiness.ffmpegMissing
      ..devices = [tvDevice];
    await openPicker(tester);
    expect(find.text("This build can't cast: FFmpeg is missing."), findsOne);
    await tester.tap(find.text('Living Room TV'));
    await settleCast(tester);
    expect(ui.cast.receivers.joins, isEmpty);
  });

  testWidgets('no network: says so', (tester) async {
    await pump(tester);
    ui.online = false;
    await openPicker(tester);
    expect(find.textContaining("This computer isn't on a network"), findsOne);
  });

  testWidgets('C opens it, the first device has the focus, Esc closes it', (
    tester,
  ) async {
    await pump(tester);
    ui.devices = [tvDevice, _bedroom];
    await tester.sendKeyEvent(LogicalKeyboardKey.keyC);
    await settleCast(tester);
    expect(find.text('Cast to a device'), findsOneWidget);
    expect(focusedLabelOf(tester), startsWith('Living Room TV'));
    await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
    await tester.pump();
    expect(focusedLabelOf(tester), startsWith('Bedroom'));
    await tester.sendKeyEvent(LogicalKeyboardKey.escape);
    await settleCast(tester);
    expect(find.text('Cast to a device'), findsNothing);
  });

  testWidgets('Enter casts: what played here moves to the TV, the casting '
      'view opens', (tester) async {
    await pump(tester);
    ui.devices = [tvDevice];
    final channel = await tester.runAsync(() => ui.channel('201'));
    unawaited(ui.live.rig.coordinator.playLive(channel!));
    await settleCast(tester);
    ui.live.rig.engine.firstFrame();
    await settleCast(tester);
    await openPicker(tester);
    expect(find.textContaining('Arena Sports 1'), findsWidgets);

    await tester.sendKeyEvent(LogicalKeyboardKey.enter);
    await settleCast(tester, rounds: 10);
    expect(find.text('Cast to a device'), findsNothing);
    expect(ui.cast.receivers.joins.single.host, '192.168.1.155');
    expect(ui.live.rig.engine.calls, contains('stop'));
    expect(ui.cast.tv.loads, hasLength(1));
    expect(ui.cast.coordinator.state.item, PlayableChannel(channel));
    expect(find.text('PLAYING ON LIVING ROOM TV'), findsOneWidget);
    await stopCasting(tester);
  });

  testWidgets('while casting: Stop casting from the picker', (tester) async {
    await pump(tester);
    ui.devices = [tvDevice];
    unawaited(ui.cast.coordinator.connect(tvDevice));
    await settleCast(tester);
    await openPicker(tester);
    expect(find.text('Casting to Living Room TV'), findsOneWidget);
    expect(find.text('Casting'), findsOneWidget, reason: "the row's status");
    await tester.tap(
      find.descendant(
        of: find.byType(CastPicker),
        matching: find.text('Stop casting'),
      ),
    );
    await settleCast(tester);
    expect(ui.cast.coordinator.state.phase, CastPhase.off);
    expect(ui.cast.tv.calls, contains('stop'));
  });

  group('Add device by IP address (sketch E)', () {
    Future<void> openAdd(WidgetTester tester) async {
      await openPicker(tester);
      await tester.tap(find.text('Add device by IP address'));
      await settleCast(tester);
      expect(find.text('Add a device by address'), findsOneWidget);
    }

    testWidgets('a device answers: kept, and listed', (tester) async {
      await pump(tester);
      ui.check.answers['192.168.1.60'] = const CastDeviceAnswered(
        CastDevice(
          id: 'bedroom',
          name: 'Bedroom',
          host: '192.168.1.60',
          model: 'Chromecast',
        ),
      );
      await openAdd(tester);
      await tester.enterText(_addressField, '192.168.1.60');
      await tester.tap(find.text('Add'));
      await settleCast(tester);
      expect(find.text('Add a device by address'), findsNothing);
      expect(ui.cast.devices.devices['bedroom']!.manual, isTrue);
    });

    testWidgets('nothing answers, a speaker, a bad address: said', (
      tester,
    ) async {
      await pump(tester);
      ui.check.answers['192.168.1.80'] = const CastAudioOnlyAnswered(
        'Kitchen speaker',
      );
      await openAdd(tester);
      final field = _addressField;
      await tester.enterText(field, 'not an address!');
      await tester.tap(find.text('Add'));
      await settleCast(tester);
      expect(find.text('Type an address like 192.168.1.60.'), findsOneWidget);
      await tester.enterText(field, '192.168.1.99');
      await tester.tap(find.text('Add'));
      await settleCast(tester);
      expect(find.text('Nothing answered at 192.168.1.99.'), findsOneWidget);
      await tester.enterText(field, '192.168.1.80');
      await tester.tap(find.text('Add'));
      await settleCast(tester);
      expect(
        find.text(
          '"Kitchen speaker" is a speaker: it has no screen to cast to.',
        ),
        findsOneWidget,
      );
      expect(ui.cast.devices.devices, isEmpty);
    });
  });

  testWidgets('Troubleshoot opens the help', (tester) async {
    await pump(tester);
    await openPicker(tester);
    await tester.tap(find.text('Troubleshoot'));
    await settleCast(tester);
    expect(find.text('Casting troubleshooting'), findsOneWidget);
    expect(find.textContaining('38400–38499'), findsWidgets);
  });
}
