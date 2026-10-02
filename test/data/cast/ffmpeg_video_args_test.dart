import 'package:flutter_test/flutter_test.dart';
import 'package:iptv_player/core/cast/cast_encoders.dart';
import 'package:iptv_player/core/cast/cast_plan.dart';
import 'package:iptv_player/core/cast/stream_facts.dart';
import 'package:iptv_player/data/cast/ffmpeg_video_args.dart';

const Set<HardwareDecode> _all = {
  HardwareDecode.h264,
  HardwareDecode.hevc,
  HardwareDecode.hevc10,
  HardwareDecode.mpeg2,
};

const _hevc4k = VideoFacts(
  codec: 'hevc',
  profile: 'Main',
  width: 3840,
  height: 2160,
  fps: 25,
  bitDepth: 8,
);

const _mpeg2 = VideoFacts(
  codec: 'mpeg2video',
  profile: 'Main',
  width: 720,
  height: 576,
  fps: 25,
  interlaced: true,
  bitDepth: 8,
);

const _to1080 = CastVideoTranscode(
  height: 1080,
  bitRate: 8000000,
  fps: 25,
  reasons: [TranscodeReason.aboveLearnedHeight],
);

const _deinterlaced = CastVideoTranscode(
  height: 576,
  bitRate: 3000000,
  fps: 50,
  deinterlace: true,
  reasons: [TranscodeReason.codecUnsupported],
);

/// The value after [flag].
String? _after(List<String> args, String flag) {
  final at = args.indexOf(flag);
  return at < 0 || at + 1 >= args.length ? null : args[at + 1];
}

void main() {
  group('NVENC', () {
    test('HEVC 4K decoded, scaled and encoded on the chip', () {
      final args = videoTranscodeArgs(
        plan: _to1080,
        encoder: const CastEncoder(CastEncoderKind.nvenc, decodes: _all),
        source: _hevc4k,
      );
      expect(args.input, [
        ...['-hwaccel', 'cuda', '-hwaccel_output_format', 'cuda'],
      ]);
      expect(args.output, [
        ...['-vf', 'scale_cuda=w=-2:h=1080:format=nv12'],
        ...['-c:v', 'h264_nvenc', '-preset', 'p4', '-rc', 'vbr'],
        ...['-profile:v', 'high'],
        ...['-b:v', '8000000', '-maxrate', '12000000'],
        ...['-bufsize', '16000000', '-g', '50'],
      ]);
      expect(args.environment, isEmpty);
    });

    test('MPEG-2 576i: one picture per field on the chip, not scaled', () {
      final args = videoTranscodeArgs(
        plan: _deinterlaced,
        encoder: const CastEncoder(CastEncoderKind.nvenc, decodes: _all),
        source: _mpeg2,
      );
      expect(
        _after(args.output, '-vf'),
        'bwdif_cuda=mode=send_field:parity=auto:deint=all,'
        'scale_cuda=format=nv12',
      );
      // Two seconds at 50 pictures a second.
      expect(_after(args.output, '-g'), '100');
    });

    test("a picture its chip doesn't decode: the processor, then NVENC", () {
      final args = videoTranscodeArgs(
        plan: _deinterlaced,
        encoder: const CastEncoder(
          CastEncoderKind.nvenc,
          decodes: {HardwareDecode.hevc},
        ),
        source: _mpeg2,
      );
      expect(args.input, isEmpty);
      expect(
        _after(args.output, '-vf'),
        'bwdif=mode=send_field:parity=auto:deint=all,format=yuv420p',
      );
      expect(_after(args.output, '-c:v'), 'h264_nvenc');
    });
  });

  group('VA-API', () {
    const vaapi = CastEncoder(
      CastEncoderKind.vaapi,
      device: '/dev/dri/renderD129',
      decodes: _all,
      bundledLibva: true,
    );
    const libva = {'LD_LIBRARY_PATH': '/app/ffmpeg/libva'};

    test('on its render node, with the bundled libva when it needs it', () {
      final args = videoTranscodeArgs(
        plan: _to1080,
        encoder: vaapi,
        source: _hevc4k,
        libvaEnvironment: libva,
      );
      expect(args.input, [
        ...['-hwaccel', 'vaapi', '-hwaccel_device', '/dev/dri/renderD129'],
        ...['-hwaccel_output_format', 'vaapi'],
      ]);
      expect(args.output, [
        ...['-vf', 'scale_vaapi=w=-2:h=1080:format=nv12'],
        ...['-c:v', 'h264_vaapi', '-rc_mode', 'VBR'],
        ...['-profile:v', 'high'],
        ...['-b:v', '8000000', '-maxrate', '12000000'],
        ...['-bufsize', '16000000', '-g', '50'],
      ]);
      expect(args.environment, libva);
    });

    test("with the system's libva, no environment", () {
      final args = videoTranscodeArgs(
        plan: _to1080,
        encoder: const CastEncoder(
          CastEncoderKind.vaapi,
          device: '/dev/dri/renderD128',
          decodes: _all,
        ),
        source: _hevc4k,
        libvaEnvironment: libva,
      );
      expect(args.environment, isEmpty);
    });

    test("deinterlacing with the driver's best method, at field rate", () {
      final args = videoTranscodeArgs(
        plan: _deinterlaced,
        encoder: vaapi,
        source: _mpeg2,
      );
      expect(
        _after(args.output, '-vf'),
        'deinterlace_vaapi=rate=field,scale_vaapi=format=nv12',
      );
    });

    test("decoded on the processor: uploaded to the render node's device", () {
      final args = videoTranscodeArgs(
        plan: _to1080,
        encoder: const CastEncoder(
          CastEncoderKind.vaapi,
          device: '/dev/dri/renderD129',
        ),
        source: _hevc4k,
      );
      expect(args.input, [
        ...['-init_hw_device', 'vaapi=cast:/dev/dri/renderD129'],
        ...['-filter_hw_device', 'cast'],
      ]);
      expect(
        _after(args.output, '-vf'),
        'scale=w=-2:h=1080,format=nv12,hwupload',
      );
    });
  });

  group('Quick Sync', () {
    test("Linux: on the render node's VA-API, with its own decoder", () {
      final args = videoTranscodeArgs(
        plan: _to1080,
        encoder: const CastEncoder(
          CastEncoderKind.qsv,
          device: '/dev/dri/renderD128',
          decodes: _all,
        ),
        source: _hevc4k,
      );
      expect(args.input, [
        ...[
          '-init_hw_device',
          'qsv=cast:hw_any,child_device=/dev/dri/renderD128',
        ],
        ...['-hwaccel', 'qsv', '-hwaccel_device', 'cast'],
        ...['-hwaccel_output_format', 'qsv', '-c:v', 'hevc_qsv'],
      ]);
      // vpp_qsv takes no -2: the width that keeps the shape.
      expect(_after(args.output, '-vf'), 'vpp_qsv=w=1920:h=1080:format=nv12');
      expect(args.output.sublist(2, 6), [
        '-c:v',
        'h264_qsv',
        '-preset',
        'medium',
      ]);
    });

    test('Windows: on Direct3D 11', () {
      final args = videoTranscodeArgs(
        plan: _deinterlaced,
        encoder: const CastEncoder(CastEncoderKind.qsv, decodes: _all),
        source: _mpeg2,
        windows: true,
      );
      expect(
        _after(args.input, '-init_hw_device'),
        'qsv=cast:hw_any,child_device_type=d3d11va',
      );
      expect(_after(args.input, '-c:v'), 'mpeg2_qsv');
      expect(
        _after(args.output, '-vf'),
        'vpp_qsv=deinterlace=2:rate=field:format=nv12',
      );
    });

    test('decoded on the processor: uploaded with room for its frames', () {
      final args = videoTranscodeArgs(
        plan: _to1080,
        encoder: const CastEncoder(CastEncoderKind.qsv),
        source: _hevc4k,
        windows: true,
      );
      expect(args.input, [
        ...['-init_hw_device', 'qsv=cast:hw_any,child_device_type=d3d11va'],
        ...['-filter_hw_device', 'cast'],
      ]);
      expect(
        _after(args.output, '-vf'),
        'scale=w=-2:h=1080,format=nv12,hwupload=extra_hw_frames=64',
      );
    });
  });

  group('AMF', () {
    test('decoded through Direct3D 11, filtered on the processor', () {
      final args = videoTranscodeArgs(
        plan: _deinterlaced,
        encoder: const CastEncoder(CastEncoderKind.amf, decodes: _all),
        source: _mpeg2,
        windows: true,
      );
      expect(args.input, ['-hwaccel', 'd3d11va']);
      expect(
        _after(args.output, '-vf'),
        'bwdif=mode=send_field:parity=auto:deint=all,format=nv12',
      );
      expect(args.output.sublist(2, 8), [
        '-c:v',
        'h264_amf',
        '-usage',
        'transcoding',
        '-rc',
        'vbr_peak',
      ]);
    });

    test("a picture its chip doesn't decode: no hwaccel at all", () {
      final args = videoTranscodeArgs(
        plan: _to1080,
        encoder: const CastEncoder(CastEncoderKind.amf),
        source: _hevc4k,
        windows: true,
      );
      expect(args.input, isEmpty);
    });
  });

  group('libx264', () {
    test('the processor only, veryfast (docs/04 rule 3)', () {
      final args = videoTranscodeArgs(
        plan: _to1080,
        encoder: const CastEncoder(CastEncoderKind.x264),
        source: _hevc4k,
      );
      expect(args.input, isEmpty);
      expect(args.output, [
        ...['-vf', 'scale=w=-2:h=1080,format=yuv420p'],
        ...['-c:v', 'libx264', '-preset', 'veryfast'],
        ...['-profile:v', 'high'],
        ...['-b:v', '8000000', '-maxrate', '12000000'],
        ...['-bufsize', '16000000', '-g', '50'],
      ]);
    });

    test('its decodes, if any were claimed, change nothing', () {
      final args = videoTranscodeArgs(
        plan: _to1080,
        encoder: const CastEncoder(CastEncoderKind.x264, decodes: _all),
        source: _hevc4k,
      );
      expect(args.input, isEmpty);
    });
  });

  group('every encoder', () {
    final encoders = [
      const CastEncoder(CastEncoderKind.nvenc, decodes: _all),
      const CastEncoder(CastEncoderKind.nvenc),
      const CastEncoder(CastEncoderKind.vaapi, device: '/d', decodes: _all),
      const CastEncoder(CastEncoderKind.vaapi, device: '/d'),
      const CastEncoder(CastEncoderKind.qsv, device: '/d', decodes: _all),
      const CastEncoder(CastEncoderKind.qsv, device: '/d'),
      const CastEncoder(CastEncoderKind.amf, decodes: _all),
      const CastEncoder(CastEncoderKind.x264),
    ];

    test('a picture is never made taller: no scaling at its height', () {
      const same = CastVideoTranscode(
        height: 2160,
        bitRate: 20000000,
        fps: 25,
        reasons: [TranscodeReason.hevcRefused],
      );
      for (final encoder in encoders) {
        final filters = _after(
          videoTranscodeArgs(
            plan: same,
            encoder: encoder,
            source: _hevc4k,
          ).output,
          '-vf',
        )!;
        expect(filters, isNot(contains('h=')), reason: '$encoder');
      }
    });

    test('an unknown height is only ever made smaller', () {
      const unknown = VideoFacts(codec: 'hevc', profile: 'Main', fps: 25);
      for (final encoder in encoders) {
        final filters = _after(
          videoTranscodeArgs(
            plan: _to1080,
            encoder: encoder,
            source: unknown,
          ).output,
          '-vf',
        )!;
        expect(filters, contains(r'h=min(ih\,1080)'), reason: '$encoder');
      }
    });

    test('8-bit H.264 High, the bit rate, a keyframe every 2 s', () {
      for (final encoder in encoders) {
        final output = videoTranscodeArgs(
          plan: _to1080,
          encoder: encoder,
          source: _hevc4k,
        ).output;
        expect(_after(output, '-c:v'), encoder.kind.ffmpegName);
        expect(_after(output, '-profile:v'), 'high');
        expect(_after(output, '-b:v'), '8000000');
        expect(_after(output, '-maxrate'), '12000000');
        expect(_after(output, '-bufsize'), '16000000');
        expect(_after(output, '-g'), '50');
        // Every chain ends in 8-bit 4:2:0.
        final filters = _after(output, '-vf')!;
        expect(
          filters.contains('format=nv12') || filters.contains('format=yuv420p'),
          isTrue,
          reason: '$encoder: $filters',
        );
      }
    });

    test('deinterlacing whenever the plan asks, never otherwise', () {
      for (final encoder in encoders) {
        final on = _after(
          videoTranscodeArgs(
            plan: _deinterlaced,
            encoder: encoder,
            source: _mpeg2,
          ).output,
          '-vf',
        )!;
        final off = _after(
          videoTranscodeArgs(
            plan: const CastVideoTranscode(
              height: 576,
              bitRate: 3000000,
              fps: 25,
              reasons: [TranscodeReason.codecUnsupported],
            ),
            encoder: encoder,
            source: _mpeg2.copyWith(interlaced: false),
          ).output,
          '-vf',
        )!;
        expect(on, matches(RegExp('bwdif|deinterlace')), reason: '$encoder');
        expect(
          off,
          isNot(matches(RegExp('bwdif|deinterlace'))),
          reason: '$encoder',
        );
      }
    });

    test("no frame rate known: the source's, else 25", () {
      const plan = CastVideoTranscode(
        height: 720,
        bitRate: 4000000,
        reasons: [TranscodeReason.codecUnsupported],
      );
      const x264 = CastEncoder(CastEncoderKind.x264);
      expect(
        _after(
          videoTranscodeArgs(
            plan: plan,
            encoder: x264,
            source: const VideoFacts(codec: 'vc1', height: 720, fps: 30),
          ).output,
          '-g',
        ),
        '60',
      );
      expect(
        _after(
          videoTranscodeArgs(
            plan: plan,
            encoder: x264,
            source: const VideoFacts(codec: 'vc1', height: 720),
          ).output,
          '-g',
        ),
        '50',
      );
    });

    test('its words leave out the input', () {
      final args = videoTranscodeArgs(
        plan: _to1080,
        encoder: const CastEncoder(CastEncoderKind.x264),
        source: _hevc4k,
      );
      expect(args.toString(), contains('-i …'));
    });
  });
}
