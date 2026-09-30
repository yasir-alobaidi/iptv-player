// Phase 7 step 1's measurement: how long each browser takes to see the
// Cast devices on this computer's network, and what the direct DNS-SD
// query answers. Listening only, plus one query to each device's mDNS
// port: nothing shows on any screen.
//
//     flutter test --tags real_network --run-skipped \
//       test/tools/cast_discovery_network_test.dart
//
// With Avahi out of reach (as when it is stopped), run it again with
// DBUS_SYSTEM_BUS_ADDRESS=unix:path=/nonexistent: bonsoir then fails and
// multicast_dns carries on alone.
@Tags(['real_network'])
library;

import 'dart:async';
import 'dart:io';

import 'package:bonsoir_linux/bonsoir_linux.dart';

import 'package:flutter_test/flutter_test.dart';
import 'package:iptv_player/core/cast/cast_device.dart';
import 'package:iptv_player/core/cast/cast_discovery.dart';
import 'package:iptv_player/core/logging/app_log.dart';
import 'package:iptv_player/core/logging/secret_registry.dart';
import 'package:iptv_player/data/cast/cast_browsers.dart';
import 'package:iptv_player/data/cast/db_cast_device_store.dart';
import 'package:iptv_player/data/cast/merged_cast_discovery.dart';
import 'package:iptv_player/data/cast/unicast_address_check.dart';
import 'package:iptv_player/data/db/app_database.dart';
import 'package:logger/logger.dart';

const _window = Duration(seconds: 20);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  // bonsoir's Linux side is a Dart plugin, which `flutter test` doesn't
  // register by itself.
  if (Platform.isLinux) BonsoirLinux.registerWith();
  final log = AppLog(
    output: ConsoleOutput(),
    secrets: SecretRegistry(),
    level: Level.debug,
  );

  Future<void> firstSights(CastBrowser browser) async {
    final clock = Stopwatch()..start();
    final seen = <String>{};
    final hosts = <String, String>{};
    final done = Completer<void>();
    final subscription = browser.watch().listen((devices) {
      for (final device in devices) {
        if (seen.contains(device.id) && hosts[device.id] != device.host) {
          _say(
            '${browser.name}: "${device.name}" now at ${device.host} '
            'after ${clock.elapsedMilliseconds} ms',
          );
        }
        hosts[device.id] = device.host;
        if (seen.add(device.id)) {
          _say(
            '${browser.name}: "${device.name}" (${device.model}) '
            '${device.host}:${device.port} ca=${device.capabilities} '
            'rs=${device.status} after ${clock.elapsedMilliseconds} ms',
          );
        }
      }
    });
    Timer(_window, done.complete);
    await done.future;
    await subscription.cancel();
    _say('${browser.name}: ${seen.length} device(s) in ${_window.inSeconds} s');
  }

  test(
    'bonsoir',
    () => firstSights(BonsoirCastBrowser(log: log)),
    timeout: const Timeout(Duration(seconds: 40)),
  );

  test(
    'multicast_dns',
    () => firstSights(MulticastDnsCastBrowser(log: log)),
    timeout: const Timeout(Duration(seconds: 40)),
  );

  test('both, merged, and the direct query to each', () async {
    final db = AppDatabase.memory();
    addTearDown(db.close);
    final check = UnicastCastAddressCheck(log: log);
    final discovery = MergedCastDiscovery(
      browsers: [
        BonsoirCastBrowser(log: log),
        MulticastDnsCastBrowser(log: log),
      ],
      store: DbCastDeviceStore(db),
      addressCheck: check,
      log: log,
    );
    final clock = Stopwatch()..start();
    var last = <CastDevice>[];
    final subscription = discovery.devices.listen((devices) {
      last = devices;
      _say(
        'merged after ${clock.elapsedMilliseconds} ms: '
        '${[for (final d in devices) '"${d.name}" ${d.host}'].join(', ')}',
      );
    });
    await Future<void>.delayed(_window);
    await subscription.cancel();
    for (final device in last) {
      final asked = Stopwatch()..start();
      final answer = await check.check(CastAddress(device.host));
      final said = switch (answer) {
        CastDeviceAnswered(device: final d) =>
          '"${d.name}" (${d.model}) id ${d.id}',
        CastAudioOnlyAnswered(:final name) => 'audio only: "$name"',
        CastNoAnswer() => 'no answer',
      };
      _say(
        'direct query to ${device.host}: $said '
        'in ${asked.elapsedMilliseconds} ms',
      );
    }
  }, timeout: const Timeout(Duration(seconds: 60)));
}

/// The measurement's output, for the reader of the run.
void _say(String line) {
  // A tool run: its output is the point.
  // ignore: avoid_print
  print(line);
}
