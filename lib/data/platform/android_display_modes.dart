import 'dart:async';

import 'package:flutter/services.dart';
import 'package:iptv_player/core/logging/app_log.dart';
import 'package:iptv_player/core/platform/display_modes.dart';

const _tag = 'display';

/// A Google TV's display (ADR-035, item 2), over `MainActivity`'s
/// `bijou/display` channel (`DisplayModes.kt`): its modes, the window's
/// preferred one, and its changes.
///
/// What the channel answers is read tolerantly: a mode it can't read is
/// left out, an answer with no display in it is a display that couldn't
/// be read, and a failure is logged and answered null or false, never
/// thrown (hard rule 1's spirit).
final class AndroidDisplayModes implements DisplayModes {
  new({
    required this._log,
    this._channel = const MethodChannel('bijou/display'),
  }) {
    _channel.setMethodCallHandler(_called);
  }

  final AppLog _log;
  final MethodChannel _channel;
  final _changes = StreamController<DisplayMode>.broadcast();

  @override
  bool get available => true;

  @override
  Future<DisplayFacts?> read() async {
    try {
      final facts = displayFactsFrom(
        await _channel.invokeMethod<Object?>('read'),
      );
      if (facts == null) _log.info(_tag, 'The display said nothing it has');
      return facts;
    } on Object catch (error) {
      _log.warning(_tag, "The display couldn't be read: $error");
      return null;
    }
  }

  @override
  Future<bool> request(int id) async {
    try {
      return await _channel.invokeMethod<Object?>('request', {'id': id}) ==
          true;
    } on Object catch (error) {
      _log.warning(_tag, "Display mode $id couldn't be asked for: $error");
      return false;
    }
  }

  @override
  Stream<DisplayMode> get changes => _changes.stream;

  Future<Object?> _called(MethodCall call) async {
    if (call.method != 'modeChanged') return null;
    if (displayModeFrom(call.arguments) case final mode?) {
      _changes.add(mode);
    } else {
      _log.info(_tag, "A display change came that couldn't be read");
    }
    return null;
  }
}

/// `read`'s answer; null when it holds no display: no current mode and
/// no modes.
DisplayFacts? displayFactsFrom(Object? answer) {
  if (answer is! Map) return null;
  final current = displayModeFrom(answer['current']);
  final modes = [
    for (final mode in _list(answer['modes'])) ?displayModeFrom(mode),
  ];
  if (current == null && modes.isEmpty) return null;
  return DisplayFacts(
    current: current,
    modes: modes,
    alternativeRefreshRates: [
      for (final rate in _list(answer['alternativeRefreshRates'])) ?_rate(rate),
    ],
    matchContentFrameRate: _preference(answer['matchContentFrameRate']),
    apiLevel: _whole(answer['apiLevel']),
  );
}

/// One mode, `{id, width, height, refreshRate}`; null unless each is
/// there and sensible (an id of 0 asks for no mode, so it is none).
DisplayMode? displayModeFrom(Object? value) {
  if (value is! Map) return null;
  final id = _whole(value['id']);
  final width = _whole(value['width']);
  final height = _whole(value['height']);
  final rate = _rate(value['refreshRate']);
  if (id == null || id <= 0) return null;
  if (width == null || width <= 0 || height == null || height <= 0) {
    return null;
  }
  if (rate == null) return null;
  return DisplayMode(id: id, width: width, height: height, refreshRate: rate);
}

List<Object?> _list(Object? value) => value is List ? value : const [];

/// A whole number, as an int, a whole double or a numeral.
int? _whole(Object? value) => switch (value) {
  final int whole => whole,
  final double number
      when number.isFinite && number == number.truncateToDouble() =>
    number.toInt(),
  final String text => int.tryParse(text.trim()),
  _ => null,
};

/// A refresh rate in Hz: positive and finite.
double? _rate(Object? value) {
  final rate = switch (value) {
    final num number => number.toDouble(),
    final String text => double.tryParse(text.trim()),
    _ => null,
  };
  return rate != null && rate.isFinite && rate > 0 ? rate : null;
}

/// DisplayModes.kt says it in words; Android's own numbers are read too.
MatchContentFrameRate _preference(Object? value) => switch (value) {
  'always' || 2 => MatchContentFrameRate.always,
  'seamlessOnly' || 1 => MatchContentFrameRate.seamlessOnly,
  'never' || 0 => MatchContentFrameRate.never,
  _ => MatchContentFrameRate.unknown,
};
