import 'dart:async';
import 'dart:io';

import 'package:bonsoir/bonsoir.dart';
import 'package:fake_async/fake_async.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:iptv_player/core/cast/cast_device.dart';
import 'package:iptv_player/data/cast/cast_browsers.dart';

const _tv = CastDevice(
  id: 'aaaa',
  name: 'Living Room TV',
  model: 'Chromecast',
  host: '192.168.1.60',
);
const _bedroom = CastDevice(id: 'bbbb', name: 'Bedroom', host: '192.168.1.61');

void main() {
  group('MulticastDnsCastBrowser', () {
    /// Runs the browser on scripted rounds (each a list of devices, or an
    /// error), 8 s apart, and returns what it emitted after [rounds].
    List<List<CastDevice>> run(
      List<Object> script, {
      int rounds = 0,
      void Function(FakeAsync async, StreamSubscription<void> sub)? then,
    }) {
      final emitted = <List<CastDevice>>[];
      fakeAsync((async) {
        var i = 0;
        final browser = MulticastDnsCastBrowser(
          round: () {
            final step = i < script.length ? script[i] : const <CastDevice>[];
            i++;
            return step is List<CastDevice>
                ? Stream.fromIterable(step)
                : Stream.error(step);
          },
        );
        final sub = browser.watch().listen(emitted.add);
        async
          ..flushMicrotasks()
          ..elapse(browser.interval * (rounds > 0 ? rounds - 1 : 0));
        then?.call(async, sub);
        unawaited(sub.cancel());
      });
      return emitted;
    }

    test('a device is listed as soon as it answers', () {
      final emitted = run([
        [_tv, _bedroom],
      ], rounds: 1);
      expect(emitted.first, [_tv]);
      expect(emitted.last, [_tv, _bedroom]);
    });

    test('a first round with nothing says so', () {
      expect(run([<CastDevice>[]], rounds: 1), [<CastDevice>[]]);
    });

    test('one missed round keeps it; the second drops it', () {
      final emitted = run([
        [_tv],
        <CastDevice>[],
        <CastDevice>[],
      ], rounds: 3);
      expect(emitted.where((list) => list.isNotEmpty), isNotEmpty);
      // Still listed after round 2, gone after round 3.
      expect(emitted.last, isEmpty);
      final run2 = run([
        [_tv],
        <CastDevice>[],
      ], rounds: 2);
      expect(run2.last, [_tv]);
    });

    test('answering again resets the count', () {
      final emitted = run([
        [_tv],
        <CastDevice>[],
        [_tv],
        <CastDevice>[],
        [_tv],
      ], rounds: 5);
      expect(emitted.every((list) => list.contains(_tv)), isTrue);
    });

    test('a device that changes is listed again', () {
      final busy = _tv.copyWith(status: 'YouTube');
      final emitted = run([
        [_tv],
        [busy],
      ], rounds: 2);
      expect(emitted.last, [busy]);
    });

    test('a failed round is a round with nothing; the next runs', () {
      final emitted = run([
        const SocketException('no multicast'),
        [_tv],
      ], rounds: 2);
      expect(emitted.last, [_tv]);
    });

    test('no rounds after the listener leaves', () {
      var rounds = 0;
      fakeAsync((async) {
        final browser = MulticastDnsCastBrowser(
          round: () {
            rounds++;
            return const Stream.empty();
          },
        );
        final sub = browser.watch().listen((_) {});
        async
          ..flushMicrotasks()
          ..elapse(browser.interval * 2);
        unawaited(sub.cancel());
        final before = rounds;
        async.elapse(browser.interval * 5);
        expect(rounds, before);
      });
    });
  });

  group('BonsoirCastBrowser', () {
    late _FakeDiscoveryAction action;
    late BonsoirPlatformInterface original;

    setUp(() {
      original = BonsoirPlatformInterface.instance;
      action = _FakeDiscoveryAction();
      BonsoirPlatformInterface.instance = _FakePlatform(action);
    });
    tearDown(() => BonsoirPlatformInterface.instance = original);

    BonsoirService service(
      String name, {
      List<String> hosts = const [],
      Map<String, String> txt = const {},
      String? hostname,
    }) => BonsoirService.ignoreNorms(
      name: name,
      type: '_googlecast._tcp',
      port: hosts.isEmpty ? 0 : 8009,
      hostAddresses: hosts,
      hostname: hostname,
      attributes: txt,
    );

    const tvTxt = {
      'id': 'aaaa',
      'fn': 'Living Room TV',
      'md': 'Chromecast',
      'ca': '465413',
    };

    Future<List<List<CastDevice>>> watch(
      Future<void> Function() script, {
      Future<List<InternetAddress>> Function(
        String host, {
        InternetAddressType type,
      })?
      lookup,
    }) async {
      final emitted = <List<CastDevice>>[];
      final browser = BonsoirCastBrowser(lookup: lookup);
      final sub = browser.watch().listen(emitted.add);
      await pumpEventQueue();
      await script();
      await pumpEventQueue();
      await sub.cancel();
      return emitted;
    }

    test('resolves what it finds, and lists it once resolved', () async {
      final emitted = await watch(() async {
        action.add(BonsoirDiscoveryServiceFoundEvent(service: service('TV')));
        await pumpEventQueue();
        expect(action.resolved, ['TV']);
        action.add(
          BonsoirDiscoveryServiceResolvedEvent(
            service: service('TV', hosts: ['192.168.1.60'], txt: tvTxt),
          ),
        );
      });
      expect(action.started, isTrue);
      expect(emitted.last.single.name, 'Living Room TV');
      expect(emitted.last.single.host, '192.168.1.60');
      expect(action.stopped, isTrue);
    });

    test('a TXT update keeps the resolved address', () async {
      final emitted = await watch(() async {
        action
          ..add(
            BonsoirDiscoveryServiceResolvedEvent(
              service: service('TV', hosts: ['192.168.1.60'], txt: tvTxt),
            ),
          )
          ..add(
            BonsoirDiscoveryServiceUpdatedEvent(
              service: service('TV', txt: {...tvTxt, 'rs': 'YouTube'}),
            ),
          );
      });
      expect(emitted.last.single.status, 'YouTube');
      expect(emitted.last.single.host, '192.168.1.60');
    });

    test("an IPv6 answer gets the host name's IPv4 address", () async {
      final asked = <(String, InternetAddressType)>[];
      final emitted = await watch(
        () async {
          action.add(
            BonsoirDiscoveryServiceResolvedEvent(
              service: service(
                'TV',
                hosts: ['2600:4040::89c3'],
                hostname: 'aaaa.local',
                txt: tvTxt,
              ),
            ),
          );
        },
        lookup: (host, {type = InternetAddressType.any}) async {
          asked.add((host, type));
          return [InternetAddress('192.168.1.60')];
        },
      );
      expect(asked, [('aaaa.local', InternetAddressType.IPv4)]);
      final listed = emitted.where((list) => list.isNotEmpty);
      expect(listed.first.single.host, '2600:4040::89c3');
      expect(emitted.last.single.host, '192.168.1.60');
    });

    test('an IPv4 answer asks nothing more', () async {
      var asked = 0;
      await watch(
        () async => action.add(
          BonsoirDiscoveryServiceResolvedEvent(
            service: service(
              'TV',
              hosts: ['192.168.1.60'],
              hostname: 'aaaa.local',
              txt: tvTxt,
            ),
          ),
        ),
        lookup: (host, {type = InternetAddressType.any}) async {
          asked++;
          return const [];
        },
      );
      expect(asked, 0);
    });

    test('a lost device goes', () async {
      final emitted = await watch(() async {
        action
          ..add(
            BonsoirDiscoveryServiceResolvedEvent(
              service: service('TV', hosts: ['192.168.1.60'], txt: tvTxt),
            ),
          )
          ..add(BonsoirDiscoveryServiceLostEvent(service: service('TV')));
      });
      expect(emitted.last, isEmpty);
    });

    test('a speaker is not listed', () async {
      final emitted = await watch(() async {
        action.add(
          BonsoirDiscoveryServiceResolvedEvent(
            service: service(
              'Speaker',
              hosts: ['192.168.1.61'],
              txt: const {'id': 'cccc', 'fn': 'Speaker', 'ca': '198660'},
            ),
          ),
        );
      });
      expect(emitted.last, isEmpty);
    });

    test(
      'Avahi out of reach: sees nothing, says so once, never throws',
      () async {
        action.failOnInit = const SocketException('no D-Bus');
        final emitted = await watch(() async {});
        expect(emitted, [<CastDevice>[]]);
        expect(action.started, isFalse);
      },
    );
  });
}

final class _FakeDiscoveryAction extends BonsoirAction<BonsoirDiscoveryEvent>
    with ServiceResolver {
  final _events = StreamController<BonsoirDiscoveryEvent>.broadcast();
  final resolved = <String>[];
  Exception? failOnInit;
  var _initialized = false;
  bool started = false;
  bool stopped = false;

  void add(BonsoirDiscoveryEvent event) => _events.add(event);

  @override
  Stream<BonsoirDiscoveryEvent>? get eventStream =>
      _initialized ? _events.stream : null;

  @override
  Future<void> initialize() async {
    if (failOnInit case final error?) throw error;
    _initialized = true;
  }

  @override
  Future<void> start() async => started = true;

  @override
  Future<void> stop() async => stopped = true;

  @override
  bool get isReady => _initialized && !stopped;

  @override
  bool get isStopped => stopped;

  @override
  void resolveService(BonsoirService service) => resolved.add(service.name);

  @override
  bool supportsMdnsHostname() => true;
}

final class _FakePlatform extends BonsoirPlatformInterface {
  new(this.action);

  final _FakeDiscoveryAction action;

  @override
  BonsoirAction<BonsoirDiscoveryEvent> createDiscoveryAction(
    String type, {
    bool printLogs = false,
  }) => action;

  @override
  BonsoirAction<BonsoirBroadcastEvent> createBroadcastAction(
    BonsoirService service, {
    bool printLogs = false,
  }) => throw UnimplementedError();
}
