import 'dart:ffi';
import 'dart:io';

import 'package:ffi/ffi.dart';
import 'package:iptv_player/core/platform/system_facts.dart';
import 'package:win32/win32.dart';

/// [SystemFacts] on Windows: the system's own version text, and the
/// display adapters `EnumDisplayDevices` lists.
///
/// **Untried on a real Windows PC** (ADR-016, step 4): CI compiles it,
/// nothing here has run it. Everything is guarded, so the worst it can
/// do is leave the graphics line out.
final class WindowsSystemFacts implements SystemFactsReader {
  const new();

  @override
  Future<SystemFacts> read() async {
    String? os;
    try {
      // "Windows 11 Pro" 10.0 (Build 22631)
      os = Platform.operatingSystemVersion.replaceAll('"', '').trim();
    } on Object {
      os = null;
    }
    return SystemFacts(
      os: os == null || os.isEmpty ? 'Windows' : os,
      graphics: _adapters(),
    );
  }

  /// Each adapter once, by its name: a card with three outputs is listed
  /// three times.
  static List<GraphicsCard> _adapters() {
    final names = <String>[];
    try {
      final device = calloc<DISPLAY_DEVICE>();
      try {
        for (var index = 0; index < 32; index++) {
          device.ref.cb = sizeOf<DISPLAY_DEVICE>();
          if (!EnumDisplayDevices(null, index, device, 0)) break;
          final name = device.ref.DeviceString.trim();
          if (name.isNotEmpty && !names.contains(name)) names.add(name);
        }
      } finally {
        calloc.free(device);
      }
    } on Object {
      // The graphics line is left out.
    }
    return [for (final name in names) GraphicsCard(name: name)];
  }
}
