import 'dart:io';

import 'package:iptv_player/core/cast/cast_device.dart';
import 'package:iptv_player/core/cast/cast_device_store.dart';

import 'package:iptv_player/core/cast/cast_discovery.dart';
import 'package:iptv_player/core/cast/cast_encoders.dart';
import 'package:iptv_player/core/cast/cast_readiness.dart';
import 'package:iptv_player/core/cast/cast_receiver.dart';
import 'package:iptv_player/core/cast/stream_probe.dart';
import 'package:iptv_player/core/core_providers.dart';
import 'package:iptv_player/data/cast/cast_browsers.dart';
import 'package:iptv_player/data/cast/cast_connection_check.dart';
import 'package:iptv_player/data/cast/cast_v2_receivers.dart';
import 'package:iptv_player/data/cast/db_cast_device_store.dart';
import 'package:iptv_player/data/cast/ffmpeg_binaries.dart';
import 'package:iptv_player/data/cast/ffmpeg_encoder_detector.dart';
import 'package:iptv_player/data/cast/ffprobe_stream_probe.dart';
import 'package:iptv_player/data/cast/merged_cast_discovery.dart';
import 'package:iptv_player/data/cast/unicast_address_check.dart';
import 'package:iptv_player/data/db/db_providers.dart';
import 'package:iptv_player/data/process/process_providers.dart';
import 'package:iptv_player/features/casting/domain/stream_facts_lookup.dart';
import 'package:path/path.dart' as p;
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'casting_providers.g.dart';

@Riverpod(keepAlive: true)
CastDeviceStore castDeviceStore(Ref ref) =>
    DbCastDeviceStore(ref.watch(appDatabaseProvider));

/// The device's mDNS port first (its name and model, ADR-014), then a
/// Cast connection for one that ignores it.
@Riverpod(keepAlive: true)
CastAddressCheck castAddressCheck(Ref ref) {
  final log = ref.watch(appLogProvider);
  return CastAddressChecks([
    UnicastCastAddressCheck(log: log),
    CastConnectionCheck(log: log),
  ]);
}

/// bonsoir and multicast_dns side by side (Phase 7 decision 6).
@Riverpod(keepAlive: true)
CastDiscovery castDiscovery(Ref ref) {
  final log = ref.watch(appLogProvider);
  return MergedCastDiscovery(
    browsers: [
      BonsoirCastBrowser(log: log),
      MulticastDnsCastBrowser(log: log),
    ],
    store: ref.watch(castDeviceStoreProvider),
    addressCheck: ref.watch(castAddressCheckProvider),
    log: log,
  );
}

/// The Cast devices on the network and the ones added by address.
/// Discovery runs only while something shows them.
@riverpod
Stream<List<CastDevice>> castDevices(Ref ref) =>
    ref.watch(castDiscoveryProvider).devices;

/// Our own Cast v2 client (docs/04).
@Riverpod(keepAlive: true)
CastReceivers castReceivers(Ref ref) =>
    CastV2Receivers(log: ref.watch(appLogProvider));

/// The bundled FFmpeg and ffprobe; null when this build has none.
@Riverpod(keepAlive: true)
FfmpegBinaries? ffmpegBinaries(Ref ref) => FfmpegBinaries.locate();

@Riverpod(keepAlive: true)
CastReadiness castReadiness(Ref ref) =>
    ref.watch(ffmpegBinariesProvider) == null
    ? CastReadiness.ffmpegMissing
    : CastReadiness.ready;

/// The bundled ffprobe under the process supervisor (docs/04).
@Riverpod(keepAlive: true)
StreamProbe streamProbe(Ref ref) {
  final binaries = ref.watch(ffmpegBinariesProvider);
  if (binaries == null) return const UnavailableStreamProbe();
  return FfprobeStreamProbe(
    ffprobe: binaries.ffprobe,
    supervisor: ref.watch(processSupervisorProvider),
    log: ref.watch(appLogProvider),
  );
}

/// A cast's facts, cheapest first; remembered for the app's run (Phase 7
/// decision 4).
@Riverpod(keepAlive: true)
StreamFactsLookup streamFactsLookup(Ref ref) =>
    StreamFactsLookup(probe: ref.watch(streamProbeProvider));

/// Where casting keeps its own files. `bootstrap()` points it into the
/// app's own folder; this is the fallback when it has none.
@Riverpod(keepAlive: true)
Directory castFolder(Ref ref) =>
    Directory(p.join(Directory.systemTemp.path, 'iptv_player', 'cast'));

/// The encoders a re-encode can use (Phase 7 step 4), found once per
/// FFmpeg and remembered.
@Riverpod(keepAlive: true)
CastEncoderDetection castEncoderDetection(Ref ref) {
  final binaries = ref.watch(ffmpegBinariesProvider);
  if (binaries == null) return const NoCastEncoders();
  return FfmpegEncoderDetector(
    binaries: binaries,
    folder: ref.watch(castFolderProvider),
    supervisor: ref.watch(processSupervisorProvider),
    log: ref.watch(appLogProvider),
  );
}
