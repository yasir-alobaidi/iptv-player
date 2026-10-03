import 'package:iptv_player/core/cast/cast_encoders.dart';
import 'package:iptv_player/core/cast/cast_plan.dart';
import 'package:iptv_player/core/cast/stream_facts.dart';
import 'package:iptv_player/core/result.dart';
import 'package:meta/meta.dart';

/// The relay (docs/04): serves a cast the TV can't fetch from the provider
/// itself, from this computer. It runs in its own isolate (Phase 7
/// decision 5) and reads the provider through a loopback proxy (decision
/// 3), so no credentials reach FFmpeg and every connection is counted.
abstract interface class CastRelay {
  /// Starts relaying [request]. Never throws.
  Future<CastRelayStart> start(CastRelayRequest request);

  /// What ffprobe reads for [source]: the proxy's loopback URL (decision
  /// 3). Null when the relay can't run. Close it once the probe is done:
  /// its provider connection stays open until then.
  Future<CastRelayInput?> openInput(CastUpstreamSource source);

  /// Serves the picture at [path] (a channel's logo or a poster, from the
  /// app's own artwork cache) to a TV that reaches this computer at
  /// [localAddress], for LOAD's metadata. Null when it can't: not a JPEG,
  /// PNG or WebP, or nothing can listen there.
  Future<CastServedFile?> servePicture(
    String path, {
    required String localAddress,
  });

  /// The provider connections the proxy holds, per source, as they open
  /// and close (one-connection sources, Phase 8's downloads).
  Stream<CastRelayConnections> get connections;

  /// Stops every session and FFmpeg: the app quits.
  Future<void> close();
}

/// Where a relayed stream comes from: a source's channel, movie or
/// episode, its URL built afresh by [resolve] for every connection the
/// proxy makes (an expiring redirect is followed fresh, ADR-009).
@immutable
final class CastUpstreamSource {
  const new({
    required this.sourceId,
    required this.live,
    required this.resolve,
  });

  final String sourceId;

  /// A live channel: reconnected whenever it ends. A file is read with
  /// Range.
  final bool live;
  final Future<Result<CastUpstream>> Function() resolve;
}

/// One connection's worth of a provider's stream. It carries the
/// credentials: never logged.
@immutable
final class CastUpstream {
  const new({
    required this.url,
    required this.maxConnections,
    this.userAgent,
    this.hls = false,
  });

  final String url;
  final String? userAgent;

  /// The provider's own HLS.
  final bool hls;

  /// Streams the source allows at once.
  final int maxConnections;

  @override
  String toString() =>
      'CastUpstream(hls: $hls, maxConnections: $maxConnections)';
}

/// A cast for the relay: [plan] (a relay delivery) of a stream whose
/// facts are [facts], to a TV that reaches this computer at
/// [localAddress] (the Cast connection's own local address).
@immutable
final class CastRelayRequest {
  const new({
    required this.plan,
    required this.facts,
    required this.source,
    required this.localAddress,
    this.encoder,
    this.startAt,
  });

  final CastPlan plan;
  final StreamFacts facts;
  final CastUpstreamSource source;
  final String localAddress;

  /// The encoder for a plan that re-encodes the picture (step 4's
  /// `CastEncoders.best`, or the next after a failure).
  final CastEncoder? encoder;

  /// Where a file starts (a resume, a seek: Phase 7 decision 1).
  final Duration? startAt;
}

@immutable
sealed class CastRelayStart {
  const new();
}

final class CastRelayStarted extends CastRelayStart {
  const new(this.session);

  final CastRelaySession session;
}

final class CastRelayNotStarted extends CastRelayStart {
  const new(this.failure);

  final CastRelayFailure failure;
}

/// One cast through the relay.
abstract interface class CastRelaySession {
  String get id;

  /// What LOAD names: this computer on the TV's network. It changes with
  /// [renew].
  String get url;

  /// LOAD's `contentType`.
  String get contentType;

  /// Completes when a LOAD can go: once the playlist lists 2 segments
  /// (HLS, docs/04), at once for a continuous stream. With the failure,
  /// if the session fails first.
  Future<CastRelayFailure?> get ready;

  /// What happens to the session, from its start: one listener (the
  /// coordinator), which gets what came before it listened too.
  Stream<CastRelayEvent> get events;

  /// The same session under a new URL, for a new LOAD: a continuous
  /// stream that ended (ADR-004), a file from [startAt] (a seek, decision
  /// 1), or [plan] after a change. Counted against the restart budget (5
  /// within 2 minutes). Null when renewed, else why not; the session is
  /// over then.
  Future<CastRelayFailure?> renew({Duration? startAt, CastPlan? plan});

  /// Ends it: its FFmpeg, its provider connection and its files.
  Future<void> stop();
}

@immutable
sealed class CastRelayEvent {
  const new();
}

/// The TV asked for the stream: it can reach this computer (step 6 says
/// otherwise after 10 s without it).
final class CastRelayFetched extends CastRelayEvent {
  const new();
}

/// FFmpeg opened the stream, and found [facts] (Phase 7 decision 4: the
/// next cast of it starts from them; a plan made from other facts is made
/// again).
final class CastRelayOpened extends CastRelayEvent {
  const new(this.facts);

  final StreamFacts facts;
}

/// A stream appeared mid-way: the channel changed codec, and FFmpeg goes
/// on copying the one it opened. The plan is made again.
final class CastRelayStreamsChanged extends CastRelayEvent {
  const new();
}

/// HLS: FFmpeg started again behind the same URL (a stall, an end); the
/// TV keeps polling.
final class CastRelayRestarted extends CastRelayEvent {
  const new(this.count);

  final int count;
}

/// Continuous: the TV's stream ended. The TV plays out what it has, then
/// reports IDLE/FINISHED; a new LOAD needs [CastRelaySession.renew].
final class CastRelayEnded extends CastRelayEvent {
  const new({required this.tvLeft});

  /// The TV closed the connection, rather than the stream ending.
  final bool tvLeft;
}

/// The session is over.
final class CastRelayFailed extends CastRelayEvent {
  const new(this.failure);

  final CastRelayFailure failure;
}

/// Why a relay session failed, with what Details shows.
@immutable
final class CastRelayFailure {
  const new(this.kind, {this.status, this.body = '', this.detail});

  final CastRelayFailureKind kind;

  /// The provider's HTTP status, for a refusal: with [body], what docs/03
  /// classifies (`classifyStreamFailure`).
  final int? status;

  /// The first bytes of the provider's answer, redacted.
  final String body;

  /// FFmpeg's last warnings, redacted.
  final String? detail;

  @override
  String toString() =>
      'CastRelayFailure(${kind.name}'
      '${status == null ? '' : ', HTTP $status'})';
}

enum CastRelayFailureKind {
  /// The provider answered with an error ([CastRelayFailure.status]).
  providerRefused,

  /// The provider couldn't be reached.
  providerUnreachable,

  /// The stream's URL couldn't be built (the source is gone, its keyring
  /// is locked).
  unresolved,

  /// The relay's own other connections (a probe) hold every one the
  /// source allows.
  connectionsInUse,

  /// FFmpeg failed before any output.
  ffmpegFailed,

  /// The re-encode failed before any output: try the next encoder
  /// (`CastEncoders.after`, after `detectAgain`).
  encoderFailed,

  /// 5 restarts within 2 minutes (docs/04).
  restartBudget,

  /// FFmpeg couldn't start, there is none, or the relay couldn't listen
  /// on the TV's network.
  couldNotStart,
}

/// A file the relay serves to the TV; [close] stops serving it.
abstract interface class CastServedFile {
  String get url;

  Future<void> close();
}

/// The proxy's URL for a probe; [close] lets the provider's connection go.
abstract interface class CastRelayInput {
  String get url;

  /// The provider's last refusal of it, for a probe that failed.
  CastRelayFailure? get refusal;

  Future<void> close();
}

/// The provider connections the proxy holds for [sourceId] now.
@immutable
final class CastRelayConnections {
  const new(this.sourceId, this.open);

  final String sourceId;
  final int open;

  @override
  bool operator ==(Object other) =>
      other is CastRelayConnections &&
      other.sourceId == sourceId &&
      other.open == open;

  @override
  int get hashCode => Object.hash(sourceId, open);

  @override
  String toString() => 'CastRelayConnections($sourceId, $open)';
}

/// A build without FFmpeg: nothing is relayed (`castReadinessProvider`
/// already says why).
final class UnavailableCastRelay implements CastRelay {
  const new();

  @override
  Future<CastRelayStart> start(CastRelayRequest request) async =>
      const CastRelayNotStarted(
        CastRelayFailure(
          CastRelayFailureKind.couldNotStart,
          detail: 'This build has no FFmpeg.',
        ),
      );

  @override
  Future<CastRelayInput?> openInput(CastUpstreamSource source) async => null;

  @override
  Future<CastServedFile?> servePicture(
    String path, {
    required String localAddress,
  }) async => null;

  @override
  Stream<CastRelayConnections> get connections => const Stream.empty();

  @override
  Future<void> close() async {}
}
