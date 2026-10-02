import 'package:flutter_test/flutter_test.dart';
import 'package:iptv_player/core/cast/cast_device.dart';
import 'package:iptv_player/core/cast/cast_device_profile.dart';
import 'package:iptv_player/core/cast/cast_plan.dart';
import 'package:iptv_player/core/cast/cast_planner.dart';
import 'package:iptv_player/design/components/quality_badge.dart';
import 'package:iptv_player/features/casting/presentation/cast_plan_text.dart';

import '../../../data/cast/probe_fixtures.dart';

CastPlan _plan(
  String sample, {
  CastDeviceProfile device = const CastDeviceProfile(model: 'Chromecast'),
  CastSourceInfo source = const CastSourceInfo(sourceId: 's1', live: true),
  CastSettings settings = const CastSettings(),
  bool softwareOnly = false,
}) => (planCast(
  CastPlanRequest(
    facts: readFixture(sample),
    source: source,
    device: device,
    settings: settings,
    softwareEncoderOnly: softwareOnly,
  ),
) as CastPlanned).plan;

CastPlan _with(CastVideo video, {CastAudio audio = const CastAudioCopy(0)}) =>
    CastPlan(
      delivery: CastDelivery.relayHls,
      video: video,
      audio: audio,
      live: true,
      output: const CastOutput(),
    );

CastVideoTranscode _transcode(
  TranscodeReason reason, {
  int height = 1080,
  bool softwareCapped = false,
}) => CastVideoTranscode(
  height: height,
  bitRate: 6000000,
  reasons: [reason],
  softwareCapped: softwareCapped,
);

void main() {
  group('the details line', () {
    test("the canvas's own: 1080p · 50 fps · H.264 · AAC 2.0", () {
      expect(
        castDetailsLine(_plan('h264_1080p50_aac').output),
        '1080p · 50 fps · H.264 · AAC 2.0',
      );
    });

    test('every sample on Living Room TV as found', () {
      const lines = {
        'h264_1080p25_ac3': '1080p · 25 fps · H.264 · AAC 2.0',
        'h264_1080i50_mp2': '1080i · 25 fps · H.264 · AAC 2.0',
        'hevc_1080p50_aac': '1080p · 50 fps · HEVC · AAC 2.0',
        'hevc_2160p25_eac3': '4K · 25 fps · HEVC · AAC 2.0',
        'mpeg2_576i25_mp2': '576p · 50 fps · H.264 · AAC 2.0',
        'h264_2160p25_aac': '4K · 25 fps · H.264 · AAC 2.0',
        'codec_switch_h264_720p_to_1080p': '720p · 50 fps · H.264 · AAC 2.0',
      };
      for (final MapEntry(key: sample, value: line) in lines.entries) {
        expect(castDetailsLine(_plan(sample).output), line, reason: sample);
      }
    });

    test('Dolby passed through', () {
      final plan = _plan(
        'hevc_2160p25_eac3',
        settings: const CastSettings(dolbyPassthrough: true),
      );
      expect(
        castDetailsLine(plan.output),
        '4K · 25 fps · HEVC · Dolby Digital Plus 5.1',
      );
    });

    test('odd frame rates, interlaced 4K, and what is not known', () {
      expect(
        castDetailsLine(
          const CastOutput(height: 1080, fps: 29.97, videoCodec: 'h264'),
        ),
        '1080p · 29.97 fps · H.264',
      );
      expect(castDetailsLine(const CastOutput(fps: 23.976)), '23.976 fps');
      expect(
        castDetailsLine(const CastOutput(height: 2160, interlaced: true)),
        '2160i',
      );
      expect(castDetailsLine(const CastOutput(audioCodec: 'aac')), 'AAC');
      expect(castDetailsLine(const CastOutput()), '');
    });

    test('names', () {
      expect(videoCodecName('mpeg2video'), 'MPEG-2');
      expect(videoCodecName('theora'), 'THEORA');
      expect(audioCodecName('ac3'), 'Dolby Digital');
      expect(audioCodecName('pcm_s16le'), 'PCM_S16LE');
      expect(channelsName(1), '1.0');
      expect(channelsName(3), '2.1');
      expect(channelsName(8), '7.1');
      expect(channelsName(4), '4 ch');
    });
  });

  group('the badge', () {
    test('each quality has its badge', () {
      expect(castBadge(_plan('h264_1080p50_aac')), StreamQuality.original);
      expect(
        castBadge(_plan('h264_1080p25_ac3')),
        StreamQuality.convertedAudio,
      );
      expect(castBadge(_plan('mpeg2_576i25_mp2')), StreamQuality.transcoded);
    });
  });

  group('the sentence', () {
    test("Original, in the canvas's words", () {
      expect(
        castPlanSentence(_plan('h264_1080p50_aac')),
        'Video and audio go to your TV untouched. Nothing is re-encoded.',
      );
    });

    test('Original, direct from the provider', () {
      expect(
        castPlanSentence(
          _plan(
            'h264_1080p50_aac',
            source: const CastSourceInfo(sourceId: 's1', live: true, hls: true),
          ),
        ),
        'Video and audio go to your TV untouched, straight from the '
        'provider. Nothing is re-encoded.',
      );
    });

    test('Original without a picture, or without a sound', () {
      expect(
        castPlanSentence(_with(const CastNoVideo())),
        'Audio goes to your TV untouched. Nothing is re-encoded.',
      );
      expect(
        castPlanSentence(
          _with(const CastVideoCopy(), audio: const CastNoAudio()),
        ),
        'Video goes to your TV untouched. Nothing is re-encoded.',
      );
    });

    test('Converted audio, for each reason', () {
      expect(
        castPlanSentence(_plan('h264_1080p25_ac3')),
        startsWith(
          'Video goes to your TV untouched. Dolby audio is converted to AAC '
          'stereo',
        ),
      );
      expect(
        castPlanSentence(_plan('h264_1080i50_mp2')),
        "Video goes to your TV untouched. Cast devices can't play this audio "
        "format, so it's converted to AAC stereo.",
      );
      for (final reason in AudioConversionReason.values) {
        final sentence = castPlanSentence(
          _with(const CastVideoCopy(), audio: CastAudioToAac(0, reason)),
        );
        expect(sentence, contains('AAC stereo'), reason: reason.name);
      }
      expect(
        castPlanSentence(
          _with(
            const CastNoVideo(),
            audio: const CastAudioToAac(0, AudioConversionReason.refused),
          ),
        ),
        "Your TV said no to this audio format, so it's converted to AAC "
        'stereo.',
      );
    });

    test("Transcoded: the plan's example", () {
      expect(
        castPlanSentence(
          _plan(
            'hevc_1080p50_aac',
            device: const CastDeviceProfile(
              learned: CastLearned(refusedCodecs: {'hevc'}),
            ),
          ),
        ),
        'Your TV said no to HEVC, so the video is re-encoded to H.264.',
      );
    });

    test('Transcoded after a 4K refusal: the TV-setting hint (docs/04)', () {
      final sentence = castPlanSentence(
        _plan(
          'hevc_2160p25_eac3',
          device: const CastDeviceProfile(
            learned: CastLearned(maxHeight: 1080),
          ),
        ),
      );
      expect(sentence, contains('re-encoded to 1080p'));
      expect(sentence, contains('HDMI input may be limited to HD'));
      expect(sentence, contains('may unlock 4K'));
    });

    test('Transcoded: every reason has a sentence of its own', () {
      final sentences = {
        for (final reason in TranscodeReason.values)
          castPlanSentence(_with(_transcode(reason))),
      };
      expect(sentences, hasLength(TranscodeReason.values.length));
      expect(
        castPlanSentence(_with(_transcode(TranscodeReason.hevcOff))),
        'HEVC is set to No for this TV, so the video is re-encoded to H.264.',
      );
    });

    test('Transcoded on the processor says it is held at 1080p', () {
      expect(
        castPlanSentence(
          _plan(
            'hevc_2160p25_eac3',
            device: const CastDeviceProfile(hevc: HevcSupport.no),
            softwareOnly: true,
          ),
        ),
        'HEVC is set to No for this TV, so the video is re-encoded to H.264. '
        "With no hardware encoder, it's made at 1080p at most.",
      );
    });
  });
}
