import 'dart:convert';
import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:iptv_player/core/cast/stream_facts.dart';
import 'package:iptv_player/data/cast/ffprobe_json.dart';

import 'probe_fixtures.dart';

/// One stream in ffprobe's shape, for the tolerant cases.
String probeJson({
  List<Map<String, Object?>> streams = const [],
  Map<String, Object?>? format,
}) => jsonEncode({'streams': streams, 'format': ?format});

void main() {
  group('every sample, as ffprobe read it', () {
    test('H.264 1080i50 with MP2: interlaced, 25 pictures a second', () {
      final facts = readFixture('h264_1080i50_mp2');
      expect(facts.origin, StreamFactsOrigin.probe);
      expect(facts.container, MediaContainer.mpegTs);
      expect(
        facts.video,
        const VideoFacts(
          codec: 'h264',
          profile: 'High',
          width: 1920,
          height: 1080,
          fps: 25,
          interlaced: true,
          bitDepth: 8,
        ),
      );
      expect(facts.audio, const [
        AudioFacts(index: 0, codec: 'mp2', channels: 2, bitRate: 192000),
      ]);
      expect(facts.duration, const Duration(milliseconds: 60010));
      expect(facts.bitRate, 8449539);
    });

    const live = {
      'h264_1080p50_aac': ('h264', 1080, 50.0, false, 'aac', 2),
      'h264_1080p25_ac3': ('h264', 1080, 25.0, false, 'ac3', 6),
      'h264_2160p25_aac': ('h264', 2160, 25.0, false, 'aac', 2),
      'hevc_1080p50_aac': ('hevc', 1080, 50.0, null, 'aac', 2),
      'hevc_2160p25_eac3': ('hevc', 2160, 25.0, null, 'eac3', 6),
      'mpeg2_576i25_mp2': ('mpeg2video', 576, 25.0, true, 'mp2', 2),
      'codec_switch_h264_720p_to_1080p': ('h264', 720, 50.0, false, 'aac', 2),
    };
    for (final MapEntry(key: name, value: want) in live.entries) {
      test(name, () {
        final facts = readFixture(name);
        final (codec, height, fps, interlaced, audio, channels) = want;
        expect(facts.container, MediaContainer.mpegTs);
        expect(facts.video?.codec, codec);
        expect(facts.video?.height, height);
        expect(facts.video?.fps, fps);
        // HEVC's field order is "unknown" to ffprobe: not said.
        expect(facts.video?.interlaced, interlaced);
        expect(facts.audio.single.codec, audio);
        expect(facts.audio.single.channels, channels);
        expect(facts.audio.single.index, 0);
      });
    }

    test('the MP4 movie: an MP4, with default tracks and a length', () {
      final facts = readFixture('vod_h264_aac_10min');
      expect(facts.container, MediaContainer.mp4);
      expect(facts.video?.codec, 'h264');
      expect(facts.video?.bitRate, 2500173);
      expect(facts.duration, const Duration(minutes: 10));
      final audio = facts.audio.single;
      expect(audio.codec, 'aac');
      expect(audio.isDefault, isTrue);
      // "und" is no language at all.
      expect(audio.language, isNull);
    });

    test('the MKV movies: Matroska, English sound, subtitles not listed', () {
      final ac3 = readFixture('vod_h264_ac3_10min');
      expect(ac3.container, MediaContainer.matroska);
      expect(ac3.audio.single.codec, 'ac3');
      expect(ac3.audio.single.language, 'eng');

      final hevc = readFixture('vod_hevc_eac3_subs');
      expect(hevc.container, MediaContainer.matroska);
      expect(hevc.video?.codec, 'hevc');
      expect(hevc.video?.interlaced, isFalse);
      expect(hevc.audio.single.codec, 'eac3');
      expect(hevc.audio.single.language, 'eng');
    });
  });

  group('tolerant reading', () {
    test('not JSON, or not an object, is null', () {
      for (final text in ['', '{', 'null', '[]', '"streams"', '42']) {
        expect(readFfprobeJson(text), isNull, reason: text);
      }
    });

    test('an object without streams or format is facts with nothing', () {
      final facts = readFfprobeJson('{}')!;
      expect(facts.video, isNull);
      expect(facts.audio, isEmpty);
      expect(facts.container, isNull);
      expect(facts.duration, isNull);
    });

    test('streams that are not a list, and items that are not objects', () {
      expect(readFfprobeJson('{"streams": {"a": 1}}')!.audio, isEmpty);
      final facts = readFfprobeJson(
        '{"streams": [1, "x", null, [], {"codec_type": "audio"}]}',
      )!;
      expect(facts.audio, const [AudioFacts(index: 0)]);
    });

    test('numbers as strings, N/A and empty strings', () {
      final facts = readFfprobeJson(
        probeJson(
          streams: [
            {
              'codec_type': 'video',
              'codec_name': ' H264 ',
              'width': '1920',
              'height': 1080.0,
              'avg_frame_rate': 'N/A',
              'r_frame_rate': '30000/1001',
              'bit_rate': 'N/A',
              'profile': '',
            },
            {
              'codec_type': 'audio',
              'codec_name': 'aac',
              'channels': '6',
              'bit_rate': '128000',
            },
          ],
          format: {'duration': 'N/A', 'bit_rate': '', 'format_name': 'mpegts'},
        ),
      )!;
      expect(
        facts.video,
        const VideoFacts(codec: 'h264', width: 1920, height: 1080, fps: 29.97),
      );
      expect(facts.audio.single.channels, 6);
      expect(facts.audio.single.bitRate, 128000);
      expect(facts.duration, isNull);
      expect(facts.bitRate, isNull);
    });

    test('zero and negative sizes, rates and lengths are not known', () {
      final facts = readFfprobeJson(
        probeJson(
          streams: [
            {
              'codec_type': 'video',
              'width': 0,
              'height': -1,
              'avg_frame_rate': '0/0',
              'r_frame_rate': '-25/1',
              'bit_rate': 0,
            },
          ],
          format: {'duration': '-1.0', 'bit_rate': -5},
        ),
      )!;
      expect(facts.video, const VideoFacts());
      expect(facts.duration, isNull);
      expect(facts.bitRate, isNull);
    });

    test('frame rates: fractions, whole numbers, nonsense', () {
      double? fps(Object? avg, [Object? r]) => readFfprobeJson(
        probeJson(
          streams: [
            {'codec_type': 'video', 'avg_frame_rate': avg, 'r_frame_rate': r},
          ],
        ),
      )!.video!.fps;
      expect(fps('50/1'), 50);
      expect(fps('24000/1001'), 23.976);
      expect(fps('25'), 25);
      expect(fps('0/0', '25/1'), 25);
      expect(fps('1/0', '50/1'), 50);
      expect(fps('abc'), isNull);
      expect(fps('100000/1'), isNull);
      expect(fps(25), isNull);
    });

    test('field orders', () {
      bool? interlaced(Object? order) => readFfprobeJson(
        probeJson(
          streams: [
            {'codec_type': 'video', 'field_order': order},
          ],
        ),
      )!.video!.interlaced;
      expect(interlaced('progressive'), isFalse);
      for (final order in ['tt', 'bb', 'tb', 'bt']) {
        expect(interlaced(order), isTrue, reason: order);
      }
      expect(interlaced('unknown'), isNull);
      expect(interlaced(null), isNull);
      expect(interlaced(1), isNull);
    });

    test('bit depth from the pixel format, else bits per sample', () {
      int? depth(Map<String, Object?> fields) => readFfprobeJson(
        probeJson(
          streams: [
            {'codec_type': 'video', ...fields},
          ],
        ),
      )!.video!.bitDepth;
      expect(depth({'pix_fmt': 'yuv420p'}), 8);
      expect(depth({'pix_fmt': 'yuv420p10le'}), 10);
      expect(depth({'pix_fmt': 'p010le'}), 10);
      expect(depth({'pix_fmt': 'yuv444p12be'}), 12);
      expect(depth({'pix_fmt': 'nv12'}), 8);
      expect(depth({'bits_per_raw_sample': '10'}), 10);
      expect(depth({}), isNull);
    });

    test('a cover picture is not the video', () {
      final facts = readFfprobeJson(
        probeJson(
          streams: [
            {
              'codec_type': 'video',
              'codec_name': 'mjpeg',
              'disposition': {'attached_pic': 1},
            },
            {
              'codec_type': 'video',
              'codec_name': 'png',
              'disposition': {'still_image': '1'},
            },
            {'codec_type': 'video', 'codec_name': 'h264', 'height': 720},
          ],
        ),
      )!;
      expect(facts.video?.codec, 'h264');
      expect(facts.video?.height, 720);
    });

    test('only covers is no video', () {
      final facts = readFfprobeJson(
        probeJson(
          streams: [
            {
              'codec_type': 'video',
              'codec_name': 'mjpeg',
              'disposition': {'attached_pic': 1},
            },
            {'codec_type': 'audio', 'codec_name': 'mp3'},
          ],
        ),
      )!;
      expect(facts.video, isNull);
      expect(facts.audio.single.codec, 'mp3');
    });

    test("audio tracks keep FFmpeg's numbers, unreadable ones included", () {
      final facts = readFfprobeJson(
        probeJson(
          streams: [
            {'codec_type': 'video', 'codec_name': 'h264'},
            {'codec_type': 'audio', 'codec_name': 'ac3'},
            {'codec_type': 'subtitle', 'codec_name': 'dvb_subtitle'},
            {'codec_type': 'audio'},
            {'codec_type': 'data'},
            {
              'codec_type': 'audio',
              'codec_name': 'aac',
              'tags': {'LANGUAGE': 'GER', 'TITLE': 'Deutsch'},
              'disposition': {'default': '1'},
            },
          ],
        ),
      )!;
      expect(facts.audio.map((a) => a.index), [0, 1, 2]);
      expect(facts.audio.map((a) => a.codec), ['ac3', null, 'aac']);
      expect(facts.audio[2].language, 'ger');
      expect(facts.audio[2].title, 'Deutsch');
      expect(facts.audio[2].isDefault, isTrue);
    });

    test('channels from the layout when the count is missing', () {
      int? channels(Object? layout) => readFfprobeJson(
        probeJson(
          streams: [
            {'codec_type': 'audio', 'channel_layout': layout},
          ],
        ),
      )!.audio.single.channels;
      expect(channels('5.1(side)'), 6);
      expect(channels('stereo'), 2);
      expect(channels('mono'), 1);
      expect(channels('7.1'), 8);
      expect(channels('weird'), isNull);
    });

    test('containers by format name', () {
      MediaContainer? container(String name) =>
          readFfprobeJson(probeJson(format: {'format_name': name}))!.container;
      expect(container('mpegts'), MediaContainer.mpegTs);
      expect(container('hls'), MediaContainer.hls);
      expect(container('applehttp'), MediaContainer.hls);
      expect(container('mov,mp4,m4a,3gp,3g2,mj2'), MediaContainer.mp4);
      expect(container('matroska,webm'), MediaContainer.matroska);
      expect(container('flv'), MediaContainer.other);
      expect(container('N/A'), isNull);
    });

    test('codec "none" and profile "unknown" are not known', () {
      final facts = readFfprobeJson(
        probeJson(
          streams: [
            {'codec_type': 'video', 'codec_name': 'none', 'profile': 'unknown'},
          ],
        ),
      )!;
      expect(facts.video, const VideoFacts());
    });

    test('25,000 corrupted answers never throw', () {
      final random = Random(7);
      final seeds = [
        for (final name in [
          'h264_1080i50_mp2',
          'vod_h264_aac_10min',
          'vod_hevc_eac3_subs',
        ])
          probeFixture(name),
      ];
      const junk = '{}[]":,0123456789.-/aeNA \n';
      for (var round = 0; round < 25000; round++) {
        final chars = seeds[round % seeds.length].split('');
        final edits = 1 + random.nextInt(8);
        for (var e = 0; e < edits; e++) {
          final at = random.nextInt(chars.length);
          switch (random.nextInt(3)) {
            case 0:
              chars.removeAt(at);
            case 1:
              chars.insert(at, junk[random.nextInt(junk.length)]);
            default:
              chars[at] = junk[random.nextInt(junk.length)];
          }
        }
        final text = round.isEven
            ? chars.join()
            : chars.take(random.nextInt(chars.length)).join();
        readFfprobeJson(text);
      }
    });

    test('25,000 well-formed answers of the wrong types never throw', () {
      final random = Random(11);
      final values = <Object?>[
        null,
        true,
        0,
        -1,
        1.5,
        double.maxFinite,
        '',
        'N/A',
        '1/0',
        'x',
        const <Object?>[],
        const <String, Object?>{},
        const {'default': 'yes'},
        const {'language': 7},
      ];
      const fields = [
        'codec_type',
        'codec_name',
        'profile',
        'width',
        'height',
        'avg_frame_rate',
        'r_frame_rate',
        'field_order',
        'pix_fmt',
        'bits_per_raw_sample',
        'bit_rate',
        'channels',
        'channel_layout',
        'tags',
        'disposition',
      ];
      Object? any() => values[random.nextInt(values.length)];
      for (var round = 0; round < 25000; round++) {
        final streams = [
          for (var s = 0; s < random.nextInt(4); s++)
            {
              'codec_type': random.nextBool() ? 'video' : 'audio',
              for (final field in fields)
                if (random.nextBool()) field: any(),
            },
        ];
        readFfprobeJson(
          jsonEncode({
            'streams': random.nextInt(10) == 0 ? any() : streams,
            'format': random.nextBool()
                ? any()
                : {'format_name': any(), 'duration': any(), 'bit_rate': any()},
          }),
        );
      }
    });
  });
}
