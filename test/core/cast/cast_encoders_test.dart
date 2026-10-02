import 'package:flutter_test/flutter_test.dart';
import 'package:iptv_player/core/cast/cast_encoders.dart';
import 'package:iptv_player/core/cast/stream_facts.dart';

void main() {
  group('HardwareDecode.of', () {
    HardwareDecode? of(String? codec, {String? profile, int? depth}) =>
        HardwareDecode.of(
          VideoFacts(codec: codec, profile: profile, bitDepth: depth),
        );

    test('8-bit 4:2:0 H.264, whatever its profile says', () {
      expect(of('h264', profile: 'High', depth: 8), HardwareDecode.h264);
      expect(of('h264', profile: 'Main'), HardwareDecode.h264);
      expect(of('h264', profile: 'Constrained Baseline'), HardwareDecode.h264);
      expect(of('h264'), HardwareDecode.h264);
    });

    test('no chip decodes H.264 beyond 8 bits or 4:2:0', () {
      expect(of('h264', profile: 'High 10', depth: 10), isNull);
      expect(of('h264', depth: 10), isNull);
      expect(of('h264', profile: 'High 10 Intra'), isNull);
      expect(of('h264', profile: 'High 4:2:2'), isNull);
      expect(of('h264', profile: 'High 4:4:4 Predictive'), isNull);
    });

    test('HEVC Main and Main 10', () {
      expect(of('hevc', profile: 'Main', depth: 8), HardwareDecode.hevc);
      expect(of('hevc', profile: 'main'), HardwareDecode.hevc);
      expect(of('hevc'), HardwareDecode.hevc);
      expect(of('hevc', profile: 'Main 10', depth: 10), HardwareDecode.hevc10);
      expect(of('hevc', profile: 'Main 10'), HardwareDecode.hevc10);
      // The player says no profile, only the depth.
      expect(of('hevc', depth: 10), HardwareDecode.hevc10);
      expect(of('hevc', profile: 'unknown', depth: 10), HardwareDecode.hevc10);
    });

    test('HEVC range extensions and 12 bits on the processor', () {
      expect(of('hevc', profile: 'Rext'), isNull);
      expect(of('hevc', profile: 'Main 4:4:4'), isNull);
      expect(of('hevc', profile: 'Main 12', depth: 12), isNull);
      expect(of('hevc', depth: 12), isNull);
    });

    test('MPEG-2, and everything else on the processor', () {
      expect(of('mpeg2video', profile: 'Main'), HardwareDecode.mpeg2);
      expect(of('mpeg2video', profile: '4:2:2', depth: 10), isNull);
      for (final codec in ['vc1', 'vp9', 'av1', 'mpeg4', 'rawvideo', null]) {
        expect(of(codec), isNull, reason: '$codec');
      }
    });
  });

  group('CastEncoderKind', () {
    test("docs/04 rule 3's order on each system", () {
      expect(CastEncoderKind.order(windows: false), [
        CastEncoderKind.nvenc,
        CastEncoderKind.vaapi,
        CastEncoderKind.qsv,
        CastEncoderKind.x264,
      ]);
      expect(CastEncoderKind.order(windows: true), [
        CastEncoderKind.nvenc,
        CastEncoderKind.qsv,
        CastEncoderKind.amf,
        CastEncoderKind.x264,
      ]);
    });

    test("FFmpeg's names; only libx264 is the processor", () {
      expect(CastEncoderKind.values.map((k) => k.ffmpegName), [
        'h264_nvenc',
        'h264_vaapi',
        'h264_qsv',
        'h264_amf',
        'libx264',
      ]);
      expect(CastEncoderKind.values.where((k) => !k.hardware), [
        CastEncoderKind.x264,
      ]);
    });
  });

  group('CastEncoder', () {
    const nvenc = CastEncoder(
      CastEncoderKind.nvenc,
      decodes: {HardwareDecode.hevc, HardwareDecode.mpeg2},
    );

    test('decodes on its chip only the kinds it was found to', () {
      expect(
        nvenc.decodesOnChip(const VideoFacts(codec: 'hevc', profile: 'Main')),
        isTrue,
      );
      expect(
        nvenc.decodesOnChip(
          const VideoFacts(codec: 'hevc', profile: 'Main 10', bitDepth: 10),
        ),
        isFalse,
      );
      expect(nvenc.decodesOnChip(const VideoFacts(codec: 'h264')), isFalse);
      expect(nvenc.decodesOnChip(const VideoFacts(codec: 'vp9')), isFalse);
    });

    test('equal by value, decodes in any order', () {
      expect(
        const CastEncoder(
          CastEncoderKind.nvenc,
          decodes: {HardwareDecode.mpeg2, HardwareDecode.hevc},
        ),
        nvenc,
      );
      expect(
        const CastEncoder(
          CastEncoderKind.nvenc,
          decodes: {HardwareDecode.mpeg2, HardwareDecode.hevc},
        ).hashCode,
        nvenc.hashCode,
      );
      expect(nvenc == const CastEncoder(CastEncoderKind.nvenc), isFalse);
      expect(
        const CastEncoder(CastEncoderKind.vaapi, device: '/dev/dri/renderD128'),
        isNot(
          const CastEncoder(
            CastEncoderKind.vaapi,
            device: '/dev/dri/renderD128',
            bundledLibva: true,
          ),
        ),
      );
    });

    test('says what it is for the log', () {
      expect(
        const CastEncoder(
          CastEncoderKind.vaapi,
          device: '/dev/dri/renderD129',
          bundledLibva: true,
          decodes: {HardwareDecode.mpeg2, HardwareDecode.h264},
        ).toString(),
        'VA-API on renderD129 (bundled libva; decodes h264, mpeg2)',
      );
      expect(const CastEncoder(CastEncoderKind.x264).toString(), 'libx264');
    });
  });

  group('CastEncoders', () {
    const nvenc = CastEncoder(CastEncoderKind.nvenc);
    const vaapi = CastEncoder(CastEncoderKind.vaapi, device: '/dev/dri/r');
    const x264 = CastEncoder(CastEncoderKind.x264);

    test('the best is the first; hardware means no software cap', () {
      const all = CastEncoders([nvenc, vaapi, x264]);
      expect(all.best, nvenc);
      expect(all.canTranscode, isTrue);
      expect(all.softwareOnly, isFalse);
      expect(all.toString(), 'NVENC, VA-API on r, libx264');
    });

    test('only libx264: the planner caps re-encodes at 1080p', () {
      const software = CastEncoders([x264]);
      expect(software.best, x264);
      expect(software.canTranscode, isTrue);
      expect(software.softwareOnly, isTrue);
    });

    test('none: nothing can re-encode', () {
      expect(CastEncoders.none.best, isNull);
      expect(CastEncoders.none.canTranscode, isFalse);
      expect(CastEncoders.none.softwareOnly, isTrue);
      expect(CastEncoders.none.toString(), 'no encoder');
    });

    test('after a failure, the next one', () {
      const all = CastEncoders([nvenc, vaapi, x264]);
      expect(all.after(CastEncoderKind.nvenc), vaapi);
      expect(all.after(CastEncoderKind.vaapi), x264);
      expect(all.after(CastEncoderKind.x264), isNull);
      // One that isn't in the list: the best.
      expect(all.after(CastEncoderKind.amf), nvenc);
      expect(CastEncoders.none.after(CastEncoderKind.nvenc), isNull);
    });

    test('a build without FFmpeg finds none', () async {
      expect(await const NoCastEncoders().encoders(), CastEncoders.none);
      expect(await const NoCastEncoders().detectAgain(), CastEncoders.none);
    });
  });
}
