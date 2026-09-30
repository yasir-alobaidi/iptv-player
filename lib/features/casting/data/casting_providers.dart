import 'package:iptv_player/core/cast/cast_device.dart';
import 'package:iptv_player/core/cast/cast_device_store.dart';
import 'package:iptv_player/core/cast/cast_discovery.dart';
import 'package:iptv_player/core/cast/cast_readiness.dart';
import 'package:iptv_player/core/core_providers.dart';
import 'package:iptv_player/data/cast/cast_browsers.dart';
import 'package:iptv_player/data/cast/db_cast_device_store.dart';
import 'package:iptv_player/data/cast/ffmpeg_binaries.dart';
import 'package:iptv_player/data/cast/merged_cast_discovery.dart';
import 'package:iptv_player/data/cast/unicast_address_check.dart';
import 'package:iptv_player/data/db/db_providers.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'casting_providers.g.dart';

@Riverpod(keepAlive: true)
CastDeviceStore castDeviceStore(Ref ref) =>
    DbCastDeviceStore(ref.watch(appDatabaseProvider));

@Riverpod(keepAlive: true)
CastAddressCheck castAddressCheck(Ref ref) =>
    UnicastCastAddressCheck(log: ref.watch(appLogProvider));

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

/// The bundled FFmpeg and ffprobe; null when this build has none.
@Riverpod(keepAlive: true)
FfmpegBinaries? ffmpegBinaries(Ref ref) => FfmpegBinaries.locate();

@Riverpod(keepAlive: true)
CastReadiness castReadiness(Ref ref) =>
    ref.watch(ffmpegBinariesProvider) == null
    ? CastReadiness.ffmpegMissing
    : CastReadiness.ready;
