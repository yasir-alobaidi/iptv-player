import 'dart:io';

import 'package:dbus/dbus.dart';
import 'package:iptv_player/core/logging/app_log.dart';
import 'package:iptv_player/core/platform/sleep_inhibitor.dart';
import 'package:win32/win32.dart';

const _tag = 'sleep';

/// The way this system has to hold sleep off (Phase 7 decision 7).
SleepInhibitor platformSleepInhibitor(AppLog log) {
  if (Platform.isLinux) return DbusSleepInhibitor(log: log);
  if (Platform.isWindows) return WindowsSleepInhibitor(log: log);
  return const NoSleepInhibitor();
}

/// Linux: the desktop portal's Inhibit, which GNOME and KDE honour, over
/// the session bus; logind's sleep lock over the system bus when there is
/// no portal. Both are D-Bus calls in pure Dart (the `dbus` package).
///
/// The portal holds until its request is closed, or our connection ends;
/// logind until the file descriptor it hands back is closed.
final class DbusSleepInhibitor implements SleepInhibitor {
  new({
    required this._log,
    DBusClient Function()? session,
    DBusClient Function()? system,
  }) : _session = session ?? DBusClient.session,
       _system = system ?? DBusClient.system;

  final AppLog _log;
  final DBusClient Function() _session;
  final DBusClient Function() _system;

  /// Suspend (4) and idle (8): the portal's flags.
  static const int portalFlags = 4 | 8;

  DBusClient? _client;
  DBusObjectPath? _portalRequest;
  RandomAccessFile? _logindLock;
  Future<bool>? _holding;

  @override
  Future<bool> hold(String why) => _holding ??= _hold(why).then((held) {
    if (!held) _holding = null;
    return held;
  });

  Future<bool> _hold(String why) async {
    final session = _session();
    try {
      final reply = await session.callMethod(
        destination: 'org.freedesktop.portal.Desktop',
        path: DBusObjectPath('/org/freedesktop/portal/desktop'),
        interface: 'org.freedesktop.portal.Inhibit',
        name: 'Inhibit',
        values: [
          const DBusString(''),
          const DBusUint32(portalFlags),
          DBusDict.stringVariant({'reason': DBusString(why)}),
        ],
        replySignature: DBusSignature('o'),
      );
      _client = session;
      _portalRequest = reply.returnValues.single.asObjectPath();
      _log.info(_tag, 'Sleep held off through the desktop portal: $why');
      return true;
    } on Object catch (error) {
      await _close(session);
      _log.info(_tag, 'No desktop portal to hold sleep off: $error');
    }
    final system = _system();
    try {
      final reply = await system.callMethod(
        destination: 'org.freedesktop.login1',
        path: DBusObjectPath('/org/freedesktop/login1'),
        interface: 'org.freedesktop.login1.Manager',
        name: 'Inhibit',
        values: [
          const DBusString('sleep:idle'),
          const DBusString('IPTV Player'),
          DBusString(why),
          const DBusString('block'),
        ],
        replySignature: DBusSignature('h'),
      );
      final fd = reply.returnValues.single;
      if (fd is! DBusUnixFd) throw StateError('logind sent no lock');
      _client = system;
      _logindLock = fd.handle.toFile();
      _log.info(_tag, 'Sleep held off through logind: $why');
      return true;
    } on Object catch (error) {
      await _close(system);
      _log.warning(_tag, 'Could not hold sleep off: $error');
      return false;
    }
  }

  @override
  Future<void> release() async {
    final holding = _holding;
    if (holding == null) return;
    _holding = null;
    if (!await holding) return;
    final client = _client;
    final request = _portalRequest;
    final lock = _logindLock;
    _client = null;
    _portalRequest = null;
    _logindLock = null;
    if (request != null && client != null) {
      try {
        await client.callMethod(
          destination: 'org.freedesktop.portal.Desktop',
          path: request,
          interface: 'org.freedesktop.portal.Request',
          name: 'Close',
          replySignature: DBusSignature(''),
        );
      } on Object catch (error) {
        // Closing our connection below ends it anyway.
        _log.info(_tag, 'The portal did not take the release: $error');
      }
    }
    if (lock != null) {
      try {
        await lock.close();
      } on Object catch (_) {}
    }
    if (client != null) await _close(client);
    _log.info(_tag, 'Sleep allowed again');
  }

  static Future<void> _close(DBusClient client) async {
    try {
      await client.close();
    } on Object catch (_) {}
  }
}

/// Windows: `SetThreadExecutionState`, which holds until it is called
/// again without `ES_SYSTEM_REQUIRED`. It is the calling thread's state:
/// the UI isolate's, which stays on one thread.
final class WindowsSleepInhibitor implements SleepInhibitor {
  new({required this._log});

  final AppLog _log;
  var _held = false;

  @override
  Future<bool> hold(String why) async {
    if (_held) return true;
    try {
      final previous = SetThreadExecutionState(
        ES_CONTINUOUS | ES_SYSTEM_REQUIRED,
      );
      _held = previous != 0;
    } on Object catch (error) {
      _log.warning(_tag, 'Could not hold sleep off: $error');
      return false;
    }
    if (_held) _log.info(_tag, 'Sleep held off: $why');
    return _held;
  }

  @override
  Future<void> release() async {
    if (!_held) return;
    _held = false;
    try {
      SetThreadExecutionState(ES_CONTINUOUS);
      _log.info(_tag, 'Sleep allowed again');
    } on Object catch (error) {
      _log.warning(_tag, 'Could not allow sleep again: $error');
    }
  }
}
