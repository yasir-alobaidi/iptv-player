import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:iptv_player/app/destinations.dart';
import 'package:iptv_player/features/settings/presentation/settings_screen.dart';
import 'package:iptv_player/features/sources/domain/source.dart';

import '../../app/app_harness.dart';
import '../live_tv/live_tv_fakes.dart';

void main() {
  Future<LiveTvFakes> open(WidgetTester tester) async {
    final live = LiveTvFakes();
    addTearDown(() => tester.runAsync(live.db.close));
    await tester.runAsync(live.seed);
    await pumpApp(
      tester,
      initialLocation: AppDestination.settings.path,
      overrides: live.overrides,
    );
    await _settle(tester);
    await tester.tap(find.text('Playback').first);
    await _settle(tester);
    return live;
  }

  testWidgets("a preset chosen here is the next stream's preset", (
    tester,
  ) async {
    final live = await open(tester);
    expect(find.byType(SettingsPanel), findsOneWidget);
    expect(find.textContaining('About 8 s of buffer'), findsOneWidget);

    await tester.tap(find.text('Stable'));
    await _settle(tester);
    expect(find.textContaining('About 20 s of buffer'), findsOneWidget);

    final stored = await tester.runAsync(
      () => live.db.settingsDao.read('playback.settings'),
    );
    expect(stored, contains('"preset":"stable"'));
  });

  testWidgets('languages are saved as typed; Deinterlacing Off', (
    tester,
  ) async {
    final live = await open(tester);

    await tester.enterText(find.byType(EditableText).first, 'AR, en');
    await _settle(tester);
    await tester.tap(find.text('Off'));
    await _settle(tester);

    final stored = await tester.runAsync(
      () => live.db.settingsDao.read('playback.settings'),
    );
    expect(stored, contains('"audio":["ar","en"]'));
    expect(stored, contains('"deinterlace":"off"'));
  });

  testWidgets("the source's live format is saved on the source", (
    tester,
  ) async {
    final live = await open(tester);
    expect(find.text('Live format · Northwind TV'), findsOneWidget);

    await tester.tap(find.text('HLS'));
    await _settle(tester);

    final (id, draft) = live.fakes.sources.updated.single;
    expect(id, 'src-1');
    expect(draft.liveFormat, LiveFormat.hls);
    expect(draft.password, isNull, reason: 'the stored one is kept');
  });
}

Future<void> _settle(WidgetTester tester) async {
  for (var i = 0; i < 5; i++) {
    await tester.runAsync(() => Future<void>.delayed(Duration.zero));
    await tester.pump(const Duration(milliseconds: 50));
  }
}
