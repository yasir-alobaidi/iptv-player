import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/misc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:iptv_player/core/cast/cast_device.dart';
import 'package:iptv_player/core/cast/cast_discovery.dart';
import 'package:iptv_player/core/cast/cast_readiness.dart';
import 'package:iptv_player/design/components.dart';
import 'package:iptv_player/features/casting/data/casting_providers.dart';
import 'package:iptv_player/features/casting/domain/cast_coordinator.dart';
import 'package:iptv_player/features/casting/presentation/cast_shell_slots.dart';
import 'package:iptv_player/features/live_tv/data/db_channel_repository.dart';
import 'package:iptv_player/features/live_tv/domain/channels.dart';

import '../../live_tv/live_tv_fakes.dart';
import 'cast_fakes.dart';

/// The casting screens on fakes: Live TV's (a real in-memory database
/// with its channels, the playback rig, the guide), a real cast
/// coordinator on them (`CastRig`), the devices the picker lists, and the
/// shell's casting slots.
final class CastUi {
  new({CastTimings timings = const CastTimings()}) : live = LiveTvFakes() {
    cast = CastRig(playback: live.rig, timings: timings);
  }

  final LiveTvFakes live;
  late final CastRig cast;
  final check = FakeAddressCheck();
  CastReadiness ready = CastReadiness.ready;
  bool online = true;

  List<CastDevice> _devices = const [];
  final _deviceChanges = StreamController<List<CastDevice>>.broadcast();

  List<CastDevice> get devices => _devices;

  /// What discovery finds, from now on.
  set devices(List<CastDevice> devices) {
    _devices = devices;
    _deviceChanges.add(devices);
  }

  Stream<List<CastDevice>> _deviceStream() async* {
    yield _devices;
    yield* _deviceChanges.stream;
  }

  List<Override> get overrides => [
    ...live.overrides,
    castCoordinatorProvider.overrideWithValue(cast.coordinator),
    castDeviceStoreProvider.overrideWithValue(cast.devices),
    castDevicesProvider.overrideWith((ref) => _deviceStream()),
    castReadinessProvider.overrideWith((ref) => ready),
    castNetworkAvailableProvider.overrideWith((ref) async => online),
    castAddressCheckProvider.overrideWithValue(check),
    castNoticeToastsProvider.overrideWith((ref) {}),
    ...castShellOverrides,
  ];

  /// Live TV's channel [key] ('201', '202', '203'), as the screens hold
  /// it.
  Future<ChannelItem> channel(String key) async => (await DbChannelRepository(
    live.db,
  ).byRemoteKey('src-1', key)).valueOrNull!;

  /// Nothing is awaited: after a widget test's body nothing pumps its
  /// fake time, so a close waiting on it would hang. Tests end their own
  /// sessions while they still pump.
  void dispose() => unawaited(_deviceChanges.close());
}

/// The address check, scripted: who answers at which host.
final class FakeAddressCheck implements CastAddressCheck {
  final answers = <String, CastAddressAnswer>{};
  final asked = <CastAddress>[];

  @override
  Future<CastAddressAnswer> check(CastAddress address) async {
    asked.add(address);
    return answers[address.host] ?? const CastNoAnswer();
  }
}

/// Lets drift's real futures and the fakes' run, a few frames' worth.
Future<void> settleCast(WidgetTester tester, {int rounds = 5}) async {
  for (var i = 0; i < rounds; i++) {
    await tester.runAsync(() => Future<void>.delayed(Duration.zero));
    await tester.pump(const Duration(milliseconds: 50));
  }
}

/// The label of the control with the keyboard focus.
String? focusedLabelOf(WidgetTester tester) {
  final context = FocusManager.instance.primaryFocus?.context;
  if (context == null) return null;
  final surface = context.widget is FocusableSurface
      ? context.widget as FocusableSurface
      : context.findAncestorWidgetOfExactType<FocusableSurface>();
  return surface?.semanticLabel;
}
