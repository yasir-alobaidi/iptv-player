import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:iptv_player/core/platform/system_facts.dart';
import 'package:iptv_player/data/platform/linux_system_facts.dart';
import 'package:path/path.dart' as p;

/// A folder laid out like `/` on a Linux laptop with two graphics cards.
final class _System {
  new() : root = Directory.systemTemp.createTempSync('linux_facts_') {
    addTearDown(() => root.deleteSync(recursive: true));
  }

  final Directory root;

  void write(String path, String text) => File(p.join(root.path, path))
    ..createSync(recursive: true)
    ..writeAsStringSync(text);

  void card(String name, {String? vendor, String? device, String? driver}) {
    if (vendor != null) write('sys/class/drm/$name/device/vendor', '$vendor\n');
    if (device != null) write('sys/class/drm/$name/device/device', '$device\n');
    write(
      'sys/class/drm/$name/device/uevent',
      '${driver == null ? '' : 'DRIVER=$driver\n'}PCI_CLASS=30000\n',
    );
  }

  SystemFacts read({
    Map<String, String> environment = const {
      'XDG_SESSION_TYPE': 'wayland',
      'XDG_CURRENT_DESKTOP': 'ubuntu:GNOME',
    },
    String kernel = 'Linux 6.8.0-138-generic #138~22.04.1-Ubuntu SMP',
  }) => readLinuxFacts(root.path, environment, kernel);
}

const _pciIds = '''
# List of PCI ID's
8086  Intel Corporation
\t3e9b  CoffeeLake-H GT2 [UHD Graphics 630]
\t\t1028 0926  Subsystem of something
\t9a49  TigerLake-LP GT2 [Iris Xe Graphics]
10de  NVIDIA Corporation
\t1f95  TU117M [GeForce GTX 1650 Ti Mobile]
1002  Advanced Micro Devices, Inc. [AMD/ATI]
\t73df  Navi 22 [Radeon RX 6700/6700 XT/6750 XT / 6800M/6850M XT]
1a03  ASPEED Technology, Inc.
\t2000  ASPEED Graphics Family
C 03  Display controller
\t00  VGA compatible controller
''';

void main() {
  test('the system, the session, the desktop and both graphics cards with '
      'their drivers', () {
    final system = _System()
      ..write(
        'etc/os-release',
        'NAME="Ubuntu"\nVERSION_ID="22.04"\n'
            'PRETTY_NAME="Ubuntu 22.04.5 LTS"\nID=ubuntu\n',
      )
      ..write('usr/share/misc/pci.ids', _pciIds)
      ..card('card0', vendor: '0x8086', device: '0x3e9b', driver: 'i915')
      ..card('card1', vendor: '0x10de', device: '0x1f95', driver: 'nvidia')
      // A card's outputs are folders too: they aren't cards.
      ..card('card0-HDMI-A-1')
      ..card('card0-eDP-1');

    final facts = system.read();

    expect(facts.os, 'Ubuntu 22.04.5 LTS');
    expect(facts.kernel, 'Linux 6.8.0-138-generic');
    expect(facts.session, 'Wayland');
    expect(facts.desktop, 'GNOME');
    expect(
      [for (final card in facts.graphics) card.line],
      [
        'Intel UHD Graphics 630 (i915)',
        'NVIDIA GeForce GTX 1650 Ti Mobile (nvidia)',
      ],
    );
  });

  test('a vendor with no short name of ours keeps its own, tidied', () {
    final system = _System()
      ..write('usr/share/hwdata/pci.ids', _pciIds)
      ..card('card0', vendor: '0x1a03', device: '0x2000', driver: 'ast')
      ..card('card1', vendor: '0x1002', device: '0x73df', driver: 'amdgpu');

    expect(
      [for (final card in system.read().graphics) card.line],
      [
        'ASPEED Graphics Family (ast)',
        'AMD Radeon RX 6700/6700 XT/6750 XT / 6800M/6850M XT (amdgpu)',
      ],
    );
  });

  test('without the id list, or for a card it doesn’t know, the vendor and '
      'the ids', () {
    final system = _System()
      ..card('card0', vendor: '0x8086', device: '0x3e9b', driver: 'i915')
      ..card('card1', vendor: '0xabcd', device: '0x0001');

    expect(
      [for (final card in system.read().graphics) card.line],
      ['Intel graphics (8086:3e9b) (i915)', 'Vendor abcd graphics (abcd:0001)'],
    );
  });

  test('an X11 session, KDE, and a system with no pretty name', () {
    final system = _System()..write('etc/os-release', 'NAME=Arch Linux\n');

    final facts = system.read(
      environment: const {
        'XDG_SESSION_TYPE': 'x11',
        'XDG_CURRENT_DESKTOP': 'KDE',
      },
      kernel: 'Linux 6.11.1-arch1-1',
    );

    expect(facts.os, 'Arch Linux');
    expect(facts.kernel, 'Linux 6.11.1-arch1-1');
    expect(facts.session, 'X11');
    expect(facts.desktop, 'KDE');
  });

  test('nothing there to read is nothing said, never an error', () {
    final facts = _System().read(environment: const {}, kernel: '');

    expect(facts.os, isNull);
    expect(facts.kernel, isNull);
    expect(facts.session, isNull);
    expect(facts.desktop, isNull);
    expect(facts.graphics, isEmpty);
  });

  test('a card whose files are junk is left out', () {
    final system = _System()
      ..card('card0', vendor: 'not hex', device: '0x3e9b')
      ..card('card1', vendor: '0x8086')
      ..card('card2', vendor: '0x8086', device: '0x9a49', driver: 'i915')
      ..write('usr/share/misc/pci.ids', _pciIds);

    expect(
      [for (final card in system.read().graphics) card.line],
      ['Intel Iris Xe Graphics (i915)'],
    );
  });

  test('on this computer the reader answers in an isolate, and names '
      'nothing that isn’t a card', () async {
    final facts = await const LinuxSystemFacts().read();

    // Whatever this machine has: the shape is what is checked.
    for (final card in facts.graphics) {
      expect(card.name, isNotEmpty);
      expect(card.name, isNot(contains('\n')));
    }
  }, testOn: 'linux');
}
