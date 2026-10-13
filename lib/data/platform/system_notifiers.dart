import 'dart:io';

import 'package:iptv_player/core/logging/app_log.dart';
import 'package:iptv_player/core/platform/system_notifier.dart';
import 'package:iptv_player/data/platform/dbus_notifier.dart';
import 'package:iptv_player/data/platform/windows_notifier.dart';

/// The notifications of the system the app runs on.
SystemNotifier platformSystemNotifier(AppLog log) {
  if (Platform.isLinux) return DbusNotifier(log: log);
  if (Platform.isWindows) return WindowsNotifier(log: log);
  return const NoSystemNotifier();
}
