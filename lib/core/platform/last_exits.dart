import 'package:meta/meta.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'last_exits.g.dart';

/// Why a run of the app ended, as Android keeps it
/// (`ApplicationExitInfo.REASON_*`, ADR-058).
enum ExitReason {
  /// A crash in native code: the engine, a GPU driver, the player.
  crashNative,

  /// A Java or Kotlin exception nothing caught.
  crash,

  /// It stopped answering and Android closed it.
  anr,

  /// Android closed it to free memory.
  lowMemory,

  /// Ended by a signal (status is its number), from outside or from the
  /// app itself.
  signaled,
  exitSelf,
  initializationFailure,
  excessiveResourceUsage,
  other,
  userRequested,
  userStopped,
  permissionChange,
  dependencyDied,
  freezer,
  packageStateChange,
  packageUpdated,
  unknown;

  static ExitReason named(Object? name) =>
      values.firstWhere((reason) => reason.name == name, orElse: () => unknown);
}

/// `ActivityManager.RunningAppProcessInfo.IMPORTANCE_VISIBLE`: an
/// importance at or under it was on the screen.
const _visible = 200;

/// One end of the app's process, newest facts first (ADR-058).
@immutable
final class AppExit {
  const new({
    required this.time,
    required this.reason,
    this.status = 0,
    this.importance = 0,
    this.pssKb = 0,
    this.rssKb = 0,
    this.description,
    this.byBijou = false,
    this.signal,
    this.thread,
    this.abort,
    this.cause,
    this.frames = const [],
    this.drawing = false,
    this.trace,
  });

  final DateTime time;
  final ExitReason reason;

  /// The exit code, or the signal's number.
  final int status;

  /// How visible the app was as it ended (100 on the screen, 400 cached).
  final int importance;
  final int pssKb;
  final int rssKb;

  /// Android's own words, when it gave any.
  final String? description;

  /// Back on Home ending the process (ADR-032): the app's own doing.
  final bool byBijou;

  /// A native crash's signal (`SIGSEGV SEGV_MAPERR`), the thread it hit
  /// (`1.raster`), its abort message, its cause and where it was, from
  /// the tombstone Android 12 and later keep.
  final String? signal;
  final String? thread;
  final String? abort;
  final String? cause;
  final List<String> frames;

  /// The native crash was in the drawing: one of Flutter's drawing
  /// threads, or a GPU driver.
  final bool drawing;

  /// A Java crash's stack, or an ANR's main thread.
  final String? trace;

  /// An end nobody asked for, seen happen: a crash or an ANR always; a
  /// kill only while the app was on the screen, and never the app's own
  /// leave. Android ending a cached app in the background is no news.
  bool get unexpected => switch (reason) {
    ExitReason.crashNative ||
    ExitReason.crash ||
    ExitReason.anr ||
    ExitReason.initializationFailure => true,
    ExitReason.lowMemory ||
    ExitReason.signaled ||
    ExitReason.exitSelf ||
    ExitReason.excessiveResourceUsage ||
    ExitReason.other ||
    ExitReason.unknown => !byBijou && importance > 0 && importance <= _visible,
    _ => false,
  };

  /// What happened, in a sentence: "It crashed while drawing the
  /// screen."
  String get summary => switch (reason) {
    ExitReason.crashNative when drawing =>
      'It crashed while drawing the screen.',
    ExitReason.crashNative => 'It crashed in its native code.',
    ExitReason.crash => 'It crashed on an error nothing caught.',
    ExitReason.anr => 'It stopped responding, and Android closed it.',
    ExitReason.lowMemory => 'Android closed it to free memory.',
    ExitReason.initializationFailure => "It couldn't start.",
    ExitReason.excessiveResourceUsage =>
      'Android closed it for using too much of the TV.',
    _ => 'Android ended it${status > 0 ? ' (signal $status)' : ''}.',
  };

  /// The facts behind [summary], one per line, for the log, the report
  /// and a photo of the screen.
  List<String> get details => [
    [
      reason.name,
      ?signal,
      if (thread case final thread?) 'thread $thread',
      if (reason != ExitReason.crashNative && status != 0) 'status $status',
      if (rssKb > 0) 'memory ${(rssKb / 1024).round()} MB',
    ].join(' · '),
    // Android's word for a crash, Java or native, is "crash": the kind,
    // said already.
    if (description case final text? when text != 'crash') text,
    if (abort case final text? when text.isNotEmpty) 'abort: $text',
    if (cause case final text? when text.isNotEmpty) 'cause: $text',
    for (final (index, frame) in frames.indexed)
      '#${index.toString().padLeft(2, '0')} $frame',
    if (trace case final text? when text.isNotEmpty) ...text.split('\n'),
  ];

  @override
  String toString() => 'AppExit($time, ${reason.name})';
}

/// How the screen is drawn on this TV: Flutter's own choice (Vulkan where
/// the driver has it), or OpenGL ES after a crash drawing (ADR-058).
@immutable
final class DrawingBackend {
  const new({this.openGles = false, this.since, this.cause});

  final bool openGles;

  /// The crash that made it OpenGL ES, and what it was:
  /// `SIGSEGV SEGV_MAPERR on 1.raster in libGLES_mali.so`.
  final DateTime? since;
  final String? cause;
}

/// What `bijou/exits` says: the newest ends, newest first, the newest
/// already told, and how the screen is drawn.
@immutable
final class LastExits {
  const new({
    this.exits = const [],
    this.seenUpTo,
    this.drawing = const DrawingBackend(),
  });

  final List<AppExit> exits;
  final DateTime? seenUpTo;
  final DrawingBackend drawing;

  /// The unexpected ends not told yet, newest first.
  List<AppExit> get untold => [
    for (final exit in exits)
      if (exit.unexpected && (seenUpTo == null || exit.time.isAfter(seenUpTo!)))
        exit,
  ];
}

/// Why the app's last runs ended (ADR-058). Never throws: what can't be
/// read is null.
abstract interface class LastExitsSource {
  /// False where nothing keeps them: the desktop, a test.
  bool get available;

  Future<LastExits?> read();

  /// The ends up to [upTo] have been told.
  Future<void> seen(DateTime upTo);
}

/// Nothing to read: the desktop and tests.
final class NoLastExits implements LastExitsSource {
  const new();

  @override
  bool get available => false;

  @override
  Future<LastExits?> read() async => null;

  @override
  Future<void> seen(DateTime upTo) async {}
}

/// `bootstrap()` gives a TV's (`AndroidLastExits`).
@Riverpod(keepAlive: true)
LastExitsSource lastExits(Ref ref) => const NoLastExits();

/// `read`'s answer, read tolerantly (hard rule 1's spirit): an end with no
/// time is left out, a field of the wrong kind is as if missing; null when
/// the answer isn't a map.
LastExits? lastExitsFrom(Object? answer) {
  if (answer is! Map) return null;
  final exits = [for (final exit in _list(answer['exits'])) ?_exitFrom(exit)]
    ..sort((a, b) => b.time.compareTo(a.time));
  final drawing = answer['drawing'];
  return LastExits(
    exits: exits,
    seenUpTo: _time(answer['seenUpTo']),
    drawing: drawing is Map
        ? DrawingBackend(
            openGles: drawing['backend'] == 'opengles',
            since: _time(drawing['since']),
            cause: _text(drawing['cause']),
          )
        : const DrawingBackend(),
  );
}

AppExit? _exitFrom(Object? exit) {
  if (exit is! Map) return null;
  final time = _time(exit['time']);
  if (time == null) return null;
  return AppExit(
    time: time,
    reason: ExitReason.named(exit['reason']),
    status: _int(exit['status']),
    importance: _int(exit['importance']),
    pssKb: _int(exit['pssKb']),
    rssKb: _int(exit['rssKb']),
    description: _text(exit['description']),
    byBijou: exit['byBijou'] == true,
    signal: _text(exit['signal']),
    thread: _text(exit['thread']),
    abort: _text(exit['abort']),
    cause: _text(exit['cause']),
    frames: [
      for (final frame in _list(exit['frames']))
        if (frame is String) frame,
    ],
    drawing: exit['drawing'] == true,
    trace: _text(exit['trace']),
  );
}

/// Milliseconds since the epoch; 0 and below are none.
DateTime? _time(Object? value) => value is num && value > 0
    ? DateTime.fromMillisecondsSinceEpoch(value.toInt())
    : null;

int _int(Object? value) => value is num ? value.toInt() : 0;

String? _text(Object? value) =>
    value is String && value.trim().isNotEmpty ? value : null;

List<Object?> _list(Object? value) => value is List ? value : const [];
