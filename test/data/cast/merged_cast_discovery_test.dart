import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:iptv_player/core/cast/cast_device.dart';
import 'package:iptv_player/core/cast/cast_discovery.dart';
import 'package:iptv_player/data/cast/cast_browsers.dart';
import 'package:iptv_player/data/cast/db_cast_device_store.dart';
import 'package:iptv_player/data/cast/merged_cast_discovery.dart';
import 'package:iptv_player/data/db/app_database.dart';

const _tv = CastDevice(
  id: 'aaaa',
  name: 'Living Room TV',
  model: 'Chromecast',
  host: '192.168.1.60',
  capabilities: 5,
);
const _bedroom = CastDevice(id: 'bbbb', name: 'bedroom', host: '192.168.1.61');
const _office = CastDevice(
  id: 'cccc',
  name: 'Office',
  host: '10.0.0.9',
  manual: true,
);

final class _FakeBrowser implements CastBrowser {
  new(this.name);

  @override
  final String name;
  StreamController<List<CastDevice>>? _out;
  int watches = 0;

  bool get watching => _out != null;

  void see(List<CastDevice> devices) => _out!.add(devices);

  void fail(Object error) => _out!.addError(error);

  @override
  Stream<List<CastDevice>> watch() {
    watches++;
    final out = StreamController<List<CastDevice>>(onCancel: () => _out = null);
    _out = out;
    return out.stream;
  }
}

final class _FakeCheck implements CastAddressCheck {
  final answers = <String, CastAddressAnswer>{};
  final asked = <CastAddress>[];

  @override
  Future<CastAddressAnswer> check(CastAddress address) async {
    asked.add(address);
    return answers[address.host] ?? const CastNoAnswer();
  }
}

void main() {
  late AppDatabase db;
  late DbCastDeviceStore store;
  late _FakeBrowser bonsoir;
  late _FakeBrowser mdns;
  late _FakeCheck check;
  late MergedCastDiscovery discovery;

  setUp(() {
    db = AppDatabase.memory();
    store = DbCastDeviceStore(db);
    bonsoir = _FakeBrowser('bonsoir');
    mdns = _FakeBrowser('multicast_dns');
    check = _FakeCheck();
    discovery = MergedCastDiscovery(
      browsers: [bonsoir, mdns],
      store: store,
      addressCheck: check,
    );
  });
  tearDown(() => db.close());

  /// Listens, runs [script], and returns the last list seen.
  Future<List<CastDevice>> last(Future<void> Function() script) async {
    List<CastDevice>? seen;
    final sub = discovery.devices.listen((devices) => seen = devices);
    await pumpEventQueue();
    await script();
    await pumpEventQueue();
    await sub.cancel();
    return seen ?? const [];
  }

  test('runs the browsers only while listened to', () async {
    expect(bonsoir.watching, isFalse);
    final first = discovery.devices.listen((_) {});
    final second = discovery.devices.listen((_) {});
    await pumpEventQueue();
    expect(bonsoir.watching && mdns.watching, isTrue);
    expect(bonsoir.watches, 1);
    await first.cancel();
    expect(bonsoir.watching, isTrue);
    await second.cancel();
    expect(bonsoir.watching || mdns.watching, isFalse);
  });

  test('one device seen twice is listed once', () async {
    final devices = await last(() async {
      bonsoir.see([_tv]);
      mdns.see([_tv]);
    });
    expect(devices, [_tv]);
  });

  test('the IPv4 address wins, and missing fields are filled', () async {
    final devices = await last(() async {
      bonsoir.see([
        _tv.copyWith(host: '2600:4040::89c3', model: null, status: 'YouTube'),
      ]);
      mdns.see([_tv.copyWith(capabilities: null)]);
    });
    expect(devices.single.host, '192.168.1.60');
    expect(devices.single.model, 'Chromecast');
    expect(devices.single.status, 'YouTube');
    expect(devices.single.capabilities, 5);
  });

  test('listed while either browser sees it', () async {
    final devices = await last(() async {
      bonsoir.see([_tv, _bedroom]);
      mdns.see([_tv]);
      await pumpEventQueue();
      bonsoir.see(const []);
    });
    expect(devices, [_tv]);
  });

  test('by name, without case', () async {
    final devices = await last(() async {
      mdns.see([_tv, _bedroom]);
    });
    expect([for (final d in devices) d.name], ['bedroom', 'Living Room TV']);
  });

  test('a browser that fails leaves the other one working', () async {
    final devices = await last(() async {
      bonsoir.fail(StateError('Avahi is not running'));
      mdns.see([_tv]);
    });
    expect(devices, [_tv]);
  });

  test('a new listener gets the list at once', () async {
    final first = discovery.devices.listen((_) {});
    await pumpEventQueue();
    mdns.see([_tv]);
    await pumpEventQueue();
    final second = await discovery.devices.first;
    expect(second, [_tv]);
    await first.cancel();
  });

  test('the same list twice is sent once', () async {
    final lists = <List<CastDevice>>[];
    final sub = discovery.devices.listen(lists.add);
    await pumpEventQueue();
    mdns.see([_tv]);
    await pumpEventQueue();
    mdns.see([_tv]);
    bonsoir.see([_tv]);
    await pumpEventQueue();
    await sub.cancel();
    expect(lists.where((l) => l.isNotEmpty), hasLength(1));
  });

  group('devices added by address', () {
    test('listed, asked, and answering', () async {
      await store.addManual(_office);
      check.answers['10.0.0.9'] = CastDeviceAnswered(
        _office.copyWith(status: 'Netflix'),
      );
      final devices = await last(() async {});
      expect(devices.single.id, 'cccc');
      expect(devices.single.manual, isTrue);
      expect(devices.single.answering, isTrue);
      expect(devices.single.status, 'Netflix');
      expect(check.asked, [const CastAddress('10.0.0.9')]);
    });

    test('listed as not answering when nothing answers', () async {
      await store.addManual(_office);
      final devices = await last(() async {});
      expect(devices.single.name, 'Office');
      expect(devices.single.answering, isFalse);
    });

    test('another device at its address is not it', () async {
      await store.addManual(_office);
      check.answers['10.0.0.9'] = const CastDeviceAnswered(
        CastDevice(id: 'dddd', name: 'Someone else', host: '10.0.0.9'),
      );
      final devices = await last(() async {});
      expect(devices.single.id, 'cccc');
      expect(devices.single.answering, isFalse);
    });

    test('found by a browser: not asked, and marked manual', () async {
      await store.addManual(_tv.copyWith(manual: true));
      final devices = await last(() async {
        mdns.see([_tv]);
        await pumpEventQueue();
      });
      expect(devices.single.manual, isTrue);
      expect(devices.single.host, '192.168.1.60');
    });

    test('asked again every interval while listened to', () async {
      final quick = MergedCastDiscovery(
        browsers: [bonsoir, mdns],
        store: store,
        addressCheck: check,
        manualInterval: const Duration(milliseconds: 40),
      );
      await store.addManual(_office);
      final sub = quick.devices.listen((_) {});
      final waited = Stopwatch()..start();
      while (check.asked.length < 3 && waited.elapsed.inSeconds < 5) {
        await Future<void>.delayed(const Duration(milliseconds: 10));
      }
      expect(check.asked.length, greaterThanOrEqualTo(3));
      await sub.cancel();
      final asked = check.asked.length;
      await Future<void>.delayed(const Duration(milliseconds: 150));
      expect(check.asked.length, asked);
    });
  });

  group('kept devices follow the network', () {
    test('a new address or name is written back', () async {
      await store.markUsed(_tv, DateTime.utc(2026, 9, 29));
      await last(() async {
        mdns.see([_tv.copyWith(host: '192.168.1.77', name: 'TV')]);
        await pumpEventQueue();
      });
      final kept = (await store.byId('aaaa')).valueOrNull!;
      expect(kept.host, '192.168.1.77');
      expect(kept.name, 'TV');
    });

    test('a device only seen is not kept', () async {
      await last(() async => mdns.see([_bedroom]));
      expect((await store.byId('bbbb')).valueOrNull, isNull);
    });
  });
}
