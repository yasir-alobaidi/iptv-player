import 'package:freezed_annotation/freezed_annotation.dart';

part 'cast_device.freezed.dart';

/// The port a Cast device listens on (Cast v2 over TLS).
const castPort = 8009;

/// A Cast device with a screen that can be cast to now: found on the
/// network, or added by the user by its address.
@freezed
abstract class CastDevice with _$CastDevice {
  const factory({
    /// The device's own id (TXT `id`, 32 hex digits), the same whichever
    /// way it was found; the key everything else is stored under.
    required String id,

    /// What the user named it (TXT `fn`), such as "Living Room TV".
    required String name,

    /// The address to connect to, IPv4 whenever the device has one.
    required String host,
    @Default(castPort) int port,

    /// TXT `md`, such as "Chromecast". The capability profile starts
    /// from it (docs/04).
    String? model,

    /// TXT `ca`, the capability bits; null when the device sent none, or
    /// nothing that reads as a number.
    int? capabilities,

    /// What the device says it is running (TXT `rs`), such as "YouTube";
    /// null when it runs nothing.
    String? status,

    /// Added by the user by its address; listed even when discovery
    /// doesn't see it (another subnet, multicast blocked).
    @Default(false) bool manual,

    /// False for a device added by address that didn't answer the last
    /// check. Found devices always answer: they drop out when they stop.
    @Default(true) bool answering,
  }) = _CastDevice;
}

/// Whether a device plays HEVC: learned, or the user's choice in
/// Settings → Casting (docs/04's profiles).
enum HevcSupport { auto, yes, no }

/// What the app learned from a device refusing a stream (docs/04
/// "Learning"). Kept per device; Settings → Casting can reset it.
@freezed
abstract class CastLearned with _$CastLearned {
  const factory({
    /// The tallest picture the device took; null until one was refused.
    int? maxHeight,

    /// Video and audio codecs it refused (ffprobe's names, such as
    /// `hevc`), transcoded from then on.
    @Default(<String>{}) Set<String> refusedCodecs,

    /// Sources whose streams it could not play directly (docs/04 rule 1);
    /// they go through the relay from then on.
    @Default(<String>{}) Set<String> directRefusedSources,
  }) = _CastLearned;
}

/// A device the app keeps: added by address, cast to, or set up in
/// Settings → Casting (`cast_devices`, schema v8).
@freezed
abstract class KnownCastDevice with _$KnownCastDevice {
  const factory({
    required String id,
    required String name,

    /// The address it had when last seen or used.
    required String host,
    required int port,
    required bool manual,
    required HevcSupport hevc,
    required CastLearned learned,
    String? model,
    DateTime? lastUsedAt,
  }) = _KnownCastDevice;
}
