import 'package:iptv_player/core/cast/cast_device.dart';
import 'package:iptv_player/core/cast/cast_discovery.dart';
import 'package:iptv_player/core/logging/app_log.dart';
import 'package:iptv_player/data/cast/cast_channel.dart';
import 'package:iptv_player/data/cast/cast_namespaces.dart';
import 'package:iptv_player/data/cast/cast_status_json.dart';
import 'package:iptv_player/data/cast/cast_transport.dart';
import 'package:iptv_player/data/cast/cast_v2_receivers.dart';

/// Asks the device at an address who it is over a Cast connection:
/// CONNECT, then the receiver's and the multizone status. Nothing shows on
/// its screen. The fallback for a device that ignores the direct DNS-SD
/// query (`UnicastCastAddressCheck`): one on another subnet, or a test
/// receiver at `127.0.0.1:<port>`.
///
/// MULTIZONE_STATUS names the device and gives its id (Living Room TV
/// sends it, ADR-014); one that doesn't is named by its address.
final class CastConnectionCheck implements CastAddressCheck {
  new({
    this.log,
    this.connect = connectCastSocket,
    this.timeout = const Duration(seconds: 3),
  });

  final AppLog? log;
  final CastConnect connect;
  final Duration timeout;

  static const _tag = 'cast.address';

  @override
  Future<CastAddressAnswer> check(CastAddress address) async {
    final (channel, error) = await openCastChannel(
      address,
      connect: connect,
      timings: CastTimings(connect: timeout, answer: timeout),
      log: log,
    );
    if (channel == null) {
      log?.info(_tag, 'no Cast connection to $address: $error');
      return const CastNoAnswer();
    }
    try {
      channel.connectTo(castReceiverId);
      final (zone, status) = await (
        channel.request(castReceiverId, CastNamespace.multizone, const {
          'type': 'GET_STATUS',
        }, timeout: timeout),
        ReceiverChannel(channel).status(timeout: timeout),
      ).wait;
      if (status == null) {
        log?.info(_tag, '$address took a connection but did not answer');
        return const CastNoAnswer();
      }
      final devices = zone?.type == 'MULTIZONE_STATUS'
          ? readZoneDevices(zone!.payload)
          : const <CastZoneDevice>[];
      // A group lists its members; which of them answered isn't said.
      final self = devices.length == 1 ? devices.single : null;
      final capabilities = self?.capabilities;
      if (self != null && capabilities != null && capabilities & 1 == 0) {
        return CastAudioOnlyAnswered(self.name);
      }
      log?.info(
        _tag,
        '$address answered over Cast'
        '${self == null ? ' without its name' : ' as "${self.name}"'}',
      );
      return CastDeviceAnswered(
        CastDevice(
          id: self?.id ?? 'address:${address.host}:${address.port}',
          name: self?.name ?? address.toString(),
          host: address.host,
          port: address.port,
          capabilities: capabilities,
          status: status.foreground?.displayName,
          manual: true,
        ),
      );
    } finally {
      await channel.close();
    }
  }
}

/// Several checks in turn: the first answer that isn't [CastNoAnswer].
final class CastAddressChecks implements CastAddressCheck {
  const new(this.checks);

  final List<CastAddressCheck> checks;

  @override
  Future<CastAddressAnswer> check(CastAddress address) async {
    for (final check in checks) {
      final answer = await check.check(address);
      if (answer is! CastNoAnswer) return answer;
    }
    return const CastNoAnswer();
  }
}
