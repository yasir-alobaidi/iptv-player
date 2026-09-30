import 'package:iptv_player/core/cast/cast_device.dart';
import 'package:meta/meta.dart';

/// Finds the Cast devices with a screen on the network (docs/04).
abstract interface class CastDiscovery {
  /// The devices found, and the ones the user added by address, by name.
  /// Discovery runs while this is listened to, and stops with the last
  /// listener; a new listener gets the current list at once.
  Stream<List<CastDevice>> get devices;
}

/// Asks the device at an address who it is, for "Add device by address"
/// (sketch E). Shows nothing on its screen.
abstract interface class CastAddressCheck {
  Future<CastAddressAnswer> check(CastAddress address);
}

/// What an address answered.
@immutable
sealed class CastAddressAnswer {
  const new();
}

/// A Cast device with a screen.
final class CastDeviceAnswered extends CastAddressAnswer {
  const new(this.device);

  final CastDevice device;
}

/// A Cast device without video out, such as a speaker: not listed.
final class CastAudioOnlyAnswered extends CastAddressAnswer {
  const new(this.name);

  final String name;
}

/// Nothing answered in time.
final class CastNoAnswer extends CastAddressAnswer {
  const new();
}

/// What the user typed as a device's address: a host (an IPv4 address,
/// an IPv6 address, or a name) and a port, 8009 unless given.
@immutable
final class CastAddress {
  const new(this.host, [this.port = castPort]);

  /// Reads `192.168.1.60`, `192.168.1.60:8009`, `tv.local`, `fe80::1` or
  /// `[fe80::1]:8009`, with spaces around it. Null for anything else.
  static CastAddress? tryParse(String text) {
    final value = text.trim();
    if (value.isEmpty || value.contains(RegExp(r'\s|/|@'))) return null;
    if (value.startsWith('[')) {
      final close = value.indexOf(']');
      if (close < 0) return null;
      final host = value.substring(1, close);
      final rest = value.substring(close + 1);
      if (!_isIpv6(host)) return null;
      if (rest.isEmpty) return CastAddress(host);
      if (!rest.startsWith(':')) return null;
      final port = _port(rest.substring(1));
      return port == null ? null : CastAddress(host, port);
    }
    final colons = ':'.allMatches(value).length;
    if (colons > 1) return _isIpv6(value) ? CastAddress(value) : null;
    final parts = value.split(':');
    final host = parts.first;
    if (!_isHost(host)) return null;
    if (parts.length == 1) return CastAddress(host);
    final port = _port(parts[1]);
    return port == null ? null : CastAddress(host, port);
  }

  final String host;
  final int port;

  static int? _port(String text) {
    if (!RegExp(r'^\d{1,5}$').hasMatch(text)) return null;
    final port = int.parse(text);
    return port >= 1 && port <= 65535 ? port : null;
  }

  /// Eight groups of 1–4 hex digits, or fewer around one `::`; the last
  /// two may be an IPv4 address; a `%zone` may follow.
  static bool _isIpv6(String text) {
    final zone = text.indexOf('%');
    if (zone == 0 || zone == text.length - 1) return false;
    final address = zone < 0 ? text : text.substring(0, zone);
    if (zone > 0 && !RegExp(r'^[\w.-]+$').hasMatch(text.substring(zone + 1))) {
      return false;
    }
    final halves = address.split('::');
    if (halves.length > 2) return false;
    var groups = 0;
    for (final (h, half) in halves.indexed) {
      if (half.isEmpty) continue;
      final parts = half.split(':');
      for (final (i, part) in parts.indexed) {
        final last = h == halves.length - 1 && i == parts.length - 1;
        if (last && part.contains('.')) {
          if (!_isHost(part) || !RegExp(r'^[\d.]+$').hasMatch(part)) {
            return false;
          }
          groups += 2;
        } else if (RegExp(r'^[0-9A-Fa-f]{1,4}$').hasMatch(part)) {
          groups += 1;
        } else {
          return false;
        }
      }
    }
    return halves.length == 2 ? groups <= 7 : groups == 8;
  }

  static bool _isHost(String text) {
    if (RegExp(r'^\d+(\.\d+)*$').hasMatch(text)) {
      final octets = text.split('.');
      return octets.length == 4 &&
          octets.every((o) => o.length <= 3 && int.parse(o) <= 255);
    }
    return text.length <= 253 &&
        RegExp(
          r'^[A-Za-z0-9]([A-Za-z0-9-]{0,62})?(\.[A-Za-z0-9]([A-Za-z0-9-]{0,62})?)*\.?$',
        ).hasMatch(text);
  }

  @override
  bool operator ==(Object other) =>
      other is CastAddress && other.host == host && other.port == port;

  @override
  int get hashCode => Object.hash(host, port);

  @override
  String toString() => port == castPort
      ? host
      : (host.contains(':') ? '[$host]:$port' : '$host:$port');
}
