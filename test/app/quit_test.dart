import 'dart:async';

import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:iptv_player/app/quit.dart';
import 'package:iptv_player/core/logging/app_log.dart';
import 'package:iptv_player/core/logging/secret_registry.dart';
import 'package:iptv_player/features/playback/domain/playback_state.dart';
import 'package:iptv_player/features/playback/presentation/player_screen.dart';
import 'package:iptv_player/features/vod/domain/watch_progress.dart';
import 'package:logger/logger.dart';

import '../features/playback/support/vod_player_rig.dart';
import '../features/vod/vod_fakes.dart';

final class _Silent extends LogOutput {
  @override
  void output(OutputEvent event) {}
}

void main() {
  testWidgets('closing the window mid-film stops it and keeps its place to '
      'the second, not its last save up to 10 s before', (tester) async {
    final t = VodPlayerRig();
    try {
      await t.open(tester, '/movies/src-1/501');
      await tester.sendKeyEvent(LogicalKeyboardKey.enter);
      await settle(tester);
      await t.firstFrame(tester);
      t.rig.engine.progress(const Duration(minutes: 7, seconds: 4));
      await settle(tester);

      final container = ProviderScope.containerOf(
        tester.element(find.byType(PlayerScreen)),
      );
      unawaited(
        quitApp(
          container,
          AppLog(output: _Silent(), secrets: SecretRegistry()),
        ),
      );
      await settle(tester);

      expect(t.rig.state, isA<PlaybackIdle>());
      final mark = await tester.runAsync(
        () => t.progress.watch(const MovieRef('src-1', '501')).first,
      );
      expect(mark?.position, const Duration(minutes: 7, seconds: 4));
    } finally {
      await t.finish(tester);
    }
  });
}
