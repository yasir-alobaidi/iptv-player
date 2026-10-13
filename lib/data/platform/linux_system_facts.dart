import 'dart:io';
import 'dart:isolate';

import 'package:iptv_player/core/platform/system_facts.dart';
import 'package:path/path.dart' as p;

/// [SystemFacts] on Linux, from files only (no program is run):
/// `/etc/os-release`, the session's variables, `/sys/class/drm` for the
/// graphics cards and the PCI id list for their names. Read in an
/// isolate: the id list is over a megabyte.
final class LinuxSystemFacts implements SystemFactsReader {
  /// [root] is `/`; a test gives a folder laid out like it.
  const new({this.root = '/', this.environment, this.kernel});

  final String root;

  /// The session's variables; the process's own by default.
  final Map<String, String>? environment;

  /// `Linux 6.8.0-138-generic …`, as dart:io gives it.
  final String? kernel;

  @override
  Future<SystemFacts> read() async {
    final root = this.root;
    final environment = this.environment ?? Platform.environment;
    final kernel = this.kernel ?? Platform.operatingSystemVersion;
    try {
      return await Isolate.run(() => readLinuxFacts(root, environment, kernel));
    } on Object {
      return const SystemFacts();
    }
  }
}

/// [LinuxSystemFacts.read]'s work, synchronous, for the isolate.
SystemFacts readLinuxFacts(
  String root,
  Map<String, String> environment,
  String kernel,
) => SystemFacts(
  os: _prettyName(root),
  kernel: _kernel(kernel),
  session: switch (environment['XDG_SESSION_TYPE']?.toLowerCase()) {
    'wayland' => 'Wayland',
    'x11' => 'X11',
    final other? when other.isNotEmpty => other,
    _ => null,
  },
  desktop: _desktop(environment['XDG_CURRENT_DESKTOP']),
  graphics: _graphics(root),
);

String? _read(String path) {
  try {
    return File(path).readAsStringSync();
  } on Object {
    return null;
  }
}

/// `PRETTY_NAME="Ubuntu 22.04.5 LTS"`.
String? _prettyName(String root) {
  final text =
      _read(p.join(root, 'etc', 'os-release')) ??
      _read(p.join(root, 'usr', 'lib', 'os-release'));
  if (text == null) return null;
  String? value(String key) {
    for (final line in text.split('\n')) {
      if (!line.startsWith('$key=')) continue;
      final raw = line.substring(key.length + 1).trim();
      final unquoted =
          raw.length >= 2 && raw.startsWith('"') && raw.endsWith('"')
          ? raw.substring(1, raw.length - 1)
          : raw;
      if (unquoted.isNotEmpty) return unquoted;
    }
    return null;
  }

  return value('PRETTY_NAME') ?? value('NAME');
}

/// `Linux 6.8.0-138-generic`: the name and the release, without the
/// build line after them.
String? _kernel(String version) {
  final words = version.trim().split(RegExp(r'\s+'));
  if (words.isEmpty || words.first.isEmpty) return null;
  return words.take(2).join(' ');
}

/// `ubuntu:GNOME` is GNOME on Ubuntu: the last name is the desktop.
String? _desktop(String? value) {
  final names = [
    for (final name in (value ?? '').split(':'))
      if (name.trim().isNotEmpty) name.trim(),
  ];
  return names.isEmpty ? null : names.last;
}

final _card = RegExp(r'^card\d+$');

List<GraphicsCard> _graphics(String root) {
  final drm = Directory(p.join(root, 'sys', 'class', 'drm'));
  final List<String> cards;
  try {
    cards = [
      for (final entity in drm.listSync(followLinks: false))
        if (_card.hasMatch(p.basename(entity.path))) entity.path,
    ]..sort();
  } on Object {
    return const [];
  }
  final ids = <(String, String, String?)>[];
  for (final card in cards) {
    final vendor = _hex(_read(p.join(card, 'device', 'vendor')));
    final device = _hex(_read(p.join(card, 'device', 'device')));
    if (vendor == null || device == null) continue;
    String? driver;
    for (final line in (_read(p.join(card, 'device', 'uevent')) ?? '').split(
      '\n',
    )) {
      if (line.startsWith('DRIVER=')) driver = line.substring(7).trim();
    }
    ids.add((vendor, device, driver == null || driver.isEmpty ? null : driver));
  }
  if (ids.isEmpty) return const [];
  final names = _pciNames(root, {
    for (final (vendor, device, _) in ids) (vendor, device),
  });
  return [
    for (final (vendor, device, driver) in ids)
      GraphicsCard(
        name: names[(vendor, device)] ?? _unnamed(vendor, device),
        driver: driver,
      ),
  ];
}

/// `0x8086\n` → `8086`.
String? _hex(String? text) {
  final match = RegExp(r'^\s*(?:0x)?([0-9a-fA-F]{4})\s*$')
      .firstMatch(text ?? '');
  return match?[1]!.toLowerCase();
}

const _vendors = {
  '8086': 'Intel',
  '10de': 'NVIDIA',
  '1002': 'AMD',
  '1022': 'AMD',
  '15ad': 'VMware',
  '1af4': 'Virtio',
  '1234': 'QEMU',
};

String _unnamed(String vendor, String device) =>
    '${_vendors[vendor] ?? 'Vendor $vendor'} graphics ($vendor:$device)';

/// The names of [wanted] (vendor, device) pairs from the PCI id list:
///
///     8086  Intel Corporation
///     	3e9b  CoffeeLake-H GT2 [UHD Graphics 630]
Map<(String, String), String> _pciNames(
  String root,
  Set<(String, String)> wanted,
) {
  final text =
      _read(p.join(root, 'usr', 'share', 'misc', 'pci.ids')) ??
      _read(p.join(root, 'usr', 'share', 'hwdata', 'pci.ids'));
  if (text == null) return const {};
  final names = <(String, String), String>{};
  final vendors = {for (final (vendor, _) in wanted) vendor};
  String? vendor;
  String? vendorName;
  for (final line in text.split('\n')) {
    if (line.isEmpty || line.startsWith('#')) continue;
    if (!line.startsWith('\t')) {
      // A vendor, or the device classes at the end of the file.
      if (line.startsWith('C ')) break;
      final id = line.length >= 4 ? line.substring(0, 4).toLowerCase() : '';
      vendor = vendors.contains(id) ? id : null;
      vendorName = vendor == null ? null : line.substring(4).trim();
      continue;
    }
    if (vendor == null || line.startsWith('\t\t') || line.length < 6) continue;
    final device = line.substring(1, 5).toLowerCase();
    if (!wanted.contains((vendor, device))) continue;
    names[(vendor, device)] = _cardName(
      vendor,
      vendorName ?? '',
      line.substring(5).trim(),
    );
    if (names.length == wanted.length) break;
  }
  return names;
}

/// "Intel Corporation" + "CoffeeLake-H GT2 [UHD Graphics 630]" → "Intel
/// UHD Graphics 630": the name in brackets is the one on the box.
String _cardName(String vendor, String vendorName, String device) {
  final marketed = RegExp(r'\[([^\]]+)\]').allMatches(device).lastOrNull?[1];
  final short =
      _vendors[vendor] ??
      vendorName
          .replaceAll(RegExp(r'\s*\[[^\]]*\]'), '')
          .replaceAll(
            RegExp(
              r',?\s+(Corporation|Inc\.?|Ltd\.?|Co\.)$',
              caseSensitive: false,
            ),
            '',
          )
          .trim();
  final name = (marketed ?? device).trim();
  // "ASPEED Graphics Family" already says whose it is.
  final first = short.split(' ').first.toLowerCase();
  if (short.isEmpty || name.toLowerCase().startsWith(first)) return name;
  return '$short $name';
}
