import 'package:iptv_player/core/cast/cast_device.dart';

/// Pairs this computer with a TV that shows a code (AirPlay, ADR-067).
/// [start] makes the TV show its code; the attempt takes the code the user
/// read off the screen. The pairing is kept (the system keychain) and used
/// for every cast after.
abstract interface class CastPairing {
  /// Whether [device] is paired with this computer already.
  Future<bool> isPaired(CastDevice device);

  /// Asks [device] to show its code.
  Future<CastPairingStart> start(CastDevice device);

  /// Forgets [device]'s pairing (Settings → Casting).
  Future<void> forget(CastDevice device);
}

/// How [CastPairing.start] went.
sealed class CastPairingStart {
  const new();
}

/// The TV shows its code: send it with [CastPairingAttempt.finish].
final class CastPairingShown extends CastPairingStart {
  const new(this.attempt);

  final CastPairingAttempt attempt;
}

/// The TV couldn't be reached, or refused to pair now.
final class CastPairingUnavailable extends CastPairingStart {
  const new(this.reason, [this.detail]);

  final CastPairingProblem reason;

  /// For the log; never shown in front.
  final String? detail;
}

/// One pairing in progress: the code on the TV's screen is waited for.
abstract interface class CastPairingAttempt {
  /// Sends [code]; kept on success.
  Future<CastPairingResult> finish(String code);

  /// Gives up; the TV takes its code away.
  Future<void> cancel();
}

/// How a pairing ended.
enum CastPairingResult {
  paired,

  /// The code wasn't the one on the screen.
  wrongCode,

  /// The TV asked for a pause after too many tries.
  tooManyTries,

  /// The connection broke, or the TV gave another error.
  failed,
}

/// Why a pairing couldn't start.
enum CastPairingProblem { unreachable, busy, refused }
