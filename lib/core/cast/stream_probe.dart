import 'package:flutter/foundation.dart';
import 'package:iptv_player/core/cast/stream_facts.dart';

/// Reads a stream's facts with the bundled ffprobe (docs/04): the third
/// of Phase 7 decision 4's sources, after the laptop's player and what
/// this run remembers.
abstract interface class StreamProbe {
  /// Reads [input]: the relay's loopback proxy for a provider's stream
  /// (decision 3, so no credentials reach a command line), or a file.
  /// Never throws; gives up after its timeout (8 s).
  Future<StreamProbeResult> probe(String input, {String? userAgent});
}

@immutable
sealed class StreamProbeResult {
  const new();
}

final class StreamProbed extends StreamProbeResult {
  const new(this.facts);

  final StreamFacts facts;
}

final class StreamProbeFailed extends StreamProbeResult {
  const new(this.reason, [this.detail]);

  final StreamProbeFailure reason;

  /// ffprobe's own words, redacted, for the log and Details.
  final String? detail;
}

enum StreamProbeFailure {
  /// Nothing readable within the timeout.
  timedOut,

  /// ffprobe couldn't open or read it ([StreamProbeFailed.detail] has
  /// its words).
  unreadable,

  /// It opened, and has neither a picture nor a sound.
  noStreams,

  /// ffprobe itself couldn't be started.
  couldNotStart,
}
