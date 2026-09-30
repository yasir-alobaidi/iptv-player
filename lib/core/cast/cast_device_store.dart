import 'package:iptv_player/core/cast/cast_device.dart';
import 'package:iptv_player/core/result.dart';

/// The devices the app keeps (`cast_devices`, schema v8): the ones added
/// by address, cast to, or set up in Settings → Casting. A device only
/// seen on the network is not stored.
abstract interface class CastDeviceStore {
  /// Every kept device, by name; again after every change.
  Stream<List<KnownCastDevice>> watchAll();

  Future<Result<KnownCastDevice?>> byId(String id);

  /// Keeps [device] as added by address, or marks a kept one so; its
  /// name, model and address are refreshed either way.
  Future<Result<void>> addManual(CastDevice device);

  /// Keeps [device] as cast to at [at], or refreshes a kept one's name,
  /// model, address and last use. A device added by address stays so.
  Future<Result<void>> markUsed(CastDevice device, DateTime at);

  /// Refreshes a kept device's name, model and address from the network;
  /// does nothing for a device not kept.
  Future<Result<void>> refresh(CastDevice device);

  Future<Result<void>> setHevcSupport(String id, HevcSupport value);

  Future<Result<void>> setLearned(String id, CastLearned learned);

  /// Removes a kept device, with its settings and what was learned.
  Future<Result<void>> forget(String id);
}
