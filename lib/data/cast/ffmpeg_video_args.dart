import 'package:flutter/foundation.dart';
import 'package:iptv_player/core/cast/cast_encoders.dart';
import 'package:iptv_player/core/cast/cast_plan.dart';
import 'package:iptv_player/core/cast/stream_facts.dart';

/// FFmpeg's arguments for a re-encoded picture: [input] goes before its
/// `-i`, [output] after the maps; [environment] is the process's.
@immutable
final class FfmpegVideoArgs {
  const new({
    required this.input,
    required this.output,
    this.environment = const {},
  });

  final List<String> input;
  final List<String> output;
  final Map<String, String> environment;

  @override
  String toString() => [...input, '-i', '…', ...output].join(' ');
}

/// The arguments that re-encode [source] to [plan] with [encoder] (docs/04
/// rules 2 and 3, ADR-014 step 4). On the encoder's chip when it decodes
/// the source, so the picture never reaches the processor; on the
/// processor otherwise, then handed to the encoder. Interlaced pictures
/// become one picture per field (`send_field`, as the plan's frame rate
/// assumes); a picture is only ever made smaller. [libvaEnvironment] is
/// how the process finds the bundled libva, for an encoder that needs it.
FfmpegVideoArgs videoTranscodeArgs({
  required CastVideoTranscode plan,
  required CastEncoder encoder,
  required VideoFacts source,
  Map<String, String> libvaEnvironment = const {},
  bool windows = false,
}) {
  final kind = encoder.kind;
  final onChip = kind.hardware && encoder.decodesOnChip(source);
  final height = plan.height;
  final sourceHeight = source.height;
  // An unknown height is only ever made smaller.
  final scaleTo = sourceHeight == null
      ? 'min(ih\\,$height)'
      : height < sourceHeight
      ? '$height'
      : null;
  final device = encoder.device;

  final input = <String>[];
  final filters = <String>[];
  switch ((kind, onChip)) {
    case (CastEncoderKind.nvenc, true):
      input.addAll(['-hwaccel', 'cuda', '-hwaccel_output_format', 'cuda']);
      if (plan.deinterlace) {
        filters.add('bwdif_cuda=mode=send_field:parity=auto:deint=all');
      }
      // Also 10-bit to 8: H.264 on a TV is 8-bit.
      filters.add(
        'scale_cuda=${scaleTo == null ? '' : 'w=-2:h=$scaleTo:'}format=nv12',
      );
    case (CastEncoderKind.vaapi, true):
      input.addAll([
        '-hwaccel',
        'vaapi',
        if (device != null) ...['-hwaccel_device', device],
        '-hwaccel_output_format',
        'vaapi',
      ]);
      // The driver's best method, at one picture per field.
      if (plan.deinterlace) filters.add('deinterlace_vaapi=rate=field');
      filters.add(
        'scale_vaapi=${scaleTo == null ? '' : 'w=-2:h=$scaleTo:'}format=nv12',
      );
    case (CastEncoderKind.qsv, true):
      input.addAll([
        ..._qsvDevice(device, windows: windows),
        ...['-hwaccel', 'qsv', '-hwaccel_device', 'cast'],
        ...['-hwaccel_output_format', 'qsv'],
        ...['-c:v', _qsvDecoder(source)],
      ]);
      filters.add(
        [
          'vpp_qsv=',
          if (plan.deinterlace) 'deinterlace=2:rate=field:',
          if (scaleTo != null) 'w=${_qsvWidth(source, height)}:h=$scaleTo:',
          'format=nv12',
        ].join(),
      );
    case (_, _):
      // AMF's chip decodes through Direct3D 11 and hands the pictures
      // back: the filters run on the processor either way.
      if (kind == CastEncoderKind.amf && onChip) {
        input.addAll(['-hwaccel', 'd3d11va']);
      }
      if (kind == CastEncoderKind.vaapi) {
        input.addAll([
          ...[
            '-init_hw_device',
            'vaapi=cast${device == null ? '' : ':$device'}',
          ],
          ...['-filter_hw_device', 'cast'],
        ]);
      } else if (kind == CastEncoderKind.qsv) {
        input.addAll([
          ..._qsvDevice(device, windows: windows),
          ...['-filter_hw_device', 'cast'],
        ]);
      }
      if (plan.deinterlace) {
        filters.add('bwdif=mode=send_field:parity=auto:deint=all');
      }
      if (scaleTo != null) filters.add('scale=w=-2:h=$scaleTo');
      filters.addAll(switch (kind) {
        CastEncoderKind.vaapi => ['format=nv12', 'hwupload'],
        CastEncoderKind.qsv => ['format=nv12', 'hwupload=extra_hw_frames=64'],
        CastEncoderKind.amf => ['format=nv12'],
        CastEncoderKind.nvenc || CastEncoderKind.x264 => ['format=yuv420p'],
      });
  }

  final bitRate = plan.bitRate;
  // Two seconds a keyframe: docs/04's HLS segments.
  final fps = plan.fps ?? source.fps ?? 25;
  final gop = (fps * 2).round().clamp(1, 600);
  final output = [
    ...['-vf', filters.join(',')],
    ...['-c:v', kind.ffmpegName],
    ...switch (kind) {
      CastEncoderKind.nvenc => ['-preset', 'p4', '-rc', 'vbr'],
      CastEncoderKind.vaapi => ['-rc_mode', 'VBR'],
      CastEncoderKind.qsv => ['-preset', 'medium'],
      CastEncoderKind.amf => ['-usage', 'transcoding', '-rc', 'vbr_peak'],
      CastEncoderKind.x264 => ['-preset', 'veryfast'],
    },
    ...['-profile:v', 'high'],
    ...['-b:v', '$bitRate', '-maxrate', '${(bitRate * 1.5).round()}'],
    ...['-bufsize', '${bitRate * 2}'],
    ...['-g', '$gop'],
  ];
  return FfmpegVideoArgs(
    input: input,
    output: output,
    environment: encoder.bundledLibva ? libvaEnvironment : const {},
  );
}

/// Quick Sync's device, named `cast`: on the render node's VA-API on
/// Linux, on Direct3D 11 on Windows.
List<String> _qsvDevice(String? device, {required bool windows}) {
  final child = windows
      ? ',child_device_type=d3d11va'
      : device == null
      ? ''
      : ',child_device=$device';
  return ['-init_hw_device', 'qsv=cast:hw_any$child'];
}

/// Quick Sync decodes with its own decoders, not FFmpeg's.
String _qsvDecoder(VideoFacts source) => switch (HardwareDecode.of(source)) {
  HardwareDecode.hevc || HardwareDecode.hevc10 => 'hevc_qsv',
  HardwareDecode.mpeg2 => 'mpeg2_qsv',
  _ => 'h264_qsv',
};

/// vpp_qsv takes no `-2`: the width that keeps the shape, even.
String _qsvWidth(VideoFacts source, int height) {
  final width = source.width;
  final sourceHeight = source.height;
  if (width == null || sourceHeight == null || sourceHeight <= 0) return '-1';
  final scaled = (width * height / sourceHeight / 2).round() * 2;
  return '${scaled < 2 ? 2 : scaled}';
}
