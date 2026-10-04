import 'dart:async';

import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'network_status.g.dart';

/// Whether the computer reaches the internet, as the system says.
enum Reachability { online, offline, unknown }

/// The system's own word on the network (Phase 8 decision 11):
/// NetworkManager on Linux, Windows' connectivity hint.
abstract interface class SystemNetwork {
  /// The state now, then each change. Never errors: unknown when the
  /// system can't say.
  Stream<Reachability> watch();
}

/// No system to ask: tests, and systems without a way.
final class NoSystemNetwork implements SystemNetwork {
  const new();

  @override
  Stream<Reachability> watch() => Stream.value(Reachability.unknown);
}

/// "You're offline" (docs/05's banner on Home), from the system, with the
/// app's own requests as the fallback (Phase 8 decision 11):
/// - the system says online: online, whatever a source does (a provider
///   that doesn't answer is down, not the internet);
/// - the system says offline: offline, until a source answers — a
///   provider on the home network still works without the internet;
/// - the system can't say: offline after a request that got no answer at
///   all, until the next one that does.
///
/// A new word from the system forgets what the sources said before it.
/// Going offline is told once it has lasted [settle] (a Wi-Fi roam
/// passes through "connecting"); coming back at once.
final class NetworkStatus {
  new(SystemNetwork system, {this.settle = const Duration(seconds: 3)}) {
    _watching = system.watch().listen((state) {
      if (state == _system) return;
      _system = state;
      _sourcesAnswer = null;
      _update();
    });
  }

  final Duration settle;

  late final StreamSubscription<Reachability> _watching;
  final _changes = StreamController<bool>.broadcast();
  Reachability _system = Reachability.unknown;

  /// What the last request to a source said: true answered, false no
  /// answer at all, null nothing since the system last spoke.
  bool? _sourcesAnswer;
  bool _offline = false;
  Timer? _settling;

  bool get offline => _offline;

  /// [offline] now, then each change.
  Stream<bool> watch() async* {
    yield _offline;
    yield* _changes.stream;
  }

  /// A source answered (a stream's picture came, a request got a reply).
  void sourceAnswered() {
    if (_sourcesAnswer == true) return;
    _sourcesAnswer = true;
    _update();
  }

  /// A request to a source got no answer at all: no connection, a
  /// timeout. An HTTP error is an answer.
  void sourceUnanswered() {
    if (_sourcesAnswer == false) return;
    _sourcesAnswer = false;
    _update();
  }

  void _update() {
    final offline = switch (_system) {
      Reachability.online => false,
      Reachability.offline => _sourcesAnswer != true,
      Reachability.unknown => _sourcesAnswer == false,
    };
    if (!offline) {
      _settling?.cancel();
      _settling = null;
      _set(false);
      return;
    }
    if (_offline || _settling != null) return;
    _settling = Timer(settle, () {
      _settling = null;
      _set(true);
    });
  }

  void _set(bool offline) {
    if (offline == _offline) return;
    _offline = offline;
    if (!_changes.isClosed) _changes.add(offline);
  }

  /// Not awaiting the subscription's cancel: its future belongs to the
  /// root zone, which a test's fake time never reaches.
  Future<void> dispose() async {
    _settling?.cancel();
    unawaited(_watching.cancel());
    await _changes.close();
  }
}

/// The system's word on the network. Nothing here; `bootstrap()` gives it
/// the system's (`platformSystemNetwork`).
@Riverpod(keepAlive: true)
SystemNetwork systemNetwork(Ref ref) => const NoSystemNetwork();

/// Whether the app is offline: the system's word, with the sources'
/// answers as the fallback; playback reports those
/// (`playbackReachabilityProvider`).
@Riverpod(keepAlive: true)
NetworkStatus networkStatus(Ref ref) {
  final status = NetworkStatus(ref.watch(systemNetworkProvider));
  ref.onDispose(status.dispose);
  return status;
}
