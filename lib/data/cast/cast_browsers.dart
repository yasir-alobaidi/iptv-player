import 'dart:async';
import 'dart:io';

import 'package:bonsoir/bonsoir.dart';
import 'package:iptv_player/core/cast/cast_device.dart';
import 'package:iptv_player/core/cast/cast_discovery.dart';
import 'package:iptv_player/core/logging/app_log.dart';
import 'package:iptv_player/data/cast/cast_txt.dart';
import 'package:multicast_dns/multicast_dns.dart';

/// One way of finding Cast devices on the network. `MergedCastDiscovery`
/// runs two side by side (Phase 7 decision 6).
abstract interface class CastBrowser {
  /// For logs: `bonsoir`, `multicast_dns`.
  String get name;

  /// The devices with a screen this browser sees now; again on every
  /// change. Runs while listened to. A browser that fails logs why and
  /// sees nothing; the stream never reports an error.
  Stream<List<CastDevice>> watch();
}

/// One query round: the devices that answered, as they are resolved; the
/// stream ends with the round.
typedef CastQueryRound = Stream<CastDevice> Function();

/// multicast_dns (proven next to Avahi on this laptop, ADR-006), in
/// rounds: a query every [interval], answers taken as they come, and a
/// device dropped once it misses [missedRounds] rounds in a row.
final class MulticastDnsCastBrowser implements CastBrowser {
  new({
    this.log,
    this.interval = const Duration(seconds: 8),
    this.missedRounds = 2,
    this._round,
  });

  final AppLog? log;
  final Duration interval;
  final int missedRounds;
  final CastQueryRound? _round;

  static const _tag = 'cast.mdns';

  @override
  String get name => 'multicast_dns';

  @override
  Stream<List<CastDevice>> watch() {
    final devices = <String, CastDevice>{};
    final misses = <String, int>{};
    var running = true;
    Timer? next;
    late final StreamController<List<CastDevice>> out;

    void emit() {
      if (!out.isClosed) out.add([...devices.values]);
    }

    Future<void> runRound() async {
      final seen = <String>{};
      try {
        await for (final device in (_round ?? _queryRound)()) {
          if (!running) return;
          seen.add(device.id);
          misses[device.id] = 0;
          if (devices[device.id] != device) {
            devices[device.id] = device;
            emit();
          }
        }
      } on Object catch (error) {
        log?.warning(_tag, 'query round failed: $error');
      }
      if (!running) return;
      var changed = false;
      for (final id in [...devices.keys]) {
        if (seen.contains(id)) continue;
        final missed = (misses[id] ?? 0) + 1;
        misses[id] = missed;
        if (missed >= missedRounds) {
          devices.remove(id);
          misses.remove(id);
          changed = true;
        }
      }
      // Every round ends with the list, so a listener knows the first
      // round is over even when it found nothing.
      if (changed || seen.isEmpty) emit();
      next = Timer(interval, () => unawaited(runRound()));
    }

    out = StreamController<List<CastDevice>>(
      onListen: () => unawaited(runRound()),
      onCancel: () {
        running = false;
        next?.cancel();
      },
    );
    return out.stream;
  }

  /// PTR `_googlecast._tcp.local` for [_ptrWindow], then each answer's
  /// TXT, SRV and A, as they come (a Cast device sends them all with the
  /// PTR, so they are usually in the client's cache already).
  Stream<CastDevice> _queryRound() async* {
    final client = MDnsClient();
    try {
      await client.start();
    } on Object catch (error) {
      log?.warning(_tag, 'could not start: $error');
      client.stop();
      return;
    }
    try {
      final resolving = <Future<CastDevice?>>[];
      final found = StreamController<CastDevice>();
      // Ends by itself when the window closes; the client stops after.
      // ignore: cancel_subscriptions
      final ptrs = client
          .lookup<PtrResourceRecord>(
            ResourceRecordQuery.serverPointer('$castServiceType.local'),
            timeout: _ptrWindow,
          )
          .listen((ptr) {
            final resolved = _resolve(client, ptr.domainName);
            resolving.add(resolved);
            unawaited(
              resolved.then((device) {
                if (device != null && !found.isClosed) found.add(device);
              }),
            );
          });
      unawaited(
        ptrs.asFuture<void>().catchError((Object _) {}).then((_) async {
          await Future.wait(resolving);
          await found.close();
        }),
      );
      yield* found.stream;
    } finally {
      client.stop();
    }
  }

  static const _ptrWindow = Duration(seconds: 3);
  static const _recordWindow = Duration(seconds: 2);

  Future<CastDevice?> _resolve(MDnsClient client, String service) async {
    try {
      final txt = await _first<TxtResourceRecord>(
        client,
        ResourceRecordQuery.text(service),
      );
      final srv = await _first<SrvResourceRecord>(
        client,
        ResourceRecordQuery.service(service),
      );
      if (txt == null || srv == null) return null;
      final address = await _first<IPAddressResourceRecord>(
        client,
        ResourceRecordQuery.addressIPv4(srv.target),
      );
      if (address == null) return null;
      const suffix = '.$castServiceType.local';
      final answer = readCastService(
        instance: service.endsWith(suffix)
            ? service.substring(0, service.length - suffix.length)
            : service,
        // multicast_dns joins a TXT record's strings with newlines.
        txt: parseTxtStrings(txt.text.split('\n')),
        hosts: [address.address.address],
        port: srv.port,
      );
      return answer is CastDeviceAnswered ? answer.device : null;
    } on Object catch (error) {
      log?.warning(_tag, 'could not resolve a device: $error');
      return null;
    }
  }

  static Future<T?> _first<T extends ResourceRecord>(
    MDnsClient client,
    ResourceRecordQuery query,
  ) async {
    await for (final record in client.lookup<T>(
      query,
      timeout: _recordWindow,
    )) {
      return record;
    }
    return null;
  }
}

/// bonsoir: the system's own resolver (Avahi here, DNS-SD on Windows).
/// A device goes when the resolver says it is lost.
final class BonsoirCastBrowser implements CastBrowser {
  new({this.log, this._create, this._lookup});

  final AppLog? log;
  final BonsoirDiscovery Function()? _create;

  /// `InternetAddress.lookup`; another in tests.
  final Future<List<InternetAddress>> Function(
    String host, {
    InternetAddressType type,
  })?
  _lookup;

  static const _tag = 'cast.bonsoir';

  @override
  String get name => 'bonsoir';

  @override
  Stream<List<CastDevice>> watch() {
    final services = <String, BonsoirService>{};
    BonsoirDiscovery? discovery;
    StreamSubscription<BonsoirDiscoveryEvent>? events;
    var running = true;
    late final StreamController<List<CastDevice>> out;

    void emit() {
      if (out.isClosed) return;
      final devices = <String, CastDevice>{};
      for (final service in services.values) {
        final answer = readCastService(
          instance: service.name,
          txt: parseTxtStrings([
            for (final MapEntry(:key, :value) in service.attributes.entries)
              '$key=$value',
          ]),
          hosts: service.hostAddresses,
          port: service.port,
        );
        if (answer is CastDeviceAnswered) {
          devices[answer.device.id] = answer.device;
        }
      }
      out.add([...devices.values]);
    }

    void onEvent(BonsoirDiscoveryEvent event) {
      switch (event) {
        case BonsoirDiscoveryServiceFoundEvent(:final service):
          unawaited(
            Future.sync(
              () => discovery?.serviceResolver.resolveService(service),
            ).catchError((Object error) {
              log?.info(_tag, 'resolve failed: $error');
            }),
          );
        case BonsoirDiscoveryServiceResolvedEvent(:final service):
          services[service.name] = service;
          emit();
          unawaited(
            _withIpv4(service).then((better) {
              if (!running || better == null) return;
              // A TXT update keeps the addresses; a new resolve or a loss
              // meanwhile wins.
              final current = services[service.name];
              if (current == null ||
                  current.hostAddresses.join(' ') !=
                      service.hostAddresses.join(' ')) {
                return;
              }
              services[service.name] = current.copyWith(
                hostAddresses: better.hostAddresses,
              );
              emit();
            }),
          );
        case BonsoirDiscoveryServiceUpdatedEvent(:final service):
          // A TXT change comes on the service as first found, without
          // the address the resolver gave: keep that.
          final held = services[service.name];
          if (held == null) return;
          services[service.name] = held.copyWith(
            attributes: service.attributes,
          );
          emit();
        case BonsoirDiscoveryServiceLostEvent(:final service):
          if (services.remove(service.name) != null) emit();
        default:
      }
    }

    Future<void> start() async {
      try {
        final created = (_create ?? _discovery)();
        discovery = created;
        await created.initialize();
        if (!running) return;
        events = created.eventStream?.listen(
          onEvent,
          onError: (Object error) => log?.warning(_tag, 'event: $error'),
        );
        await created.start();
      } on Object catch (error) {
        // Avahi not running, no D-Bus, a platform without the plugin:
        // the other browser carries on.
        log?.warning(_tag, 'could not start: $error');
      }
      if (running && services.isEmpty) emit();
    }

    out = StreamController<List<CastDevice>>(
      onListen: () => unawaited(start()),
      onCancel: () async {
        running = false;
        await events?.cancel();
        try {
          if (discovery?.isReady ?? false) await discovery?.stop();
        } on Object catch (error) {
          log?.info(_tag, 'stop failed: $error');
        }
      },
    );
    return out.stream;
  }

  /// [service] with its host name's IPv4 address added, when Avahi
  /// resolved it to IPv6 only (it resolves whichever of the two it saw
  /// first: measured both ways on this laptop); null when there is
  /// nothing better.
  Future<BonsoirService?> _withIpv4(BonsoirService service) async {
    final hostname = service.hostname;
    if (hostname == null || hostname.isEmpty) return null;
    if (preferredHost(service.hostAddresses) case final host?
        when !host.contains(':')) {
      return null;
    }
    try {
      final found = await (_lookup ?? InternetAddress.lookup)(
        hostname,
        type: InternetAddressType.IPv4,
      ).timeout(const Duration(seconds: 3));
      if (found.isEmpty) return null;
      return service.copyWith(
        hostAddresses: [
          for (final address in found) address.address,
          ...service.hostAddresses,
        ],
      );
    } on Object catch (error) {
      log?.info(_tag, 'no IPv4 address for $hostname: $error');
      return null;
    }
  }

  static BonsoirDiscovery _discovery() =>
      BonsoirDiscovery(type: castServiceType, printLogs: false);
}
