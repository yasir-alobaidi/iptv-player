import 'package:iptv_player/core/cast/cast_device.dart';
import 'package:iptv_player/core/cast/cast_discovery.dart';

/// The DNS-SD service type Cast devices announce.
const castServiceType = '_googlecast._tcp';

/// DNS-SD TXT strings (`key=value`) as a map (RFC 6763 §6): keys are
/// read without case, the first of a repeated key wins, a string with no
/// `=` is a key with an empty value, and one with an empty key is
/// skipped.
Map<String, String> parseTxtStrings(Iterable<String> strings) {
  final map = <String, String>{};
  for (final entry in strings) {
    final equals = entry.indexOf('=');
    final key = (equals < 0 ? entry : entry.substring(0, equals))
        .trim()
        .toLowerCase();
    if (key.isEmpty) continue;
    map.putIfAbsent(key, () => equals < 0 ? '' : entry.substring(equals + 1));
  }
  return map;
}

/// What one DNS-SD answer for a `_googlecast._tcp` service says: the
/// device with a screen it is ([CastDeviceAnswered]), a speaker
/// ([CastAudioOnlyAnswered]), or null when it gives no address to reach
/// it at.
///
/// [instance] is the service's instance name
/// (`Chromecast-711587f3…`), [txt] its TXT map, [hosts] its addresses in
/// any order, and [port] its SRV port. Tolerant of anything a device
/// might send (hard rule 1): no `fn`, `md` or `id`, a `ca` that isn't a
/// number, odd characters in the name.
CastAddressAnswer? readCastService({
  required String instance,
  required Map<String, String> txt,
  required Iterable<String> hosts,
  int? port,
}) {
  final host = preferredHost(hosts);
  if (host == null) return null;
  final model = _text(txt['md']);
  final name =
      _text(txt['fn']) ?? model ?? _text(_withoutId(instance)) ?? 'Cast device';
  final capabilities = int.tryParse(txt['ca']?.trim() ?? '', radix: 10);
  // Bit 0 is video out (docs/04). A device that sent no readable bits is
  // listed: a LOAD it can't play says so, a hidden TV says nothing.
  if (capabilities != null && capabilities & 1 == 0) {
    return CastAudioOnlyAnswered(name);
  }
  return CastDeviceAnswered(
    CastDevice(
      id: castDeviceId(instance, txt),
      name: name,
      model: model,
      host: host,
      port: port != null && port > 0 && port <= 65535 ? port : castPort,
      capabilities: capabilities,
      status: _text(txt['rs']),
    ),
  );
}

/// The device's id: TXT `id`, else the 32 hex digits the instance name
/// ends in (Cast devices name the instance `<model>-<id>`), else the
/// instance name. Lower case, so both browsers agree.
String castDeviceId(String instance, Map<String, String> txt) {
  final id = txt['id']?.trim().toLowerCase() ?? '';
  if (id.isNotEmpty) return id;
  final tail = RegExp(r'-([0-9a-fA-F]{32})$').firstMatch(instance.trim());
  return (tail?.group(1) ?? instance.trim()).toLowerCase();
}

/// The address to connect to: an IPv4 one first, then a global IPv6
/// one, then any other; null when there is none. The relay serves on
/// the address the Cast connection leaves from, and a TV reaches an IPv4
/// URL most reliably.
String? preferredHost(Iterable<String> hosts) {
  String? ipv6;
  String? other;
  for (final raw in hosts) {
    final host = raw.trim();
    if (host.isEmpty) continue;
    if (RegExp(r'^\d{1,3}(\.\d{1,3}){3}$').hasMatch(host)) return host;
    if (host.contains(':')) {
      if (!host.toLowerCase().startsWith('fe80')) ipv6 ??= host;
      other ??= host;
    } else {
      other ??= host;
    }
  }
  return ipv6 ?? other;
}

/// Instance names end in `-<32 hex>`; without it they read as a model
/// (and one that is only the id reads as nothing).
String _withoutId(String instance) =>
    instance.replaceFirst(RegExp(r'-?[0-9a-fA-F]{32}$'), '');

/// [value] fit to show: control characters as spaces, runs collapsed,
/// at most 100 characters; null when nothing is left.
String? _text(String? value) {
  if (value == null) return null;
  final cleaned = value
      .replaceAll(RegExp(r'[\x00-\x1F\x7F\uFFFD]'), ' ')
      .replaceAll(RegExp(r'\s+'), ' ')
      .trim();
  if (cleaned.isEmpty) return null;
  final runes = cleaned.runes.toList();
  return runes.length <= 100
      ? cleaned
      : String.fromCharCodes(runes.take(100)).trimRight();
}
