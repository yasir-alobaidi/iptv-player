import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:iptv_player/features/playback/domain/playback_coordinator.dart';

/// On a TV, what plays stops when the app leaves the screen and plays
/// again when it comes back (docs/07 "Lifecycle"). Seen on the Bedroom
/// TV: after the remote's Home, Bijou went on reading the stream at
/// 2 MB/s behind the launcher, holding a one-connection source.
///
/// Hidden or paused is away (Home, another app, the device asleep);
/// inactive alone is a system dialog over the app, which still shows it.
final class TvAwayObserver with WidgetsBindingObserver {
  new(this._coordinator);

  final PlaybackCoordinator _coordinator;
  bool _away = false;

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    switch (state) {
      case AppLifecycleState.hidden ||
          AppLifecycleState.paused ||
          AppLifecycleState.detached:
        if (_away) return;
        _away = true;
        unawaited(_coordinator.stopWhileAway());
      case AppLifecycleState.resumed:
        if (!_away) return;
        _away = false;
        unawaited(_coordinator.resumeAfterAway());
      case AppLifecycleState.inactive:
        break;
    }
  }
}
