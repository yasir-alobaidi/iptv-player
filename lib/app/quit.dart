import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:iptv_player/core/logging/app_log.dart';
import 'package:iptv_player/data/process/process_providers.dart';
import 'package:iptv_player/features/casting/data/casting_providers.dart';
import 'package:iptv_player/features/downloads/data/download_providers.dart';
import 'package:iptv_player/features/playback/data/playback_providers.dart';

/// What quitting stops, of what ran (the desktop window's close): the
/// cast (its TV goes home), the relay and its FFmpegs, the downloads
/// (flushed, to resume next time), what plays (saved where it is), every
/// other supervised process (hard rule 8).
Future<void> quitApp(ProviderContainer container, AppLog log) async {
  final clock = Stopwatch()..start();
  if (container.exists(castCoordinatorProvider)) {
    await container.read(castCoordinatorProvider).shutdown();
  }
  if (container.exists(castRelayProvider)) {
    await container.read(castRelayProvider).close();
  }
  // Downloads pause and flush; the next launch resumes them (docs/09).
  // The queue closes as this is called, so the connection the player
  // gives up below isn't taken by a download on the way out.
  final downloads = container.exists(downloadQueueProvider)
      ? container.read(downloadQueueProvider).shutdown()
      : null;
  // What plays stops and keeps its place to the second: a film closed
  // with the window had kept only its last save, up to 10 s before.
  final playback = container.exists(playbackCoordinatorProvider)
      ? container.read(playbackCoordinatorProvider).stop()
      : null;
  await Future.wait([?downloads, ?playback]);
  if (container.exists(processSupervisorProvider)) {
    await container.read(processSupervisorProvider).stopAll();
  }
  log.info('bootstrap', 'Quit in ${clock.elapsedMilliseconds} ms');
}
