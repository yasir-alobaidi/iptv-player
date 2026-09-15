import 'dart:async';

import 'package:multicast_dns/multicast_dns.dart';

class CastDevice {
  CastDevice({
    required this.name,
    required this.model,
    required this.id,
    required this.host,
    this.port = 8009,
    this.txt = const {},
  });

  final String name;
  final String model;
  final String id;
  final String host;
  final int port;
  final Map<String, String> txt;

  @override
  String toString() => '$name · md=$model · $host:$port · id=$id';
}

/// PTR `_googlecast._tcp.local` → TXT (`fn`, `md`, `id`) + SRV → A.
Future<List<CastDevice>> discoverCastDevices({
  Duration timeout = const Duration(seconds: 5),
}) async {
  final client = MDnsClient();
  await client.start();
  final devices = <String, CastDevice>{};
  const inner = Duration(seconds: 2);
  try {
    await for (final ptr in client.lookup<PtrResourceRecord>(
      ResourceRecordQuery.serverPointer('_googlecast._tcp.local'),
      timeout: timeout,
    )) {
      final txt = <String, String>{};
      await for (final t in client.lookup<TxtResourceRecord>(
        ResourceRecordQuery.text(ptr.domainName),
        timeout: inner,
      )) {
        for (final entry in t.text.split('\n')) {
          final i = entry.indexOf('=');
          if (i > 0) txt[entry.substring(0, i)] = entry.substring(i + 1);
        }
      }
      await for (final srv in client.lookup<SrvResourceRecord>(
        ResourceRecordQuery.service(ptr.domainName),
        timeout: inner,
      )) {
        await for (final ip in client.lookup<IPAddressResourceRecord>(
          ResourceRecordQuery.addressIPv4(srv.target),
          timeout: inner,
        )) {
          final id = txt['id'] ?? ptr.domainName;
          devices[id] ??= CastDevice(
            name: txt['fn'] ?? ptr.domainName,
            model: txt['md'] ?? '?',
            id: id,
            host: ip.address.address,
            port: srv.port,
            txt: txt,
          );
        }
      }
    }
  } finally {
    client.stop();
  }
  return devices.values.toList();
}
