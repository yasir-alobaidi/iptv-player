import 'package:iptv_player/core/core_providers.dart';
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
