import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:isolate';

import 'package:iptv_player/core/cast/cast_subtitles.dart';
import 'package:iptv_player/core/logging/app_log.dart';
import 'package:iptv_player/core/text/languages.dart';
import 'package:iptv_player/data/cast/ffmpeg_binaries.dart';
import 'package:iptv_player/data/cast/relay/relay_job.dart';
import 'package:iptv_player/data/cast/webvtt.dart';
import 'package:iptv_player/data/library/library_probe.dart';
import 'package:iptv_player/data/library/library_scan.dart' show subtitleBeside;
import 'package:iptv_player/data/process/process_supervisor.dart';
import 'package:path/path.dart' as p;

const _tag = 'cast';

/// How long each of [FfmpegCastSubtitles]' FFmpeg runs may take.
typedef CastSubtitleTimings = ({
  /// One subtitle file beside the video.
  Duration beside,

  /// The video's own tracks: the whole file is read for them.
  Duration own,

  /// Asking where a relayed stream starts.
  Duration start,
});

/// [CastSubtitles] with the bundled FFmpeg and ffprobe, supervised (hard
/// rule 8): each run has an owner, a timeout and the supervisor's PID
/// file, and a set's runs are killed when it is deleted.
///
/// The files go into the folder it is given, one folder a set. The app
/// gives it the relay's own folder for this run, so whatever a crash
/// leaves there goes with the relay's segments at the next launch
/// (docs/04 "On app start").
final class FfmpegCastSubtitles implements CastSubtitles {
  new({
    required this._supervisor,
    required this._binaries,
    required this._folder,
    required this._log,
    List<String> Function()? languages,
    this._timings = (
      beside: const Duration(seconds: 30),
      own: const Duration(minutes: 10),
      start: const Duration(seconds: 10),
    ),
  }) : _languages = languages ?? (() => const []);

  final ProcessSupervisor _supervisor;
  final FfmpegBinaries _binaries;
  final Directory _folder;
  final AppLog _log;

  /// Settings → Playback's subtitle languages: the guess for a subtitle
  /// file that is neither Unicode nor named for a language.
  final List<String> Function() _languages;
  final CastSubtitleTimings _timings;
  var _sets = 0;

  @override
  CastSubtitleSet prepare(String video, {List<String> beside = const []}) {
    final set = _Set(
      this,
      Directory(p.join(_folder.path, 'subtitles-${++_sets}')),
    );
    unawaited(set._make(video, beside));
    return set;
  }

  @override
  Future<Duration> startOf(
    String video, {
    required Duration at,
    required CastCopiedStreams copied,
  }) async {
    final audio = copied.audioTrack;
    if (at <= Duration.zero || (!copied.video && audio == null)) return at;
    // The relay's own way in: the same flags, the same `-ss`, the picture
    // mapped (FFmpeg seeks by it). Each stream's first packet is printed
    // with its time counted from [at]: the picture's on standard output,
    // the sound's on standard error.
    final run = await _supervisor.run(
      _binaries.ffmpeg,
      [
        ...['-hide_banner', '-v', 'fatal', '-nostdin'],
        ...relayInputFlags,
        ...['-ss', (at.inMilliseconds / 1000).toStringAsFixed(3)],
        ...['-i', video],
        ...['-map', '0:V:0', '-c', 'copy', '-frames:v', '1'],
        ...['-f', 'framecrc', 'pipe:1'],
        if (audio != null) ...[
          ...['-map', '0:a:$audio', '-c', 'copy', '-frames:a', '1'],
          ...['-f', 'framecrc', 'pipe:2'],
        ],
      ],
      owner: 'cast-start',
      timeout: _timings.start,
    );
    if (run.exitCode != 0 || run.timedOut) {
      _log.info(_tag, 'Where the relayed file starts is not known');
      return at;
    }
    final firsts = [
      if (copied.video)
        ?firstPacketTime(utf8.decode(run.stdout, allowMalformed: true)),
      if (audio != null) ?firstPacketTime(run.stderr),
    ];
    // What isn't copied starts at [at], or with what is.
    var earliest = Duration.zero;
    for (final first in firsts) {
      if (first < earliest) earliest = first;
    }
    final start = at + earliest;
    return start < Duration.zero ? Duration.zero : start;
  }

  /// FFmpeg to its end for [set]: its exit code (null when it didn't
  /// start, or was stopped) and the last it said.
  Future<(int?, String)> _run(
    _Set set,
    List<String> arguments, {
    required String owner,
    required Duration timeout,
  }) async {
    if (set._deleted) return (null, 'stopped');
    final SupervisedProcess process;
    try {
      process = await _supervisor.start(
        _binaries.ffmpeg,
        ['-hide_banner', '-v', 'error', '-nostdin', '-y', ...arguments],
        owner: owner,
        timeout: timeout,
      );
    } on Object catch (error) {
      return (null, "FFmpeg couldn't start: $error");
    }
    set._running.add(process);
    if (set._deleted) unawaited(process.kill());
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
    final code = await process.exitCode;
    await Future.wait(reading);
    set._running.remove(process);
    if (set._deleted) return (null, 'stopped');
    if (process.timedOut) return (null, 'took too long');
    return (code, said.toString().trim().split('\n').last.trim());
  }
}

/// A subtitle's text is small, and read where it is asked for. Text that
/// isn't (a "subtitle" of megabytes) is worked on away from the UI
/// isolate (hard rule 2).
const _muchText = 200000;

Future<int> _cuesIn(String text) => text.length > _muchText
    ? Isolate.run(() => webVttCues(text))
    : Future.value(webVttCues(text));

Future<String> _movedBack(String text, Duration by) => text.length > _muchText
    ? Isolate.run(() => shiftWebVtt(text, by))
    : Future.value(shiftWebVtt(text, by));

/// The time of the first packet in `-f framecrc` output, in its stream's
/// own time base: null when [text] holds none.
Duration? firstPacketTime(String text) {
  final base = RegExp(r'^#tb 0: (\d+)/(\d+)', multiLine: true).firstMatch(text);
  final packet = RegExp(r'^\s*0,\s*(-?\d+),', multiLine: true).firstMatch(text);
  if (base == null || packet == null) return null;
  final unit = int.parse(base[2]!);
  final dts = int.tryParse(packet[1]!);
  // A packet with no time prints as the smallest number there is.
  const most = 1 << 53;
  if (unit == 0 || dts == null || dts < -most || dts > most) return null;
  return Duration(
    microseconds: (dts * int.parse(base[1]!) * 1e6 / unit).round(),
  );
}

/// The code page FFmpeg should read a subtitle file with when its bytes
/// aren't Unicode: the one its [language] was commonly written in, by
/// the file's own tag or else the first of [hints]; Windows-1252
/// otherwise. Null for Unicode ([bytes] is UTF-8, or opens with a byte
/// order mark), which FFmpeg reads as it is.
String? subtitleCodePage(
  List<int> bytes, {
  String? language,
  List<String> hints = const [],
}) {
  bool opens(List<int> mark) =>
      bytes.length >= mark.length &&
      [for (var i = 0; i < mark.length; i++) bytes[i]].join(',') ==
          mark.join(',');
  if (opens(const [0xEF, 0xBB, 0xBF]) ||
      opens(const [0xFF, 0xFE]) ||
      opens(const [0xFE, 0xFF])) {
    return null;
  }
  try {
    utf8.decode(bytes);
    return null;
  } on FormatException {
    // Not UTF-8: an older code page.
  }
  final code = language ?? hints.firstOrNull;
  return (code == null ? null : _codePages[languageTag(code)]) ?? 'CP1252';
}

const _codePages = {
  // Arabic script.
  'ar': 'CP1256', 'fa': 'CP1256', 'ur': 'CP1256', 'ku': 'CP1256',
  // Cyrillic.
  'ru': 'CP1251', 'uk': 'CP1251', 'ukr': 'CP1251', 'bg': 'CP1251',
  'bul': 'CP1251', 'sr': 'CP1251', 'srp': 'CP1251', 'mk': 'CP1251',
  'be': 'CP1251',
  'el': 'CP1253',
  'tr': 'CP1254', 'az': 'CP1254',
  'he': 'CP1255',
  // Central Europe.
  'pl': 'CP1250', 'cs': 'CP1250', 'cze': 'CP1250', 'ces': 'CP1250',
  'sk': 'CP1250', 'slo': 'CP1250', 'slk': 'CP1250', 'hu': 'CP1250',
  'hun': 'CP1250', 'ro': 'CP1250', 'rum': 'CP1250', 'ron': 'CP1250',
  'hr': 'CP1250', 'hrv': 'CP1250', 'sl': 'CP1250', 'slv': 'CP1250',
  'bs': 'CP1250', 'sq': 'CP1250',
  // The Baltic.
  'lt': 'CP1257', 'lit': 'CP1257', 'lv': 'CP1257', 'lav': 'CP1257',
  'et': 'CP1257', 'est': 'CP1257',
  'vi': 'CP1258', 'vie': 'CP1258',
  'th': 'CP874', 'tha': 'CP874',
  'ja': 'CP932', 'ko': 'CP949', 'zh': 'GB18030',
};

final class _Set implements CastSubtitleSet {
  new(this._owner, this._folder);

  final FfmpegCastSubtitles _owner;
  final Directory _folder;
  final _made = <(CastSubtitle, String)>[];
  final _done = Completer<void>();
  final _running = <SupervisedProcess>{};
  var _deleted = false;
  var _moves = 0;
  Directory? _moved;

  AppLog get _log => _owner._log;

  @override
  List<CastSubtitle> get subtitles => [
    for (final (subtitle, _) in _made) subtitle,
  ];

  @override
  Future<void> get done => _done.future;

  Future<void> _make(String video, List<String> beside) async {
    final clock = Stopwatch()..start();
    var own = 0;
    try {
      _folder.createSync(recursive: true);
      // The file's own tracks are read while the files beside it are
      // made, and listed after them.
      final embedded = _own(video);
      final external = await Future.wait([
        for (final (index, file) in beside.indexed) _beside(video, file, index),
      ]);
      if (!_deleted) _made.addAll(external.nonNulls);
      final tracks = await embedded;
      own = tracks.length;
      if (!_deleted) _made.addAll(tracks);
    } on Object catch (error) {
      // A full drive, a folder that can't be made: no subtitles.
      _log.warning(_tag, 'The subtitles could not be made', error: error);
    }
    if (!_deleted && (beside.isNotEmpty || own > 0)) {
      _log.info(
        _tag,
        'Subtitles for the TV: ${_made.length - own} beside the file, '
        '$own of its own, in ${clock.elapsedMilliseconds} ms',
      );
    }
    _done.complete();
  }

  /// A subtitle file beside the video, as WebVTT; null when FFmpeg
  /// can't read it or it says nothing.
  Future<(CastSubtitle, String)?> _beside(
    String video,
    String file,
    int index,
  ) async {
    final named = subtitleBeside(video, file);
    String? page;
    try {
      final source = File(file);
      // A subtitle file is small; anything else is read as it is.
      if (await source.length() <= 2 << 20) {
        page = subtitleCodePage(
          await source.readAsBytes(),
          language: named?.language,
          hints: _owner._languages(),
        );
      }
    } on FileSystemException {
      return null;
    }
    final output = p.join(_folder.path, 'beside-$index.vtt');
    final (code, said) = await _owner._run(
      this,
      [
        if (page != null) ...['-sub_charenc', page],
        ...['-i', file],
        ...['-map', '0:s:0', '-c:s', 'webvtt', '-f', 'webvtt', output],
      ],
      owner: 'cast-subtitles',
      timeout: _owner._timings.beside,
    );
    if (code != 0 || !await _hasCues(output)) {
      if (!_deleted) {
        _log.info(_tag, 'A subtitle file was left out: ${_why(code, said)}');
      }
      return null;
    }
    return (
      CastSubtitle(
        language: named?.language,
        forced: named?.forced ?? false,
        beside: true,
      ),
      output,
    );
  }

  /// The video's own text tracks, as WebVTT: all in one reading of the
  /// file, or one by one when that fails (the rest still come).
  Future<List<(CastSubtitle, String)>> _own(String video) async {
    final media = await probeLibraryFile(
      _owner._supervisor,
      _owner._binaries.ffprobe,
      video,
    );
    // Where each is among the file's subtitle streams: FFmpeg's `0:s:<n>`.
    final tracks = [
      for (final (index, track) in media.subtitles.indexed)
        if (track.isText)
          (
            index,
            CastSubtitle(
              language: track.language,
              title: track.title,
              forced: track.forced,
            ),
          ),
    ];
    if (tracks.isEmpty || _deleted) return const [];
    String output(int index) => p.join(_folder.path, 'own-$index.vtt');
    Future<(int?, String)> read(List<int> indexes) => _owner._run(
      this,
      [
        ...['-i', video],
        for (final index in indexes) ...[
          ...['-map', '0:s:$index', '-c:s', 'webvtt'],
          ...['-f', 'webvtt', output(index)],
        ],
      ],
      owner: 'cast-subtitles',
      timeout: _owner._timings.own,
    );
    final (code, said) = await read([for (final (index, _) in tracks) index]);
    if (code != 0 && code != null && tracks.length > 1) {
      for (final (index, _) in tracks) {
        await read([index]);
      }
    } else if (code != 0 && !_deleted) {
      _log.info(
        _tag,
        "The file's subtitles were left out: ${_why(code, said)}",
      );
    }
    return [
      for (final (index, subtitle) in tracks)
        if (await _hasCues(output(index))) (subtitle, output(index)),
    ];
  }

  static String _why(int? code, String said) =>
      code == null || said.isNotEmpty ? said : 'FFmpeg ended with $code';

  Future<bool> _hasCues(String path) async {
    try {
      return await _cuesIn(await File(path).readAsString()) > 0;
    } on FileSystemException {
      return false;
    } on FormatException {
      return false;
    }
  }

  @override
  Future<List<String>> files({Duration by = Duration.zero}) async {
    final made = [..._made];
    if (_deleted) return const [];
    try {
      final before = _moved;
      _moved = null;
      if (before != null && before.existsSync()) {
        before.deleteSync(recursive: true);
      }
      if (by <= Duration.zero) return [for (final (_, path) in made) path];
      final folder = _moved = Directory(
        p.join(_folder.path, 'from-${by.inMilliseconds}-${++_moves}'),
      )..createSync(recursive: true);
      final paths = <String>[];
      for (final (index, (_, path)) in made.indexed) {
        final moved = File(p.join(folder.path, '$index.vtt'));
        await moved.writeAsString(
          await _movedBack(await File(path).readAsString(), by),
        );
        paths.add(moved.path);
      }
      return paths;
    } on Object catch (error) {
      _log.warning(_tag, 'The subtitles could not be written', error: error);
      return const [];
    }
  }

  @override
  Future<void> delete() async {
    if (_deleted) return;
    _deleted = true;
    await Future.wait([
      for (final process in [..._running]) process.kill(),
    ]);
    await done;
    try {
      if (_folder.existsSync()) _folder.deleteSync(recursive: true);
    } on FileSystemException catch (error) {
      // The relay's folder goes when the app quits, and at the next launch.
      _log.info(_tag, 'A subtitles folder was left: ${error.message}');
    }
  }
}
