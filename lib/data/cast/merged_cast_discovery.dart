import 'dart:async';

import 'package:iptv_player/core/cast/cast_device.dart';
import 'package:iptv_player/core/cast/cast_device_store.dart';
import 'package:iptv_player/core/cast/cast_discovery.dart';
import 'package:iptv_player/core/logging/app_log.dart';
import 'package:iptv_player/data/cast/cast_browsers.dart';
import 'package:iptv_player/data/cast/cast_txt.dart';

/// [CastDiscovery] from several browsers side by side, merged by device
/// id (Phase 7 decision 6), plus the devices the user added by address,
/// each asked again every [manualInterval].
///
/// Everything runs while [devices] has a listener, and stops with the
/// last one. A kept device found at a new address, or under a new name,
/// is refreshed in the store.
final class MergedCastDiscovery implements CastDiscovery {
  new({
    required this.browsers,
    required this.store,
    required this.addressCheck,
    this.log,
    this.manualInterval = const Duration(seconds: 20),
  });

  final List<CastBrowser> browsers;
  final CastDeviceStore store;
  final CastAddressCheck addressCheck;
  final AppLog? log;
  final Duration manualInterval;

  static const _tag = 'cast.discovery';

  final _listeners = <MultiStreamController<List<CastDevice>>>{};
  final _subscriptions = <StreamSubscription<Object?>>[];
  final _seen = <String, List<CastDevice>>{};
  final _answers = <String, CastDevice?>{};
  var _kept = <KnownCastDevice>[];
  List<CastDevice>? _current;
  Timer? _manualTimer;
  var _checking = false;
  final _sighted = <String>{};
  final _clock = Stopwatch();

  @override
  Stream<List<CastDevice>> get devices =>
      Stream<List<CastDevice>>.multi((controller) {
        _listeners.add(controller);
        if (_current case final current?) controller.add(current);
        if (_listeners.length == 1) _start();
        controller.onCancel = () {
          _listeners.remove(controller);
          if (_listeners.isEmpty) _stop();
        };
      });

  void _start() {
    log?.info(_tag, 'looking for devices');
    _clock
      ..reset()
      ..start();
    for (final browser in browsers) {
      _subscriptions.add(
        browser.watch().listen(
          (found) {
            _logFirstSights(browser.name, found);
            _seen[browser.name] = found;
            _publish();
          },
          onError: (Object error) =>
              log?.warning(_tag, '${browser.name}: $error'),
        ),
      );
    }
    _subscriptions.add(
      store.watchAll().listen((kept) {
        _kept = kept;
        _publish();
        unawaited(_checkManual());
      }, onError: (Object error) => log?.warning(_tag, 'store: $error')),
    );
    _manualTimer = Timer.periodic(
      manualInterval,
      (_) => unawaited(_checkManual()),
    );
  }

  void _stop() {
    log?.info(_tag, 'stopped looking');
    for (final subscription in _subscriptions) {
      unawaited(subscription.cancel());
    }
    _subscriptions.clear();
    _manualTimer?.cancel();
    _manualTimer = null;
    _seen.clear();
    _answers.clear();
    _sighted.clear();
    _current = null;
  }

  /// How long each browser took to see each device, for the logs (and
  /// the step 1 measurement).
  void _logFirstSights(String browser, List<CastDevice> found) {
    for (final device in found) {
      if (_sighted.add('$browser/${device.id}')) {
        log?.info(
          _tag,
          '$browser saw "${device.name}" (${device.model ?? 'no model'}) '
          'at ${device.host}:${device.port} after '
          '${_clock.elapsedMilliseconds} ms',
        );
      }
    }
  }

  /// Asks each device added by address that no browser sees.
  Future<void> _checkManual() async {
    if (_checking || _listeners.isEmpty) return;
    _checking = true;
    try {
      final found = _found();
      for (final kept in [..._kept]) {
        if (!kept.manual || found.containsKey(kept.id)) continue;
        final answer = await addressCheck.check(
          CastAddress(kept.host, kept.port),
        );
        if (_listeners.isEmpty) return;
        _answers[kept.id] = switch (answer) {
          CastDeviceAnswered(:final device) when device.id == kept.id => device,
          _ => null,
        };
        _publish();
      }
    } finally {
      _checking = false;
    }
  }

  /// What the browsers see, merged by id.
  Map<String, CastDevice> _found() {
    final merged = <String, CastDevice>{};
    for (final list in _seen.values) {
      for (final device in list) {
        final held = merged[device.id];
        merged[device.id] = held == null ? device : _merge(held, device);
      }
    }
    return merged;
  }

  void _publish() {
    if (_listeners.isEmpty) return;
    final byId = _found();
    for (final kept in _kept) {
      final found = byId[kept.id];
      if (found != null) {
        if (kept.manual) byId[kept.id] = found.copyWith(manual: true);
        if (found.host != kept.host ||
            found.port != kept.port ||
            found.name != kept.name ||
            found.model != kept.model) {
          unawaited(store.refresh(found));
        }
      } else if (kept.manual) {
        final answered = _answers[kept.id];
        byId[kept.id] =
            answered?.copyWith(manual: true) ??
            CastDevice(
              id: kept.id,
              name: kept.name,
              model: kept.model,
              host: kept.host,
              port: kept.port,
              manual: true,
              answering: !_answers.containsKey(kept.id),
            );
      }
    }
    final list = [...byId.values]
      ..sort((a, b) {
        final byName = a.name.toLowerCase().compareTo(b.name.toLowerCase());
        return byName != 0 ? byName : a.id.compareTo(b.id);
      });
    if (_same(_current, list)) return;
    _current = list;
    for (final listener in _listeners) {
      listener.add(list);
    }
  }

  static bool _same(List<CastDevice>? a, List<CastDevice> b) {
    if (a == null || a.length != b.length) return false;
    for (var i = 0; i < a.length; i++) {
      if (a[i] != b[i]) return false;
    }
    return true;
  }

  /// One device seen by two browsers: the IPv4 address whichever has it,
  /// and any field one of them lacks from the other.
  static CastDevice _merge(CastDevice a, CastDevice b) {
    final host = preferredHost([a.host, b.host]) ?? a.host;
    final base = host == b.host && host != a.host ? b : a;
    final other = identical(base, a) ? b : a;
    return base.copyWith(
      host: host,
      model: base.model ?? other.model,
      capabilities: base.capabilities ?? other.capabilities,
      status: base.status ?? other.status,
    );
  }
}
