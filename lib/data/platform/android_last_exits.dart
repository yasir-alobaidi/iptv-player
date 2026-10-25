import 'package:flutter/services.dart';
import 'package:iptv_player/core/logging/app_log.dart';
import 'package:iptv_player/core/platform/last_exits.dart';

const _tag = 'exits';

/// A TV's last ends (ADR-058), over `MainActivity`'s `bijou/exits` channel
/// (`LastExits.kt`): Android's own record of why the app's process ended,
/// a native crash's tombstone, and how the screen is drawn.
///
/// What the channel answers is read tolerantly ([lastExitsFrom]); a
/// failure is logged and answered null, never thrown.
final class AndroidLastExits implements LastExitsSource {
  new({required this._log, this._channel = const MethodChannel('bijou/exits')});

  final AppLog _log;
  final MethodChannel _channel;

  @override
  bool get available => true;

  @override
  Future<LastExits?> read() async {
    try {
      final exits = lastExitsFrom(await _channel.invokeMethod<Object?>('read'));
      if (exits == null) _log.info(_tag, 'The last ends said nothing');
      return exits;
    } on Object catch (error) {
      _log.warning(_tag, "The last ends couldn't be read: $error");
      return null;
    }
  }

  @override
  Future<void> seen(DateTime upTo) async {
    try {
      await _channel.invokeMethod<Object?>('seen', {
        'upTo': upTo.millisecondsSinceEpoch,
      });
    } on Object catch (error) {
      _log.warning(_tag, "The last end told couldn't be kept: $error");
    }
  }
}
