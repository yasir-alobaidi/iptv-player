import 'package:iptv_player/core/player/player_engine.dart';
import 'package:meta/meta.dart';

/// What decoded one kind of video the last time it played: "H.264 1080p
/// → vaapi" (Phase 9 decision 9). Diagnostics shows the list, so a
/// faulty graphics driver can be told from a slow connection.
@immutable
final class DecoderNote {
  const new({
    required this.codec,
    required this.height,
    required this.at,
    this.interlaced = false,
    this.decoder,
  });

  /// From what the player says of a stream; null when it doesn't yet
  /// know the codec or the size.
  static DecoderNote? of(StreamInfo info, DateTime at) {
    final codec = shortCodec(info.videoCodec);
    final height = info.height;
    if (codec == null || height == null || height <= 0) return null;
    return DecoderNote(
      codec: codec,
      height: height,
      interlaced: info.interlaced ?? false,
      decoder: info.hardwareDecoder,
      at: at,
    );
  }

  /// Tolerant: anything that isn't a note reads as null.
  static DecoderNote? fromJson(Object? json) {
    if (json is! Map) return null;
    final codec = json['codec'];
    final height = json['height'];
    final at = json['at'];
    final decoder = json['decoder'];
    if (codec is! String || codec.isEmpty || height is! int) return null;
    return DecoderNote(
      codec: codec,
      height: height,
      interlaced: json['interlaced'] == true,
      decoder: decoder is String && decoder.isNotEmpty ? decoder : null,
      at:
          (at is String ? DateTime.tryParse(at) : null) ??
          DateTime.fromMillisecondsSinceEpoch(0, isUtc: true),
    );
  }

  /// `H.264`, `HEVC`, `MPEG-2`.
  final String codec;
  final int height;
  final bool interlaced;

  /// mpv's `hwdec-current` (`vaapi`, `nvdec-copy`, `d3d11va`); null is
  /// the processor.
  final String? decoder;
  final DateTime at;

  /// One note per kind of video: its codec, its height and whether it is
  /// interlaced.
  String get kind => '$codec $height${interlaced ? 'i' : 'p'}';

  /// `H.264 1080p → vaapi`.
  String get line => '$kind → ${decoder ?? 'software'}';

  Map<String, Object?> toJson() => {
    'codec': codec,
    'height': height,
    'interlaced': interlaced,
    'decoder': decoder,
    'at': at.toUtc().toIso8601String(),
  };
}

/// mpv names a codec at length ("H.264 / AVC / MPEG-4 AVC / MPEG-4 part
/// 10", "HEVC (High Efficiency Video Coding)", "MPEG-2 video"): the
/// short name people use.
String? shortCodec(String? name) {
  if (name == null) return null;
  var short = name.split(' / ').first.split(' (').first.trim();
  if (short.toLowerCase().endsWith(' video')) {
    short = short.substring(0, short.length - ' video'.length).trim();
  }
  return short.isEmpty ? null : short;
}

/// Where the notes are kept. Nothing throws across it: a note that can't
/// be written is a note lost, never a playback problem.
abstract interface class DecoderNotes {
  /// Notes what decodes [info]'s video; does nothing when the player
  /// doesn't know its codec or size yet.
  Future<void> note(StreamInfo info);

  /// The newest first, one per kind of video, twenty at most.
  Future<List<DecoderNote>> recent();
}

/// Keeps nothing: tests, and a build with no database.
final class NoDecoderNotes implements DecoderNotes {
  const new();

  @override
  Future<void> note(StreamInfo info) async {}

  @override
  Future<List<DecoderNote>> recent() async => const [];
}
