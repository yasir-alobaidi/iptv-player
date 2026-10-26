import 'dart:io';

import 'package:iptv_player/core/platform/system_facts.dart';
import 'package:iptv_player/data/platform/android_system_facts.dart';
import 'package:iptv_player/data/platform/linux_system_facts.dart';
import 'package:iptv_player/data/platform/windows_system_facts.dart';

/// The reader for the system the app runs on.
SystemFactsReader platformSystemFacts() {
  if (Platform.isLinux) return const LinuxSystemFacts();
  if (Platform.isWindows) return const WindowsSystemFacts();
  if (Platform.isAndroid) return const AndroidSystemFacts();
  return const NoSystemFacts();
}
