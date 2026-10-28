import 'package:iptv_player/core/cast/cast_device.dart';
import 'package:iptv_player/core/cast/cast_discovery.dart';
import 'package:iptv_player/data/airplay/airplay_features.dart';
import 'package:iptv_player/data/cast/cast_txt.dart';

/// An `_airplay._tcp` service as a device to cast to (ADR-067): one that
/// plays video by URL (an Apple TV; a Samsung, LG, Sony, Vizio, Hisense or
/// Roku TV with AirPlay 2). A speaker, a Mac's screen-only receiver or a
/// receiver that wants a password is left out. Tolerant, as
/// `readCastService` (hard rule 1).
CastAddressAnswer? readAirPlayService({
  required String instance,
  required Map<String, String> txt,
  required Iterable<String> hosts,
  int? port,
}) {
  final host = preferredHost(hosts);
  if (host == null) return null;
  final info = AirPlayDeviceInfo.fromTxt(name: instance, txt: txt);
  final deviceId = info.deviceId;
  if (deviceId == null || !info.playsVideoUrls || info.needsPassword) {
    return null;
  }
  final name = cleanCastText(instance) ?? info.model ?? 'AirPlay TV';
  final model = [?info.manufacturer, ?info.model].join(' ');
  return CastDeviceAnswered(
    CastDevice(
      id: '$airPlayIdPrefix$deviceId',
      name: name,
      host: host,
      port: port ?? airPlayPort,
      model: model.isEmpty ? null : model,
      needsPairing: info.needsPin,
    ),
  );
}

/// The port AirPlay receivers listen on, unless their record says.
const airPlayPort = 7000;
