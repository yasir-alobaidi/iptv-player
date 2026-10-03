import 'dart:async';

import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:iptv_player/core/cast/cast_plan.dart';
import 'package:iptv_player/core/cast/cast_receiver.dart';
import 'package:iptv_player/core/core_providers.dart';
import 'package:iptv_player/core/notices/app_notices.dart';
import 'package:iptv_player/data/db/app_database.dart';
import 'package:iptv_player/data/settings/settings_repository.dart';
import 'package:iptv_player/design/theme.dart';
import 'package:iptv_player/features/casting/data/casting_providers.dart';
import 'package:iptv_player/features/casting/domain/casting_state.dart';
import 'package:iptv_player/features/casting/presentation/cast_shell_slots.dart';

import '../../playback/support/playback_fakes.dart';
import '../support/cast_fakes.dart';

CastPlan _plan({
  CastDelivery delivery = CastDelivery.relayHls,
  CastVideo video = const CastVideoCopy(),
  CastAudio audio = const CastAudioCopy(0),
  int height = 2160,
}) => CastPlan(
  delivery: delivery,
  video: video,
  audio: audio,
  live: true,
  output: CastOutput(height: height),
);

const _transcode = CastVideoTranscode(
  height: 1080,
  bitRate: 6000000,
  reasons: [TranscodeReason.aboveLearnedHeight],
);

void main() {
  group('the toasts say what changed', () {
    test('a quiet fallback', () {
      expect(
        castPlanChangedText(
          _plan(delivery: CastDelivery.directHls),
          _plan(),
          'Living Room TV',
        ),
        "Living Room TV couldn't fetch it directly, so this computer sends it",
      );
      expect(
        castPlanChangedText(
          _plan(),
          _plan(video: _transcode, height: 1080),
          'Living Room TV',
        ),
        'Now re-encoding the video for Living Room TV',
      );
      expect(
        castPlanChangedText(
          _plan(),
          _plan(audio: const CastAudioToAac(0, AudioConversionReason.refused)),
          'Living Room TV',
        ),
        'Now converting the audio for Living Room TV',
      );
    });

    test('a session the TV ended', () {
      expect(
        castNoticeText(
          const CastSessionClosed(
            'Living Room TV',
            CastEnd.otherApp,
            otherApp: 'YouTube',
          ),
        ),
        'Living Room TV started YouTube',
      );
      expect(
        castNoticeText(const CastSessionClosed('Bedroom', CastEnd.lost)),
        'Lost the connection to Bedroom',
      );
      expect(
        castNoticeText(const CastStoppedOnDevice('Bedroom')),
        'Stopped on Bedroom',
      );
    });

    test("the cast's notices become the app's toasts", () async {
      final rig = CastRig();
      final notices = AppNotices();
      final container = ProviderContainer(
        overrides: [
          castCoordinatorProvider.overrideWithValue(rig.coordinator),
          appNoticesProvider.overrideWithValue(notices),
        ],
      );
      addTearDown(container.dispose);
      final shown = <AppNotice>[];
      notices.stream.listen(shown.add);
      container.read(castNoticeToastsProvider);

      await rig.coordinator.connect(tvDevice);
      await rig.phase(CastPhase.idle);
      unawaited(rig.playback.coordinator.playLive(channel(1)));
      await rig.loaded();
      rig.tv.playing();
      await rig.phase(CastPhase.playing);
      rig.tv.emit(
        rig.tv.state.copyWith(
          link: CastLink.ended,
          end: CastEnd.otherApp,
          otherApp: 'YouTube',
        ),
      );
      await rig.until(() => shown.isNotEmpty);
      expect(shown.single.message, 'Living Room TV started YouTube');
      await rig.dispose();
    });
  });

  testWidgets("Windows' firewall is explained once, before the first relay", (
    tester,
  ) async {
    final db = AppDatabase(NativeDatabase.memory());
    addTearDown(() => tester.runAsync(db.close));
    final store = CastFirewallNoticeStore(SettingsRepository(db));
    final navigator = GlobalKey<NavigatorState>();
    await tester.pumpWidget(
      MaterialApp(
        theme: buildAppTheme(),
        navigatorKey: navigator,
        home: const SizedBox.expand(),
      ),
    );
    final notice = windowsFirewallNotice(store, () => navigator.currentContext);
    var done = false;
    unawaited(notice().then((_) => done = true));
    for (var i = 0; i < 5; i++) {
      await tester.runAsync(() => Future<void>.delayed(Duration.zero));
      await tester.pump(const Duration(milliseconds: 100));
    }
    expect(find.text('Windows will ask about the firewall'), findsOneWidget);
    await tester.tap(find.text('Got it'));
    for (var i = 0; i < 5; i++) {
      await tester.runAsync(() => Future<void>.delayed(Duration.zero));
      await tester.pump(const Duration(milliseconds: 100));
    }
    expect(done, isTrue);
    expect(await tester.runAsync(store.explained), isTrue);

    unawaited(notice());
    for (var i = 0; i < 5; i++) {
      await tester.runAsync(() => Future<void>.delayed(Duration.zero));
      await tester.pump(const Duration(milliseconds: 100));
    }
    expect(find.text('Windows will ask about the firewall'), findsNothing);
  });
}
