import 'dart:async';
import 'dart:io';

import 'package:iptv_player/core/cast/cast_device.dart';
import 'package:iptv_player/core/cast/cast_device_store.dart';
import 'package:iptv_player/core/cast/cast_discovery.dart';
import 'package:iptv_player/core/cast/cast_encoders.dart';
import 'package:iptv_player/core/cast/cast_planner.dart';
import 'package:iptv_player/core/cast/cast_readiness.dart';
import 'package:iptv_player/core/cast/cast_receiver.dart';
import 'package:iptv_player/core/cast/cast_relay.dart';
import 'package:iptv_player/core/cast/stream_probe.dart';
import 'package:iptv_player/core/core_providers.dart';
import 'package:iptv_player/core/result.dart';
import 'package:iptv_player/data/cast/cast_browsers.dart';
import 'package:iptv_player/data/cast/cast_connection_check.dart';
import 'package:iptv_player/data/cast/cast_v2_receivers.dart';
import 'package:iptv_player/data/cast/db_cast_device_store.dart';
import 'package:iptv_player/data/cast/ffmpeg_binaries.dart';
import 'package:iptv_player/data/cast/ffmpeg_encoder_detector.dart';
import 'package:iptv_player/data/cast/ffprobe_stream_probe.dart';
import 'package:iptv_player/data/cast/merged_cast_discovery.dart';
import 'package:iptv_player/data/cast/relay/isolate_cast_relay.dart';
import 'package:iptv_player/data/cast/unicast_address_check.dart';
import 'package:iptv_player/data/db/db_providers.dart';
import 'package:iptv_player/data/platform/platform_providers.dart';
import 'package:iptv_player/data/process/process_providers.dart';
import 'package:iptv_player/data/settings/settings_repository.dart';
import 'package:iptv_player/features/casting/domain/cast_coordinator.dart';
import 'package:iptv_player/features/casting/domain/cast_items.dart';
import 'package:iptv_player/features/casting/domain/stream_facts_lookup.dart';
import 'package:iptv_player/features/live_tv/data/live_tv_providers.dart';
import 'package:iptv_player/features/playback/data/http_stream_prober.dart';
import 'package:iptv_player/features/playback/data/playback_providers.dart';
import 'package:iptv_player/features/vod/data/vod_providers.dart';
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

/// Where the relay keeps its sessions' segments. `bootstrap()` points it
/// into the app's cache folder; this is the fallback when it has none.
@Riverpod(keepAlive: true)
Directory relayFolder(Ref ref) =>
    Directory(p.join(Directory.systemTemp.path, 'iptv_player', 'relay'));

/// The relay (Phase 7 step 5): its isolate starts with the first cast or
/// probe, and stops with the app.
@Riverpod(keepAlive: true)
CastRelay castRelay(Ref ref) {
  final binaries = ref.watch(ffmpegBinariesProvider);
  if (binaries == null) return const UnavailableCastRelay();
  final relay = IsolateCastRelay(
    binaries: binaries,
    processFolder: ref.watch(processFolderProvider),
    relayFolder: ref.watch(relayFolderProvider),
    log: ref.watch(appLogProvider),
  );
  ref.onDispose(relay.close);
  return relay;
}

/// Settings → Casting (sketch C): Dolby passthrough, Low-latency mode,
/// Smooth interlaced. The defaults at once, the stored choices as soon as
/// they are read; a change is saved and applies to the next cast.
@Riverpod(keepAlive: true)
class CastSettingsController extends _$CastSettingsController {
  @override
  CastSettings build() {
    unawaited(_load());
    return const CastSettings();
  }

  var _changed = false;

  Future<void> _load() async {
    final stored = await ref
        .read(settingsRepositoryProvider)
        .readValue<Object?>(SettingsKeys.cast, null);
    // A choice made while loading wins over what was stored.
    if (!_changed && ref.mounted) {
      state = CastSettings.fromJson(stored.valueOrNull);
    }
  }

  Future<Result<void>> update(CastSettings settings) {
    _changed = true;
    state = settings;
    return ref
        .read(settingsRepositoryProvider)
        .writeValue(SettingsKeys.cast, settings.toJson());
  }
}

/// Whether this computer has an address on a network a TV could be on
/// (not only loopback): the picker says so when it hasn't.
@riverpod
Future<bool> castNetworkAvailable(Ref ref) async {
  try {
    final interfaces = await NetworkInterface.list();
    return interfaces.any(
      (interface) => interface.addresses.any((a) => !a.isLoopback),
    );
  } on Object {
    // Can't tell: don't claim there is no network.
    return true;
  }
}

/// The TV's picture, from the app's artwork cache. `bootstrap()` points it
/// at the cache; without one there is none.
@Riverpod(keepAlive: true)
CastPictures castPictures(Ref ref) => const NoCastPictures();

/// What runs before the first relay start: on Windows, the dialog that
/// explains the firewall prompt which follows (step 7). Null: nothing.
@Riverpod(keepAlive: true)
RelayFirewallNotice? relayFirewallNotice(Ref ref) => null;

typedef RelayFirewallNotice = Future<void> Function();

/// The cast session (Phase 7 step 6): the playback coordinator hands it
/// every play while it is on.
@Riverpod(keepAlive: true)
CastCoordinator castCoordinator(Ref ref) {
  final coordinator = CastCoordinator(
    receivers: ref.watch(castReceiversProvider),
    relay: ref.watch(castRelayProvider),
    lookup: ref.watch(streamFactsLookupProvider),
    encoderDetection: ref.watch(castEncoderDetectionProvider),
    devices: ref.watch(castDeviceStoreProvider),
    items: CastItems(
      resolver: ref.watch(streamResolverProvider),
      guide: ref.watch(guideServiceProvider),
    ),
    playback: ref.watch(playbackCoordinatorProvider),
    classify: classifyStreamFailure,
    log: ref.watch(appLogProvider),
    progress: ref.watch(watchProgressProvider),
    history: ref.watch(playbackHistoryProvider),
    sleep: ref.watch(sleepInhibitorProvider),
    pictures: ref.watch(castPicturesProvider),
    settings: () => ref.read(castSettingsControllerProvider),
    audioLanguages: () =>
        ref.read(playbackSettingsControllerProvider).audioLanguages,
    beforeFirstRelay: ref.watch(relayFirewallNoticeProvider),
  );
  ref.onDispose(coordinator.dispose);
  return coordinator;
}

/// Whether Windows' firewall prompt has been explained before the first
/// relay start (Phase 7 step 7): once is enough.
@Riverpod(keepAlive: true)
CastFirewallNoticeStore castFirewallNoticeStore(Ref ref) =>
    CastFirewallNoticeStore(ref.watch(settingsRepositoryProvider));

final class CastFirewallNoticeStore {
  new(this._settings);

  final SettingsRepository _settings;

  Future<bool> explained() async =>
      (await _settings.readBool(SettingsKeys.castFirewallExplained))
          .valueOrNull ??
      false;

  Future<void> markExplained() async {
    await _settings.writeValue(SettingsKeys.castFirewallExplained, true);
  }
}
