import 'dart:async';

import 'package:dbus/dbus.dart';
import 'package:iptv_player/core/logging/app_log.dart';
import 'package:iptv_player/core/platform/system_notifier.dart';

const _tag = 'notifications';
const _name = 'org.freedesktop.Notifications';
final _path = DBusObjectPath('/org/freedesktop/Notifications');

/// The button's key in the notification, and a click on its body's.
const _watch = 'watch';
const _default = 'default';

/// Linux: the desktop's notification service over D-Bus
/// (`org.freedesktop.Notifications`), spoken directly rather than through
/// a package: it can be pointed at a fake server in a test, and it reads
/// the activation token a desktop hands out with a click (Phase 9
/// decision 11).
///
/// **GNOME Shell is told of no default action.** Clicked on its body, a
/// notice with one tells the app and leaves its window where it is;
/// without one, the shell brings the app's window forward itself and
/// says only that the notice was closed (looked up on GNOME Shell 42.9,
/// which also hands out no activation token: ADR-016, step 5). So there
/// a closed notice is reported as not chosen, and the caller looks at
/// its window. Every other server gets the default action, as the
/// specification means it.
final class DbusNotifier implements SystemNotifier {
  new({
    required this._log,
    DBusClient Function()? session,
    this.appName = 'IPTV Player',
    this.desktopEntry = 'io.github.yasiralobaidi.iptvplayer',
    this.timeout = const Duration(seconds: 5),
  }) : _session = session ?? DBusClient.session;

  final AppLog _log;
  final DBusClient Function() _session;
  final String appName;

  /// The app's desktop file, without `.desktop`: how a desktop ties a
  /// notice to its app.
  final String desktopEntry;

  /// How long the service may take to answer.
  final Duration timeout;

  final _responses = StreamController<NoticeResponse>.broadcast();
  final _subscriptions = <StreamSubscription<DBusSignal>>[];

  /// The server's id of each notice still showing → ours.
  final _shown = <int, int>{};

  /// The token the desktop sent for a notice, just before its action.
  final _tokens = <int, String>{};

  DBusClient? _client;
  Future<bool>? _ready;
  bool _clickOpensApp = false;
  bool _disposed = false;

  @override
  Stream<NoticeResponse> get responses => _responses.stream;

  /// Connects, asks the server who it is, and listens for what users do.
  /// False when there is no notification service.
  Future<bool> _connect() async {
    final client = _session();
    try {
      final info = await client
          .callMethod(
            destination: _name,
            path: _path,
            interface: _name,
            name: 'GetServerInformation',
            replySignature: DBusSignature('ssss'),
          )
          .timeout(timeout);
      final server = info.values.first.asString();
      _clickOpensApp = server == 'gnome-shell';
      _log.info(
        _tag,
        'Notification service: $server ${info.values[2].asString()}, '
        'specification ${info.values[3].asString()}',
      );
    } on Object catch (error) {
      _log.info(_tag, 'No notification service on the session bus: $error');
      unawaited(client.close());
      return false;
    }
    _client = client;
    void listen(String signal, void Function(DBusSignal) handle) {
      _subscriptions.add(
        DBusSignalStream(
          client,
          interface: _name,
          name: signal,
          path: _path,
        ).listen(handle, onError: (Object _) {}),
      );
    }

    listen('ActivationToken', _onToken);
    listen('ActionInvoked', _onAction);
    listen('NotificationClosed', _onClosed);
    return true;
  }

  static int? _id(DBusSignal signal) {
    final values = signal.values;
    if (values.isEmpty || values.first is! DBusUint32) return null;
    return values.first.asUint32();
  }

  static String? _text(DBusSignal signal) {
    final values = signal.values;
    if (values.length < 2 || values[1] is! DBusString) return null;
    return values[1].asString();
  }

  void _onToken(DBusSignal signal) {
    final id = _id(signal);
    final token = _text(signal);
    if (id == null || token == null || !_shown.containsKey(id)) return;
    _tokens[id] = token;
  }

  void _onAction(DBusSignal signal) {
    final id = _id(signal);
    final action = _text(signal);
    final ours = id == null ? null : _shown[id];
    if (ours == null || (action != _watch && action != _default)) return;
    // An answered notice is done with: what closes it afterwards is no
    // second answer.
    _shown.remove(id);
    _emit(
      NoticeResponse(ours, chosen: true, activationToken: _tokens.remove(id)),
    );
  }

  void _onClosed(DBusSignal signal) {
    final id = _id(signal);
    if (id == null) return;
    final ours = _shown.remove(id);
    _tokens.remove(id);
    if (ours == null) return;
    final values = signal.values;
    // 2: dismissed by the user. (1 expired, 3 closed by the app.)
    final dismissed =
        values.length > 1 &&
        values[1] is DBusUint32 &&
        values[1].asUint32() == 2;
    if (dismissed && _clickOpensApp) {
      _emit(NoticeResponse(ours, chosen: false));
    }
  }

  void _emit(NoticeResponse response) {
    if (!_disposed) _responses.add(response);
  }

  @override
  Future<bool> show(SystemNotice notice) async {
    if (_disposed) return false;
    if (!await (_ready ??= _connect())) {
      // Asked again next time: a service may start later in the session.
      _ready = null;
      return false;
    }
    final action = notice.action;
    try {
      final reply = await _client!
          .callMethod(
            destination: _name,
            path: _path,
            interface: _name,
            name: 'Notify',
            values: [
              DBusString(appName),
              const DBusUint32(0),
              const DBusString(''),
              DBusString(notice.title),
              DBusString(notice.body),
              DBusArray.string([
                if (action != null) ...[
                  if (!_clickOpensApp) ...[_default, action],
                  _watch,
                  action,
                ],
              ]),
              DBusDict.stringVariant({
                'desktop-entry': DBusString(desktopEntry),
                // Normal: it shows as a banner and may make a sound, and
                // doesn't stay on screen as a critical one would.
                'urgency': const DBusByte(1),
              }),
              const DBusInt32(-1),
            ],
            replySignature: DBusSignature('u'),
          )
          .timeout(timeout);
      _shown[reply.values.first.asUint32()] = notice.id;
      return true;
    } on Object catch (error) {
      _log.warning(_tag, "A notification couldn't be shown: $error");
      return false;
    }
  }

  @override
  Future<void> dispose() async {
    if (_disposed) return;
    _disposed = true;
    for (final subscription in _subscriptions) {
      await subscription.cancel();
    }
    await _responses.close();
    await _client?.close();
  }
}
