import 'package:flutter_test/flutter_test.dart';
import 'package:iptv_player/core/cast/cast_device.dart';
import 'package:iptv_player/core/cast/cast_device_profile.dart';
import 'package:iptv_player/core/cast/cast_plan.dart';
import 'package:iptv_player/core/cast/cast_planner.dart';
import 'package:iptv_player/core/cast/stream_facts.dart';

import '../../data/cast/probe_fixtures.dart';

// The devices docs/04 and the plan name (decision 8's profiles).

/// Living Room TV as found: `md` Chromecast, nothing learned yet, so HEVC
/// and 4K are tried.
const tv4k = CastDeviceProfile(model: 'Chromecast');

/// A 1080p-generation Chromecast once it refused HEVC.
const h264Only = CastDeviceProfile(
  model: 'Chromecast',
  learned: CastLearned(refusedCodecs: {'hevc'}),
);

/// Living Room TV with Input Signal Plus off: it refused 4K.
const tvOn1080Link = CastDeviceProfile(
  model: 'Chromecast',
  learned: CastLearned(maxHeight: 1080),
);

/// docs/04's one unambiguous model.
const ultra = CastDeviceProfile(model: 'Chromecast Ultra');

/// HEVC set to No in Settings → Casting (the matrix's stand-in for an
/// H.264-only device).
const hevcOff = CastDeviceProfile(model: 'Chromecast', hevc: HevcSupport.no);

const devices = <String, CastDeviceProfile>{
  'tv4k': tv4k,
  'h264Only': h264Only,
  'tvOn1080Link': tvOn1080Link,
  'ultra': ultra,
  'hevcOff': hevcOff,
};

const liveTs = CastSourceInfo(sourceId: 's1', live: true);
const liveHls = CastSourceInfo(sourceId: 's1', live: true, hls: true);
const mp4File = CastSourceInfo(sourceId: 's1', live: false);

const h264Hd = VideoFacts(
  codec: 'h264',
  profile: 'High',
  width: 1920,
  height: 1080,
  fps: 25,
  interlaced: false,
  bitDepth: 8,
);
const aac = AudioFacts(index: 0, codec: 'aac', channels: 2);

StreamFacts facts({
  VideoFacts? video = h264Hd,
  List<AudioFacts> audio = const [aac],
  MediaContainer? container = MediaContainer.mpegTs,
  int? bitRate,
}) => StreamFacts(
  origin: StreamFactsOrigin.probe,
  video: video,
  audio: audio,
  container: container,
  bitRate: bitRate,
);

CastPlan plan(
  StreamFacts facts, {
  CastSourceInfo source = liveTs,
  CastDeviceProfile device = tv4k,
  CastSettings settings = const CastSettings(),
  CastAudioChoice audio = const CastAudioChoice(),
  bool softwareOnly = false,
}) {
  final result = planCast(
    CastPlanRequest(
      facts: facts,
      source: source,
      device: device,
      settings: settings,
      audio: audio,
      softwareEncoderOnly: softwareOnly,
    ),
  );
  if (result is! CastPlanned) fail('nothing to play');
  return result.plan;
}

/// A transcode's target, reasons, frame rate and bit rate, for tables.
typedef Re = (int height, List<TranscodeReason> why, double? fps, int bits);

void main() {
  group('every live sample on every device (docs/04, the matrix)', () {
    // Expected per sample and device: delivery, the video (copy, or a
    // transcode's numbers), the audio, the badge.
    const copy = null;
    const toAac = AudioConversionReason.dolby;
    const mp2 = AudioConversionReason.codecUnsupported;
    const hevc4kBits = 20200000;
    final table = <String, Map<String, (CastDelivery, Re?, Object?)>>{
      'h264_1080p50_aac': {
        for (final d in devices.keys) d: (CastDelivery.relayHls, copy, copy),
      },
      'h264_1080p25_ac3': {
        for (final d in devices.keys) d: (CastDelivery.relayHls, copy, toAac),
      },
      'h264_1080i50_mp2': {
        // Interlaced is copied first (docs/04 rule 2).
        for (final d in devices.keys) d: (CastDelivery.relayHls, copy, mp2),
      },
      'hevc_1080p50_aac': {
        'tv4k': (CastDelivery.relayContinuous, copy, copy),
        'h264Only': (
          CastDelivery.relayHls,
          (1080, [TranscodeReason.hevcRefused], 50, 6000000),
          copy,
        ),
        'tvOn1080Link': (CastDelivery.relayContinuous, copy, copy),
        'ultra': (CastDelivery.relayContinuous, copy, copy),
        'hevcOff': (
          CastDelivery.relayHls,
          (1080, [TranscodeReason.hevcOff], 50, 6000000),
          copy,
        ),
      },
      'hevc_2160p25_eac3': {
        'tv4k': (CastDelivery.relayContinuous, copy, toAac),
        'h264Only': (
          CastDelivery.relayHls,
          (2160, [TranscodeReason.hevcRefused], 25, hevc4kBits),
          toAac,
        ),
        'tvOn1080Link': (
          CastDelivery.relayHls,
          (1080, [TranscodeReason.aboveLearnedHeight], 25, 6000000),
          toAac,
        ),
        'ultra': (CastDelivery.relayContinuous, copy, toAac),
        'hevcOff': (
          CastDelivery.relayHls,
          (2160, [TranscodeReason.hevcOff], 25, hevc4kBits),
          toAac,
        ),
      },
      'mpeg2_576i25_mp2': {
        for (final d in devices.keys)
          d: (
            CastDelivery.relayHls,
            // Deinterlaced, one picture per field: 50.
            (576, [TranscodeReason.codecUnsupported], 50, 5000000),
            mp2,
          ),
      },
      'h264_2160p25_aac': {
        for (final d in devices.keys) d: (CastDelivery.relayHls, copy, copy),
        'tvOn1080Link': (
          CastDelivery.relayHls,
          (1080, [TranscodeReason.aboveLearnedHeight], 25, 6000000),
          copy,
        ),
      },
      'codec_switch_h264_720p_to_1080p': {
        for (final d in devices.keys) d: (CastDelivery.relayHls, copy, copy),
      },
    };

    test('the table covers every sample and device', () {
      expect(table.keys, unorderedEquals(liveSampleNames));
      for (final row in table.values) {
        expect(row.keys, unorderedEquals(devices.keys));
      }
    });

    for (final MapEntry(key: sample, value: row) in table.entries) {
      for (final MapEntry(key: name, value: want) in row.entries) {
        test('$sample on $name', () {
          final probe = readFixture(sample);
          final got = plan(probe, device: devices[name]!);
          final (delivery, video, audio) = want;
          expect(got.delivery, delivery);
          expect(got.live, isTrue);
          if (video == null) {
            expect(got.video, const CastVideoCopy());
            expect(got.output.videoCodec, probe.video!.codec);
            expect(got.output.height, probe.video!.height);
            expect(got.output.interlaced, probe.video!.interlaced ?? false);
          } else {
            final (height, why, fps, bits) = video;
            final t = got.video as CastVideoTranscode;
            expect(t.height, height);
            expect(t.reasons, why);
            expect(t.fps, fps);
            expect(t.bitRate, bits);
            expect(t.deinterlace, probe.video!.interlaced ?? false);
            expect(got.output.videoCodec, 'h264');
            expect(got.output.height, height);
            expect(got.output.interlaced, isFalse);
          }
          if (audio == null) {
            expect(got.audio, const CastAudioCopy(0));
            expect(got.output.audioCodec, probe.audio.single.codec);
            expect(got.output.audioChannels, probe.audio.single.channels);
          } else {
            expect(
              got.audio,
              CastAudioToAac(0, audio as AudioConversionReason),
            );
            expect(got.output.audioCodec, 'aac');
            expect(got.output.audioChannels, 2);
          }
          expect(
            got.quality,
            video != null
                ? CastQuality.transcoded
                : audio != null
                ? CastQuality.convertedAudio
                : CastQuality.original,
          );
        });
      }
    }
  });

  group('rule 1: the direct fast path', () {
    test('HLS + H.264 + AAC never refused goes direct', () {
      final got = plan(facts(), source: liveHls);
      expect(got.delivery, CastDelivery.directHls);
      expect(got.delivery.contentType, 'application/x-mpegurl');
      expect(got.quality, CastQuality.original);
    });

    test('interlaced H.264 too: interlaced is copied first', () {
      final got = plan(
        facts(video: h264Hd.copyWith(interlaced: true)),
        source: liveHls,
      );
      expect(got.delivery, CastDelivery.directHls);
      expect(got.output.interlaced, isTrue);
    });

    test('no sound at all is no reason against it', () {
      expect(
        plan(facts(audio: const []), source: liveHls).delivery,
        CastDelivery.directHls,
      );
    });

    final notDirect = <String, CastPlan Function()>{
      'not HLS': () => plan(facts()),
      'HEVC': () => plan(
        facts(video: h264Hd.copyWith(codec: 'hevc')),
        source: liveHls,
      ),
      'MP3 sound': () => plan(
        facts(audio: const [AudioFacts(index: 0, codec: 'mp3')]),
        source: liveHls,
      ),
      'Dolby sound': () => plan(
        facts(audio: const [AudioFacts(index: 0, codec: 'ac3')]),
        source: liveHls,
      ),
      'Dolby with passthrough': () => plan(
        facts(audio: const [AudioFacts(index: 0, codec: 'ac3')]),
        source: liveHls,
        settings: const CastSettings(dolbyPassthrough: true),
      ),
      'a picture to re-encode': () => plan(
        facts(video: h264Hd.copyWith(height: 2160)),
        source: liveHls,
        device: tvOn1080Link,
      ),
      'the second audio track': () => plan(
        facts(
          audio: const [
            aac,
            AudioFacts(index: 1, codec: 'aac'),
          ],
        ),
        source: liveHls,
        audio: const CastAudioChoice(track: 1),
      ),
      'refused direct before': () => plan(
        facts(),
        source: liveHls,
        device: const CastDeviceProfile(
          learned: CastLearned(directRefusedSources: {'s1'}),
        ),
      ),
      'a User-Agent of its own': () => plan(
        facts(),
        source: const CastSourceInfo(
          sourceId: 's1',
          live: true,
          hls: true,
          customUserAgent: true,
        ),
      ),
      'Low-latency mode': () => plan(
        facts(),
        source: liveHls,
        settings: const CastSettings(lowLatency: true),
      ),
      'a radio channel': () => plan(facts(video: null), source: liveHls),
    };
    for (final MapEntry(key: why, value: make) in notDirect.entries) {
      test('not direct: $why', () {
        expect(make().delivery.direct, isFalse);
      });
    }

    test('a refusal on another source leaves this one direct', () {
      final got = plan(
        facts(),
        source: liveHls,
        device: const CastDeviceProfile(
          learned: CastLearned(directRefusedSources: {'s2'}),
        ),
      );
      expect(got.delivery, CastDelivery.directHls);
    });
  });

  group('decision 1: files', () {
    final movie = readFixture('vod_h264_aac_10min');

    test('the MP4 sample goes direct, with its own Range seeks', () {
      final got = plan(movie, source: mp4File);
      expect(got.delivery, CastDelivery.directFile);
      expect(got.delivery.contentType, 'video/mp4');
      expect(got.live, isFalse);
      expect(got.quality, CastQuality.original);
    });

    test('MP3 sound plays direct too', () {
      final got = plan(
        movie.copyWith(audio: const [AudioFacts(index: 0, codec: 'mp3')]),
        source: mp4File,
      );
      expect(got.delivery, CastDelivery.directFile);
    });

    test('HEVC direct where HEVC is tried, relayed where refused', () {
      final hevc = movie.copyWith(
        video: movie.video!.copyWith(codec: 'hevc', profile: 'Main'),
      );
      expect(plan(hevc, source: mp4File).delivery, CastDelivery.directFile);
      final refused = plan(hevc, source: mp4File, device: h264Only);
      expect(refused.delivery, CastDelivery.relayContinuous);
      expect(refused.video, isA<CastVideoTranscode>());
    });

    test('the container from the provider when the facts have none', () {
      final fromPlayer = movie.copyWith(container: null);
      for (final ext in ['mp4', 'M4V', '.mov']) {
        final got = plan(
          fromPlayer,
          source: CastSourceInfo(
            sourceId: 's1',
            live: false,
            fileExtension: ext,
          ),
        );
        expect(got.delivery, CastDelivery.directFile, reason: ext);
      }
      for (final ext in ['mkv', 'avi', null]) {
        final got = plan(
          fromPlayer,
          source: CastSourceInfo(
            sourceId: 's1',
            live: false,
            fileExtension: ext,
          ),
        );
        expect(got.delivery, CastDelivery.relayContinuous, reason: ext);
      }
    });

    test('the facts win over the provider: an "mp4" that is Matroska', () {
      final got = plan(
        movie.copyWith(container: MediaContainer.matroska),
        source: const CastSourceInfo(
          sourceId: 's1',
          live: false,
          fileExtension: 'mp4',
        ),
      );
      expect(got.delivery, CastDelivery.relayContinuous);
    });

    test('the MKV movies relay as one continuous stream', () {
      final ac3 = plan(readFixture('vod_h264_ac3_10min'), source: mp4File);
      expect(ac3.delivery, CastDelivery.relayContinuous);
      expect(ac3.video, const CastVideoCopy());
      expect(ac3.audio, const CastAudioToAac(0, AudioConversionReason.dolby));

      final hevc = readFixture('vod_hevc_eac3_subs');
      expect(
        plan(hevc, source: mp4File).delivery,
        CastDelivery.relayContinuous,
      );
      // H.264 out, but a file stays one continuous stream.
      final transcoded = plan(hevc, source: mp4File, device: h264Only);
      expect(transcoded.delivery, CastDelivery.relayContinuous);
      expect(transcoded.output.videoCodec, 'h264');
    });

    final notDirect = <String, CastPlan Function()>{
      'Dolby sound': () => plan(
        movie.copyWith(audio: const [AudioFacts(index: 0, codec: 'ac3')]),
        source: mp4File,
      ),
      'Dolby with passthrough (copied, but relayed)': () => plan(
        movie.copyWith(audio: const [AudioFacts(index: 0, codec: 'eac3')]),
        source: mp4File,
        settings: const CastSettings(dolbyPassthrough: true),
      ),
      'the second audio track': () => plan(
        movie.copyWith(
          audio: const [
            aac,
            AudioFacts(index: 1, codec: 'aac'),
          ],
        ),
        source: mp4File,
        audio: const CastAudioChoice(track: 1),
      ),
      'refused direct before': () => plan(
        movie,
        source: mp4File,
        device: const CastDeviceProfile(
          learned: CastLearned(directRefusedSources: {'s1'}),
        ),
      ),
      'a User-Agent of its own': () => plan(
        movie,
        source: const CastSourceInfo(
          sourceId: 's1',
          live: false,
          customUserAgent: true,
        ),
      ),
      'a picture too tall': () => plan(
        movie.copyWith(video: movie.video!.copyWith(height: 2160)),
        source: mp4File,
        device: tvOn1080Link,
      ),
    };
    for (final MapEntry(key: why, value: make) in notDirect.entries) {
      test('not direct: $why', () {
        final got = make();
        expect(got.delivery, CastDelivery.relayContinuous);
        expect(got.live, isFalse);
      });
    }

    test('Low-latency mode leaves files alone', () {
      final got = plan(
        movie,
        source: mp4File,
        settings: const CastSettings(lowLatency: true),
      );
      expect(got.delivery, CastDelivery.directFile);
    });
  });

  group('rule 2: video', () {
    test('supported and progressive: copied', () {
      expect(plan(facts()).video, const CastVideoCopy());
    });

    test('codecs Cast devices never play are re-encoded', () {
      for (final codec in ['mpeg2video', 'vc1', 'vp9', 'av1', 'mpeg4']) {
        final got = plan(facts(video: h264Hd.copyWith(codec: codec)));
        expect((got.video as CastVideoTranscode).reasons, [
          TranscodeReason.codecUnsupported,
        ], reason: codec);
        expect(got.delivery, CastDelivery.relayHls);
      }
    });

    test('an unknown codec is re-encoded to be safe', () {
      final got = plan(facts(video: h264Hd.copyWith(codec: null)));
      expect((got.video as CastVideoTranscode).reasons, [
        TranscodeReason.codecUnknown,
      ]);
    });

    test('H.264 Cast devices do not decode', () {
      for (final video in [
        h264Hd.copyWith(profile: 'High 10'),
        h264Hd.copyWith(profile: 'High 4:2:2'),
        h264Hd.copyWith(profile: 'High 4:4:4 Predictive'),
        h264Hd.copyWith(profile: null, bitDepth: 10),
      ]) {
        final got = plan(facts(video: video));
        expect((got.video as CastVideoTranscode).reasons, [
          TranscodeReason.profileUnsupported,
        ], reason: '$video');
      }
    });

    test('HEVC Main and Main 10 are copied; range extensions are not', () {
      const hevc = VideoFacts(codec: 'hevc', height: 2160, fps: 25);
      for (final ok in [
        hevc,
        hevc.copyWith(profile: 'Main'),
        hevc.copyWith(profile: 'Main 10', bitDepth: 10),
        hevc.copyWith(profile: 'unknown'),
      ]) {
        expect(plan(facts(video: ok)).video, const CastVideoCopy());
      }
      for (final not in [
        hevc.copyWith(profile: 'Rext'),
        hevc.copyWith(bitDepth: 12),
      ]) {
        expect((plan(facts(video: not)).video as CastVideoTranscode).reasons, [
          TranscodeReason.profileUnsupported,
        ]);
      }
    });

    test('interlaced: copied, unless Smooth interlaced or refused before', () {
      final interlaced = facts(video: h264Hd.copyWith(interlaced: true));
      expect(plan(interlaced).video, const CastVideoCopy());

      final smooth =
          plan(
                interlaced,
                settings: const CastSettings(smoothInterlaced: true),
              ).video
              as CastVideoTranscode;
      expect(smooth.reasons, [TranscodeReason.smoothInterlaced]);
      expect(smooth.deinterlace, isTrue);
      expect(smooth.fps, 50);
      expect(smooth.height, 1080);

      final refused =
          plan(
                interlaced,
                device: const CastDeviceProfile(
                  learned: CastLearned(refusedInterlaced: true),
                ),
              ).video
              as CastVideoTranscode;
      expect(refused.reasons, [TranscodeReason.interlacedRefused]);
    });

    test('Smooth interlaced leaves progressive pictures alone', () {
      final got = plan(
        facts(),
        settings: const CastSettings(smoothInterlaced: true),
      );
      expect(got.video, const CastVideoCopy());
    });

    test('a deinterlaced 30 fps picture tops out at 60', () {
      final got = plan(
        facts(
          video: h264Hd.copyWith(
            codec: 'mpeg2video',
            fps: 30,
            interlaced: true,
          ),
        ),
      );
      expect((got.video as CastVideoTranscode).fps, 60);
      final fast = plan(
        facts(
          video: h264Hd.copyWith(
            codec: 'mpeg2video',
            fps: 50,
            interlaced: true,
          ),
        ),
      );
      expect((fast.video as CastVideoTranscode).fps, 60);
    });

    test('taller than learned: down to it, with the learned reason', () {
      final got = plan(
        facts(video: h264Hd.copyWith(height: 2160)),
        device: tvOn1080Link,
      );
      final t = got.video as CastVideoTranscode;
      expect(t.height, 1080);
      expect(t.reasons, [TranscodeReason.aboveLearnedHeight]);
      expect(got.quality, CastQuality.transcoded);
    });

    test('taller than the model shows: the model reason', () {
      final got = plan(
        facts(video: h264Hd.copyWith(height: 4320)),
        device: ultra,
      );
      final t = got.video as CastVideoTranscode;
      expect(t.height, 2160);
      expect(t.reasons, [TranscodeReason.aboveModelHeight]);
    });

    test("a learned limit under the model's is the learned one", () {
      final got = plan(
        facts(video: h264Hd.copyWith(height: 2160)),
        device: const CastDeviceProfile(
          model: 'Chromecast Ultra',
          learned: CastLearned(maxHeight: 1080),
        ),
      );
      final t = got.video as CastVideoTranscode;
      expect(t.height, 1080);
      expect(t.reasons, [TranscodeReason.aboveLearnedHeight]);
    });

    test('HEVC refused and too tall: both reasons, the codec first', () {
      final got = plan(
        facts(video: const VideoFacts(codec: 'hevc', height: 2160)),
        device: const CastDeviceProfile(
          learned: CastLearned(refusedCodecs: {'hevc'}, maxHeight: 1080),
        ),
      );
      final t = got.video as CastVideoTranscode;
      expect(t.reasons, [
        TranscodeReason.hevcRefused,
        TranscodeReason.aboveLearnedHeight,
      ]);
      expect(t.height, 1080);
    });

    test('HEVC "Yes" in Settings wins over a refusal', () {
      final got = plan(
        facts(video: const VideoFacts(codec: 'hevc', height: 1080)),
        device: const CastDeviceProfile(
          hevc: HevcSupport.yes,
          learned: CastLearned(refusedCodecs: {'hevc'}),
        ),
      );
      expect(got.video, const CastVideoCopy());
      expect(got.delivery, CastDelivery.relayContinuous);
    });

    test('a picture of unknown height is re-encoded at 1080p at most', () {
      final unknown = h264Hd.copyWith(codec: 'mpeg2video', height: null);
      expect(
        (plan(facts(video: unknown)).video as CastVideoTranscode).height,
        1080,
      );
      final small = plan(
        facts(video: unknown),
        device: const CastDeviceProfile(learned: CastLearned(maxHeight: 720)),
      );
      expect((small.video as CastVideoTranscode).height, 720);
    });

    test('a picture of unknown height is copied when nothing says not to', () {
      final got = plan(facts(video: h264Hd.copyWith(height: null)));
      expect(got.video, const CastVideoCopy());
      expect(got.output.height, isNull);
    });

    test('no frame rate: none in the plan or the output', () {
      final copied = plan(facts(video: h264Hd.copyWith(fps: null)));
      expect(copied.output.fps, isNull);
      final transcoded = plan(
        facts(video: h264Hd.copyWith(codec: 'mpeg2video', fps: null)),
      );
      expect((transcoded.video as CastVideoTranscode).fps, isNull);
      expect(transcoded.output.fps, isNull);
    });
  });

  group('rule 3: the processor alone holds a re-encode at 1080p', () {
    test('4K HEVC on an H.264-only device, software only', () {
      final got = plan(
        readFixture('hevc_2160p25_eac3'),
        device: h264Only,
        softwareOnly: true,
      );
      final t = got.video as CastVideoTranscode;
      expect(t.height, 1080);
      expect(t.softwareCapped, isTrue);
      expect(t.reasons, [TranscodeReason.hevcRefused]);
      expect(t.bitRate, 6000000);
    });

    test('1080p and below are not capped', () {
      final got = plan(readFixture('mpeg2_576i25_mp2'), softwareOnly: true);
      final t = got.video as CastVideoTranscode;
      expect(t.height, 576);
      expect(t.softwareCapped, isFalse);
    });

    test('a copy is not touched', () {
      final got = plan(readFixture('h264_2160p25_aac'), softwareOnly: true);
      expect(got.video, const CastVideoCopy());
    });
  });

  group('rule 3: bit rates', () {
    test("an unknown source gets each height's floor", () {
      expect(transcodeBitRate(targetHeight: 480), 1500000);
      expect(transcodeBitRate(targetHeight: 576), 2000000);
      expect(transcodeBitRate(targetHeight: 720), 4000000);
      expect(transcodeBitRate(targetHeight: 1080), 6000000);
      expect(transcodeBitRate(targetHeight: 1440), 10000000);
      expect(transcodeBitRate(targetHeight: 2160), 16000000);
    });

    test('1.3 × the source, in whole 100 kbps', () {
      expect(
        transcodeBitRate(
          targetHeight: 1080,
          sourceBitRate: 8000000,
          sourceHeight: 1080,
        ),
        10400000,
      );
      expect(
        transcodeBitRate(
          targetHeight: 1080,
          sourceBitRate: 7777777,
          sourceHeight: 1080,
        ),
        10100000,
      );
    });

    test('at least 6 Mbps at 1080p, and at most each ceiling', () {
      expect(
        transcodeBitRate(targetHeight: 1080, sourceBitRate: 1000000),
        6000000,
      );
      expect(
        transcodeBitRate(targetHeight: 1080, sourceBitRate: 50000000),
        15000000,
      );
      expect(
        transcodeBitRate(targetHeight: 2160, sourceBitRate: 90000000),
        40000000,
      );
    });

    test('a smaller picture keeps the bits per pixel', () {
      // 40 Mbps at 2160p is 10 Mbps at 1080p; × 1.3 = 13 Mbps.
      expect(
        transcodeBitRate(
          targetHeight: 1080,
          sourceBitRate: 40000000,
          sourceHeight: 2160,
        ),
        13000000,
      );
    });

    test('never scaled up', () {
      expect(
        transcodeBitRate(
          targetHeight: 1080,
          sourceBitRate: 8000000,
          sourceHeight: 720,
        ),
        10400000,
      );
    });

    test('zero and negative sources are unknown', () {
      expect(transcodeBitRate(targetHeight: 720, sourceBitRate: 0), 4000000);
      expect(transcodeBitRate(targetHeight: 720, sourceBitRate: -1), 4000000);
    });

    test(
      'the source from the stream less its sound when the picture has none',
      () {
        final got = plan(
          facts(
            video: h264Hd.copyWith(codec: 'mpeg2video', bitRate: null),
            audio: const [AudioFacts(index: 0, codec: 'mp2', bitRate: 192000)],
            bitRate: 10192000,
          ),
        );
        // 10 Mbps × 1.3.
        expect((got.video as CastVideoTranscode).bitRate, 13000000);
      },
    );

    test("the picture's own when it has one", () {
      final got = plan(
        facts(
          video: h264Hd.copyWith(codec: 'mpeg2video', bitRate: 9000000),
          bitRate: 20000000,
        ),
      );
      expect((got.video as CastVideoTranscode).bitRate, 11700000);
    });
  });

  group('rule 4: audio', () {
    test('AAC and MP3 are copied', () {
      for (final codec in ['aac', 'mp3']) {
        final got = plan(facts(audio: [AudioFacts(index: 0, codec: codec)]));
        expect(got.audio, const CastAudioCopy(0), reason: codec);
        expect(got.quality, CastQuality.original);
      }
    });

    test('Dolby is converted, unless Dolby passthrough is on', () {
      for (final codec in ['ac3', 'eac3']) {
        final track = AudioFacts(index: 0, codec: codec, channels: 6);
        final converted = plan(facts(audio: [track]));
        expect(
          converted.audio,
          const CastAudioToAac(0, AudioConversionReason.dolby),
        );
        expect(converted.output.audioCodec, 'aac');
        expect(converted.output.audioChannels, 2);

        final passed = plan(
          facts(audio: [track]),
          settings: const CastSettings(dolbyPassthrough: true),
        );
        expect(passed.audio, const CastAudioCopy(0));
        expect(passed.output.audioCodec, codec);
        expect(passed.output.audioChannels, 6);
        expect(passed.quality, CastQuality.original);
      }
    });

    test('everything else is converted', () {
      for (final codec in [
        'mp2',
        'dts',
        'truehd',
        'opus',
        'flac',
        'aac_latm',
      ]) {
        final got = plan(facts(audio: [AudioFacts(index: 0, codec: codec)]));
        expect(
          got.audio,
          const CastAudioToAac(0, AudioConversionReason.codecUnsupported),
          reason: codec,
        );
        expect(got.quality, CastQuality.convertedAudio);
      }
    });

    test('an unknown codec is converted to be safe', () {
      final got = plan(facts(audio: const [AudioFacts(index: 0)]));
      expect(
        got.audio,
        const CastAudioToAac(0, AudioConversionReason.codecUnknown),
      );
    });

    test('a codec refused before is converted, Dolby passthrough or not', () {
      for (final codec in ['aac', 'eac3']) {
        final got = plan(
          facts(audio: [AudioFacts(index: 0, codec: codec)]),
          device: CastDeviceProfile(
            learned: CastLearned(refusedCodecs: {codec}),
          ),
          settings: const CastSettings(dolbyPassthrough: true),
        );
        expect(
          got.audio,
          const CastAudioToAac(0, AudioConversionReason.refused),
          reason: codec,
        );
      }
    });

    test('a transcoded picture with converted sound is "Transcoded"', () {
      expect(
        plan(readFixture('mpeg2_576i25_mp2')).quality,
        CastQuality.transcoded,
      );
    });
  });

  group('rule 5: containers', () {
    test('H.264 → HLS/TS, HEVC → one continuous MP4', () {
      expect(plan(facts()).delivery, CastDelivery.relayHls);
      expect(
        plan(facts(video: const VideoFacts(codec: 'hevc'))).delivery,
        CastDelivery.relayContinuous,
      );
    });

    test('Low-latency mode: one continuous MP4 for H.264 too', () {
      final got = plan(facts(), settings: const CastSettings(lowLatency: true));
      expect(got.delivery, CastDelivery.relayContinuous);
      expect(got.delivery.contentType, 'video/mp4');
    });

    test('re-encoded HEVC is H.264, so HLS', () {
      final got = plan(
        facts(video: const VideoFacts(codec: 'hevc')),
        device: h264Only,
      );
      expect(got.delivery, CastDelivery.relayHls);
      expect(got.delivery.contentType, 'application/x-mpegurl');
    });

    test('a radio channel: sound only, over HLS', () {
      final got = plan(facts(video: null));
      expect(got.video, const CastNoVideo());
      expect(got.delivery, CastDelivery.relayHls);
      expect(got.output.videoCodec, isNull);
      expect(got.output.height, isNull);
      expect(got.quality, CastQuality.original);
    });
  });

  group('rule 6: tracks', () {
    const english = AudioFacts(index: 0, codec: 'ac3', language: 'eng');
    const german = AudioFacts(index: 1, codec: 'aac', language: 'ger');
    const french = AudioFacts(
      index: 2,
      codec: 'aac',
      language: 'fre',
      isDefault: true,
    );
    const tracks = [english, german, french];

    test("the laptop's track wins", () {
      expect(
        pickAudioTrack(
          tracks,
          const CastAudioChoice(track: 1, languages: ['fr']),
        ),
        german,
      );
    });

    test('a track that is not there falls through', () {
      expect(pickAudioTrack(tracks, const CastAudioChoice(track: 9)), french);
    });

    test('then the first preferred language there is', () {
      expect(
        pickAudioTrack(tracks, const CastAudioChoice(languages: ['es', 'de'])),
        german,
      );
      expect(
        pickAudioTrack(tracks, const CastAudioChoice(languages: ['eng'])),
        english,
      );
    });

    test("then the stream's default, then the first", () {
      expect(pickAudioTrack(tracks, const CastAudioChoice()), french);
      expect(
        pickAudioTrack(const [english, german], const CastAudioChoice()),
        english,
      );
    });

    test('no tracks, no track', () {
      expect(pickAudioTrack(const [], const CastAudioChoice(track: 0)), isNull);
    });

    test('the plan maps the chosen track', () {
      final got = plan(
        facts(audio: tracks),
        audio: const CastAudioChoice(languages: ['de']),
      );
      expect(got.audio, const CastAudioCopy(1));
    });

    test('languages: two letters or three, either three', () {
      expect(sameLanguage('en', 'eng'), isTrue);
      expect(sameLanguage('ENG', 'en'), isTrue);
      expect(sameLanguage('de', 'ger'), isTrue);
      expect(sameLanguage('deu', 'ger'), isTrue);
      expect(sameLanguage('fr', 'fra'), isTrue);
      expect(sameLanguage('ar', 'ara'), isTrue);
      expect(sameLanguage(' es ', 'spa'), isTrue);
      expect(sameLanguage('xx', 'xx'), isTrue);
      expect(sameLanguage('ar', 'arm'), isFalse);
      expect(sameLanguage('en', 'ger'), isFalse);
      expect(sameLanguage(null, 'en'), isFalse);
      expect(sameLanguage('', ''), isFalse);
    });
  });

  group('missing facts', () {
    test('neither a picture nor a sound: nothing to play', () {
      final result = planCast(
        CastPlanRequest(
          facts: facts(video: null, audio: const []),
          source: liveTs,
          device: tv4k,
        ),
      );
      expect(result, isA<CastNothingToPlay>());
    });

    test('no sound: the picture alone, Original', () {
      final got = plan(facts(audio: const []));
      expect(got.audio, const CastNoAudio());
      expect(got.output.audioCodec, isNull);
      expect(got.output.audioChannels, isNull);
      expect(got.quality, CastQuality.original);
    });

    test('facts with nothing but codecs still plan', () {
      final got = plan(
        const StreamFacts(
          origin: StreamFactsOrigin.player,
          video: VideoFacts(codec: 'h264'),
          audio: [AudioFacts(index: 0, codec: 'aac')],
        ),
      );
      expect(got.delivery, CastDelivery.relayHls);
      expect(got.video, const CastVideoCopy());
      expect(
        got.output,
        const CastOutput(videoCodec: 'h264', audioCodec: 'aac'),
      );
    });
  });

  group('the plan', () {
    test('equal plans are equal, and print their parts', () {
      final a = plan(readFixture('mpeg2_576i25_mp2'));
      final b = plan(readFixture('mpeg2_576i25_mp2'));
      expect(a, b);
      expect(a.hashCode, b.hashCode);
      expect('$a', contains('relayHls'));
      expect('$a', contains('codecUnsupported'));
      expect('$a', contains('deinterlace'));
    });

    test('the same request always plans the same', () {
      for (final name in liveSampleNames) {
        for (final device in devices.values) {
          expect(
            plan(readFixture(name), device: device),
            plan(readFixture(name), device: device),
          );
        }
      }
    });

    test('the H.264 1080p50 sample in full', () {
      expect(
        plan(readFixture('h264_1080p50_aac')),
        const CastPlan(
          delivery: CastDelivery.relayHls,
          video: CastVideoCopy(),
          audio: CastAudioCopy(0),
          live: true,
          output: CastOutput(
            height: 1080,
            fps: 50,
            videoCodec: 'h264',
            audioCodec: 'aac',
            audioChannels: 2,
          ),
        ),
      );
    });
  });
}
