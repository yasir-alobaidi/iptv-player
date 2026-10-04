import 'dart:async';
import 'dart:io';

import 'package:dbus/dbus.dart';
import 'package:iptv_player/core/logging/app_log.dart';
import 'package:iptv_player/core/platform/file_reveal.dart';
import 'package:path/path.dart' as p;

const _tag = 'files';

/// Starts a program that hands off to the desktop and exits (xdg-open,
/// Explorer): not supervised, since nothing of ours keeps running.
typedef StartDetached = Future<void> Function(
  String executable,
  List<String> arguments,
);

Future<void> _startDetached(String executable, List<String> arguments) =>
    Process.start(executable, arguments, mode: ProcessStartMode.detached);

/// The way this system has to show a file in its folder.
FileReveal platformFileReveal(AppLog log) {
  if (Platform.isLinux) return DbusFileReveal(log: log);
  if (Platform.isWindows) return WindowsFileReveal(log: log);
  return const NoFileReveal();
}

/// Linux: the file manager's own D-Bus interface,
/// `org.freedesktop.FileManager1` (Nautilus, Dolphin, Nemo, Thunar and
/// Caja have it, and the bus starts one that isn't running): `ShowItems`
/// selects the file, `ShowFolders` opens a folder. With no file manager
/// on the bus, `xdg-open` on the folder.
final class DbusFileReveal implements FileReveal {
  new({
    required this._log,
    DBusClient Function()? session,
    StartDetached? start,
    this.timeout = const Duration(seconds: 10),
  }) : _session = session ?? DBusClient.session,
       _start = start ?? _startDetached;

  final AppLog _log;
  final DBusClient Function() _session;
  final StartDetached _start;

  /// How long the file manager may take to answer (the bus may be
  /// starting it).
  final Duration timeout;

  @override
  Future<bool> showInFolder(String path) async {
    final file = File(path).existsSync();
    final folder = file ? p.dirname(path) : await nearestFolder(path);
    if (folder == null) return false;
    final client = _session();
    try {
      await client
          .callMethod(
            destination: 'org.freedesktop.FileManager1',
            path: DBusObjectPath('/org/freedesktop/FileManager1'),
            interface: 'org.freedesktop.FileManager1',
            name: file ? 'ShowItems' : 'ShowFolders',
            values: [
              DBusArray.string([Uri.file(file ? path : folder).toString()]),
              const DBusString(''),
            ],
            replySignature: DBusSignature(''),
          )
          .timeout(timeout);
      return true;
    } on Object catch (error) {
      _log.info(_tag, 'No file manager on the session bus: $error');
    } finally {
      unawaited(client.close());
    }
    try {
      await _start('xdg-open', [folder]);
      return true;
    } on Object catch (error) {
      _log.warning(_tag, 'Could not open a folder: $error');
      return false;
    }
  }
}

/// Windows: Explorer with the file selected (`/select,`), or the folder.
/// Untried here (the plan's risks: Windows waits for the user's PC).
final class WindowsFileReveal implements FileReveal {
  new({required this._log, StartDetached? start})
    : _start = start ?? _startDetached;

  final AppLog _log;
  final StartDetached _start;

  @override
  Future<bool> showInFolder(String path) async {
    try {
      if (File(path).existsSync()) {
        await _start('explorer.exe', ['/select,$path']);
        return true;
      }
      final folder = await nearestFolder(path);
      if (folder == null) return false;
      await _start('explorer.exe', [folder]);
      return true;
    } on Object catch (error) {
      _log.warning(_tag, 'Could not open a folder: $error');
      return false;
    }
  }
}

/// The nearest folder above [path] that exists; null when not even the
/// root does.
Future<String?> nearestFolder(String path) async {
  var folder = p.dirname(path);
  while (true) {
    if (Directory(folder).existsSync()) return folder;
    final up = p.dirname(folder);
    if (up == folder) return null;
    folder = up;
  }
}
