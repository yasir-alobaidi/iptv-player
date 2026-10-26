import 'package:flutter/services.dart';
import 'package:iptv_player/core/logging/app_log.dart';
import 'package:iptv_player/core/platform/run_logs.dart';

const _tag = 'report';

/// A TV's own log of each run (ADR-059), over `MainActivity`'s
/// `bijou/system` channel (`SystemInfo.kt`, `RunLog.kt`). Read tolerantly
/// ([runLogsFrom]); a failure is logged and answered null, never thrown.
final class AndroidRunLogs implements RunLogsSource {
  new({
    required this._log,
    this._channel = const MethodChannel('bijou/system'),
  });

  final AppLog _log;
  final MethodChannel _channel;

  @override
  bool get available => true;

  @override
  Future<RunLogs?> read({int maxBytes = 256 * 1024}) async {
    try {
      return runLogsFrom(
        await _channel.invokeMethod<Object?>('runLogs', {'maxBytes': maxBytes}),
      );
    } on Object catch (error) {
      _log.warning(_tag, "The runs' own logs couldn't be read: $error");
      return null;
    }
  }
}
