import 'package:flutter/foundation.dart';
import 'package:iptv_player/core/cast/stream_facts.dart';

/// The H.264 encoders a re-encode can use (docs/04 rule 3).
enum CastEncoderKind {
  nvenc('h264_nvenc', 'NVENC'),
  vaapi('h264_vaapi', 'VA-API'),
  qsv('h264_qsv', 'Quick Sync'),
  amf('h264_amf', 'AMF'),

  /// The processor: for 1080p and below only (docs/04 rule 3).
  x264('libx264', 'libx264');

  new(this.ffmpegName, this.label);

  /// FFmpeg's name for it.
  final String ffmpegName;

  /// For the log and Details.
  final String label;

  bool get hardware => this != x264;

  /// docs/04 rule 3's order, which detection tries and keeps.
  static List<CastEncoderKind> order({required bool windows}) =>
      windows ? const [nvenc, qsv, amf, x264] : const [nvenc, vaapi, qsv, x264];
}

/// The kinds of picture a hardware encoder's own chip decodes as well, so
/// a re-encode never decodes them on the processor (transcoding HEVC 4K
/// would otherwise cost about a core: ADR-014 step 4).
enum HardwareDecode {
  /// 8-bit 4:2:0 H.264. No Cast-era chip decodes High 10 or 4:2:2.
  h264,

  /// HEVC Main.
  hevc,

  /// HEVC Main 10.
  hevc10,

  /// MPEG-2 video: SD channels, often interlaced.
  mpeg2;

  /// The kind [video] is, or null when only the processor decodes it
  /// (10-bit H.264, HEVC range extensions, VC-1, VP9, AV1…).
  static HardwareDecode? of(VideoFacts video) {
    final depth = video.bitDepth ?? 8;
    final profile = video.profile?.toLowerCase() ?? '';
    switch (video.codec) {
      case 'h264':
        if (depth > 8) return null;
        if (profile.contains('10') ||
            profile.contains('4:2:2') ||
            profile.contains('4:4:4')) {
          return null;
        }
        return h264;
      case 'hevc':
        if (depth > 10) return null;
        if (profile.isEmpty || profile == 'unknown' || profile == 'main') {
          return depth == 10 ? hevc10 : hevc;
        }
        if (profile == 'main 10') return hevc10;
        return null;
      case 'mpeg2video':
        return depth > 8 ? null : mpeg2;
      default:
        return null;
    }
  }
}

/// One encoder that works on this computer, as detection found it.
@immutable
final class CastEncoder {
  const new(
    this.kind, {
    this.device,
    this.decodes = const {},
    this.bundledLibva = false,
  });

  final CastEncoderKind kind;

  /// The VA-API render node (`/dev/dri/renderD129`) VA-API and Quick Sync
  /// use on Linux; null otherwise.
  final String? device;

  /// What its chip decodes too (only a hardware encoder's).
  final Set<HardwareDecode> decodes;

  /// VA-API through the libva the app bundles: this system's own is older
  /// than the bundled FFmpeg needs (libva 2.21, ADR-014 step 4).
  final bool bundledLibva;

  /// Whether [video] is decoded on the encoder's chip.
  bool decodesOnChip(VideoFacts video) {
    final kind = HardwareDecode.of(video);
    return kind != null && decodes.contains(kind);
  }

  @override
  bool operator ==(Object other) =>
      other is CastEncoder &&
      other.kind == kind &&
      other.device == device &&
      setEquals(other.decodes, decodes) &&
      other.bundledLibva == bundledLibva;

  @override
  int get hashCode =>
      Object.hash(kind, device, Object.hashAllUnordered(decodes), bundledLibva);

  /// `VA-API on renderD129 (bundled libva; decodes h264, hevc)`.
  @override
  String toString() {
    final notes = [
      if (bundledLibva) 'bundled libva',
      if (decodes.isNotEmpty)
        'decodes ${[for (final d in HardwareDecode.values)
          if (decodes.contains(d)) d.name].join(', ')}',
    ];
    final on = device == null ? '' : ' on ${device!.split('/').last}';
    return '${kind.label}$on${notes.isEmpty ? '' : ' (${notes.join('; ')})'}';
  }
}

/// What this computer can re-encode a cast with.
@immutable
final class CastEncoders {
  const new(this.available);

  /// Nothing works: a plan that re-encodes can't be cast.
  static const none = CastEncoders([]);

  /// In docs/04's order: hardware first, libx264 last.
  final List<CastEncoder> available;

  /// The one to use.
  CastEncoder? get best => available.isEmpty ? null : available.first;

  bool get canTranscode => available.isNotEmpty;

  /// No hardware encoder: a re-encode runs on the processor and stays at
  /// 1080p or below (`CastPlanRequest.softwareEncoderOnly`).
  bool get softwareOnly => !available.any((e) => e.kind.hardware);

  /// The next to try after [failed] failed on a stream, if any.
  CastEncoder? after(CastEncoderKind failed) {
    final at = available.indexWhere((e) => e.kind == failed);
    if (at < 0) return best;
    return at + 1 < available.length ? available[at + 1] : null;
  }

  @override
  bool operator ==(Object other) =>
      other is CastEncoders && listEquals(other.available, available);

  @override
  int get hashCode => Object.hashAll(available);

  @override
  String toString() => available.isEmpty ? 'no encoder' : available.join(', ');
}

/// Finds the encoders (Phase 7 step 4): a one-second test encode per
/// candidate, and a test decode of each kind of picture on its chip.
abstract interface class CastEncoderDetection {
  /// What works here: remembered for this FFmpeg, else tested. Never
  /// throws; [CastEncoders.none] when nothing works or FFmpeg is missing.
  Future<CastEncoders> encoders();

  /// Tests again, whatever was remembered: a re-encode failed.
  Future<CastEncoders> detectAgain();
}

/// A build without FFmpeg: nothing can re-encode (`castReadinessProvider`
/// already says why).
final class NoCastEncoders implements CastEncoderDetection {
  const new();

  @override
  Future<CastEncoders> encoders() async => CastEncoders.none;

  @override
  Future<CastEncoders> detectAgain() async => CastEncoders.none;
}
