import 'package:flutter_test/flutter_test.dart';
import 'package:iptv_player/core/cast/stream_facts.dart';
import 'package:iptv_player/data/cast/relay/ffmpeg_log.dart';
import 'package:iptv_player/data/cast/relay/isolate_cast_relay.dart';

/// FFmpeg's standard error under `-loglevel repeat+level+info`, as the
/// relay reads it: levels, and the input's description (Phase 7 decision
/// 4). The descriptions are FFmpeg's own, from the bundled 8.1 and CI's
/// 4.4 reading the media samples.
void main() {
  FfmpegInputReport? read(String text) {
    final reader = FfmpegInputReader();
    for (final line in text.trim().split('\n')) {
      final report = reader.add(parseFfmpegLine(line));
      if (report != null) return report;
    }
    return null;
  }

  group('a line', () {
    test('with a context and a level', () {
      final line = parseFfmpegLine(
        '[mpegts @ 0x5c8d49a2d300] [warning] Packet corrupt (stream = 0)',
      );
      expect(line.level, FfmpegLevel.warning);
      expect(line.context, 'mpegts');
      expect(line.text, 'Packet corrupt (stream = 0)');
      expect('$line', 'mpegts: Packet corrupt (stream = 0)');
      expect(line.level.worrying, isTrue);
    });

    test('with a level only', () {
      final line = parseFfmpegLine('[info]   Duration: N/A, start: 1.4');
      expect(line.level, FfmpegLevel.info);
      expect(line.context, isNull);
      expect(line.text, '  Duration: N/A, start: 1.4');
      expect(line.level.worrying, isFalse);
    });

    test("an output's context, with a slash", () {
      final line = parseFfmpegLine(
        '[out#0/hls @ 0x5c8d49a7d440] [error] Error writing trailer',
      );
      expect(line.context, 'out#0/hls');
      expect(line.level, FfmpegLevel.error);
    });

    test('without a level', () {
      final line = parseFfmpegLine('Exiting normally, received signal 15.');
      expect(line.level, FfmpegLevel.unknown);
      expect(line.text, 'Exiting normally, received signal 15.');
      expect(line.level.worrying, isFalse);
    });

    test('every level that worries', () {
      for (final level in ['panic', 'fatal', 'error', 'warning']) {
        expect(parseFfmpegLine('[$level] x').level.worrying, isTrue);
      }
      for (final level in ['info', 'verbose', 'debug', 'trace']) {
        expect(parseFfmpegLine('[$level] x').level.worrying, isFalse);
      }
    });

    test('a stream that appears mid-way', () {
      expect(
        isNewStreamLine(
          parseFfmpegLine(
            '[in#0/mpegts @ 0x55] [warning] New video stream with index 2 at '
            'pos:5531712 and DTS:7.1s',
          ),
        ),
        isTrue,
      );
      expect(
        isNewStreamLine(
          parseFfmpegLine('[warning] New audio stream 0:3 at pos:1'),
        ),
        isTrue,
      );
      expect(
        isNewStreamLine(parseFfmpegLine('[warning] New subtitle stream 0:4')),
        isFalse,
      );
      expect(
        isNewStreamLine(parseFfmpegLine('[warning] Packet corrupt')),
        isFalse,
      );
    });
  });

  group("the input's description", () {
    test('H.264 1080p50 and AAC in MPEG-TS (8.1)', () {
      final report = read('''
[info] Input #0, mpegts, from 'http://127.0.0.1:41235/in/9f2c':
[info]   Duration: N/A, start: 1.418667, bitrate: N/A
[info]   Program 1
[info]     Metadata:
[info]       service_name    : h264_1080p50_aac
[info]   Stream #0:0[0x100]: Video: h264 (High) ([27][0][0][0] / 0x001B), yuv420p(progressive), 1920x1080 [SAR 1:1 DAR 16:9], 50 fps, 50 tbr, 90k tbn, start 1.440000
[info]   Stream #0:1[0x101]: Audio: aac (LC) ([15][0][0][0] / 0x000F), 48000 Hz, stereo, fltp, 130 kb/s, start 1.418667
[info] Stream mapping:
[info]   Stream #0:0 -> #0:0 (copy)
''')!;
      expect(report.container, 'mpegts');
      expect(report.duration, isNull);
      final video = report.video!;
      expect(video.codec, 'h264');
      expect(video.profile, 'High');
      expect(video.pixelFormat, 'yuv420p');
      expect(video.bitDepth, 8);
      expect((video.width, video.height), (1920, 1080));
      expect(video.fps, 50);
      expect(video.interlaced, isFalse);
      final audio = report.audio.single;
      expect(audio.codec, 'aac');
      expect(audio.profile, 'LC');
      expect(audio.layout, 'stereo');
      expect(audio.bitRate, 130000);
      expect(audio.language, isNull);
      expect(audio.isDefault, isFalse);
    });

    test('AC-3 5.1 as 4.4 writes it, its codec tag no profile', () {
      final report = read('''
[info] Input #0, mpegts, from 'http://127.0.0.1:41235/in/9f2c':
[info]   Duration: 00:01:00.01, start: 1.474667, bitrate: 500 kb/s
[info]   Stream #0:0[0x100]: Video: h264 (High) ([27][0][0][0] / 0x001B), yuv420p(tv, bt470bg/unknown/unknown, progressive), 1920x1080 [SAR 1:1 DAR 16:9], 25 fps, 25 tbr, 90k tbn, 50 tbc
[info]   Stream #0:1[0x101]: Audio: ac3 (AC-3 / 0x332D4341), 48000 Hz, 5.1(side), fltp, 384 kb/s
[info] Stream mapping:
''')!;
      expect(report.duration, const Duration(minutes: 1, milliseconds: 10));
      expect(report.video!.interlaced, isFalse);
      expect(report.video!.fps, 25);
      final audio = report.audio.single;
      expect(audio.codec, 'ac3');
      expect(audio.profile, isNull);
      expect(audio.layout, '5.1(side)');
      expect(audio.bitRate, 384000);
    });

    test('MPEG-2 576i, top field first', () {
      final report = read('''
[info] Input #0, mpegts, from 'http://127.0.0.1:41235/in/9f2c':
[info]   Duration: 00:01:00.01, start: 1.429978, bitrate: 4343 kb/s
[info]   Stream #0:0[0x100]: Video: mpeg2video (Main) ([2][0][0][0] / 0x0002), yuv420p(tv, top first), 720x576 [SAR 16:15 DAR 4:3], 25 fps, 25 tbr, 90k tbn, start 1.440000
[info]   Stream #0:1[0x101]: Audio: mp2 (mp3float) ([3][0][0][0] / 0x0003), 48000 Hz, stereo, fltp, 192 kb/s, start 1.429978
[info] Output #0, hls, to '/tmp/relay/cast-1-0/index.m3u8':
''')!;
      final video = report.video!;
      expect(video.codec, 'mpeg2video');
      expect(video.profile, 'Main');
      expect(video.interlaced, isTrue);
      expect((video.width, video.height), (720, 576));
      expect(report.audio.single.codec, 'mp2');
    });

    test(
      'Matroska: languages, the default, subtitles and a cover left out',
      () {
        final report = read('''
[info] Input #0, matroska,webm, from 'http://127.0.0.1:41235/in/9f2c':
[info]   Metadata:
[info]     title           : VOD HEVC E-AC-3 with subtitles
[info]   Duration: 00:10:00.00, start: 0.000000, bitrate: 513 kb/s
[info]   Stream #0:0: Video: png, rgba(pc), 600x900, 90k tbr, 90k tbn (attached pic)
[info]   Stream #0:1: Video: hevc (Main 10), yuv420p10le(tv, bt2020nc/bt2020/smpte2084), 3840x2160 [SAR 1:1 DAR 16:9], 23.98 fps, 23.98 tbr, 1k tbn
[info]     Metadata:
[info]       ENCODER         : Lavc62.28.102 libx265
[info]   Stream #0:2(eng): Audio: eac3, 48000 Hz, 5.1(side), fltp, 384 kb/s (default)
[info]   Stream #0:3(ger): Audio: aac (LC), 48000 Hz, stereo, fltp
[info]   Stream #0:4(und): Audio: ac3, 48000 Hz, mono, fltp, 96 kb/s
[info]   Stream #0:5(eng): Subtitle: subrip (srt) (default)
[info] Stream mapping:
''')!;
        expect(report.container, 'matroska,webm');
        expect(report.duration, const Duration(minutes: 10));
        final video = report.video!;
        expect(video.codec, 'hevc');
        expect(video.profile, 'Main 10');
        expect(video.bitDepth, 10);
        expect(video.height, 2160);
        expect(video.fps, closeTo(23.98, 0.001));
        expect(video.interlaced, isNull);
        expect([for (final a in report.audio) a.codec], ['eac3', 'aac', 'ac3']);
        expect(
          [for (final a in report.audio) a.language],
          ['eng', 'ger', null],
        );
        expect(
          [for (final a in report.audio) a.isDefault],
          [true, false, false],
        );
        expect(report.audio[1].bitRate, isNull);
      },
    );

    test('a stream with no picture', () {
      final report = read('''
[info] Input #0, mpegts, from 'http://127.0.0.1:41235/in/9f2c':
[info]   Stream #0:0[0x101]: Audio: mp2, 48000 Hz, stereo, fltp, 128 kb/s
[info] Stream mapping:
''')!;
      expect(report.video, isNull);
      expect(report.audio.single.codec, 'mp2');
    });

    test('comes once, and only after the input is described', () {
      final reader = FfmpegInputReader();
      expect(
        reader.add(parseFfmpegLine('[info] Stream mapping:')),
        isNull,
        reason: 'no input yet',
      );
      reader.add(parseFfmpegLine("[info] Input #0, mpegts, from 'x':"));
      expect(reader.add(parseFfmpegLine('[info] Stream mapping:')), isNotNull);
      expect(reader.add(parseFfmpegLine('[info] Stream mapping:')), isNull);
    });

    test('odd lines are read as far as they go, never thrown', () {
      final report = read('''
[info] Input #0, mpegts, from 'x':
[info]   Duration: garbage
[info]   Stream #0:0: Video: , , ,
[info]   Stream #0:1: Audio:
[info]   Stream #0:2: Video: h264 (High), yuv420p, 99999999x1 fps
[info] Output #0, mp4, to 'pipe:':
''')!;
      expect(report.duration, isNull);
      expect(report.audio, isEmpty, reason: 'no codec, no stream');
      expect(report.video!.codec, 'h264');
      expect(report.video!.height, isNull);
    });
  });

  group('bit depth from the pixel format', () {
    for (final (format, depth) in [
      ('yuv420p', 8),
      ('yuvj420p', 8),
      ('nv12', 8),
      ('yuv420p10le', 10),
      ('yuv422p10be', 10),
      ('yuv420p12le', 12),
      ('p010le', 10),
      ('p016le', 16),
      ('gray', 8),
    ]) {
      test(format, () {
        expect(
          FfmpegVideoStream(codec: 'x', pixelFormat: format).bitDepth,
          depth,
        );
      });
    }
  });

  test("the report as the plan's facts", () {
    const report = FfmpegInputReport(
      container: 'mov,mp4,m4a,3gp,3g2,mj2',
      duration: Duration(minutes: 10),
      video: FfmpegVideoStream(
        codec: 'h264',
        profile: 'High',
        pixelFormat: 'yuv420p',
        width: 1920,
        height: 1080,
        fps: 25,
        interlaced: false,
      ),
      audio: [
        FfmpegAudioStream(codec: 'ac3', layout: '5.1(side)', language: 'eng'),
        FfmpegAudioStream(codec: 'aac', layout: 'stereo', isDefault: true),
      ],
    );
    final facts = streamFactsFromFfmpeg(report);
    expect(facts.origin, StreamFactsOrigin.relay);
    expect(facts.container, MediaContainer.mp4);
    expect(facts.duration, const Duration(minutes: 10));
    expect(
      facts.video,
      const VideoFacts(
        codec: 'h264',
        profile: 'High',
        width: 1920,
        height: 1080,
        fps: 25,
        interlaced: false,
        bitDepth: 8,
      ),
    );
    expect(facts.audio, const [
      AudioFacts(index: 0, codec: 'ac3', channels: 6, language: 'eng'),
      AudioFacts(index: 1, codec: 'aac', channels: 2, isDefault: true),
    ]);
    expect(
      streamFactsFromFfmpeg(const FfmpegInputReport(container: 'mpegts'))
          .container,
      MediaContainer.mpegTs,
    );
    expect(
      streamFactsFromFfmpeg(const FfmpegInputReport(container: 'matroska,webm'))
          .container,
      MediaContainer.matroska,
    );
    expect(
      streamFactsFromFfmpeg(const FfmpegInputReport(container: 'hls'))
          .container,
      MediaContainer.hls,
    );
    expect(
      streamFactsFromFfmpeg(const FfmpegInputReport(container: 'flv'))
          .container,
      MediaContainer.other,
    );
  });
}
