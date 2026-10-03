@TestOn('linux')
library;

import 'dart:io';

import 'package:dbus/dbus.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:iptv_player/core/logging/app_log.dart';
import 'package:iptv_player/core/logging/secret_registry.dart';
import 'package:iptv_player/data/platform/sleep_inhibitors.dart';
import 'package:logger/logger.dart';

const _request = '/org/freedesktop/portal/desktop/request/1_1/cast';

/// The desktop portal's Inhibit, and the request it hands back.
final class _Portal extends DBusObject {
  new() : super(DBusObjectPath('/org/freedesktop/portal/desktop'));

  final inhibits = <List<DBusValue>>[];

  @override
  Future<DBusMethodResponse> handleMethodCall(DBusMethodCall call) async {
    if (call.interface == 'org.freedesktop.portal.Inhibit' &&
        call.name == 'Inhibit') {
      inhibits.add(call.values);
      return DBusMethodSuccessResponse([DBusObjectPath(_request)]);
    }
    return DBusMethodErrorResponse.unknownMethod();
  }
}

final class _Request extends DBusObject {
  new() : super(DBusObjectPath(_request));

  int closed = 0;

  @override
  Future<DBusMethodResponse> handleMethodCall(DBusMethodCall call) async {
    if (call.interface == 'org.freedesktop.portal.Request' &&
        call.name == 'Close') {
      closed++;
      return DBusMethodSuccessResponse();
    }
    return DBusMethodErrorResponse.unknownMethod();
  }
}

/// logind's Manager.Inhibit: a lock held while its descriptor is open.
final class _Logind extends DBusObject {
  new(this.lock) : super(DBusObjectPath('/org/freedesktop/login1'));

  final File lock;
  final inhibits = <List<DBusValue>>[];

  @override
  Future<DBusMethodResponse> handleMethodCall(DBusMethodCall call) async {
    if (call.interface == 'org.freedesktop.login1.Manager' &&
        call.name == 'Inhibit') {
      inhibits.add(call.values);
      final file = await lock.open();
      return DBusMethodSuccessResponse([
        DBusUnixFd(ResourceHandle.fromFile(file)),
      ]);
    }
    return DBusMethodErrorResponse.unknownMethod();
  }
}

/// A bus with [name] owning [objects], or nothing on it.
Future<(DBusServer, DBusAddress, DBusClient?)> _bus(
  Directory dir, {
  String? name,
  List<DBusObject> objects = const [],
}) async {
  final server = DBusServer();
  final address = await server.listenAddress(DBusAddress.unix(dir: dir));
  if (name == null) return (server, address, null);
  final owner = DBusClient(address);
  await owner.requestName(name);
  for (final object in objects) {
    await owner.registerObject(object);
  }
  return (server, address, owner);
}

void main() {
  late Directory temp;
  late MemoryOutput logged;
  final closing = <Future<void> Function()>[];

  setUp(() async {
    temp = await Directory.systemTemp.createTemp('sleep_inhibit');
    logged = MemoryOutput();
  });

  tearDown(() async {
    for (final close in closing.reversed) {
      await close();
    }
    closing.clear();
    await temp.delete(recursive: true);
  });

  AppLog log() => AppLog(output: logged, secrets: SecretRegistry());

  Future<DBusAddress> bus({
    String? name,
    List<DBusObject> objects = const [],
  }) async {
    final (server, address, owner) = await _bus(
      Directory((await temp.createTemp()).path),
      name: name,
      objects: objects,
    );
    closing
      ..add(server.close)
      ..add(() async => await owner?.close());
    return address;
  }

  test('the portal: suspend and idle held with the reason; released by '
      'closing its request', () async {
    final portal = _Portal();
    final request = _Request();
    final session = await bus(
      name: 'org.freedesktop.portal.Desktop',
      objects: [portal, request],
    );
    final system = await bus();
    final inhibitor = DbusSleepInhibitor(
      log: log(),
      session: () => DBusClient(session),
      system: () => DBusClient(system),
    );
    expect(await inhibitor.hold('Casting to Living Room TV'), isTrue);
    expect(await inhibitor.hold('again'), isTrue);
    final values = portal.inhibits.single;
    expect(values[0], const DBusString(''));
    expect(values[1], const DBusUint32(4 | 8));
    expect(
      (values[2] as DBusDict).children[const DBusString('reason')],
      const DBusVariant(DBusString('Casting to Living Room TV')),
    );
    await inhibitor.release();
    expect(request.closed, 1);
    await inhibitor.release();
    expect(request.closed, 1);
  });

  test('no portal: logind, its lock closed on release', () async {
    final lock = File('${temp.path}/lock')..writeAsStringSync('');
    final logind = _Logind(lock);
    final session = await bus();
    final system = await bus(name: 'org.freedesktop.login1', objects: [logind]);
    final inhibitor = DbusSleepInhibitor(
      log: log(),
      session: () => DBusClient(session),
      system: () => DBusClient(system),
    );
    expect(await inhibitor.hold('Casting'), isTrue);
    expect(logind.inhibits.single, const [
      DBusString('sleep:idle'),
      DBusString('IPTV Player'),
      DBusString('Casting'),
      DBusString('block'),
    ]);
    await inhibitor.release();
    expect(logged.buffer.expand((e) => e.lines).join('\n'), contains('logind'));
  });

  test('neither: false, said once, and nothing to release', () async {
    final session = await bus();
    final system = await bus();
    final inhibitor = DbusSleepInhibitor(
      log: log(),
      session: () => DBusClient(session),
      system: () => DBusClient(system),
    );
    expect(await inhibitor.hold('Casting'), isFalse);
    await inhibitor.release();
    expect(
      logged.buffer.expand((e) => e.lines).join('\n'),
      contains('Could not hold sleep off'),
    );
  });

  test('a bus that is not there at all: false, never a throw', () async {
    final inhibitor = DbusSleepInhibitor(
      log: log(),
      session: () => DBusClient(DBusAddress.unix(path: '${temp.path}/none')),
      system: () => DBusClient(DBusAddress.unix(path: '${temp.path}/none')),
    );
    expect(await inhibitor.hold('Casting'), isFalse);
  });
}
