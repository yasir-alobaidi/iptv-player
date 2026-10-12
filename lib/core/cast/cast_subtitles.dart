import 'package:iptv_player/core/text/languages.dart';
import 'package:meta/meta.dart';

/// A text subtitle of a video file on this computer (docs/04
/// "Subtitles"): a file beside it, or one of its own tracks. Picture
/// subtitles (PGS, VobSub) aren't cast.
@immutable
final class CastSubtitle {
  const new({
    this.language,
    this.title,
    this.forced = false,
    this.beside = false,
  });

  /// As the file's name or the track's tag has it (`en`, `eng`); null
  /// when neither says.
  final String? language;

  /// The track's own title ("SDH", "Signs & songs"), when it has one.
  final String? title;

  /// Only the foreign parts of the sound.
  final bool forced;

  /// A file the user put beside the video, not one of its own tracks.
  final bool beside;

  @override
  bool operator ==(Object other) =>
      other is CastSubtitle &&
      other.language == language &&
      other.title == title &&
      other.forced == forced &&
      other.beside == beside;

  @override
  int get hashCode => Object.hash(language, title, forced, beside);

  @override
  String toString() =>
      'CastSubtitle(${language ?? 'no language'}'
      '${title == null ? '' : ', $title'}${forced ? ', forced' : ''}'
      '${beside ? ', a file' : ''})';
}

/// What the app and the TV's own menu call the [number]th subtitle (from
/// 1): "English", "English · SDH", "German · forced", "Subtitles 3" for
/// one that names no language.
String castSubtitleLabel(CastSubtitle subtitle, int number) {
  final language = subtitle.language;
  final title = subtitle.title?.trim();
  final name = language == null ? null : languageName(language);
  return [
    name ?? (title == null || title.isEmpty ? 'Subtitles $number' : title),
    // A title that only repeats the language says nothing more.
    if (name != null &&
        title != null &&
        title.isNotEmpty &&
        title.toLowerCase() != name.toLowerCase())
      title,
    if (subtitle.forced && !(title?.toLowerCase().contains('forced') ?? false))
      'forced',
  ].join(' · ');
}

/// What a relayed file's FFmpeg copies as it is: a copied stream can only
/// begin at one of its own packets, which decides where the relay's
/// stream really starts ([CastSubtitles.startOf]).
typedef CastCopiedStreams = ({bool video, int? audioTrack});

/// The subtitles of files on this computer, made ready for a TV: each as
/// a WebVTT file the relay can serve. The data layer makes them with the
/// bundled FFmpeg, supervised (hard rule 8).
abstract interface class CastSubtitles {
  /// Starts making the text subtitles of the video at [video] into
  /// WebVTT: the files in [beside] first (the ones the user put there),
  /// then its own text tracks. Never throws.
  CastSubtitleSet prepare(String video, {List<String> beside = const []});

  /// Where the relay's stream of [video] really begins when asked to
  /// start at [at]: the TV's time 0 in the file's own time. A stream that
  /// is copied begins at the key frame before [at] (seconds earlier,
  /// often), and the rest follows it; with nothing copied it is [at].
  /// Never throws: [at] when it can't tell.
  Future<Duration> startOf(
    String video, {
    required Duration at,
    required CastCopiedStreams copied,
  });
}

/// One file's subtitles as WebVTT files, until [delete].
abstract interface class CastSubtitleSet {
  /// The ones made so far, in the order the TV lists them. The files
  /// beside the video are there within a moment; the video's own tracks
  /// follow together once the whole file has been read, which takes as
  /// long as its drive needs. One that can't be read never appears.
  List<CastSubtitle> get subtitles;

  /// Completes when [subtitles] won't grow any more.
  Future<void> get done;

  /// The WebVTT file of each of [subtitles] as it is now, in order, with
  /// its cues moved back by [by]: a relayed stream that starts past 0:00
  /// is at time 0 on the TV there, and what ended before it is left out.
  /// The files of an earlier call stop existing. Never throws: an empty
  /// list when they can't be written.
  Future<List<String>> files({Duration by = Duration.zero});

  /// Stops what is still being made, and deletes every file.
  Future<void> delete();
}

/// No subtitles on the TV (tests, a build without FFmpeg).
final class NoCastSubtitles implements CastSubtitles {
  const new();

  @override
  CastSubtitleSet prepare(String video, {List<String> beside = const []}) =>
      const _NoSet();

  @override
  Future<Duration> startOf(
    String video, {
    required Duration at,
    required CastCopiedStreams copied,
  }) async => at;
}

final class _NoSet implements CastSubtitleSet {
  const new();

  @override
  List<CastSubtitle> get subtitles => const [];

  @override
  Future<void> get done async {}

  @override
  Future<List<String>> files({Duration by = Duration.zero}) async => const [];

  @override
  Future<void> delete() async {}
}
