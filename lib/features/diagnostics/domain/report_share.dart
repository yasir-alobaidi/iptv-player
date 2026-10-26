import 'package:iptv_player/core/result.dart';

/// A report offered to a phone on the same network (ADR-059): a TV out of
/// adb's reach hands its diagnostics over this way.
abstract interface class ReportSharer {
  /// Serves [text] as [fileName] at this device's network address until
  /// the offer is closed. Err(NetworkFailure) when the device has no
  /// address a phone could reach.
  Future<Result<ReportOffer>> offer(String text, {required String fileName});
}

/// One report being served.
abstract interface class ReportOffer {
  /// `http://192.168.1.50:41234/k3v9q2mx7p/`: what the QR code holds and
  /// the screen shows.
  Uri get address;

  /// An event each time a phone downloads the file.
  Stream<void> get fetched;

  /// Stops serving; idempotent.
  Future<void> close();
}
