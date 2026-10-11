import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:iptv_player/core/downloads/download_format.dart';
import 'package:iptv_player/core/library/library_media.dart';
import 'package:iptv_player/core/logging/app_log.dart';
import 'package:iptv_player/data/library/library_probe.dart';
import 'package:iptv_player/data/process/process_supervisor.dart';
import 'package:path/path.dart' as p;

const _tag = 'downloads';

/// How remaking a download as MP4 went.
sealed class RemuxOutcome {
  const new();
}

/// The MP4 is whole at the output path, checked against the file it was
/// made from; [media] is what ffprobe reads in it.
final class RemuxDone extends RemuxOutcome {
  const new(this.media);

  final LibraryMedia media;
}

/// The file stays as it came, because of [why]; nothing is at the output
/// path. [media] is what ffprobe read in it, when it read it.
final class RemuxKept extends RemuxOutcome {
  const new(this.why, {this.media});

  final String why;
  final LibraryMedia? media;
}

/// Stopped (a cancel, the app quitting) before it was done; nothing is at
/// the output path.
final class RemuxStopped extends RemuxOutcome {
  const new();
}

/// Remakes a finished download as MP4 when that loses nothing (docs/09
/// "Format").
abstract interface class DownloadRemux {
  /// [input] copied into an MP4 at [output], or the reason it stays as it
  /// came. Never throws, and never touches [input].
  Future<RemuxOutcome> toMp4(String input, String output);

  /// Stops the copy being written to [output], if one is.
  Future<void> stop(String output);

  /// The app is quitting: every copy stops, and none starts.
  Future<void> close();
}

/// How long the copy may go without writing before it is taken for stuck,
/// and how often that is looked at.
typedef RemuxTimings = ({Duration stall, Duration look});

/// [DownloadRemux] with the bundled FFmpeg, supervised (hard rule 8): the
/// download's finisher owns it, a copy that stops writing is killed, its
/// PID file is the supervisor's, and a copy left half-made is deleted here
/// and by the next try.
///
/// The streams are copied (`-c copy`), so the picture and sound are the
/// provider's, bit for bit; text subtitles become MP4's own (`mov_text`);
/// HEVC is tagged `hvc1`, which Apple's players need; the index goes at
/// the front (`+faststart`), so the file starts at once over a network or
/// on a TV.
final class FfmpegDownloadRemux implements DownloadRemux {
  new({
    required this._supervisor,
    required this._ffmpeg,
    required this._ffprobe,
    required this._log,
    int? Function(String path)? freeSpace,
    this._timings = (
      stall: const Duration(seconds: 60),
      look: const Duration(seconds: 5),
    ),
  }) : _freeSpace = freeSpace ?? ((_) => null);

  final ProcessSupervisor _supervisor;
  final String _ffmpeg;
  final String _ffprobe;
  final AppLog _log;
  final int? Function(String path) _freeSpace;
  final RemuxTimings _timings;

  /// Beside the copy itself, so the drive is never filled by it.
  static const int spareBytes = 256 << 20;

  /// How far the copy's length may be from the original's.
  static const lengthTolerance = Duration(seconds: 2);

  final _running = <String, SupervisedProcess>{};
  final _stopped = <String>{};
  var _closed = false;

  @override
  Future<RemuxOutcome> toMp4(String input, String output) async {
    if (_closed) return const RemuxStopped();
    final probed = await _probe(input);
    if (probed == null) return const RemuxKept("ffprobe didn't read it");
    final (media, dolbyVision) = probed;
    // FFmpeg writes Dolby Vision's record into MP4 only when asked to step
    // outside the standard; without it the picture would lose it.
    final obstacle = dolbyVision
        ? 'its picture is Dolby Vision'
        : mp4Obstacle(media);
    if (obstacle != null) return RemuxKept(obstacle, media: media);

    final int size;
    try {
      size = File(input).lengthSync();
      final stale = File(output);
      if (stale.existsSync()) stale.deleteSync();
    } on FileSystemException catch (error) {
      return RemuxKept('the disk said ${error.message}', media: media);
    }
    final free = _freeSpace(p.dirname(output));
    if (free != null && free < size + spareBytes) {
      return RemuxKept('the drive has no room for the copy', media: media);
    }
    if (_closed) return const RemuxStopped();

    final failure = await _copy(input, output, media);
    if (failure != null) {
      _delete(output);
      if (_closed || _stopped.remove(output)) return const RemuxStopped();
      return RemuxKept(failure, media: media);
    }
    final made = (await _probe(output))?.$1;
    final different = made == null
        ? "ffprobe didn't read the copy"
        : _difference(media, made);
    if (different != null) {
      _delete(output);
      return RemuxKept('the copy came out wrong: $different', media: media);
    }
    return RemuxDone(made!);
  }

  @override
  Future<void> stop(String output) async {
    final process = _running[output];
    if (process == null) return;
    _stopped.add(output);
    await process.kill();
  }

  @override
  Future<void> close() async {
    _closed = true;
    await Future.wait([for (final process in _running.values) process.kill()]);
  }

  /// Null when the copy ended well; else what went wrong.
  Future<String?> _copy(String input, String output, LibraryMedia media) async {
    final SupervisedProcess process;
    try {
      process = await _supervisor.start(_ffmpeg, [
        ...['-hide_banner', '-v', 'error', '-nostdin', '-y'],
        ...['-i', input],
        // Every picture that isn't a cover image, every sound track, every
        // subtitle.
        ...['-map', '0:V', '-map', '0:a?', '-map', '0:s?'],
        ...['-c', 'copy', '-c:s', 'mov_text'],
        if (media.video?.codec?.toLowerCase() == 'hevc') ...['-tag:v', 'hvc1'],
        ...['-map_metadata', '0', '-map_chapters', '0'],
        ...['-movflags', '+faststart'],
        ...['-f', 'mp4', output],
      ], owner: 'download-mp4');
    } on Object catch (error) {
      return "FFmpeg couldn't start: $error";
    }
    _running[output] = process;
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

    // Stuck is a copy whose file hasn't changed for a while: the second
    // pass (moving the index to the front) prints nothing, but it writes.
    var stuck = false;
    var last = _stamp(output);
    var since = DateTime.now();
    final watch = Timer.periodic(_timings.look, (_) {
      final now = _stamp(output);
      if (now != last) {
        last = now;
        since = DateTime.now();
      } else if (DateTime.now().difference(since) >= _timings.stall) {
        stuck = true;
        unawaited(process.kill());
      }
    });
    final code = await process.exitCode;
    watch.cancel();
    await Future.wait(reading);
    _running.remove(output);
    if (stuck) return 'FFmpeg stopped writing';
    if (code == 0) return null;
    final words = said.toString().trim().split('\n').last.trim();
    return 'FFmpeg ended with $code${words.isEmpty ? '' : ' ($words)'}';
  }

  (int, int)? _stamp(String path) {
    try {
      final stat = File(path).statSync();
      if (stat.type == FileSystemEntityType.notFound) return null;
      return (stat.size, stat.modified.microsecondsSinceEpoch);
    } on FileSystemException {
      return null;
    }
  }

  void _delete(String path) {
    try {
      final file = File(path);
      if (file.existsSync()) file.deleteSync();
    } on FileSystemException catch (error) {
      _log.warning(_tag, 'Could not delete a half-made MP4', error: error);
    }
  }

  /// What ffprobe reads in [path], and whether its picture carries Dolby
  /// Vision; null when ffprobe didn't answer.
  Future<(LibraryMedia, bool)?> _probe(String path) async {
    final run = await _supervisor.run(
      _ffprobe,
      [
        ...['-hide_banner', '-v', 'error'],
        ...['-print_format', 'json', '-show_format', '-show_streams'],
        ...['-i', path],
      ],
      owner: 'ffprobe',
      timeout: libraryProbeTimeout,
    );
    if (run.exitCode != 0 || run.timedOut) return null;
    final text = utf8.decode(run.stdout, allowMalformed: true);
    final media = readLibraryProbe(text);
    if (media.failed) return null;
    return (media, text.contains('DOVI configuration record'));
  }

  /// What the copy lost, or null: the same tracks in the same codecs, and
  /// the same length.
  static String? _difference(LibraryMedia from, LibraryMedia made) {
    if (made.video?.codec != from.video?.codec) return 'the picture';
    String? codecs(Iterable<String?> all) => all.join(',');
    if (codecs(made.audio.map((a) => a.codec)) !=
        codecs(from.audio.map((a) => a.codec))) {
      return 'the sound tracks';
    }
    if (made.subtitles.length != from.subtitles.length) return 'the subtitles';
    final before = from.duration;
    final after = made.duration;
    if (after == null) return 'no length';
    if (before != null && (after - before).abs() > lengthTolerance) {
      return 'its length (${after.inSeconds} s of ${before.inSeconds} s)';
    }
    return null;
  }
}
