import 'package:iptv_player/core/result.dart';

/// Settings → About & diagnostics: the report, and saving it.
abstract interface class DiagnosticsService {
  /// The report's text, ready to paste: redacted, with no provider's
  /// name, server or username in it (Phase 9 decision 9).
  Future<Result<String>> report();

  /// [report] with each run's own log after it, where a TV keeps them
  /// (ADR-059): the file a phone takes from the TV. The same as [report]
  /// on a computer.
  Future<Result<String>> shareReport();

  /// Writes [text] to [path], replacing a file already there.
  Future<Result<void>> save(String path, String text);
}
