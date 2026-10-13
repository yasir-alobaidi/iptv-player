import 'dart:async';

import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:iptv_player/core/logging/app_log.dart';
import 'package:iptv_player/core/platform/system_notifier.dart';

const _tag = 'notifications';

/// Windows: toast notifications through flutter_local_notifications
/// (Phase 9 decision 11).
///
/// **Untried on a real Windows PC** (ADR-016, step 5): CI builds it,
/// nothing here has run it. An app that isn't a store package needs only
/// a name, an app id and a GUID to show a toast; the Phase 10 installer
/// registers the app id. Whatever fails here answers false, and the
/// reminder is shown inside the app instead.
final class WindowsNotifier implements SystemNotifier {
  new({required this._log});

  final AppLog _log;

  /// Identifies the app's notification activator to Windows. Fixed for
  /// good: a new one would orphan the notices of the old.
  static const guid = 'd321c6df-3e8e-4242-a7dc-05c2081f896c';
  static const appUserModelId = 'io.github.yasiralobaidi.iptvplayer';
  static const _watch = 'watch';

  final _plugin = FlutterLocalNotificationsPlugin();
  final _responses = StreamController<NoticeResponse>.broadcast();
  Future<bool>? _ready;
  bool _disposed = false;

  @override
  Stream<NoticeResponse> get responses => _responses.stream;

  Future<bool> _initialize() async {
    try {
      final ok = await _plugin.initialize(
        settings: const InitializationSettings(
          windows: WindowsInitializationSettings(
            appName: 'IPTV Player',
            appUserModelId: appUserModelId,
            guid: guid,
          ),
        ),
        onDidReceiveNotificationResponse: (response) {
          final id = response.id;
          if (id == null || _disposed) return;
          // The button, or a click on the toast itself: both mean Watch,
          // and Windows brings the app forward for either.
          _responses.add(NoticeResponse(id, chosen: true));
        },
      );
      return ok ?? false;
    } on Object catch (error) {
      _log.warning(_tag, "Windows notifications couldn't start: $error");
      return false;
    }
  }

  @override
  Future<bool> show(SystemNotice notice) async {
    if (_disposed) return false;
    if (!await (_ready ??= _initialize())) return false;
    final action = notice.action;
    try {
      await _plugin.show(
        id: notice.id,
        title: notice.title,
        body: notice.body,
        notificationDetails: NotificationDetails(
          windows: WindowsNotificationDetails(
            actions: [
              if (action != null)
                WindowsAction(content: action, arguments: _watch),
            ],
          ),
        ),
      );
      return true;
    } on Object catch (error) {
      _log.warning(_tag, "A notification couldn't be shown: $error");
      return false;
    }
  }

  @override
  Future<void> dispose() async {
    _disposed = true;
    await _responses.close();
  }
}
