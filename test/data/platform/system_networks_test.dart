import 'dart:async';
import 'dart:io';

import 'package:dbus/dbus.dart';
import 'package:fake_async/fake_async.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:iptv_player/core/logging/app_log.dart';
import 'package:iptv_player/core/logging/secret_registry.dart';
import 'package:iptv_player/core/platform/network_status.dart';
import 'package:iptv_player/data/platform/system_networks.dart';
import 'package:logger/logger.dart';

/// NetworkManager's root object: its `State`, and `StateChanged`.
final class _NetworkManager extends DBusObject {
  new(this.state) : super(DBusObjectPath('/org/freedesktop/NetworkManager'));

  int state;

  @override
  Future<DBusMethodResponse> getProperty(String interface, String name) async {
    if (interface == 'org.freedesktop.NetworkManager' && name == 'State') {
      return DBusGetPropertyResponse(DBusUint32(state));
    }
    return DBusMethodErrorResponse.unknownProperty();
  }

  Future<void> change(int to) async {
    state = to;
    await emitSignal('org.freedesktop.NetworkManager', 'StateChanged', [
      DBusUint32(to),
    ]);
  }
}

void main() {
  AppLog log() => AppLog(output: MemoryOutput(), secrets: SecretRegistry());

  test("NetworkManager's states: only connected, global is online", () {
    expect(reachabilityOfNmState(70), Reachability.online);
    for (final state in [10, 20, 30, 40, 50, 60]) {
      expect(
        reachabilityOfNmState(state),
        Reachability.offline,
        reason: '$state',
      );
    }
    expect(reachabilityOfNmState(0), Reachability.unknown);
  });

  test("Windows' hint: internet access, constrained or not, is online", () {
    expect(reachabilityOfHint(3), Reachability.online);
    expect(reachabilityOfHint(4), Reachability.online);
    expect(reachabilityOfHint(1), Reachability.offline);
    expect(reachabilityOfHint(2), Reachability.offline);
    for (final level in [null, 0, 5, 99]) {
      expect(reachabilityOfHint(level), Reachability.unknown);
    }
  });

  group('NetworkManager over D-Bus', () {
    late Directory temp;
    final closing = <Future<void> Function()>[];

    setUp(() async {
      temp = await Directory.systemTemp.createTemp('network_manager');
    });

    tearDown(() async {
      for (final close in closing.reversed) {
        await close();
      }
      closing.clear();
      await temp.delete(recursive: true);
    });

    Future<DBusAddress> bus({_NetworkManager? manager}) async {
      final server = DBusServer();
      final address = await server.listenAddress(DBusAddress.unix(dir: temp));
      closing.add(server.close);
      if (manager != null) {
        final owner = DBusClient(address);
        await owner.requestName('org.freedesktop.NetworkManager');
        await owner.registerObject(manager);
        closing.add(owner.close);
      }
      return address;
    }

    /// The next [count] states [network] says.
    Future<List<Reachability>> next(
      StreamIterator<Reachability> states,
      int count,
    ) async => [
      for (var i = 0; i < count; i++)
        if (await states.moveNext().timeout(const Duration(seconds: 5)))
          states.current,
    ];

    test('the state now, then each change', () async {
      final manager = _NetworkManager(70);
      final address = await bus(manager: manager);
      final states = StreamIterator(
        NetworkManagerNetwork(
          log: log(),
          system: () => DBusClient(address),
        ).watch(),
      );
      closing.add(states.cancel);

      expect(await next(states, 1), [Reachability.online]);
      // Let the signal's match rule reach the bus before the change.
      await Future<void>.delayed(const Duration(milliseconds: 100));
      await manager.change(20);
      await manager.change(40);
      await manager.change(70);
      expect(await next(states, 3), [
        Reachability.offline,
        Reachability.offline,
        Reachability.online,
      ]);
    });

    test('no NetworkManager on the bus: unknown, never a throw', () async {
      final address = await bus();
      final network = NetworkManagerNetwork(
        log: log(),
        system: () => DBusClient(address),
      );
      expect(await network.watch().first, Reachability.unknown);
    });
  }, skip: Platform.isLinux ? null : 'the system bus is a Linux thing');

  test('Windows: the hint asked every 5 s, told when it changes; one that '
      "can't be asked is unknown", () {
    fakeAsync((async) {
      Object answer = 3;
      final network = WindowsSystemNetwork(
        log: log(),
        hint: () => answer is int ? answer : throw StateError('no'),
      );
      final told = <Reachability>[];
      final listening = network.watch().listen(told.add);
      async.flushMicrotasks();
      expect(told, [Reachability.online]);

      async.elapse(const Duration(seconds: 5));
      expect(told, [Reachability.online], reason: 'the same, not told');
      answer = 1;
      async.elapse(const Duration(seconds: 5));
      answer = 'broken';
      async.elapse(const Duration(seconds: 5));
      expect(told, [
        Reachability.online,
        Reachability.offline,
        Reachability.unknown,
      ]);
      unawaited(listening.cancel());
      async.elapse(const Duration(seconds: 20));
      expect(told, hasLength(3));
    });
  });
}
