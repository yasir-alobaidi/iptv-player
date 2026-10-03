// Plain Dart: the relay's isolate runs it.
import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math' show max, min;

import 'package:iptv_player/core/logging/app_log.dart';
import 'package:iptv_player/core/logging/redact.dart';
import 'package:iptv_player/data/cast/relay/ffmpeg_log.dart';
import 'package:iptv_player/data/cast/relay/hls_playlists.dart';
import 'package:iptv_player/data/cast/relay/relay_job.dart';
import 'package:iptv_player/data/cast/relay/relay_proxy.dart';
import 'package:iptv_player/data/cast/relay/relay_server.dart';
import 'package:iptv_player/data/process/process_supervisor.dart';
import 'package:path/path.dart' as p;

const _tag = 'relay';

/// docs/04's supervisor numbers.
final class RelayTimings {
  const new({
    this.readySegments = 2,
    this.firstSegment = const Duration(seconds: 20),
    this.stallFloor = const Duration(seconds: 10),
    this.quiet = const Duration(seconds: 10),
    this.poll = const Duration(milliseconds: 500),
    this.budget = 5,
    this.budgetWindow = const Duration(minutes: 2),
    this.restartDelays = const [
      Duration(milliseconds: 500),
      Duration(seconds: 1),
      Duration(seconds: 2),
    ],
    this.refusalMemory = const Duration(seconds: 20),
  });

  /// HLS: a LOAD goes once the playlist lists this many (docs/04).
  final int readySegments;

  /// HLS: FFmpeg's first segment, which a slow provider delays (8 s in
  /// docs/04's matrix) on top of FFmpeg's own reading of the stream.
  final Duration firstSegment;

  /// HLS: the newest segment older than max(3 × its length, this) is a
  /// stall (docs/04).
  final Duration stallFloor;

  /// Continuous: FFmpeg sending nothing for this long has stalled, or the
  /// TV stopped reading.
  final Duration quiet;

  /// How often an HLS session's playlist is read.
  final Duration poll;

  /// Restarts (HLS) and new URLs (continuous) allowed within
  /// [budgetWindow] before the session fails (docs/04: 5 in 2 minutes).
  final int budget;
  final Duration budgetWindow;

  /// Waits before a restart, by its number; the last repeats.
  final List<Duration> restartDelays;

  /// How long a refusal by the provider explains an FFmpeg that ended.
  final Duration refusalMemory;
}

/// What happens to a relay session, told to the app.
sealed class RelaySessionEvent {
  const new();
}

/// A LOAD can go: the playlist lists enough segments (HLS). A continuous
/// stream is ready at once: its FFmpeg starts with the TV's request.
final class RelayReady extends RelaySessionEvent {
  const new();
}

/// The TV asked for the stream (once per URL).
final class RelayFetched extends RelaySessionEvent {
  const new();
}

/// FFmpeg opened the stream: what it found (Phase 7 decision 4).
final class RelayOpened extends RelaySessionEvent {
  const new(this.report);

  final FfmpegInputReport report;
}

/// A stream appeared mid-way: the channel changed codec. FFmpeg keeps
/// copying the one it opened.
final class RelayStreamsChanged extends RelaySessionEvent {
  const new();
}

/// HLS: FFmpeg started again behind the same URL; the TV keeps polling.
final class RelayRestarted extends RelaySessionEvent {
  const new(this.count, this.reason);

  /// Restarts so far in this session.
  final int count;
  final RelayRestartReason reason;
}

enum RelayRestartReason {
  /// The newest segment got too old.
  stalled('stalled'),

  /// No first segment in time.
  noFirstSegment('no first segment'),

  /// FFmpeg ended.
  exited('FFmpeg ended');

  new(this.words);

  final String words;
}

/// Continuous: the TV's stream ended. The TV plays out what it has and
/// reports IDLE/FINISHED; a new LOAD needs a new URL (`renew`, ADR-004).
final class RelayEnded extends RelaySessionEvent {
  const new(this.reason);

  final RelayEndReason reason;
}

enum RelayEndReason {
  /// FFmpeg ended: the stream broke, or a file was all sent.
  finished,

  /// FFmpeg sent nothing for too long, or the TV stopped reading.
  quiet,

  /// The TV closed the connection.
  tvLeft,
}

/// The session is over; the app stops it.
final class RelayFailed extends RelaySessionEvent {
  const new(this.failure);

  final RelayFailureInfo failure;
}

/// Why a relay session failed or didn't start.
final class RelayFailureInfo {
  const new(this.kind, {this.status, this.body = '', this.detail});

  final RelayFailureKind kind;

  /// The provider's HTTP status, for a refusal.
  final int? status;

  /// The first bytes of the provider's answer, redacted.
  final String body;

  /// For Details: FFmpeg's last warnings, redacted.
  final String? detail;

  @override
  String toString() =>
      'RelayFailureInfo(${kind.name}'
      '${status == null ? '' : ', HTTP $status'})';
}

enum RelayFailureKind {
  providerRefused,
  providerUnreachable,

  /// The app couldn't build the stream's URL.
  unresolved,

  /// The relay's own other connections hold every one the source has.
  connectionsInUse,

  /// FFmpeg failed before any output, twice.
  ffmpegFailed,

  /// A re-encode failed before any output: try another encoder.
  encoderFailed,

  /// docs/04's budget: 5 restarts within 2 minutes.
  restartBudget,

  /// FFmpeg couldn't be started, or the server couldn't listen.
  couldNotStart,
}

/// The answer to a start or a renewal: the URL the TV loads, or why not.
final class RelayStartAnswer {
  const new({this.url, this.failure});

  final String? url;
  final RelayFailureInfo? failure;
}

/// The relay's sessions (docs/04 "RelayServer", "FfmpegRelay",
/// "Supervisor"), in the relay's isolate. Each session reads its input
/// through the proxy and serves the TV from the server bound to this
/// computer's address on the TV's network; every FFmpeg runs under the
/// [ProcessSupervisor] as "relay" (hard rule 8).
///
/// HLS: FFmpeg writes 2 s segments into the session's folder. A stall (no
/// new segment for max(3 × 2 s, 10 s)), no first segment in time, or an
/// FFmpeg that ends restarts it behind the same URL, its playlist
/// continued, so the TV keeps polling. Continuous: an FFmpeg per request
/// of the TV, stopped when the TV leaves or FFmpeg goes quiet; an end is
/// told to the app, which loads a new URL. Either way, 5 restarts within
/// 2 minutes fail the session, and so does a refusal by the provider.
final class RelayRuntime {
  new _({
    required this.supervisor,
    required this.folder,
    required this._log,
    required this._emit,
    required this.timings,
  });

  static Future<RelayRuntime> open({
    required ProcessSupervisor supervisor,
    required Directory folder,
    required AppLog log,
    required RelayResolver resolve,
    required void Function(String sessionId, RelaySessionEvent event) emit,
    void Function(RelayProxyEvent event)? onProxyEvent,
    RelayTimings timings = const RelayTimings(),
    RelayProxyTimings proxyTimings = const RelayProxyTimings(),
  }) async {
    final runtime = RelayRuntime._(
      supervisor: supervisor,
      folder: folder,
      log: log,
      emit: emit,
      timings: timings,
    );
    runtime._proxy = await RelayProxy.start(
      resolve: resolve,
      log: log,
      timings: proxyTimings,
      onEvent: (event) {
        switch (event) {
          case RelayProxyRefused(:final inputId, :final refusal):
            runtime._refused(inputId, refusal);
          case RelayProxyStreamsChanged(:final inputId):
            for (final session in runtime._sessions.values) {
              if (session.inputId == inputId) {
                session.emit(const RelayStreamsChanged());
              }
            }
          case RelayProxyConnections():
        }
        onProxyEvent?.call(event);
      },
    );
    return runtime;
  }

  final ProcessSupervisor supervisor;

  /// This run's sessions' folders: `<relay root>/<app pid>`.
  final Directory folder;
  final RelayTimings timings;
  final AppLog _log;
  final void Function(String sessionId, RelaySessionEvent event) _emit;
  late final RelayProxy _proxy;

  final _sessions = <String, _Session>{};
  final _servers = <String, RelayServer>{};

  RelayProxy get proxy => _proxy;

  /// Starts serving [job] to a TV that reaches this computer at
  /// [localAddress], reading [inputId]'s stream from [sourceId].
  Future<RelayStartAnswer> start({
    required String sessionId,
    required String inputId,
    required String sourceId,
    required RelayJob job,
    required String localAddress,
  }) async {
    await stop(sessionId);
    final RelayServer server;
    try {
      server = await _serverFor(localAddress);
    } on Object catch (error) {
      _log.warning(_tag, 'The relay could not listen on $localAddress: $error');
      return RelayStartAnswer(
        failure: RelayFailureInfo(
          RelayFailureKind.couldNotStart,
          detail: 'no port in $relayFirstPort–$relayLastPort on $localAddress',
        ),
      );
    }
    final session = switch (job.output) {
      RelayOutput.hls => _HlsSession(this, sessionId, inputId, sourceId, job),
      RelayOutput.continuous => _ContinuousSession(
        this,
        sessionId,
        inputId,
        sourceId,
        job,
      ),
    }..server = server;
    _sessions[sessionId] = session;
    _log.info(_tag, '$sessionId: starting ($job) on ${server.origin}');
    final answer = await session.start();
    if (answer.failure != null) await stop(sessionId);
    return answer;
  }

  /// The same session under a new URL: a continuous stream that ended, a
  /// file from another point, or a fresh HLS after a change of plan.
  /// Counted against the restart budget.
  Future<RelayStartAnswer> renew(String sessionId, {RelayJob? job}) async {
    final session = _sessions[sessionId];
    if (session == null || session.over) {
      return const RelayStartAnswer(
        failure: RelayFailureInfo(
          RelayFailureKind.couldNotStart,
          detail: 'the session has ended',
        ),
      );
    }
    return await session.renew(job);
  }

  Future<void> stop(String sessionId) async {
    final session = _sessions.remove(sessionId);
    if (session == null) return;
    await session.stop();
    _log.info(_tag, '$sessionId: stopped');
    for (final entry in [..._servers.entries]) {
      if (!entry.value.isEmpty) continue;
      _servers.remove(entry.key);
      await entry.value.close();
    }
  }

  /// Serves the picture at [path] to the TV at [localAddress]: its URL,
  /// or null when it isn't a JPEG, PNG or WebP or nothing can listen
  /// there.
  Future<String?> servePicture(
    String path, {
    required String localAddress,
  }) async {
    final file = File(path);
    final String? extension;
    try {
      final head = await file
          .openRead(0, 12)
          .fold<List<int>>([], (all, chunk) => all..addAll(chunk));
      extension = pictureExtension(head);
    } on FileSystemException catch (error) {
      _log.info(_tag, 'No picture to serve: ${error.osError?.message}');
      return null;
    }
    if (extension == null) return null;
    try {
      final server = await _serverFor(localAddress);
      return server.serveFile(file, extension: extension);
    } on Object catch (error) {
      _log.info(_tag, 'The picture could not be served: $error');
      return null;
    }
  }

  /// Stops serving [url], a picture's.
  Future<void> unserve(String url) async {
    final origin = Uri.tryParse(url)?.origin;
    final token = RelayServer.tokenOf(url);
    if (origin == null || token == null) return;
    for (final entry in [..._servers.entries]) {
      if (entry.value.origin != origin) continue;
      entry.value.remove(token);
      if (!entry.value.isEmpty || _servedBy(entry.value)) continue;
      _servers.remove(entry.key);
      await entry.value.close();
    }
  }

  bool _servedBy(RelayServer server) =>
      _sessions.values.any((session) => identical(session.server, server));

  /// What ffprobe reads for [inputId] (decision 3).
  String openInput(
    String inputId, {
    required String sourceId,
    required bool live,
  }) => _proxy.open(inputId, sourceId: sourceId, live: live);

  void closeInput(String inputId) => _proxy.close(inputId);

  /// The app quits: every session stopped, every FFmpeg ended, the
  /// folders gone.
  Future<void> shutdown() async {
    await Future.wait([
      for (final id in [..._sessions.keys]) stop(id),
    ]);
    await _proxy.shutdown();
    for (final server in _servers.values) {
      await server.close();
    }
    _servers.clear();
    await supervisor.stopAll();
    try {
      if (folder.existsSync()) folder.deleteSync(recursive: true);
    } on FileSystemException {
      // The next launch's sweep takes it.
    }
  }

  Future<RelayServer> _serverFor(String address) async {
    final known = _servers[address];
    if (known != null) return known;
    final server = await RelayServer.bind(
      address,
      log: _log,
      onFetched: (token) {
        for (final session in _sessions.values) {
          if (session.token == token) session.emit(const RelayFetched());
        }
      },
    );
    _servers[address] = server;
    return server;
  }

  void _refused(String inputId, RelayRefusal refusal) {
    for (final session in _sessions.values) {
      if (session.inputId == inputId) {
        session.refusal = (refusal, DateTime.now());
      }
    }
  }
}

sealed class _Session {
  new(this.runtime, this.id, this.inputId, this.sourceId, this.job);

  final RelayRuntime runtime;
  final String id;
  final String inputId;
  final String sourceId;
  RelayJob job;
  late RelayServer server;

  late String inputUrl;
  String url = '';
  String? token;
  SupervisedProcess? ffmpeg;
  (RelayRefusal, DateTime)? refusal;
  bool stopping = false;
  bool failed = false;

  /// Why it failed.
  RelayFailureInfo? failure;

  final _spent = <DateTime>[];
  final _tail = <String>[];
  DateTime _logWindow = DateTime.now();
  int _logged = 0;
  int _suppressed = 0;

  RelayTimings get timings => runtime.timings;

  AppLog get log => runtime._log;

  bool get over => stopping || failed;

  void emit(RelaySessionEvent event) {
    if (!stopping) runtime._emit(id, event);
  }

  Future<RelayStartAnswer> start();

  Future<RelayStartAnswer> renew(RelayJob? next);

  Future<void> stop() async {
    stopping = true;
    await teardown();
  }

  /// Stops its FFmpeg, its input and its URL; deletes its files.
  Future<void> teardown() async {
    // The provider's connection goes first: on a one-connection source
    // the next session needs it now, not after FFmpeg's exit.
    runtime._proxy.close(inputId);
    final current = token;
    if (current != null) server.remove(current);
    token = null;
    final process = ffmpeg;
    ffmpeg = null;
    await process?.stop();
  }

  Future<void> fail(RelayFailureInfo why) async {
    if (over) return;
    failed = true;
    failure = why;
    log.warning(_tag, '$id: failed: $why');
    runtime._emit(id, RelayFailed(why));
    await teardown();
  }

  /// One restart or new URL from the budget; false when it is spent.
  bool spend() {
    final now = DateTime.now();
    _spent.removeWhere((at) => now.difference(at) > timings.budgetWindow);
    if (_spent.length >= timings.budget) return false;
    _spent.add(now);
    return true;
  }

  RelayFailureInfo get budgetSpent => RelayFailureInfo(
    RelayFailureKind.restartBudget,
    detail: [
      '${timings.budget} restarts within ${timings.budgetWindow.inSeconds} s',
      ..._tail,
    ].join('\n'),
  );

  /// The provider's refusal, if a recent one explains an FFmpeg that
  /// ended.
  RelayFailureInfo? get recentRefusal {
    final (seen, at) = refusal ?? (null, null);
    if (seen == null || at == null) return null;
    if (DateTime.now().difference(at) > timings.refusalMemory) return null;
    return RelayFailureInfo(
      switch (seen.kind) {
        RelayRefusalKind.refused => RelayFailureKind.providerRefused,
        RelayRefusalKind.unreachable => RelayFailureKind.providerUnreachable,
        RelayRefusalKind.unresolved => RelayFailureKind.unresolved,
        RelayRefusalKind.connectionsInUse => RelayFailureKind.connectionsInUse,
      },
      status: seen.status,
      body: seen.body,
      detail: seen.detail,
    );
  }

  /// FFmpeg's last warnings, for Details.
  String get tail => _tail.join('\n');

  Future<SupervisedProcess?> launch(List<String> arguments) async {
    final SupervisedProcess process;
    try {
      process = await runtime.supervisor.start(
        job.ffmpeg,
        arguments,
        owner: 'relay',
        environment: job.environment.isEmpty ? null : job.environment,
      );
    } on Object catch (error) {
      await fail(
        RelayFailureInfo(
          RelayFailureKind.couldNotStart,
          detail: redact('FFmpeg could not start: $error'),
        ),
      );
      return null;
    }
    ffmpeg = process;
    _errorsRead[process] = _readErrors(process);
    return process;
  }

  /// [process]'s exit code, once its last words are read too: the exit
  /// can be noticed before them, and Details needs them.
  Future<int> ended(SupervisedProcess process) async {
    final code = await process.exitCode;
    await (_errorsRead[process] ?? Future<void>.value()).timeout(
      const Duration(seconds: 1),
      onTimeout: () {},
    );
    return code;
  }

  final _errorsRead = Expando<Future<void>>();

  Future<void> _readErrors(SupervisedProcess process) {
    final input = FfmpegInputReader();
    return process.stderr
        .transform(const Utf8Decoder(allowMalformed: true))
        .transform(const LineSplitter())
        .listen((raw) {
          final line = parseFfmpegLine(raw);
          final current = identical(process, ffmpeg);
          final report = input.add(line);
          if (report != null && current) emit(RelayOpened(report));
          if (!line.level.worrying) return;
          final text = redact('$line');
          _tail.add(text);
          if (_tail.length > 12) _tail.removeAt(0);
          if (current && isNewStreamLine(line)) {
            emit(const RelayStreamsChanged());
          }
          _logLine(text);
        })
        .asFuture<void>()
        .catchError((Object _) {});
  }

  /// FFmpeg's warnings, at most 10 a minute: a damaged stream can print
  /// one per packet.
  void _logLine(String text) {
    final now = DateTime.now();
    if (now.difference(_logWindow) > const Duration(minutes: 1)) {
      if (_suppressed > 0) {
        log.warning(_tag, '$id: FFmpeg printed $_suppressed more warnings');
      }
      _logWindow = now;
      _logged = 0;
      _suppressed = 0;
    }
    if (_logged++ < 10) {
      log.warning(_tag, '$id: FFmpeg: $text');
    } else {
      _suppressed++;
    }
  }

  Duration restartDelay(int count) =>
      timings.restartDelays[min(count, timings.restartDelays.length) - 1];
}

final class _HlsSession extends _Session {
  new(super.runtime, super.id, super.inputId, super.sourceId, super.job);

  Directory? _folder;
  Timer? _poll;
  HlsProgress _progress = HlsProgress.empty;
  DateTime _startedAt = DateTime.now();
  DateTime _movedAt = DateTime.now();
  bool _ready = false;
  bool _produced = false;
  bool _restarting = false;
  int _earlyExits = 0;
  int _restarts = 0;
  int _generation = 0;

  File get _playlist => File(p.join(_folder!.path, hlsPlaylistName));

  Duration get _stallAfter => Duration(
    milliseconds: max(
      3 * job.segmentSeconds * 1000,
      timings.stallFloor.inMilliseconds,
    ),
  );

  @override
  Future<RelayStartAnswer> start() async {
    inputUrl = runtime._proxy.open(inputId, sourceId: sourceId, live: job.live);
    return await _begin();
  }

  @override
  Future<RelayStartAnswer> renew(RelayJob? next) async {
    if (!spend()) {
      final failure = budgetSpent;
      await fail(failure);
      return RelayStartAnswer(failure: failure);
    }
    _poll?.cancel();
    final process = ffmpeg;
    ffmpeg = null;
    await process?.stop();
    final old = token;
    if (old != null) server.remove(old);
    _deleteFolder();
    if (next != null) job = next;
    refusal = null;
    return await _begin();
  }

  Future<RelayStartAnswer> _begin() async {
    final name = '$id-${_generation++}';
    final folder = Directory(p.join(runtime.folder.path, name))
      ..createSync(recursive: true);
    _folder = folder;
    url = server.serveHls(folder);
    token = RelayServer.tokenOf(url);
    _progress = HlsProgress.empty;
    _ready = false;
    _earlyExits = 0;
    if (!await _launch(append: false)) {
      return RelayStartAnswer(
        failure:
            failure ?? const RelayFailureInfo(RelayFailureKind.couldNotStart),
      );
    }
    _poll = Timer.periodic(timings.poll, (_) => _check());
    return RelayStartAnswer(url: url);
  }

  Future<bool> _launch({required bool append}) async {
    _startedAt = DateTime.now();
    _produced = false;
    final process = await launch(
      relayArguments(
        job,
        input: inputUrl,
        folder: _folder!.path,
        append: append,
      ),
    );
    if (process == null) return false;
    unawaited(ended(process).then((code) => _exited(process, code)));
    return true;
  }

  void _check() {
    if (over || _restarting) return;
    final now = DateTime.now();
    _readProgress(now);
    if (_produced) {
      if (now.difference(_movedAt) > _stallAfter) {
        unawaited(_restart(RelayRestartReason.stalled));
      }
    } else if (now.difference(_startedAt) > timings.firstSegment) {
      unawaited(_restart(RelayRestartReason.noFirstSegment));
    }
  }

  /// What the playlist says now: a new segment, and ready once it lists
  /// enough.
  void _readProgress(DateTime now) {
    String? text;
    try {
      text = _playlist.readAsStringSync();
    } on FileSystemException {
      // Not written yet.
    }
    if (text != null) {
      final next = readHlsProgress(text);
      if (next.movedOn(_progress)) {
        _movedAt = now;
        _produced = true;
        _earlyExits = 0;
      }
      _progress = next;
      if (!_ready && next.segments >= timings.readySegments) {
        _ready = true;
        log.info(
          _tag,
          '$id: ready in ${now.difference(_startedAt).inMilliseconds} ms',
        );
        emit(const RelayReady());
      }
    }
  }

  void _exited(SupervisedProcess process, int code) {
    if (!identical(process, ffmpeg) || over) return;
    ffmpeg = null;
    // Its last segment may have come after the last look.
    _readProgress(DateTime.now());
    final refused = recentRefusal;
    if (refused != null &&
        refused.kind != RelayFailureKind.providerUnreachable) {
      unawaited(fail(refused));
      return;
    }
    if (!_produced) {
      if (job.transcode) {
        unawaited(
          fail(RelayFailureInfo(RelayFailureKind.encoderFailed, detail: tail)),
        );
        return;
      }
      if (++_earlyExits >= 2) {
        unawaited(
          fail(
            refused ??
                RelayFailureInfo(RelayFailureKind.ffmpegFailed, detail: tail),
          ),
        );
        return;
      }
    }
    log.info(_tag, '$id: FFmpeg ended ($code)');
    unawaited(_restart(RelayRestartReason.exited));
  }

  Future<void> _restart(RelayRestartReason reason) async {
    if (over || _restarting) return;
    _restarting = true;
    try {
      if (!spend()) {
        await fail(budgetSpent);
        return;
      }
      _restarts++;
      log.warning(
        _tag,
        '$id: restarting FFmpeg (${reason.words}), $_restarts so far',
      );
      emit(RelayRestarted(_restarts, reason));
      final process = ffmpeg;
      ffmpeg = null;
      // A stalled FFmpeg is blocked on its input and ignores SIGTERM for
      // the whole grace (3 s); its playlist is written whole or not at
      // all, so nothing the TV reads is lost.
      await process?.kill();
      await Future<void>.delayed(restartDelay(_restarts));
      if (over) return;
      await _launch(append: _playlist.existsSync());
    } finally {
      _restarting = false;
    }
  }

  @override
  Future<void> teardown() async {
    _poll?.cancel();
    await super.teardown();
    _deleteFolder();
  }

  void _deleteFolder() {
    final folder = _folder;
    _folder = null;
    try {
      if (folder != null && folder.existsSync()) {
        folder.deleteSync(recursive: true);
      }
    } on FileSystemException {
      // A segment still open (Windows): the sweep takes it.
    }
  }
}

final class _ContinuousSession extends _Session {
  new(super.runtime, super.id, super.inputId, super.sourceId, super.job);

  /// Counts the TV's requests and new URLs: an older one, still ending,
  /// says nothing.
  int _served = 0;

  @override
  Future<RelayStartAnswer> start() async {
    inputUrl = runtime._proxy.open(inputId, sourceId: sourceId, live: job.live);
    _serveAnew();
    // After the answer: the app learns of the session first.
    Timer.run(() => emit(const RelayReady()));
    return RelayStartAnswer(url: url);
  }

  @override
  Future<RelayStartAnswer> renew(RelayJob? next) async {
    if (!spend()) {
      final failure = budgetSpent;
      await fail(failure);
      return RelayStartAnswer(failure: failure);
    }
    _served++;
    final process = ffmpeg;
    ffmpeg = null;
    await process?.stop();
    final old = token;
    if (old != null) server.remove(old);
    if (next != null) job = next;
    refusal = null;
    _serveAnew();
    return RelayStartAnswer(url: url);
  }

  void _serveAnew() {
    url = server.serveStream(_serve);
    token = RelayServer.tokenOf(url);
  }

  /// One request of the TV: an FFmpeg made for it, its standard output
  /// the answer (docs/04: the TV opens the URL once, with `Range:
  /// bytes=0-`, and gets 200, chunked).
  Future<void> _serve(HttpRequest request) async {
    final response = request.response;
    response.headers
      ..set(HttpHeaders.contentTypeHeader, 'video/mp4')
      ..set(HttpHeaders.cacheControlHeader, 'no-cache');
    if (request.method == 'HEAD' || over) {
      if (over) response.statusCode = HttpStatus.notFound;
      await response.close();
      return;
    }
    final generation = ++_served;
    // One FFmpeg per session: a second request takes over from the first.
    final previous = ffmpeg;
    ffmpeg = null;
    await previous?.stop();
    if (generation != _served || over) {
      response.statusCode = HttpStatus.serviceUnavailable;
      await response.close();
      return;
    }
    final process = await launch(relayArguments(job, input: inputUrl));
    if (process == null) {
      response.statusCode = HttpStatus.serviceUnavailable;
      await response.close();
      return;
    }
    // The stream owns its socket (ADR-010): a TV that leaves closes it,
    // which an HttpResponse would only notice at its next write — and a
    // response held back by the TV's pace writes nothing.
    final Socket tv;
    try {
      tv = await request.response.detachSocket(writeHeaders: false);
    } on Object {
      await process.stop();
      return;
    }
    tv.add(
      utf8.encode(
        [
          'HTTP/1.1 200 OK',
          'Content-Type: video/mp4',
          'Cache-Control: no-cache',
          for (final MapEntry(:key, :value) in relayCorsHeaders.entries)
            '$key: $value',
          'Transfer-Encoding: chunked',
          'Connection: close',
          '\r\n',
        ].join('\r\n'),
      ),
    );

    var why = RelayEndReason.finished;
    var sent = 0;
    late StreamSubscription<List<int>> out;
    final body = StreamController<List<int>>(sync: true);
    Timer? quiet;
    void end(RelayEndReason reason) {
      if (body.isClosed) return;
      why = reason;
      quiet?.cancel();
      unawaited(out.cancel());
      unawaited(body.close());
    }

    void watch() {
      quiet?.cancel();
      quiet = Timer(timings.quiet, () => end(RelayEndReason.quiet));
    }

    tv.listen(
      (_) {},
      onDone: () => end(RelayEndReason.tvLeft),
      onError: (Object _) => end(RelayEndReason.tvLeft),
      cancelOnError: true,
    );
    body
      ..onListen = () {
        out = process.stdout.listen(
          (chunk) {
            if (body.isClosed || chunk.isEmpty) return;
            sent += chunk.length;
            watch();
            // The chunk's frame around its bytes, never a copy of them.
            body
              ..add(ascii.encode('${chunk.length.toRadixString(16)}\r\n'))
              ..add(chunk)
              ..add(_lineEnd);
          },
          onDone: () => end(RelayEndReason.finished),
          onError: (Object _) => end(RelayEndReason.finished),
        );
        watch();
      }
      ..onPause = (() => out.pause())
      ..onResume = (() => out.resume())
      ..onCancel = () {
        if (!body.isClosed) end(RelayEndReason.tvLeft);
      };
    try {
      await tv.addStream(body.stream);
    } on Object {
      if (why == RelayEndReason.finished) why = RelayEndReason.tvLeft;
    }
    if (why == RelayEndReason.tvLeft) {
      tv.destroy();
    } else {
      // A clean end: the TV plays out what it has, then says FINISHED.
      try {
        tv.add(_lastChunk);
        await tv.close();
      } on Object {
        tv.destroy();
      }
    }
    quiet?.cancel();
    if (identical(ffmpeg, process)) ffmpeg = null;
    await process.stop();
    await ended(process);
    if (generation != _served || over) return;
    log.info(
      _tag,
      '$id: the stream to the TV ended (${why.name}) after '
      '${(sent / 1e6).toStringAsFixed(1)} MB',
    );
    if (sent == 0) {
      final refused = recentRefusal;
      if (refused != null &&
          refused.kind != RelayFailureKind.providerUnreachable) {
        await fail(refused);
        return;
      }
      if (job.transcode && why == RelayEndReason.finished) {
        await fail(
          RelayFailureInfo(RelayFailureKind.encoderFailed, detail: tail),
        );
        return;
      }
    }
    emit(RelayEnded(why));
  }
}

final List<int> _lastChunk = ascii.encode('0\r\n\r\n');
final List<int> _lineEnd = ascii.encode('\r\n');
