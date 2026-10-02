import 'dart:async';
import 'dart:io';
import 'dart:isolate';

import 'package:iptv_player/core/cast/cast_plan.dart';
import 'package:iptv_player/core/cast/cast_relay.dart';
import 'package:iptv_player/core/cast/stream_facts.dart';
import 'package:iptv_player/core/logging/app_log.dart';
import 'package:iptv_player/core/logging/redact.dart';
import 'package:iptv_player/core/result.dart';
import 'package:iptv_player/data/cast/ffmpeg_binaries.dart';
import 'package:iptv_player/data/cast/relay/ffmpeg_log.dart';
import 'package:iptv_player/data/cast/relay/relay_args.dart';
import 'package:iptv_player/data/cast/relay/relay_isolate.dart';
import 'package:iptv_player/data/cast/relay/relay_job.dart';
import 'package:iptv_player/data/cast/relay/relay_proxy.dart';
import 'package:iptv_player/data/cast/relay/relay_runtime.dart';

const _tag = 'relay';

/// [CastRelay] in its own long-lived isolate (Phase 7 decision 5): started
/// with the first cast or probe, kept until the app quits. The app's side
/// builds each session's FFmpeg job from its plan, answers the proxy's
/// requests for a stream's URL (built afresh each time, decision 3), and
/// writes the relay's log lines into the app's log.
final class IsolateCastRelay implements CastRelay {
  new({
    required this._binaries,
    required this._processFolder,
    required this._relayFolder,
    required this._log,
    this.timings = const RelayTimings(),
    this.proxyTimings = const RelayProxyTimings(),
  });

  final FfmpegBinaries _binaries;
  final Directory _processFolder;
  final Directory _relayFolder;
  final AppLog _log;
  final RelayTimings timings;
  final RelayProxyTimings proxyTimings;

  Future<SendPort>? _commands;
  Isolate? _isolate;
  final _ports = <ReceivePort>[];
  final _replies = <int, Completer<Object?>>{};
  final _sources = <String, CastUpstreamSource>{};
  final _sessions = <String, _Session>{};
  final _inputs = <String, _Input>{};
  final _connections = StreamController<CastRelayConnections>.broadcast();
  int _replyIds = 0;
  int _count = 0;
  bool _closed = false;

  @override
  Stream<CastRelayConnections> get connections => _connections.stream;

  @override
  Future<CastRelayStart> start(CastRelayRequest request) async {
    final plan = request.plan;
    if (_closed) return _notStarted('the app is quitting');
    if (plan.delivery.direct) return _notStarted('a direct plan');
    if (plan.video is CastVideoTranscode && request.encoder == null) {
      return const CastRelayNotStarted(
        CastRelayFailure(
          CastRelayFailureKind.encoderFailed,
          detail: 'Nothing on this computer can re-encode the picture.',
        ),
      );
    }
    final id = 'cast-${++_count}';
    final session = _Session(this, id, request);
    _sources[session.inputId] = request.source;
    _sessions[id] = session;
    final Object? answer;
    try {
      final job = _job(request, plan: plan, startAt: request.startAt);
      answer = await _call(
        (reply) => RelayStartCommand(
          replyId: reply,
          sessionId: id,
          inputId: session.inputId,
          sourceId: request.source.sourceId,
          job: job,
          localAddress: request.localAddress,
        ),
      );
    } on Object catch (error) {
      session._forget();
      return _notStarted(redact('$error'));
    }
    if (answer case RelayStartAnswer(:final url?)) {
      session.url = url;
      _log.info(_tag, '$id: relaying ${plan.delivery.name} to the TV');
      return CastRelayStarted(session);
    }
    session._forget();
    return CastRelayNotStarted(
      answer is RelayStartAnswer && answer.failure != null
          ? _failure(answer.failure!)
          : const CastRelayFailure(CastRelayFailureKind.couldNotStart),
    );
  }

  @override
  Future<CastRelayInput?> openInput(CastUpstreamSource source) async {
    if (_closed) return null;
    final inputId = 'probe-${++_count}';
    _sources[inputId] = source;
    Object? url;
    try {
      url = await _call(
        (reply) => RelayOpenInputCommand(
          replyId: reply,
          inputId: inputId,
          sourceId: source.sourceId,
          live: source.live,
        ),
      );
    } on Object catch (error) {
      _log.warning(_tag, 'The relay could not open an input', error: error);
    }
    if (url is! String) {
      _sources.remove(inputId);
      return null;
    }
    return _inputs[inputId] = _Input(this, inputId, url);
  }

  @override
  Future<void> close() async {
    if (_closed) return;
    _closed = true;
    if (_commands != null) {
      try {
        await _call(
          RelayShutdownCommand.new,
          timeout: const Duration(seconds: 15),
        );
      } on Object catch (error) {
        _log.warning(_tag, 'The relay did not stop cleanly', error: error);
      }
    }
    _isolate?.kill(priority: Isolate.immediate);
    for (final port in _ports) {
      port.close();
    }
    for (final session in [..._sessions.values]) {
      session._end(
        const CastRelayFailure(
          CastRelayFailureKind.couldNotStart,
          detail: 'the app is quitting',
        ),
      );
    }
    await _connections.close();
  }

  RelayJob _job(
    CastRelayRequest request, {
    required CastPlan plan,
    Duration? startAt,
  }) => castRelayJob(
    plan: plan,
    facts: request.facts,
    binaries: _binaries,
    encoder: request.encoder,
    startAt: startAt,
  );

  Future<SendPort> _spawn() {
    final running = _commands;
    if (running != null) return running;
    final starting = _startIsolate();
    _commands = starting;
    // A start that failed is forgotten: the next cast tries again.
    unawaited(
      starting.then<void>(
        (_) {},
        onError: (Object error) {
          _log.error(_tag, 'The relay could not start', error: error);
          if (identical(_commands, starting)) _commands = null;
          _isolate?.kill(priority: Isolate.immediate);
          _isolate = null;
        },
      ),
    );
    return starting;
  }

  Future<SendPort> _startIsolate() async {
    final messages = ReceivePort('cast relay');
    final errors = ReceivePort('cast relay errors');
    final exits = ReceivePort('cast relay exit');
    _ports.addAll([messages, errors, exits]);
    final ready = Completer<SendPort>();
    messages.listen((message) {
      if (message case RelayIsolateReady(:final commands)) {
        if (!ready.isCompleted) ready.complete(commands);
        return;
      }
      _onMessage(message);
    });
    errors.listen((error) {
      // The isolate goes on: one session's bug isn't every session's.
      final pair = error is List && error.length == 2;
      final stack = pair ? error[1] : null;
      _log.error(
        _tag,
        'The relay hit an error',
        error: redact('${pair ? error[0] : error}'),
        stackTrace: stack == null ? null : StackTrace.fromString('$stack'),
      );
    });
    exits.listen((_) => _lost());
    _isolate = await Isolate.spawn(
      relayIsolateMain,
      RelayIsolateSetup(
        app: messages.sendPort,
        processFolder: _processFolder.path,
        relayFolder: _relayFolder.path,
        timings: timings,
        proxyTimings: proxyTimings,
      ),
      debugName: 'cast relay',
      errorsAreFatal: false,
      onError: errors.sendPort,
      onExit: exits.sendPort,
    );
    return await ready.future.timeout(const Duration(seconds: 10));
  }

  /// The isolate ended without being asked to: every session with it.
  void _lost() {
    if (_closed) return;
    _log.error(_tag, 'The relay stopped unexpectedly');
    _commands = null;
    _isolate = null;
    for (final reply in _replies.values) {
      if (!reply.isCompleted) reply.complete(null);
    }
    _replies.clear();
    for (final session in [..._sessions.values]) {
      session._end(
        const CastRelayFailure(
          CastRelayFailureKind.couldNotStart,
          detail: 'the relay stopped',
        ),
      );
    }
  }

  Future<Object?> _call(
    Object Function(int replyId) command, {
    Duration timeout = const Duration(seconds: 30),
  }) async {
    final port = await _spawn();
    final id = _replyIds++;
    final reply = Completer<Object?>();
    _replies[id] = reply;
    port.send(command(id));
    try {
      return await reply.future.timeout(timeout);
    } finally {
      _replies.removeWhere((k, _) => k == id);
    }
  }

  void _onMessage(Object? message) {
    switch (message) {
      case RelayReply(:final replyId, :final value):
        final reply = _replies[replyId];
        if (reply != null && !reply.isCompleted) reply.complete(value);
      case RelayResolveRequest(:final requestId, :final inputId):
        unawaited(_resolve(requestId, inputId));
      case RelayLogLines(:final level, :final lines):
        _log.forward(level, lines);
      case RelaySessionMessage(:final sessionId, :final event):
        _sessions[sessionId]?._on(event);
      case RelayProxyRefused(:final inputId, :final refusal):
        _inputs[inputId]?.refusal = _failure(_refusalFailure(refusal));
      case RelayProxyConnections(:final sourceId, :final open):
        if (!_connections.isClosed) {
          _connections.add(CastRelayConnections(sourceId, open));
        }
    }
  }

  /// The proxy wants [inputId]'s stream: its URL is built from the source
  /// now (decision 3), and sent to the relay's isolate only.
  Future<void> _resolve(int requestId, String inputId) async {
    final source = _sources[inputId];
    RelayResolved answer;
    if (source == null) {
      answer = const RelayResolved(failure: 'the cast has ended');
    } else {
      try {
        answer = switch (await source.resolve()) {
          Ok(:final value) => RelayResolved(
            upstream: RelayUpstream(
              url: value.url,
              userAgent: value.userAgent,
              hls: value.hls,
              maxConnections: value.maxConnections,
            ),
          ),
          Err(:final failure) => RelayResolved(failure: redact('$failure')),
        };
      } on Object catch (error) {
        answer = RelayResolved(failure: redact('$error'));
      }
    }
    final commands = await _commands;
    commands?.send(RelayResolveAnswer(requestId, answer));
  }

  static CastRelayNotStarted _notStarted(String why) => CastRelayNotStarted(
    CastRelayFailure(CastRelayFailureKind.couldNotStart, detail: why),
  );

  static CastRelayFailure _failure(RelayFailureInfo info) => CastRelayFailure(
    switch (info.kind) {
      RelayFailureKind.providerRefused => CastRelayFailureKind.providerRefused,
      RelayFailureKind.providerUnreachable =>
        CastRelayFailureKind.providerUnreachable,
      RelayFailureKind.unresolved => CastRelayFailureKind.unresolved,
      RelayFailureKind.connectionsInUse =>
        CastRelayFailureKind.connectionsInUse,
      RelayFailureKind.ffmpegFailed => CastRelayFailureKind.ffmpegFailed,
      RelayFailureKind.encoderFailed => CastRelayFailureKind.encoderFailed,
      RelayFailureKind.restartBudget => CastRelayFailureKind.restartBudget,
      RelayFailureKind.couldNotStart => CastRelayFailureKind.couldNotStart,
    },
    status: info.status,
    body: info.body,
    detail: info.detail,
  );

  static RelayFailureInfo _refusalFailure(RelayRefusal refusal) =>
      RelayFailureInfo(
        switch (refusal.kind) {
          RelayRefusalKind.refused => RelayFailureKind.providerRefused,
          RelayRefusalKind.unreachable => RelayFailureKind.providerUnreachable,
          RelayRefusalKind.unresolved => RelayFailureKind.unresolved,
          RelayRefusalKind.connectionsInUse =>
            RelayFailureKind.connectionsInUse,
        },
        status: refusal.status,
        body: refusal.body,
        detail: refusal.detail,
      );
}

final class _Session implements CastRelaySession {
  new(this._relay, this.id, this._request)
    : inputId = '$id/input',
      contentType = _request.plan.delivery.contentType;

  final IsolateCastRelay _relay;
  final CastRelayRequest _request;
  final String inputId;

  @override
  final String id;

  @override
  final String contentType;

  @override
  String url = '';

  /// Held until its one listener comes: FFmpeg says what it opened before
  /// the session is ready.
  final _events = StreamController<CastRelayEvent>();
  var _ready = Completer<CastRelayFailure?>();
  bool _over = false;

  bool get _continuous =>
      _request.plan.delivery == CastDelivery.relayContinuous;

  @override
  Future<CastRelayFailure?> get ready => _ready.future;

  @override
  Stream<CastRelayEvent> get events => _events.stream;

  @override
  Future<CastRelayFailure?> renew({Duration? startAt, CastPlan? plan}) async {
    if (_over) {
      return const CastRelayFailure(
        CastRelayFailureKind.couldNotStart,
        detail: 'the session has ended',
      );
    }
    final Object? answer;
    try {
      final job = startAt == null && plan == null
          ? null
          : _relay._job(
              _request,
              plan: plan ?? _request.plan,
              startAt: startAt,
            );
      answer = await _relay._call(
        (reply) => RelayRenewCommand(replyId: reply, sessionId: id, job: job),
      );
    } on Object catch (error) {
      return CastRelayFailure(
        CastRelayFailureKind.couldNotStart,
        detail: redact('$error'),
      );
    }
    if (answer case RelayStartAnswer(url: final next?)) {
      url = next;
      if (!_ready.isCompleted) _ready.complete(null);
      _ready = Completer<CastRelayFailure?>();
      if (_continuous) _ready.complete(null);
      return null;
    }
    final failure = answer is RelayStartAnswer && answer.failure != null
        ? IsolateCastRelay._failure(answer.failure!)
        : const CastRelayFailure(CastRelayFailureKind.couldNotStart);
    _end(failure);
    return failure;
  }

  @override
  Future<void> stop() async {
    if (_relay._sessions[id] == null) return;
    try {
      await _relay._call(
        (reply) => RelayStopCommand(replyId: reply, sessionId: id),
      );
    } on Object catch (error) {
      _relay._log.warning(_tag, '$id: could not stop', error: error);
    }
    _forget();
  }

  void _on(RelaySessionEvent event) {
    if (_events.isClosed) return;
    switch (event) {
      case RelayReady():
        if (!_ready.isCompleted) _ready.complete(null);
      case RelayFetched():
        _events.add(const CastRelayFetched());
      case RelayOpened(:final report):
        _events.add(CastRelayOpened(streamFactsFromFfmpeg(report)));
      case RelayStreamsChanged():
        _events.add(const CastRelayStreamsChanged());
      case RelayRestarted(:final count):
        _events.add(CastRelayRestarted(count));
      case RelayEnded(:final reason):
        _events.add(CastRelayEnded(tvLeft: reason == RelayEndReason.tvLeft));
      case RelayFailed(:final failure):
        _end(IsolateCastRelay._failure(failure));
    }
  }

  /// The session failed: whoever waits is told.
  void _end(CastRelayFailure failure) {
    if (_over) return;
    _over = true;
    if (!_ready.isCompleted) _ready.complete(failure);
    if (!_events.isClosed) _events.add(CastRelayFailed(failure));
  }

  void _forget() {
    _over = true;
    _relay._sessions.remove(id);
    _relay._sources.remove(inputId);
    if (!_ready.isCompleted) {
      _ready.complete(
        const CastRelayFailure(
          CastRelayFailureKind.couldNotStart,
          detail: 'stopped',
        ),
      );
    }
    unawaited(_events.close());
  }
}

final class _Input implements CastRelayInput {
  new(this._relay, this._id, this.url);

  final IsolateCastRelay _relay;
  final String _id;

  @override
  final String url;

  @override
  CastRelayFailure? refusal;

  @override
  Future<void> close() async {
    if (_relay._inputs.remove(_id) == null) return;
    _relay._sources.remove(_id);
    final commands = await _relay._commands;
    commands?.send(RelayCloseInputCommand(_id));
  }
}

/// What the relay's FFmpeg opened, as the plan's facts (Phase 7 decision
/// 4).
StreamFacts streamFactsFromFfmpeg(FfmpegInputReport report) {
  final video = report.video;
  final container = report.container;
  return StreamFacts(
    origin: StreamFactsOrigin.relay,
    container: switch (container) {
      'mpegts' => MediaContainer.mpegTs,
      'hls' => MediaContainer.hls,
      _ when container.contains('mp4') || container.contains('mov') =>
        MediaContainer.mp4,
      _ when container.contains('matroska') => MediaContainer.matroska,
      _ => MediaContainer.other,
    },
    duration: report.duration,
    video: video == null
        ? null
        : VideoFacts(
            codec: video.codec,
            profile: video.profile,
            width: video.width,
            height: video.height,
            fps: video.fps,
            interlaced: video.interlaced,
            bitDepth: video.bitDepth,
          ),
    audio: [
      for (final (i, audio) in report.audio.indexed)
        AudioFacts(
          index: i,
          codec: audio.codec,
          channels: channelCount(audio.layout),
          language: audio.language,
          isDefault: audio.isDefault,
          bitRate: audio.bitRate,
        ),
    ],
  );
}
