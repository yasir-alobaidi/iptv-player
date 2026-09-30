import 'dart:async';
import 'dart:io';
import 'dart:math';

import 'package:iptv_player/core/cast/cast_device.dart';
import 'package:iptv_player/core/cast/cast_discovery.dart';
import 'package:iptv_player/core/logging/app_log.dart';
import 'package:iptv_player/data/cast/cast_txt.dart';
import 'package:iptv_player/data/cast/dns_message.dart';

/// Asks the address itself who it is, with a DNS-SD query sent straight
/// to its mDNS port (legacy unicast, RFC 6762 §6.7). A Cast device
/// answers with its name, model, id and port in one packet (measured on
/// Living Room TV: about 0.4 s), and nothing shows on its screen.
///
/// Devices on another subnet may not answer (RFC 6762 §5.5 lets a
/// responder ignore queries from off its link); the Cast connection's
/// own GET_STATUS is the fallback once the client exists (step 2).
final class UnicastCastAddressCheck implements CastAddressCheck {
  new({
    this.log,
    this.mdnsPort = 5353,
    this.timeout = const Duration(seconds: 3),
    this.resend = const Duration(seconds: 1),
  });

  final AppLog? log;

  /// 5353; another only for tests, which answer on a loopback port.
  final int mdnsPort;
  final Duration timeout;

  /// The query goes again after this, once, for a packet lost on Wi-Fi.
  final Duration resend;

  static const _tag = 'cast.address';
  static final _random = Random();

  @override
  Future<CastAddressAnswer> check(CastAddress address) async {
    final target = await _resolve(address.host);
    if (target == null) {
      log?.info(_tag, 'no address for ${address.host}');
      return const CastNoAnswer();
    }
    RawDatagramSocket? socket;
    try {
      socket = await RawDatagramSocket.bind(
        target.type == InternetAddressType.IPv6
            ? InternetAddress.anyIPv6
            : InternetAddress.anyIPv4,
        0,
      );
      return await _ask(socket, target, address);
    } on SocketException catch (error) {
      log?.warning(_tag, 'query to ${address.host} failed: $error');
      return const CastNoAnswer();
    } finally {
      socket?.close();
    }
  }

  Future<CastAddressAnswer> _ask(
    RawDatagramSocket socket,
    InternetAddress target,
    CastAddress address,
  ) async {
    final id = 1 + _random.nextInt(0xFFFE);
    final query = encodeDnsQuery(id, '$castServiceType.local', DnsType.ptr);
    final done = Completer<CastAddressAnswer>();
    final records = <DnsRecord>[];
    late final StreamSubscription<RawSocketEvent> listening;
    listening = socket.listen((event) {
      if (event != RawSocketEvent.read) return;
      final datagram = socket.receive();
      if (datagram == null || datagram.address != target) return;
      records.addAll(decodeDnsResponse(datagram.data, id: id));
      final answer = _answer(records, target, address);
      if (answer != null && !done.isCompleted) done.complete(answer);
    });
    void send() => socket.send(query, target, mdnsPort);
    send();
    final again = Timer(resend, send);
    final expired = Timer(timeout, () {
      if (!done.isCompleted) done.complete(const CastNoAnswer());
    });
    final answer = await done.future;
    again.cancel();
    expired.cancel();
    await listening.cancel();
    return answer;
  }

  /// The first Cast service [records] describe well enough, or null to
  /// keep listening.
  CastAddressAnswer? _answer(
    List<DnsRecord> records,
    InternetAddress target,
    CastAddress address,
  ) {
    bool named(DnsRecord r, String name) =>
        r.name.toLowerCase() == name.toLowerCase();
    for (final pointer in records.where((r) => r.type == DnsType.ptr)) {
      final instance = pointer.target;
      if (instance == null) continue;
      final txt = records.where(
        (r) => r.type == DnsType.txt && named(r, instance),
      );
      if (txt.isEmpty) continue;
      final srv = records
          .where((r) => r.type == DnsType.srv && named(r, instance))
          .firstOrNull;
      final label = instance.endsWith('.$castServiceType.local')
          ? instance.substring(
              0,
              instance.length - '.$castServiceType.local'.length,
            )
          : instance;
      final answer = readCastService(
        instance: label,
        txt: parseTxtStrings(txt.first.strings),
        // The address that answered: the one the user typed, rather than
        // whichever of its addresses the records list first.
        hosts: [target.address],
        port: address.port != castPort ? address.port : srv?.port,
      );
      if (answer is CastDeviceAnswered) {
        return CastDeviceAnswered(answer.device.copyWith(manual: true));
      }
      if (answer != null) return answer;
    }
    return null;
  }

  Future<InternetAddress?> _resolve(String host) async {
    final literal = InternetAddress.tryParse(host);
    if (literal != null) return literal;
    try {
      final found = await InternetAddress.lookup(host).timeout(timeout);
      return found
              .where((a) => a.type == InternetAddressType.IPv4)
              .firstOrNull ??
          found.firstOrNull;
    } on Object catch (error) {
      log?.info(_tag, 'lookup of $host failed: $error');
      return null;
    }
  }
}
