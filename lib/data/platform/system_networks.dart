import 'dart:async';
import 'dart:ffi';
import 'dart:io';

import 'package:dbus/dbus.dart';
import 'package:ffi/ffi.dart';
import 'package:iptv_player/core/logging/app_log.dart';
import 'package:iptv_player/core/platform/network_status.dart';

const _tag = 'network';

/// The way this system says whether it is online (Phase 8 decision 11).
SystemNetwork platformSystemNetwork(AppLog log) {
  if (Platform.isLinux) return NetworkManagerNetwork(log: log);
  if (Platform.isWindows) return WindowsSystemNetwork(log: log);
  return const NoSystemNetwork();
}

/// NetworkManager's `State` (`NMState`): only "connected, global" is
/// online; asleep, disconnected, connecting, local or site only is not;
/// 0 is NetworkManager not knowing.
Reachability reachabilityOfNmState(int state) => switch (state) {
  70 => Reachability.online,
  0 => Reachability.unknown,
  _ => Reachability.offline,
};

/// Linux: NetworkManager on the system bus, its `State` and the
/// `StateChanged` signal (Ubuntu's desktop has it). Without it on the bus:
/// unknown, and the app's own requests decide.
final class NetworkManagerNetwork implements SystemNetwork {
  new({required this._log, DBusClient Function()? system})
    : _system = system ?? DBusClient.system;

  final AppLog _log;
  final DBusClient Function() _system;

  @override
  Stream<Reachability> watch() {
    DBusClient? client;
    StreamSubscription<DBusSignal>? signals;
    late final StreamController<Reachability> controller;
    controller = StreamController<Reachability>(
      onListen: () async {
        final bus = client = _system();
        final manager = DBusRemoteObject(
          bus,
          name: 'org.freedesktop.NetworkManager',
          path: DBusObjectPath('/org/freedesktop/NetworkManager'),
        );
        // Listening first: a change while the state is asked for isn't
        // lost, and the answer, older than it, doesn't overwrite it.
        var changed = false;
        signals =
            DBusRemoteObjectSignalStream(
              object: manager,
              interface: 'org.freedesktop.NetworkManager',
              name: 'StateChanged',
              signature: DBusSignature('u'),
            ).listen(
              (signal) {
                changed = true;
                controller.add(
                  reachabilityOfNmState(signal.values.single.asUint32()),
                );
              },
              onError: (Object error) =>
                  _log.info(_tag, 'NetworkManager signal: $error'),
            );
        try {
          final state = await manager.getProperty(
            'org.freedesktop.NetworkManager',
            'State',
            signature: DBusSignature('u'),
          );
          if (!changed) controller.add(reachabilityOfNmState(state.asUint32()));
        } on Object catch (error) {
          _log.info(_tag, 'No NetworkManager to say if online: $error');
          if (!changed) controller.add(Reachability.unknown);
        }
      },
      onCancel: () async {
        await signals?.cancel();
        await client?.close();
      },
    );
    return controller.stream;
  }
}

/// `NL_NETWORK_CONNECTIVITY_LEVEL_HINT`: internet access, constrained or
/// not, is online; none or local only is not; unknown and hidden say
/// nothing.
Reachability reachabilityOfHint(int? level) => switch (level) {
  3 || 4 => Reachability.online,
  1 || 2 => Reachability.offline,
  _ => Reachability.unknown,
};

/// Windows: `GetNetworkConnectivityHint` (Windows 10 2004 and later),
/// asked every [every] — a plain function, where the Network List
/// Manager the plan named is COM, which needs an apartment on the UI
/// thread. Untried here (the plan's risks).
final class WindowsSystemNetwork implements SystemNetwork {
  new({
    required this._log,
    int? Function()? hint,
    this.every = const Duration(seconds: 5),
  }) : _hint = hint ?? _connectivityHint;

  final AppLog _log;
  final int? Function() _hint;
  final Duration every;

  @override
  Stream<Reachability> watch() => Stream.multi((listener) {
    Reachability? last;
    void check() {
      int? level;
      try {
        level = _hint();
      } on Object catch (error) {
        _log.info(_tag, 'No connectivity hint: $error');
      }
      final now = reachabilityOfHint(level);
      if (now == last) return;
      last = now;
      listener.add(now);
    }

    check();
    final timer = Timer.periodic(every, (_) => check());
    listener.onCancel = timer.cancel;
  });
}

final class _ConnectivityHint extends Struct {
  @Int32()
  external int level;

  @Int32()
  external int cost;

  @Uint8()
  external int approachingDataLimit;

  @Uint8()
  external int overDataLimit;

  @Uint8()
  external int roaming;
}

typedef _GetHintNative = Uint32 Function(Pointer<_ConnectivityHint>);
typedef _GetHint = int Function(Pointer<_ConnectivityHint>);

/// Looked up once; null on a Windows without it.
final _GetHint? _getHint = () {
  if (!Platform.isWindows) return null;
  try {
    return DynamicLibrary.open('iphlpapi.dll')
        .lookupFunction<_GetHintNative, _GetHint>('GetNetworkConnectivityHint');
  } on Object {
    return null;
  }
}();

int? _connectivityHint() {
  final get = _getHint;
  if (get == null) return null;
  final hint = calloc<_ConnectivityHint>();
  try {
    return get(hint) == 0 ? hint.ref.level : null;
  } finally {
    calloc.free(hint);
  }
}
