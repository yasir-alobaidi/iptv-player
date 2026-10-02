import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:iptv_player/core/logging/app_log.dart';
import 'package:iptv_player/data/process/windows_process_image.dart';
import 'package:path/path.dart' as p;

/// Starts a process: [Process.start], but for tests. [environment] adds
/// to the app's own.
typedef ProcessLauncher = Future<Process> Function(
  String executable,
  List<String> arguments, {
  Map<String, String>? environment,
});

/// The executable a running process runs; null when it isn't running or
/// can't be asked.
typedef ProcessImage = String? Function(int pid);

/// Kills a process by its id; true when it was sent the signal.
typedef ProcessKiller = bool Function(int pid);

/// Runs the bundled FFmpeg and ffprobe under hard rule 8: each process
/// has an owner, a timeout or a watchdog, and a PID file for as long as it
/// runs; it is stopped when the app quits ([stopAll]), and swept at the
/// next launch ([sweep]) if the app didn't get to.
final class ProcessSupervisor {
  new({
    required this.folder,
    required this._log,
    ProcessLauncher? launcher,
    ProcessImage? image,
    ProcessKiller? kill,
    this.grace = const Duration(seconds: 3),
  }) : _launch = launcher ?? _startNow,
       _image = image ?? processImage,
       _kill = kill ?? _killNow;

  /// The PID files: one folder only the app writes to.
  final Directory folder;

  /// How long a stopped process has between SIGTERM and SIGKILL.
  final Duration grace;

  final AppLog _log;
  final ProcessLauncher _launch;
  final ProcessImage _image;
  final ProcessKiller _kill;
  final _running = <SupervisedProcess>{};

  /// The processes running now.
  int get runningCount => _running.length;

  /// Starts [executable] for [owner] ("ffprobe", "relay"), stopped after
  /// [timeout] when one is given, with [environment] added to the app's.
  /// Whoever starts it reads its output: an unread pipe fills and the
  /// process stops moving. Throws a [ProcessException] when it can't be
  /// started, or its PID file can't be written (it is killed then: no
  /// process runs unswept).
  Future<SupervisedProcess> start(
    String executable,
    List<String> arguments, {
    required String owner,
    Duration? timeout,
    Map<String, String>? environment,
  }) async {
    final process = await _launch(
      executable,
      arguments,
      environment: environment,
    );
    final pidFile = File(p.join(folder.path, '$owner-${process.pid}.pid'));
    try {
      folder.createSync(recursive: true);
      pidFile.writeAsStringSync(
        jsonEncode({
          'pid': process.pid,
          'executable': executable,
          'owner': owner,
          'app_pid': pid,
          'app_executable': Platform.resolvedExecutable,
        }),
        flush: true,
      );
    } on FileSystemException catch (error) {
      process.kill(ProcessSignal.sigkill);
      unawaited(process.stdout.drain<void>());
      unawaited(process.stderr.drain<void>());
      throw ProcessException(
        executable,
        const [],
        'no PID file: ${error.message}',
      );
    }
    final supervised = SupervisedProcess._(
      process,
      owner: owner,
      pidFile: pidFile,
      grace: grace,
      log: _log,
      onExit: _running.remove,
    );
    _running.add(supervised);
    if (timeout != null) supervised._stopAfter(timeout);
    return supervised;
  }

  /// Runs [executable] to its end, and gathers what it printed: standard
  /// output up to [maxOutput] bytes (more stops it), the last 8 KiB of
  /// standard error. Never throws.
  Future<SupervisedRun> run(
    String executable,
    List<String> arguments, {
    required String owner,
    required Duration timeout,
    int maxOutput = 4 << 20,
    Map<String, String>? environment,
  }) async {
    final SupervisedProcess process;
    try {
      process = await start(
        executable,
        arguments,
        owner: owner,
        timeout: timeout,
        environment: environment,
      );
    } on Object catch (error) {
      return SupervisedRun(startError: '$error');
    }
    final output = BytesBuilder(copy: false);
    final errors = _Tail(8 << 10);
    var overflowed = false;
    final outputRead = process.stdout
        .listen((chunk) {
          if (overflowed) return;
          if (output.length + chunk.length > maxOutput) {
            overflowed = true;
            unawaited(process.stop());
            return;
          }
          output.add(chunk);
        })
        .asFuture<void>()
        .catchError((Object _) {});
    final errorsRead = process.stderr
        .listen(errors.add)
        .asFuture<void>()
        .catchError((Object _) {});
    final code = await process.exitCode;
    // Its pipes end with it, unless it left a child holding them.
    await Future.wait([outputRead, errorsRead])
        .timeout(grace, onTimeout: () => const []);
    return SupervisedRun(
      exitCode: code,
      stdout: output.takeBytes(),
      stderr: errors.text,
      timedOut: process.timedOut,
      overflowed: overflowed,
    );
  }

  /// Stops every process still running: the app is quitting.
  Future<void> stopAll() => Future.wait([
    for (final process in [..._running]) process.stop(),
  ]);

  /// The launch sweep: each PID file left by an earlier run is deleted,
  /// and its process killed first if it still runs the executable the
  /// file names (a process id can be reused) and the app that started it
  /// is gone (another copy of the app may still be running it). Answers
  /// how many were killed.
  Future<int> sweep() async {
    final List<FileSystemEntity> entries;
    try {
      if (!folder.existsSync()) return 0;
      entries = folder.listSync();
    } on FileSystemException catch (error) {
      _log.warning('process', 'Could not sweep ${folder.path}', error: error);
      return 0;
    }
    final mine = {for (final process in _running) process.pid};
    var killed = 0;
    for (final entry in entries) {
      if (entry is! File || !entry.path.endsWith('.pid')) continue;
      final record = _PidRecord.read(entry);
      if (record != null) {
        if (mine.contains(record.pid)) continue;
        if (_appStillRuns(record)) continue;
        if (_runs(record.pid, record.executable) && _kill(record.pid)) {
          killed++;
          _log.warning(
            'process',
            'Stopped a leftover ${record.owner} (pid ${record.pid}) '
                'from an earlier run',
          );
        }
      }
      try {
        entry.deleteSync();
      } on FileSystemException {
        // Gone already, or not ours to delete: the next sweep tries again.
      }
    }
    return killed;
  }

  bool _appStillRuns(_PidRecord record) {
    final appPid = record.appPid;
    final appExecutable = record.appExecutable;
    if (appPid == null || appExecutable == null || appPid == pid) {
      return false;
    }
    return _runs(appPid, appExecutable);
  }

  bool _runs(int processId, String executable) {
    final image = _image(processId);
    return image != null && samePath(image, executable);
  }

  static bool _killNow(int pid) => Process.killPid(pid, ProcessSignal.sigkill);

  static Future<Process> _startNow(
    String executable,
    List<String> arguments, {
    Map<String, String>? environment,
  }) => Process.start(executable, arguments, environment: environment);
}

/// One process under the [ProcessSupervisor].
final class SupervisedProcess {
  new _(
    this._process, {
    required this.owner,
    required this._pidFile,
    required this._grace,
    required this._log,
    required void Function(SupervisedProcess) onExit,
  }) {
    exitCode = _process.exitCode.then((code) {
      _exited = true;
      _timeout?.cancel();
      _kill?.cancel();
      try {
        _pidFile.deleteSync();
      } on FileSystemException {
        // Already gone: the sweep would have nothing to do either.
      }
      onExit(this);
      return code;
    });
  }

  final Process _process;
  final File _pidFile;
  final Duration _grace;
  final AppLog _log;

  /// Who started it: "ffprobe", "relay".
  final String owner;

  /// Completes when it has ended and its PID file is gone.
  late final Future<int> exitCode;

  Timer? _timeout;
  Timer? _kill;
  var _exited = false;
  var _stopping = false;
  var _timedOut = false;

  int get pid => _process.pid;

  Stream<List<int>> get stdout => _process.stdout;

  Stream<List<int>> get stderr => _process.stderr;

  /// It ran past its timeout and was stopped.
  bool get timedOut => _timedOut;

  bool get exited => _exited;

  /// SIGTERM (TerminateProcess on Windows), then SIGKILL after the
  /// supervisor's grace. Completes once it has ended.
  Future<void> stop() async {
    if (_exited) return;
    if (!_stopping) {
      _stopping = true;
      _process.kill();
      _kill = Timer(_grace, () => _process.kill(ProcessSignal.sigkill));
    }
    await exitCode;
  }

  void _stopAfter(Duration timeout) {
    _timeout = Timer(timeout, () {
      _timedOut = true;
      _log.warning(
        'process',
        '$owner (pid $pid) ran past ${timeout.inMilliseconds} ms; stopping it',
      );
      unawaited(stop());
    });
  }
}

/// What [ProcessSupervisor.run] gathered.
final class SupervisedRun {
  const new({
    this.exitCode,
    this.stdout = const [],
    this.stderr = '',
    this.timedOut = false,
    this.overflowed = false,
    this.startError,
  });

  /// Null when it didn't start.
  final int? exitCode;
  final List<int> stdout;

  /// The end of what it printed there.
  final String stderr;
  final bool timedOut;

  /// It printed more than it was allowed and was stopped.
  final bool overflowed;

  /// Why it didn't start.
  final String? startError;
}

/// Whether two paths name the same file: links resolved, Windows' case
/// ignored, and Linux's " (deleted)" mark on a replaced executable
/// dropped.
bool samePath(String a, String b) {
  String canonical(String path) {
    var text = path.endsWith(' (deleted)')
        ? path.substring(0, path.length - ' (deleted)'.length)
        : path;
    try {
      text = File(text).resolveSymbolicLinksSync();
    } on FileSystemException {
      // Gone, or not a file we can see: compare it as written.
    }
    text = p.normalize(text);
    return Platform.isWindows ? text.toLowerCase() : text;
  }

  return canonical(a) == canonical(b);
}

/// The executable process [pid] runs: `/proc/<pid>/exe` (or the first
/// word of its command line) on Linux, `QueryFullProcessImageName` on
/// Windows. Null when it isn't running or can't be asked.
String? processImage(int pid) {
  if (Platform.isWindows) return windowsProcessImage(pid);
  if (!Platform.isLinux && !Platform.isAndroid) return null;
  try {
    return Link('/proc/$pid/exe').targetSync();
  } on FileSystemException {
    // Another user's process, or gone; its command line may still say.
  }
  try {
    final first = File('/proc/$pid/cmdline').readAsStringSync().split('\x00');
    return first.first.isEmpty ? null : first.first;
  } on FileSystemException {
    return null;
  }
}

final class _PidRecord {
  const new({
    required this.pid,
    required this.executable,
    required this.owner,
    this.appPid,
    this.appExecutable,
  });

  final int pid;
  final String executable;
  final String owner;
  final int? appPid;
  final String? appExecutable;

  /// Null for a file that isn't what [ProcessSupervisor.start] wrote.
  static _PidRecord? read(File file) {
    try {
      final json = jsonDecode(file.readAsStringSync());
      if (json is! Map) return null;
      final processId = json['pid'];
      final executable = json['executable'];
      final appPid = json['app_pid'];
      final appExecutable = json['app_executable'];
      if (processId is! int || processId <= 0) return null;
      if (executable is! String || executable.isEmpty) return null;
      final owner = json['owner'];
      return _PidRecord(
        pid: processId,
        executable: executable,
        owner: owner is String ? owner : 'process',
        appPid: appPid is int ? appPid : null,
        appExecutable: appExecutable is String ? appExecutable : null,
      );
    } on Object {
      return null;
    }
  }
}

/// The last [capacity] bytes of a stream, as text.
final class _Tail {
  new(this.capacity);

  final int capacity;
  final _bytes = BytesBuilder(copy: false);

  void add(List<int> chunk) {
    _bytes.add(chunk);
    if (_bytes.length > capacity * 2) {
      final all = _bytes.takeBytes();
      _bytes.add(Uint8List.sublistView(all, all.length - capacity));
    }
  }

  String get text {
    final all = _bytes.toBytes();
    final start = all.length > capacity ? all.length - capacity : 0;
    return utf8.decode(all.sublist(start), allowMalformed: true);
  }
}
