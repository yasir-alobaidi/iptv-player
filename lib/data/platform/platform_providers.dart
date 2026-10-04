import 'package:iptv_player/core/core_providers.dart';
import 'package:iptv_player/core/platform/shared_sleep.dart';
import 'package:iptv_player/core/platform/sleep_inhibitor.dart';
import 'package:iptv_player/data/platform/sleep_inhibitors.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'platform_providers.g.dart';

/// Holds sleep off while the computer serves a cast (Phase 7 decision 7),
/// and Phase 8's downloads.
@Riverpod(keepAlive: true)
SleepInhibitor sleepInhibitor(Ref ref) {
  final inhibitor = platformSleepInhibitor(ref.watch(appLogProvider));
  ref.onDispose(inhibitor.release);
  return inhibitor;
}

/// The one hold the cast and the downloads share (Phase 8 step 3): the
/// computer sleeps again only when neither needs it awake.
@Riverpod(keepAlive: true)
SharedSleep sharedSleep(Ref ref) =>
    SharedSleep(ref.watch(sleepInhibitorProvider));
