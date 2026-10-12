import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:iptv_player/core/cast/cast_mp4_copies.dart';
import 'package:iptv_player/core/cast/cast_plan.dart';
import 'package:iptv_player/core/cast/stream_facts.dart';
import 'package:iptv_player/core/logging/app_log.dart';
import 'package:iptv_player/data/cast/cast_file_jobs.dart';
import 'package:iptv_player/data/cast/ffmpeg_binaries.dart';
import 'package:iptv_player/data/cast/relay/relay_args.dart';
import 'package:iptv_player/data/library/library_probe.dart';
import 'package:iptv_player/data/process/process_supervisor.dart';
import 'package:path/path.dart' as p;

const _tag = 'cast';

/// How long the copy may go without writing before it is taken for
/// stuck, and how often that is looked at.
typedef CastMp4Timings = ({Duration stall, Duration look});

/// [CastMp4Copies] with the bundled FFmpeg, supervised (hard rule 8): the
/// cast owns it, a copy that stops writing is killed, its PID file is the
/// supervisor's, and it is killed and deleted when the cast ends.
///
/// The streams are the relay's own for the plan (`castRelayJob`): the
/// picture copied (HEVC tagged `hvc1`), the planned sound track made AAC
/// stereo or copied. The index goes at the front (`+faststart`). Nearly
/// all its time is the sound's conversion: 54 times real time on this
/// laptop, so about two minutes for a two-hour film, and seconds when
/// the sound is copied.
///
/// The MP4 goes into the folder it is given, one folder a copy. The app
/// gives it the relay's own folder for this run, so whatever a crash
/// leaves there goes with the relay's segments at the next launch.
final class FfmpegCastMp4Copies implements CastMp4Copies {
  new({
    required this._supervisor,
    required this._binaries,
    required this._folder,
    required this._log,
    int? Function(String path)? freeSpace,
    this._timings = (
      stall: const Duration(seconds: 60),
      look: const Duration(seconds: 5),
    ),
  }) : _freeSpace = freeSpace ?? ((_) => null);

  final ProcessSupervisor _supervisor;
  final FfmpegBinaries _binaries;
  final Directory _folder;
  final AppLog _log;
  final int? Function(String path) _freeSpace;
  final CastMp4Timings _timings;
  var _copies = 0;

  /// Beside the copy itself (Phase 8 decision 12): the drive is never
  /// filled by it.
  static const int spareBytes = 1 << 30;

  /// How far the copy's length may be from the original's.
  static const lengthTolerance = Duration(seconds: 2);

  @override
  CastMp4Copy make(
    String video, {
    required CastPlan plan,
    required StreamFacts facts,
  }) {
    final copy = _Copy(
      this,
      Directory(p.join(_folder.path, 'mp4-${++_copies}')),
    );
    unawaited(copy._make(video, plan, facts));
    return copy;
  }
}

final class _Copy implements CastMp4Copy {
  new(this._owner, this._folder);

  final FfmpegCastMp4Copies _owner;
  final Directory _folder;
  final _ready = Completer<String?>();
  SupervisedProcess? _process;
  var _deleted = false;

  AppLog get _log => _owner._log;

  @override
  Future<String?> get ready => _ready.future;

  Future<void> _make(String video, CastPlan plan, StreamFacts facts) async {
    final clock = Stopwatch()..start();
    String? path;
    String? why;
    try {
      (path, why) = await _copy(video, plan, facts);
    } on Object catch (error) {
      // A folder that can't be made, a file that went meanwhile.
      why = '$error';
    }
    if (_deleted) {
      path = null;
    } else if (path != null) {
      _log.info(
        _tag,
        'The MP4 for seeking on the TV is ready, after '
        '${clock.elapsed.inSeconds} s',
      );
    } else {
      _delete();
      _log.info(_tag, 'No MP4 for seeking on the TV: $why');
    }
    _ready.complete(path);
  }

  /// The MP4's path, or why there is none.
  Future<(String?, String?)> _copy(
    String video,
    CastPlan plan,
    StreamFacts facts,
  ) async {
    if (plan.live ||
        plan.video is! CastVideoCopy ||
        plan.delivery != CastDelivery.relayContinuous) {
      return (null, 'its picture is not copied as it is');
    }
    final size = File(video).lengthSync();
    final free = _owner._freeSpace(_folder.parent.path);
    if (free != null && free < size + FfmpegCastMp4Copies.spareBytes) {
      return (null, 'the drive has no room for it');
    }
    if (_deleted) return (null, 'stopped');
    _folder.createSync(recursive: true);
    final part = p.join(_folder.path, 'media.mp4.part');
    final job = castRelayJob(
      plan: plan,
      facts: facts,
      binaries: _owner._binaries,
      localInput: video,
    );
    final SupervisedProcess process;
    try {
      process = _process = await _owner._supervisor.start(
        _owner._binaries.ffmpeg,
        castMp4Arguments(video: video, streams: job.outputArgs, output: part),
        owner: castMp4Owner,
      );
    } on Object catch (error) {
      return (null, "FFmpeg couldn't start: $error");
    }
    if (_deleted) unawaited(process.kill());
    final said = StringBuffer();
    final reading = [
      process.stdout.drain<void>().catchError((Object _) {}),
      process.stderr
          .transform(const Utf8Decoder(allowMalformed: true))
          .forEach((text) {
            if (said.length < 2000) said.write(text);
          })
          .catchError((Object _) {}),
    ];
    // Stuck is a copy whose file hasn't changed for a while: moving the
    // index to the front prints nothing, but it writes.
    var stuck = false;
    var last = _stamp(part);
    var since = DateTime.now();
    final watch = Timer.periodic(_owner._timings.look, (_) {
      final now = _stamp(part);
      if (now != last) {
        last = now;
        since = DateTime.now();
      } else if (DateTime.now().difference(since) >= _owner._timings.stall) {
        stuck = true;
        unawaited(process.kill());
      }
    });
    final code = await process.exitCode;
    watch.cancel();
    await Future.wait(reading);
    _process = null;
    if (_deleted) return (null, 'stopped');
    if (stuck) return (null, 'FFmpeg stopped writing');
    if (code != 0) {
      final words = said.toString().trim().split('\n').last.trim();
      return (
        null,
        'FFmpeg ended with $code${words.isEmpty ? '' : ' ($words)'}',
      );
    }
    // The whole file, as long as the one it was made from.
    final made = await probeLibraryFile(
      _owner._supervisor,
      _owner._binaries.ffprobe,
      part,
    );
    final length = made.duration;
    final wanted = facts.duration;
    if (made.failed || made.video == null || length == null) {
      return (null, "ffprobe didn't read it");
    }
    if (wanted != null &&
        (length - wanted).abs() > FfmpegCastMp4Copies.lengthTolerance) {
      return (
        null,
        'it came out ${length.inSeconds} s long, of ${wanted.inSeconds} s',
      );
    }
    if (_deleted) return (null, 'stopped');
    final path = p.join(_folder.path, 'media.mp4');
    File(part).renameSync(path);
    return (path, null);
  }

  static (int, int)? _stamp(String path) {
    try {
      final stat = File(path).statSync();
      if (stat.type == FileSystemEntityType.notFound) return null;
      return (stat.size, stat.modified.microsecondsSinceEpoch);
    } on FileSystemException {
      return null;
    }
  }

  void _delete() {
    try {
      if (_folder.existsSync()) _folder.deleteSync(recursive: true);
    } on FileSystemException catch (error) {
      // The relay's folder goes when the app quits, and at the next launch.
      _log.info(_tag, 'An MP4 folder was left: ${error.message}');
    }
  }

  @override
  Future<void> delete() async {
    if (_deleted) return;
    _deleted = true;
    await _process?.kill();
    await ready;
    _delete();
  }
}
